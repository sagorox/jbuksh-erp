import 'dart:convert';

import 'package:hive/hive.dart';

import 'api.dart';
import 'local_store.dart';

class SyncService {
  static const _supportedServerEntities = <String>{
    'party',
    'invoice',
    'collection',
    'expense',
    'attendance',
  };

  static const int _maxBackoffMinutes = 60;

  static String _normalizeServerEntity(String raw) {
    return LocalStore.canonicalEntity(raw);
  }

  static Future<Map<String, int>> syncAll() async {
    final deviceId = LocalStore.deviceId() ?? 'unknown-device';

    int pushed = 0;
    int conflicts = 0;
    int skipped = 0;
    int retried = 0;
    int pulled = 0;

    try {
      final pushRes = await push(deviceId: deviceId);
      pushed = pushRes['pushed'] ?? 0;
      conflicts = pushRes['conflicts'] ?? 0;
      skipped = pushRes['skipped'] ?? 0;
      retried = pushRes['retried'] ?? 0;
    } catch (e) {
      Hive.box('cacheBox').put(
        'last_sync_error',
        e.toString().replaceAll('Exception: ', ''),
      );
    }

    try {
      pulled = await pull();
    } catch (e) {
      Hive.box('cacheBox').put(
        'last_pull_error',
        e.toString().replaceAll('Exception: ', ''),
      );
    }

    final cache = Hive.box('cacheBox');
    await cache.put(
      'last_sync_result',
      {
        'pushed': pushed,
        'conflicts': conflicts,
        'skipped': skipped,
        'retried': retried,
        'pulled': pulled,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    return {
      'pushed': pushed,
      'conflicts': conflicts,
      'skipped': skipped,
      'retried': retried,
      'pulled': pulled,
    };
  }

  static Future<void> bootstrapAndStore({bool force = false}) async {
    final auth = Hive.box('auth');
    final cache = Hive.box('cacheBox');
    final bootstrapped = auth.get('bootstrapped') == true;

    if (bootstrapped && !force) {
      return;
    }

    final res = await Api.getJson('/api/v1/sync/bootstrap');
    await cache.put('bootstrap_response', res);
    final master = (res['master'] as Map?)?.cast<String, dynamic>() ?? const {};
    final scoped = (res['scoped'] as Map?)?.cast<String, dynamic>() ?? const {};
    final serverTime =
    (res['serverTime'] ?? DateTime.now().toUtc().toIso8601String())
        .toString();

    await _replaceBoxWithList('territories', master['territories']);
    await _replaceBoxWithList('categories', master['categories']);
    await _replaceBoxWithList('products', master['products']);

    await _replaceBoxWithList('parties', scoped['parties']);
    await _replaceBoxWithList('invoices', scoped['invoices']);
    await _replaceBoxWithList('collections', scoped['collections']);
    await _replaceBoxWithList('expenses', scoped['expenses']);
    await _replaceBoxWithList('deliveries', scoped['deliveries']);
    await _replaceBoxWithList('attendance', scoped['attendance']);

    if (scoped.containsKey('notifications')) {
      await _replaceBoxWithList('notifications', scoped['notifications']);
    }
    if (scoped.containsKey('vouchers')) {
      await _replaceBoxWithList('vouchers', scoped['vouchers']);
    }
    if (res['users'] is List) {
      await cache.put('users', (res['users'] as List));
    }
    if (res['schedules'] is List) {
      await cache.put('schedules', (res['schedules'] as List));
    }

    await auth.put('bootstrapped', true);
    await auth.put('last_bootstrap', serverTime);
    await cache.put('lastSyncAt', serverTime);
  }

  static Future<void> enqueue({
    required String entity,
    required String op,
    required String uuid,
    required int version,
    required Map<String, dynamic> payload,
    String? deviceId,
  }) async {
    final entityName = _normalizeServerEntity(entity);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final outbox = Hive.box('outboxBox');

    final entry = <String, dynamic>{
      'entity': entityName,
      'op': op.toUpperCase(),
      'uuid': uuid,
      'version': version,
      'payload': jsonDecode(jsonEncode(payload)),
      'deviceId': deviceId ?? LocalStore.deviceId() ?? 'unknown-device',
      'created_at_client': nowIso,
      'queued_at': nowIso,
      'retry_count': 0,
      'next_retry_at': null,
      'last_error': null,
    };

    final key = '${DateTime.now().microsecondsSinceEpoch}-$uuid';
    await outbox.put(key, entry);
  }

  static Future<Map<String, int>> push({required String deviceId}) async {
    final outbox = Hive.box('outboxBox');
    final cache = Hive.box('cacheBox');

    if (outbox.isEmpty) {
      return {'pushed': 0, 'conflicts': 0, 'skipped': 0, 'retried': 0};
    }

    final lastSyncAt = cache.get('lastSyncAt')?.toString();
    final now = DateTime.now().toUtc();

    final items = <_QueuedChange>[];
    int skipped = 0;

    for (final key in outbox.keys) {
      final raw = outbox.get(key);
      if (raw is! Map) continue;

      final row = raw.cast<String, dynamic>();
      final entity = _normalizeServerEntity((row['entity'] ?? '').toString());
      final uuid = (row['uuid'] ?? '').toString();
      final op = (row['op'] ?? 'UPSERT').toString().toUpperCase();

      if (uuid.isEmpty || !_supportedServerEntities.contains(entity)) {
        skipped++;
        continue;
      }

      final nextRetryAt = row['next_retry_at']?.toString();
      if (nextRetryAt != null && nextRetryAt.isNotEmpty) {
        final dueAt = DateTime.tryParse(nextRetryAt)?.toUtc();
        if (dueAt != null && dueAt.isAfter(now)) {
          skipped++;
          continue;
        }
      }

      final rawPayload = (row['payload'] is Map)
          ? (row['payload'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final sanitized = _sanitizePayload(
        entity: entity,
        op: op,
        uuid: uuid,
        payload: rawPayload,
      );

      items.add(
        _QueuedChange(
          key: key,
          entity: entity,
          op: op,
          uuid: uuid,
          version: int.tryParse((row['version'] ?? 1).toString()) ?? 1,
          payload: sanitized,
          row: row,
        ),
      );
    }

    if (items.isEmpty) {
      return {'pushed': 0, 'conflicts': 0, 'skipped': skipped, 'retried': 0};
    }

    items.sort((a, b) {
      final aTs =
      (a.row['queued_at'] ?? a.row['created_at_client'] ?? '').toString();
      final bTs =
      (b.row['queued_at'] ?? b.row['created_at_client'] ?? '').toString();
      return aTs.compareTo(bTs);
    });

    final latestByUuid = <String, _QueuedChange>{};
    for (final item in items) {
      latestByUuid[item.uuid] = item;
    }

    final requestChanges = latestByUuid.values.map((item) {
      return <String, dynamic>{
        'entity': item.entity,
        'op': item.op,
        'uuid': item.uuid,
        'version': item.version,
        'payload': item.payload,
      };
    }).toList();

    Map<String, dynamic> res;
    try {
      res = await Api.postJson('/api/v1/sync/push', {
        'deviceId': deviceId,
        'lastSyncAt': lastSyncAt,
        'changes': requestChanges,
      });
    } catch (e) {
      int retried = 0;
      for (final item in latestByUuid.values) {
        await _markRetry(item.key, item.row, e.toString());
        retried++;
      }
      return {
        'pushed': 0,
        'conflicts': 0,
        'skipped': skipped,
        'retried': retried,
      };
    }

    final results = (res['results'] as List?) ?? const [];
    int pushed = 0;
    int conflicts = 0;
    int retried = 0;

    for (final result in results) {
      if (result is! Map) continue;
      final row = result.cast<String, dynamic>();
      final uuid = (row['uuid'] ?? '').toString();
      if (uuid.isEmpty) continue;

      final item = latestByUuid[uuid];
      if (item == null) continue;

      final status = (row['status'] ?? '').toString().toUpperCase();

      if (status == 'OK') {
        pushed++;
        await LocalStore.removeOutboxByUuid(uuid);
        continue;
      }

      if (status == 'CONFLICT') {
        conflicts++;
        final server = (row['server_snapshot'] is Map)
            ? (row['server_snapshot'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};

        await LocalStore.putConflict(
          uuid: uuid,
          entity: item.entity,
          op: item.op,
          local: item.payload,
          server: server,
          serverVersion: row['server_version'],
          message: row['message']?.toString(),
        );
        continue;
      }

      retried++;
      await _markRetry(
        item.key,
        item.row,
        row['message']?.toString() ?? 'Push failed',
      );
    }

    cache.put('lastSyncAt', DateTime.now().toUtc().toIso8601String());

    return {
      'pushed': pushed,
      'conflicts': conflicts,
      'skipped': skipped,
      'retried': retried,
    };
  }

  static Future<int> pull() async {
    final cache = Hive.box('cacheBox');
    final since = cache.get('lastSyncAt')?.toString();

    if (since == null || since.isEmpty) {
      await bootstrapAndStore(force: true);
      final nowTs = DateTime.now().toUtc().toIso8601String();
      cache.put('lastSyncAt', nowTs);
      return 0;
    }

    final path = '/api/v1/sync/pull?since=${Uri.encodeComponent(since)}';
    final res = await Api.getJson(path);

    final changes = (res['changes'] as List?) ?? const [];
    final serverTime =
    (res['serverTime'] ?? DateTime.now().toUtc().toIso8601String())
        .toString();

    if (changes.isNotEmpty) {
      await bootstrapAndStore(force: true);
    }

    cache.put('lastSyncAt', serverTime);
    return changes.length;
  }

  static Future<void> _replaceBoxWithList(String boxName, dynamic listAny) async {
    final box = Hive.box(boxName);
    await box.clear();

    final list = (listAny as List?) ?? const [];
    for (final item in list) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final key = (m['id'] ?? m['uuid'])?.toString();
      final normalized = jsonDecode(jsonEncode(m));
      if (key != null && key.isNotEmpty) {
        await box.put(key, normalized);
      } else {
        await box.add(normalized);
      }
    }
  }

  static Future<void> _markRetry(
      dynamic key,
      Map<String, dynamic> row,
      String error,
      ) async {
    final outbox = Hive.box('outboxBox');
    final retryCount =
        (int.tryParse((row['retry_count'] ?? 0).toString()) ?? 0) + 1;
    final delayMinutes = _retryDelayMinutes(retryCount);
    final nextRetryAt =
    DateTime.now().toUtc().add(Duration(minutes: delayMinutes));

    final updated = Map<String, dynamic>.from(row);
    updated['retry_count'] = retryCount;
    updated['last_error'] = error.replaceAll('Exception: ', '');
    updated['last_error_at'] = DateTime.now().toUtc().toIso8601String();
    updated['next_retry_at'] = nextRetryAt.toIso8601String();

    await outbox.put(key, updated);
  }

  static int _retryDelayMinutes(int retryCount) {
    final value = 1 << (retryCount - 1);
    if (value > _maxBackoffMinutes) return _maxBackoffMinutes;
    return value;
  }

  static Map<String, dynamic> _sanitizePayload({
    required String entity,
    required String op,
    required String uuid,
    required Map<String, dynamic> payload,
  }) {
    final source = Map<String, dynamic>.from(payload);

    switch (entity) {
      case 'party':
        return {
          'uuid': uuid,
          'territory_id':
          _toInt(source['territory_id']) ??
              LocalStore.primaryTerritoryId() ??
              0,
          'assigned_mpo_user_id':
          _toInt(source['assigned_mpo_user_id']) ?? LocalStore.userId(),
          'party_code':
          _toStr(source['party_code']) ?? _toStr(source['uuid']) ?? uuid,
          'name': _toStr(source['name']) ?? 'Unnamed Party',
          'credit_limit': _toNum(source['credit_limit']),
          'is_active': _toInt(source['is_active']) ?? 1,
          'version': _toInt(source['version']) ?? 1,
        };

      case 'invoice':
        return {
          'uuid': uuid,
          'invoice_no': _toStr(source['invoice_no']),
          'mpo_user_id': _toInt(source['mpo_user_id']) ?? LocalStore.userId(),
          'territory_id':
          _toInt(source['territory_id']) ??
              LocalStore.primaryTerritoryId() ??
              0,
          'party_id': _toInt(source['party_id']) ?? 0,
          'invoice_date': _toStr(source['invoice_date']) ??
              DateTime.now().toIso8601String().substring(0, 10),
          'invoice_time': _normalizeTime(source['invoice_time']),
          'status': _toStr(source['status']) ?? 'DRAFT',
          'subtotal': _toNum(source['subtotal']),
          'discount_percent': _toNum(source['discount_percent']),
          'discount_amount': _toNum(source['discount_amount']),
          'net_total': _toNum(source['net_total']),
          'received_amount': _toNum(source['received_amount']),
          'due_amount': _toNum(source['due_amount']),
          'remarks': _toNullableStr(source['remarks']),
          'pdf_url': _toNullableStr(source['pdf_url']),
          'items': _normalizeItems(source['items']),
          'version': _toInt(source['version']) ?? 1,
        };

      case 'collection':
        return {
          'uuid': uuid,
          'collection_no': _toStr(source['collection_no']) ?? uuid,
          'territory_id':
          _toInt(source['territory_id']) ??
              LocalStore.primaryTerritoryId() ??
              0,
          'party_id': _toInt(source['party_id']) ?? 0,
          'mpo_user_id': _toInt(source['mpo_user_id']) ?? LocalStore.userId(),
          'collection_date': _toStr(source['collection_date']) ??
              DateTime.now().toIso8601String().substring(0, 10),
          'method': _toStr(source['method']) ?? 'CASH',
          'amount': _toNum(source['amount']),
          'reference_no': _toNullableStr(source['reference_no']),
          'status': _toStr(source['status']) ?? 'DRAFT',
          'allocations': _normalizeItems(source['allocations']),
          'version': _toInt(source['version']) ?? 1,
        };

      case 'expense':
        return {
          'uuid': uuid,
          'territory_id':
          _toInt(source['territory_id']) ??
              LocalStore.primaryTerritoryId() ??
              0,
          'user_id': _toInt(source['user_id']) ?? LocalStore.userId(),
          'expense_head_id': _toInt(source['expense_head_id']) ?? 0,
          'amount': _toNum(source['amount']),
          'expense_date': _toStr(source['expense_date']) ??
              DateTime.now().toIso8601String().substring(0, 10),
          'note': _toNullableStr(source['note']),
          'status': _toStr(source['status']) ?? 'DRAFT',
          'version': _toInt(source['version']) ?? 1,
        };

      case 'attendance':
        return {
          'uuid': uuid,
          'user_id': _toInt(source['user_id']) ?? LocalStore.userId(),
          'territory_id':
          _toInt(source['territory_id']) ??
              LocalStore.primaryTerritoryId() ??
              0,
          'attendance_date': _toStr(source['attendance_date']) ??
              DateTime.now().toIso8601String().substring(0, 10),
          'check_in': _toNullableStr(source['check_in']),
          'check_out': _toNullableStr(source['check_out']),
          'status': _toStr(source['status']) ?? 'PRESENT',
          'version': _toInt(source['version']) ?? 1,
        };

      default:
        return {
          ...source,
          'uuid': uuid,
          'version': _toInt(source['version']) ?? 1,
        };
    }
  }

  static List<Map<String, dynamic>> _normalizeItems(dynamic raw) {
    final list = (raw as List?) ?? const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static num _toNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  static String? _toStr(dynamic value) {
    if (value == null) return null;
    final v = value.toString().trim();
    return v.isEmpty ? null : v;
  }

  static String? _toNullableStr(dynamic value) {
    final v = _toStr(value);
    return v == null || v.isEmpty ? null : v;
  }

  static String? _normalizeTime(dynamic value) {
    final v = _toStr(value);
    if (v == null) return null;
    if (v.length >= 5) return v.substring(0, 5);
    return v;
  }
}

class _QueuedChange {
  final dynamic key;
  final String entity;
  final String op;
  final String uuid;
  final int version;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> row;

  _QueuedChange({
    required this.key,
    required this.entity,
    required this.op,
    required this.uuid,
    required this.version,
    required this.payload,
    required this.row,
  });
}