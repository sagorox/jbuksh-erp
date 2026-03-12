import 'package:hive/hive.dart';

class OfflineCache {
  static List<Map<String, dynamic>> _boxMaps(String name) {
    if (!Hive.isBoxOpen(name)) return const [];
    final box = Hive.box(name);
    return box.values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  static List<Map<String, dynamic>> _cacheMaps(String key) {
    if (!Hive.isBoxOpen('cacheBox')) return const [];
    final raw = Hive.box('cacheBox').get(key);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  static List<Map<String, dynamic>> _filterByParty(
    List<Map<String, dynamic>> rows,
    String? partyId,
  ) {
    if (partyId == null || partyId.isEmpty) return rows;
    return rows
        .where((e) => '${e['party_id'] ?? e['party']?['id'] ?? ''}' == partyId)
        .toList();
  }

  static List<Map<String, dynamic>> _filterUsers(
    List<Map<String, dynamic>> rows,
    String? q,
  ) {
    final query = (q ?? '').trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows.where((e) {
      final name = (e['full_name'] ?? '').toString().toLowerCase();
      final phone = (e['phone'] ?? '').toString().toLowerCase();
      final role = (e['role'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query) || role.contains(query);
    }).toList();
  }

  static Map<String, dynamic> _bootstrapPayload() {
    return {
      'master': {
        'territories': _boxMaps('territories'),
        'categories': _boxMaps('categories'),
        'products': _boxMaps('products'),
      },
      'scoped': {
        'parties': _boxMaps('parties'),
        'invoices': _boxMaps('invoices'),
        'collections': _boxMaps('collections'),
        'expenses': _boxMaps('expenses'),
        'deliveries': _boxMaps('deliveries'),
        'attendance': _boxMaps('attendance'),
        'notifications': _boxMaps('notifications'),
        'vouchers': _boxMaps('vouchers'),
      },
      'users': _cacheMaps('users'),
      'schedules': _cacheMaps('schedules'),
      'serverTime': Hive.isBoxOpen('cacheBox')
          ? (Hive.box('cacheBox').get('lastSyncAt') ?? DateTime.now().toUtc().toIso8601String())
          : DateTime.now().toUtc().toIso8601String(),
      'offline': true,
    };
  }

  static List<Map<String, dynamic>> _pendingApprovals() {
    final out = <Map<String, dynamic>>[];

    for (final row in _boxMaps('attendance')) {
      final status = (row['approval_status'] ?? row['status'] ?? '')
          .toString()
          .toUpperCase();
      if (status == 'SUBMITTED' || status == 'PENDING') {
        out.add({
          'id': row['id'] ?? row['uuid'],
          'entity_type': 'ATTENDANCE',
          'entity_id': row['id'] ?? row['uuid'],
          'status': 'PENDING',
          'requested_by': row['user_id'],
          'payload': row,
          'created_at': row['created_at'] ?? row['att_date'] ?? row['attendance_date'],
        });
      }
    }

    for (final boxName in ['invoices', 'collections', 'expenses']) {
      for (final row in _boxMaps(boxName)) {
        final approvalStatus = (row['approval_status'] ?? '').toString().toUpperCase();
        final status = (row['status'] ?? '').toString().toUpperCase();
        final needsApproval = approvalStatus == 'SUBMITTED' ||
            approvalStatus == 'PENDING' ||
            status == 'SUBMITTED' ||
            status == 'PENDING';
        if (!needsApproval) continue;
        out.add({
          'id': row['id'] ?? row['uuid'],
          'entity_type': boxName == 'invoices'
              ? 'INVOICE'
              : boxName == 'collections'
                  ? 'COLLECTION'
                  : 'EXPENSE',
          'entity_id': row['id'] ?? row['uuid'],
          'status': 'PENDING',
          'requested_by': row['created_by'] ?? row['user_id'],
          'payload': row,
          'created_at': row['created_at'] ?? row['invoice_date'] ?? row['collection_date'] ?? row['expense_date'],
        });
      }
    }

    out.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));
    return out;
  }

  static Map<String, dynamic> forPath(String path) {
    final uri = Uri.parse(path.startsWith('http') ? path : 'http://offline$path');
    final p = uri.path;
    final q = uri.queryParameters;

    if (p == '/api/v1/sync/bootstrap') {
      return _bootstrapPayload();
    }
    if (p == '/api/v1/sync/pull') {
      return {
        'changes': const [],
        'serverTime': DateTime.now().toUtc().toIso8601String(),
        'offline': true,
      };
    }
    if (p == '/api/v1/invoices') {
      final rows = _filterByParty(_boxMaps('invoices'), q['party_id']);
      return {'items': rows, 'invoices': rows};
    }
    if (p == '/api/v1/parties') {
      final rows = _boxMaps('parties');
      return {'items': rows, 'parties': rows};
    }
    if (p.startsWith('/api/v1/parties/') && p.endsWith('/summary')) {
      final pid = p.split('/')[4];
      final invoices = _filterByParty(_boxMaps('invoices'), pid);
      final collections = _filterByParty(_boxMaps('collections'), pid);
      num sales = 0;
      num due = 0;
      num paid = 0;
      for (final e in invoices) {
        final st = (e['status'] ?? '').toString().toUpperCase();
        if (st == 'CANCELLED' || st == 'DECLINED') continue;
        sales += _toNum(e['net_total']);
        due += _toNum(e['due_amount']);
      }
      for (final e in collections) {
        paid += _toNum(e['amount']);
      }
      return {
        'summary': {
          'total_sales': sales,
          'receivable': due,
          'total_paid': paid,
        }
      };
    }
    if (p == '/api/v1/collections') {
      final rows = _filterByParty(_boxMaps('collections'), q['party_id']);
      return {'items': rows, 'collections': rows};
    }
    if (p == '/api/v1/expenses') {
      final rows = _boxMaps('expenses');
      return {'items': rows, 'expenses': rows};
    }
    if (p == '/api/v1/expenses/heads') {
      final rows = _cacheMaps('expense_heads');
      return {'items': rows, 'heads': rows};
    }
    if (p == '/api/v1/products') {
      final rows = _boxMaps('products');
      return {'items': rows, 'products': rows};
    }
    if (p.contains('/batches') && p.startsWith('/api/v1/products/')) {
      final parts = p.split('/');
      final pid = parts.length > 4 ? parts[4] : '';
      final rows = _boxMaps('product_batches')
          .where((e) => '${e['product_id'] ?? ''}' == pid)
          .toList();
      return {'items': rows, 'batches': rows};
    }
    if (p == '/api/v1/notifications') {
      final rows = _boxMaps('notifications');
      final unread = rows.where((e) => '${e['is_read'] ?? 0}' != '1').length;
      return {'ok': true, 'unread_count': unread, 'notifications': rows};
    }
    if (p == '/api/v1/accounting/vouchers') {
      return {'ok': true, 'vouchers': _boxMaps('vouchers')};
    }
    if (p == '/api/v1/accounting/summary') {
      final vouchers = _boxMaps('vouchers');
      int total = vouchers.length, posted = 0, cancelled = 0, draft = 0;
      double debit = 0, credit = 0;
      for (final v in vouchers) {
        final st = (v['status'] ?? '').toString().toUpperCase();
        final typ = (v['voucher_type'] ?? '').toString().toUpperCase();
        final amt = _toNum(v['amount']).toDouble();
        if (st == 'POSTED') posted++;
        if (st == 'CANCELLED') cancelled++;
        if (st == 'DRAFT') draft++;
        if (typ == 'DEBIT') debit += amt;
        if (typ == 'CREDIT') credit += amt;
      }
      return {
        'ok': true,
        'counts': {
          'total': total,
          'posted': posted,
          'cancelled': cancelled,
          'draft': draft,
        },
        'totals': {
          'debit': debit,
          'credit': credit,
          'balance': debit - credit,
        }
      };
    }
    if (p == '/api/v1/schedules' || p == '/api/v1/schedules/my') {
      final cached = _cacheMaps('schedules');
      return {'items': cached, 'schedules': cached};
    }
    if (p == '/api/v1/users') {
      final rows = _cacheMaps('users');
      return {'users': _filterUsers(rows, q['q']), 'items': _filterUsers(rows, q['q'])};
    }
    if (p.startsWith('/api/v1/geo/users/') && p.endsWith('/territories')) {
      final parts = p.split('/');
      final userId = parts.length > 5 ? parts[5] : '';
      final assignments = _cacheMaps('territory_assignments');
      final territoryIds = assignments
          .where((e) => '${e['user_id'] ?? ''}' == userId)
          .map((e) => '${e['territory_id'] ?? ''}')
          .where((e) => e.isNotEmpty)
          .toSet();
      final territories = _boxMaps('territories')
          .where((e) => territoryIds.contains('${e['id'] ?? ''}'))
          .toList();
      return {'items': territories, 'territories': territories};
    }
    if (p == '/api/v1/approvals') {
      final items = _pendingApprovals();
      return {'items': items, 'approvals': items};
    }
    if (p == '/api/v1/geo/territories' || p == '/api/v1/territories') {
      final rows = _boxMaps('territories');
      return {'territories': rows, 'items': rows};
    }
    return {'items': const []};
  }

  static num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse('${v ?? 0}') ?? 0;
  }
}
