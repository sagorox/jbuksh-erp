import 'package:hive/hive.dart';

class LocalStore {
  static List<Map<String, dynamic>> allBoxMaps(String boxName) {
    final box = Hive.box(boxName);
    return box.values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  static String role() {
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    return (user['role'] ?? '').toString();
  }

  static int? userId() {
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final raw = user['id'] ?? user['sub'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  static int? primaryTerritoryId() {
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final territoryIds = (user['territory_ids'] as List?) ?? const [];
    if (territoryIds.isEmpty) return null;
    return int.tryParse(territoryIds.first.toString());
  }

  static String? deviceId() {
    final auth = Hive.box('auth');
    final raw = auth.get('deviceId');
    return raw?.toString();
  }

  static Future<int> putMap(String boxName, Map<String, dynamic> value) async {
    final box = Hive.box(boxName);
    return await box.add(value);
  }

  static Future<void> upsertByUuid(
      String boxName,
      Map<String, dynamic> value,
      ) async {
    final box = Hive.box(boxName);
    final uuid = value['uuid'];
    if (uuid == null) {
      await box.add(value);
      return;
    }
    for (final k in box.keys) {
      final v = box.get(k);
      if (v is Map && v['uuid'] == uuid) {
        await box.put(k, value);
        return;
      }
    }
    await box.add(value);
  }

  static String canonicalEntity(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'party':
      case 'parties':
        return 'party';
      case 'invoice':
      case 'invoices':
        return 'invoice';
      case 'collection':
      case 'collections':
        return 'collection';
      case 'expense':
      case 'expenses':
        return 'expense';
      case 'attendance':
        return 'attendance';
      case 'product_batch':
      case 'product_batches':
      case 'batch':
      case 'batches':
        return 'product_batch';
      default:
        return raw.trim().toLowerCase();
    }
  }

  static String boxNameForEntity(String raw) {
    switch (canonicalEntity(raw)) {
      case 'party':
        return 'parties';
      case 'invoice':
        return 'invoices';
      case 'collection':
        return 'collections';
      case 'expense':
        return 'expenses';
      case 'attendance':
        return 'attendance';
      case 'product_batch':
        return 'product_batches';
      default:
        return raw.trim().toLowerCase();
    }
  }

  static Future<void> upsertEntitySnapshot(
      String entity,
      Map<String, dynamic> snapshot,
      ) async {
    await upsertByUuid(boxNameForEntity(entity), snapshot);
  }

  static Future<void> removeOutboxByUuid(String uuid) async {
    final outbox = Hive.box('outboxBox');
    final keys = outbox.keys.toList();
    for (final k in keys) {
      final v = outbox.get(k);
      if (v is Map && (v['uuid']?.toString() ?? '') == uuid) {
        await outbox.delete(k);
      }
    }
  }

  static Future<void> putConflict({
    required String uuid,
    required String entity,
    required String op,
    required Map<String, dynamic> local,
    required Map<String, dynamic> server,
    dynamic serverVersion,
    String? message,
  }) async {
    final conflicts = Hive.box('conflicts');
    await conflicts.put(uuid, {
      'uuid': uuid,
      'entity': canonicalEntity(entity),
      'op': op,
      'local': local,
      'server': server,
      'server_snapshot': server,
      'server_version': serverVersion,
      'message': message,
      'received_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> removeConflictByUuid(String uuid) async {
    final box = Hive.box('conflicts');
    final keys = box.keys.toList();
    for (final k in keys) {
      final v = box.get(k);
      if (v is Map && (v['uuid']?.toString() ?? '') == uuid) {
        await box.delete(k);
      }
    }
  }
}