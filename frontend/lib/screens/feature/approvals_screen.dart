import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/accounting_service.dart';
import '../../core/local_store.dart';
import 'feature_scaffold.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  String filter = 'ALL'; // ALL | FINANCE | ATTENDANCE

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
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
    if (ok == true) return ctrl.text.trim().isEmpty ? 'Declined' : ctrl.text.trim();
    return null;
  }

  Future<void> _notify({
    required String title,
    required String body,
    required String type,
    String? reason,
    dynamic userId,
    String? refType,
    dynamic refId,
  }) async {
    await Hive.box('notifications').add({
      'id': DateTime.now().microsecondsSinceEpoch,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'reason': reason,
      'ref_type': refType,
      'ref_id': refId,
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _approveInvoice(Map<String, dynamic> inv) async {
    final box = Hive.box('invoices');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (inv['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = 'APPROVED';
        final voucher = await AccountingService.postInvoiceApproved(updated);
        updated['posting_status'] = 'POSTED';
        updated['posted_voucher_no'] = voucher['voucher_no'];
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'approval',
      'op': 'APPROVE',
      'ref_entity': 'invoice',
      'uuid': inv['uuid'],
      'payload': {'entity_type': 'INVOICE', 'entity_uuid': inv['uuid'], 'action': 'APPROVED'},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Invoice Approved',
      body: 'Invoice ${(inv['invoice_no'] ?? inv['uuid'] ?? '-')} approved.',
      type: 'APPROVAL',
      userId: inv['mpo_user_id'],
      refType: 'INVOICE',
      refId: inv['id'] ?? inv['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice approved (local)')));
  }

  Future<void> _declineInvoice(Map<String, dynamic> inv) async {
    final reason = await _askReason();
    if (reason == null) return;

    final box = Hive.box('invoices');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (inv['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = 'DECLINED';
        updated['decline_reason'] = reason;
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'approval',
      'op': 'DECLINE',
      'ref_entity': 'invoice',
      'uuid': inv['uuid'],
      'payload': {'entity_type': 'INVOICE', 'entity_uuid': inv['uuid'], 'action': 'DECLINED', 'reason': reason},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Invoice Declined',
      body: 'Invoice ${(inv['invoice_no'] ?? inv['uuid'] ?? '-')} declined.',
      type: 'APPROVAL',
      reason: reason,
      userId: inv['mpo_user_id'],
      refType: 'INVOICE',
      refId: inv['id'] ?? inv['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice declined (local)')));
  }

  Future<void> _approveAttendance(Map<String, dynamic> att) async {
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
      'entity': 'approval',
      'op': 'APPROVE',
      'ref_entity': 'attendance',
      'uuid': att['uuid'],
      'payload': {'entity_type': 'ATTENDANCE', 'entity_uuid': att['uuid'], 'action': 'APPROVED'},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Attendance Approved',
      body: 'Attendance ${(att['att_date'] ?? att['uuid'] ?? '-')} approved.',
      type: 'APPROVAL',
      userId: att['user_id'],
      refType: 'ATTENDANCE',
      refId: att['id'] ?? att['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance approved (local)')));
  }

  Future<void> _approveCollection(Map<String, dynamic> col) async {
    final box = Hive.box('collections');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (col['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = 'APPROVED';
        final voucher = await AccountingService.postCollectionApproved(updated);
        updated['posting_status'] = 'POSTED';
        updated['posted_voucher_no'] = voucher['voucher_no'];
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'approval',
      'op': 'APPROVE',
      'ref_entity': 'collection',
      'uuid': col['uuid'],
      'payload': {'entity_type': 'COLLECTION', 'entity_uuid': col['uuid'], 'action': 'APPROVED'},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Collection Approved',
      body: 'Collection ${(col['collection_no'] ?? col['uuid'] ?? '-')} approved.',
      type: 'APPROVAL',
      userId: col['mpo_user_id'],
      refType: 'COLLECTION',
      refId: col['id'] ?? col['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection approved (local)')));
  }

  Future<void> _declineCollection(Map<String, dynamic> col) async {
    final reason = await _askReason();
    if (reason == null) return;

    final box = Hive.box('collections');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (col['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = 'DECLINED';
        updated['decline_reason'] = reason;
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'approval',
      'op': 'DECLINE',
      'ref_entity': 'collection',
      'uuid': col['uuid'],
      'payload': {'entity_type': 'COLLECTION', 'entity_uuid': col['uuid'], 'action': 'DECLINED', 'reason': reason},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Collection Declined',
      body: 'Collection ${(col['collection_no'] ?? col['uuid'] ?? '-')} declined.',
      type: 'APPROVAL',
      reason: reason,
      userId: col['mpo_user_id'],
      refType: 'COLLECTION',
      refId: col['id'] ?? col['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collection declined (local)')));
  }

  Future<void> _approveExpense(Map<String, dynamic> exp) async {
    final box = Hive.box('expenses');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (exp['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = 'APPROVED';
        final voucher = await AccountingService.postExpenseApproved(updated);
        updated['posting_status'] = 'POSTED';
        updated['posted_voucher_no'] = voucher['voucher_no'];
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'approval',
      'op': 'APPROVE',
      'ref_entity': 'expense',
      'uuid': exp['uuid'],
      'payload': {'entity_type': 'EXPENSE', 'entity_uuid': exp['uuid'], 'action': 'APPROVED'},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Expense Approved',
      body: 'Expense ${exp['amount'] ?? '-'} approved.',
      type: 'APPROVAL',
      userId: exp['user_id'],
      refType: 'EXPENSE',
      refId: exp['id'] ?? exp['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense approved (local)')));
  }

  Future<void> _declineExpense(Map<String, dynamic> exp) async {
    final reason = await _askReason();
    if (reason == null) return;

    final box = Hive.box('expenses');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map && (v['uuid'] ?? '').toString() == (exp['uuid'] ?? '').toString()) {
        final updated = Map<String, dynamic>.from(v);
        updated['status'] = 'DECLINED';
        updated['decline_reason'] = reason;
        updated['updated_at_client'] = DateTime.now().toIso8601String();
        await box.putAt(i, updated);
        break;
      }
    }

    Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'approval',
      'op': 'DECLINE',
      'ref_entity': 'expense',
      'uuid': exp['uuid'],
      'payload': {'entity_type': 'EXPENSE', 'entity_uuid': exp['uuid'], 'action': 'DECLINED', 'reason': reason},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Expense Declined',
      body: 'Expense ${exp['amount'] ?? '-'} declined.',
      type: 'APPROVAL',
      reason: reason,
      userId: exp['user_id'],
      refType: 'EXPENSE',
      refId: exp['id'] ?? exp['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense declined (local)')));
  }

  Future<void> _declineAttendance(Map<String, dynamic> att) async {
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
      'entity': 'approval',
      'op': 'DECLINE',
      'ref_entity': 'attendance',
      'uuid': att['uuid'],
      'payload': {'entity_type': 'ATTENDANCE', 'entity_uuid': att['uuid'], 'action': 'DECLINED', 'reason': reason},
      'created_at': DateTime.now().toIso8601String(),
    });

    await _notify(
      title: 'Attendance Declined',
      body: 'Attendance ${(att['att_date'] ?? att['uuid'] ?? '-')} declined.',
      type: 'APPROVAL',
      reason: reason,
      userId: att['user_id'],
      refType: 'ATTENDANCE',
      refId: att['id'] ?? att['uuid'],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance declined (local)')));
  }

  @override
  Widget build(BuildContext context) {
    final role = LocalStore.role();
    final canApprove = role == 'RSM' || role == 'SUPER_ADMIN';

    return FeatureScaffold(
      title: 'Approvals',
      child: AnimatedBuilder(
        animation: Listenable.merge([
          Hive.box('invoices').listenable(),
          Hive.box('collections').listenable(),
          Hive.box('expenses').listenable(),
          Hive.box('attendance').listenable(),
        ]),
        builder: (context, _) {
          final inv = LocalStore.allBoxMaps('invoices')
              .where((e) {
                final s = (e['status'] ?? '').toString().toUpperCase();
                return s == 'SUBMITTED' || s == 'PENDING_APPROVAL';
              })
              .toList();
          final col = LocalStore.allBoxMaps('collections')
              .where((e) {
                final s = (e['status'] ?? '').toString().toUpperCase();
                return s == 'SUBMITTED' || s == 'PENDING_APPROVAL';
              })
              .toList();
          final exp = LocalStore.allBoxMaps('expenses')
              .where((e) {
                final s = (e['status'] ?? '').toString().toUpperCase();
                return s == 'SUBMITTED' || s == 'PENDING_APPROVAL';
              })
              .toList();
          final att = LocalStore.allBoxMaps('attendance')
              .where((e) => (e['approval_status'] ?? '').toString() == 'SUBMITTED')
              .toList();

          inv.sort((a, b) => ((b['invoice_date'] ?? '') as String).compareTo((a['invoice_date'] ?? '') as String));
          col.sort((a, b) => ((b['collection_date'] ?? '') as String).compareTo((a['collection_date'] ?? '') as String));
          exp.sort((a, b) => ((b['expense_date'] ?? '') as String).compareTo((a['expense_date'] ?? '') as String));
          att.sort((a, b) => ((b['att_date'] ?? '') as String).compareTo((a['att_date'] ?? '') as String));

          final items = <_ApprovalItem>[];
          if (filter == 'ALL' || filter == 'FINANCE') {
            for (final e in inv) {
              items.add(_ApprovalItem(type: 'INVOICE', data: e));
            }
            for (final e in col) {
              items.add(_ApprovalItem(type: 'COLLECTION', data: e));
            }
            for (final e in exp) {
              items.add(_ApprovalItem(type: 'EXPENSE', data: e));
            }
          }
          if (filter == 'ALL' || filter == 'ATTENDANCE') {
            for (final e in att) {
              items.add(_ApprovalItem(type: 'ATTENDANCE', data: e));
            }
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ALL', label: Text('All')),
                        ButtonSegment(value: 'FINANCE', label: Text('Finance')),
                        ButtonSegment(value: 'ATTENDANCE', label: Text('Attendance')),
                      ],
                      selected: {filter},
                      onSelectionChanged: (s) => setState(() => filter = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.rule_folder_outlined),
                  title: const Text('Pending approvals', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Finance (Invoice/Collection/Expense) + Attendance'),
                  trailing: Text(items.length.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              if (!canApprove)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('You do not have approval permission'),
                    subtitle: Text('Only RSM / Super Admin can approve/decline'),
                  ),
                ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No pending approvals')),
                ),
              for (final it in items)
                _ApprovalCard(
                  item: it,
                  enabled: canApprove,
                  toNum: _toNum,
                  onApprove: () {
                    if (!canApprove) return;
                    if (it.type == 'INVOICE') {
                      _approveInvoice(it.data);
                    } else if (it.type == 'COLLECTION') {
                      _approveCollection(it.data);
                    } else if (it.type == 'EXPENSE') {
                      _approveExpense(it.data);
                    } else {
                      _approveAttendance(it.data);
                    }
                  },
                  onDecline: () {
                    if (!canApprove) return;
                    if (it.type == 'INVOICE') {
                      _declineInvoice(it.data);
                    } else if (it.type == 'COLLECTION') {
                      _declineCollection(it.data);
                    } else if (it.type == 'EXPENSE') {
                      _declineExpense(it.data);
                    } else {
                      _declineAttendance(it.data);
                    }
                  },
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _ApprovalItem {
  final String type;
  final Map<String, dynamic> data;
  _ApprovalItem({required this.type, required this.data});
}

class _ApprovalCard extends StatelessWidget {
  final _ApprovalItem item;
  final bool enabled;
  final num Function(dynamic) toNum;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _ApprovalCard({
    required this.item,
    required this.enabled,
    required this.toNum,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.type == 'INVOICE'
        ? 'Invoice: ${(item.data['server_invoice_no'] ?? item.data['invoice_no'] ?? '-').toString()}'
        : item.type == 'COLLECTION'
            ? 'Collection: ${(item.data['collection_no'] ?? '-').toString()}'
            : item.type == 'EXPENSE'
                ? 'Expense: ${(item.data['head'] ?? item.data['head_name'] ?? '-').toString()}'
                : 'Attendance: ${(item.data['att_date'] ?? '-').toString()}';

    final subtitle = item.type == 'INVOICE'
        ? 'Party: ${(item.data['party']?['name'] ?? item.data['party_name'] ?? '-').toString()}'
        : item.type == 'COLLECTION'
            ? 'Party: ${(item.data['party']?['name'] ?? '-').toString()}'
            : item.type == 'EXPENSE'
                ? 'User: ${(item.data['user_name'] ?? item.data['user_id'] ?? '-').toString()}'
                : 'User: ${(item.data['user_name'] ?? item.data['user_id'] ?? '-').toString()}';

    final amount = item.type == 'INVOICE'
        ? toNum(item.data['net_total']).toStringAsFixed(2)
        : item.type == 'COLLECTION'
            ? toNum(item.data['amount']).toStringAsFixed(2)
            : item.type == 'EXPENSE'
                ? toNum(item.data['amount']).toStringAsFixed(2)
                : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(item.type == 'INVOICE' ? Icons.shopping_bag_outlined : Icons.badge_outlined),
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
