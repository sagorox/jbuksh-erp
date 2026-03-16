import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../core/role_utils.dart';
import 'feature_scaffold.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  String filter = 'ALL'; // ALL | FINANCE | ATTENDANCE
  bool _loading = false;
  bool _actionBusy = false;
  String? _error;
  List<Map<String, dynamic>> _serverApprovals = [];

  String get _role => RoleUtils.normalize(LocalStore.role());

  bool get _canApprove => _role == RoleUtils.superAdmin ||
      _role == RoleUtils.rsm ||
      _role == RoleUtils.salesDept ||
      _role == RoleUtils.accounting;

  @override
  void initState() {
    super.initState();
    if (_canApprove) {
      _loadApprovals();
    }
  }

  Future<void> _loadApprovals() async {
    if (!_canApprove) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Api.getJson('/api/v1/approvals?status=PENDING');
      final rows = _readList(res, ['approvals', 'items', 'data']);
      setState(() => _serverApprovals = rows);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> src, List<String> keys) {
    for (final k in keys) {
      final v = src[k];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline reason'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Write reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Decline')),
        ],
      ),
    );
    if (ok == true) {
      final reason = ctrl.text.trim();
      return reason.isEmpty ? 'Declined' : reason;
    }
    return null;
  }

  Future<void> _approveServer(int approvalId) async {
    setState(() => _actionBusy = true);
    try {
      await Api.postJson('/api/v1/approvals/$approvalId/approve', {});
      await _refreshFromBootstrap();
      await _loadApprovals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _declineServer(int approvalId) async {
    final reason = await _askReason();
    if (reason == null) return;

    setState(() => _actionBusy = true);
    try {
      await Api.postJson('/api/v1/approvals/$approvalId/decline', {'reason': reason});
      await _refreshFromBootstrap();
      await _loadApprovals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Decline failed: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _refreshFromBootstrap() async {
    try {
      final res = await Api.getJson('/api/v1/sync/bootstrap');
      final master = (res['master'] as Map?)?.cast<String, dynamic>() ?? const {};
      final scoped = (res['scoped'] as Map?)?.cast<String, dynamic>() ?? const {};

      await _saveListToBox('territories', master['territories']);
      await _saveListToBox('categories', master['categories']);
      await _saveListToBox('products', master['products']);
      await _saveListToBox('parties', scoped['parties']);
      await _saveListToBox('invoices', scoped['invoices']);
      await _saveListToBox('collections', scoped['collections']);
      await _saveListToBox('expenses', scoped['expenses']);
      await _saveListToBox('deliveries', scoped['deliveries']);
      await _saveListToBox('attendance', scoped['attendance']);

      final serverTime =
          (res['serverTime'] ?? DateTime.now().toUtc().toIso8601String()).toString();
      await Hive.box('cacheBox').put('lastSyncAt', serverTime);
    } catch (_) {
      // ignore sync refresh errors after approval action
    }
  }

  Future<void> _saveListToBox(String boxName, dynamic listAny) async {
    final box = Hive.box(boxName);
    await box.clear();
    final list = (listAny as List?) ?? const [];
    for (final item in list) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final key = (m['id'] ?? m['uuid'])?.toString();
      if (key != null && key.isNotEmpty) {
        await box.put(key, m);
      } else {
        await box.add(m);
      }
    }
  }

  Map<String, dynamic>? _findById(String boxName, dynamic id) {
    for (final m in LocalStore.allBoxMaps(boxName)) {
      if ((m['id']?.toString() ?? '') == (id?.toString() ?? '')) return m;
    }
    return null;
  }

  List<_ApprovalItem> _localAttendanceItems() {
    return LocalStore.allBoxMaps('attendance')
        .where((e) => (e['approval_status'] ?? '').toString().toUpperCase() == 'SUBMITTED')
        .map((e) => _ApprovalItem.local('ATTENDANCE', e))
        .toList();
  }

  Future<void> _approveLocalAttendance(Map<String, dynamic> att) async {
    final box = Hive.box('attendance');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (att['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['approval_status'] = 'APPROVED';
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'attendance',
      'op': 'UPSERT',
      'uuid': att['uuid'],
      'payload': {
        ...att,
        'approval_status': 'APPROVED',
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance approved (offline).')));
    setState(() {});
  }

  Future<void> _declineLocalAttendance(Map<String, dynamic> att) async {
    final reason = await _askReason();
    if (reason == null) return;

    final box = Hive.box('attendance');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (att['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['approval_status'] = 'DECLINED';
        updated['decline_reason'] = reason;
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'attendance',
      'op': 'UPSERT',
      'uuid': att['uuid'],
      'payload': {
        ...att,
        'approval_status': 'DECLINED',
        'decline_reason': reason,
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance declined (offline).')));
    setState(() {});
  }

  List<_ApprovalItem> _buildItems() {
    final server = _serverApprovals.map((row) {
      final type = (row['entity_type'] ?? '').toString().toUpperCase();
      final entityId = row['entity_id'];
      Map<String, dynamic>? entity;
      if (type == 'INVOICE') {
        entity = _findById('invoices', entityId);
      } else if (type == 'COLLECTION') {
        entity = _findById('collections', entityId);
      } else if (type == 'EXPENSE') {
        entity = _findById('expenses', entityId);
      }
      return _ApprovalItem.server(type: type, approval: row, entity: entity);
    }).toList();

    final localAttendance = _localAttendanceItems();

    final out = <_ApprovalItem>[];
    if (filter == 'ALL' || filter == 'FINANCE') {
      out.addAll(server.where((e) => e.type != 'ATTENDANCE'));
    }
    if (filter == 'ALL' || filter == 'ATTENDANCE') {
      out.addAll(server.where((e) => e.type == 'ATTENDANCE'));
      out.addAll(localAttendance);
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return FeatureScaffold(
      title: 'Approvals',
      actions: [
        if (_canApprove)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _actionBusy ? null : _loadApprovals,
          ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ALL', label: Text('All')),
              ButtonSegment(value: 'FINANCE', label: Text('Finance')),
              ButtonSegment(value: 'ATTENDANCE', label: Text('Attendance')),
            ],
            selected: {filter},
            onSelectionChanged: (s) => setState(() => filter = s.first),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.rule_folder_outlined),
              title: const Text('Pending approvals', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(_canApprove
                  ? (_error == null ? 'Live from backend + local attendance fallback' : _error!)
                  : 'You do not have approval permission'),
              trailing: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(items.length.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          if (!_canApprove)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Approval actions are not available for your role'),
              ),
            ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No pending approvals')),
            ),
          for (final item in items)
            _ApprovalCard(
              item: item,
              enabled: _canApprove && !_actionBusy,
              onApprove: () async {
                if (!(_canApprove && !_actionBusy)) return;
                if (item.localOnly) {
                  await _approveLocalAttendance(item.entity ?? item.approval);
                } else {
                  final approvalId = int.tryParse((item.approval['id'] ?? '').toString());
                  if (approvalId != null) await _approveServer(approvalId);
                }
              },
              onDecline: () async {
                if (!(_canApprove && !_actionBusy)) return;
                if (item.localOnly) {
                  await _declineLocalAttendance(item.entity ?? item.approval);
                } else {
                  final approvalId = int.tryParse((item.approval['id'] ?? '').toString());
                  if (approvalId != null) await _declineServer(approvalId);
                }
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ApprovalItem {
  final String type;
  final Map<String, dynamic> approval;
  final Map<String, dynamic>? entity;
  final bool localOnly;

  _ApprovalItem.server({
    required this.type,
    required this.approval,
    required this.entity,
  }) : localOnly = false;

  _ApprovalItem.local(this.type, this.approval)
      : entity = approval,
        localOnly = true;
}

class _ApprovalCard extends StatelessWidget {
  final _ApprovalItem item;
  final bool enabled;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _ApprovalCard({
    required this.item,
    required this.enabled,
    required this.onApprove,
    required this.onDecline,
  });

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final type = item.type;
    final e = item.entity ?? const <String, dynamic>{};
    final a = item.approval;

    String title;
    String subtitle;
    String amount = '';

    if (type == 'INVOICE') {
      final invNo = (e['invoice_no'] ?? '#${a['entity_id'] ?? '-'}').toString();
      final party = (e['party']?['name'] ?? e['party_name'] ?? '-').toString();
      final date = (e['invoice_date'] ?? '').toString();
      title = 'Invoice: $invNo';
      subtitle = 'Party: $party${date.isEmpty ? '' : ' • $date'}';
      amount = _toNum(e['net_total']).toStringAsFixed(2);
    } else if (type == 'COLLECTION') {
      final colNo = (e['collection_no'] ?? '#${a['entity_id'] ?? '-'}').toString();
      final party = (e['party']?['name'] ?? e['party_name'] ?? '-').toString();
      final date = (e['collection_date'] ?? '').toString();
      title = 'Collection: $colNo';
      subtitle = 'Party: $party${date.isEmpty ? '' : ' • $date'}';
      amount = _toNum(e['amount']).toStringAsFixed(2);
    } else if (type == 'EXPENSE') {
      final head = (e['head_name'] ?? e['head'] ?? 'Expense').toString();
      final date = (e['expense_date'] ?? '').toString();
      title = 'Expense: $head';
      subtitle = 'Ref: #${a['entity_id'] ?? '-'}${date.isEmpty ? '' : ' • $date'}';
      amount = _toNum(e['amount']).toStringAsFixed(2);
    } else {
      final date = (e['att_date'] ?? '-').toString();
      final userId = (e['user_id'] ?? '-').toString();
      title = 'Attendance: $date';
      subtitle = 'User: $userId';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(type == 'ATTENDANCE' ? Icons.badge_outlined : Icons.shopping_bag_outlined),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (amount.isNotEmpty) Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: 'Decline',
              onPressed: enabled ? onDecline : null,
              icon: const Icon(Icons.close),
            ),
            IconButton(
              tooltip: 'Approve',
              onPressed: enabled ? onApprove : null,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
      ),
    );
  }
}
