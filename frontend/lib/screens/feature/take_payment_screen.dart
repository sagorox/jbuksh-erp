
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../models/party.dart';
import 'feature_scaffold.dart';

class TakePaymentScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  const TakePaymentScreen({super.key, required this.party});

  @override
  State<TakePaymentScreen> createState() => _TakePaymentScreenState();
}

class _TakePaymentScreenState extends State<TakePaymentScreen> {
  late Party p;
  final amountCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  String method = 'CASH';
  DateTime date = DateTime.now();

  // allocations: invoice_uuid/id -> applied amount
  final Map<String, num> allocations = {};
  bool autoAllocate = true;

  @override
  void initState() {
    super.initState();
    p = Party.fromJson(widget.party);
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  List<Map<String, dynamic>> _openInvoicesOldestFirst() {
    final all = LocalStore.allBoxMaps('invoices');
    final list = all.where((e) {
      final pid = e['party_id'] ?? (e['party']?['id']);
      final due = _toNum(e['due_amount']);
      final status = (e['status'] ?? '').toString().toUpperCase();
      return pid == p.id && due > 0 && status != 'CANCELLED' && status != 'DECLINED';
    }).toList();

    list.sort((a, b) => ((a['invoice_date'] ?? '') as String).compareTo((b['invoice_date'] ?? '') as String));
    return list;
  }

  void _applyAuto(num amount) {
    allocations.clear();
    var remaining = amount;
    for (final inv in _openInvoicesOldestFirst()) {
      if (remaining <= 0) break;
      final key = (inv['uuid'] ?? inv['id']).toString();
      final due = _toNum(inv['due_amount']);
      final apply = remaining >= due ? due : remaining;
      allocations[key] = apply;
      remaining -= apply;
    }
  }

  Future<void> _editLine(Map<String, dynamic> inv) async {
    final key = (inv['uuid'] ?? inv['id']).toString();
    final due = _toNum(inv['due_amount']);
    final ctrl = TextEditingController(text: (allocations[key] ?? 0).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply to ${inv['invoice_no'] ?? '-'}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(helperText: 'Due: ${due.toStringAsFixed(2)}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply')),
        ],
      ),
    );
    if (ok == true) {
      final v = num.tryParse(ctrl.text.trim()) ?? 0;
      setState(() {
        allocations[key] = v.clamp(0, due);
      });
    }
  }

  Future<void> _submit() async {
    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount')));
      return;
    }

    if (autoAllocate) {
      _applyAuto(amount);
    }

    final appliedSum = allocations.values.fold<num>(0, (s, v) => s + v);
    if (appliedSum > amount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applied amount cannot exceed paid amount.')));
      return;
    }

    final now = DateTime.now();
    final colNo = 'COL-${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final uuid = _uuid();
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final mpoUserId = user['id'] ?? user['sub'];

    final map = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': uuid,
      'collection_no': colNo,
      'party_id': p.id,
      'party': {'id': p.id, 'name': p.name},
      'territory_id': p.territoryId,
      'collection_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'method': method,
      'amount': amount,
      'reference_no': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
      'status': 'PENDING_APPROVAL',
      'mpo_user_id': mpoUserId,
      'posting_status': 'UNPOSTED',
      'allocations': allocations.entries
          .where((e) => e.value > 0)
          .map((e) => {'invoice_key': e.key, 'applied_amount': e.value})
          .toList(),
      'unused_amount': amount - appliedSum,
      'version': 1,
      'updated_at_client': now.toIso8601String(),
    };

    var savedOnline = false;
    try {
      final create = await Api.postJson('/api/v1/collections', {
        'territory_id': p.territoryId,
        'party_id': p.id,
        'collection_date': map['collection_date'],
        'method': method,
        'amount': amount,
        'reference_no': map['reference_no'],
      });
      final created = (create['collection'] is Map)
          ? (create['collection'] as Map).cast<String, dynamic>()
          : null;
      if (created != null && created['id'] != null) {
        await Api.postJson('/api/v1/collections/${created['id']}/submit', {});
        created['status'] = 'PENDING_APPROVAL';
        created['party'] = {'id': p.id, 'name': p.name};
        created['allocations'] = map['allocations'];
        await Hive.box('collections').put((created['id'] ?? uuid).toString(), created);
        savedOnline = true;
      }
    } catch (_) {
      savedOnline = false;
    }

    if (!savedOnline) {
      await Hive.box('collections').add(map);
    }

    // update invoice due_amount locally (best-effort)
    final invoicesBox = Hive.box('invoices');
    for (int i = 0; i < invoicesBox.length; i++) {
      final v = invoicesBox.getAt(i);
      if (v is Map) {
        final pid = v['party_id'] ?? (v['party']?['id']);
        if (pid == p.id) {
          final key = (v['uuid'] ?? v['id']).toString();
          final apply = allocations[key] ?? 0;
          if (apply > 0) {
            final due = _toNum(v['due_amount']);
            final newDue = (due - apply).clamp(0, due);
            final updated = Map<String, dynamic>.from(v);
            updated['due_amount'] = newDue;
            updated['received_amount'] = _toNum(v['received_amount']) + apply;
            updated['updated_at_client'] = DateTime.now().toIso8601String();
            await invoicesBox.putAt(i, updated);
          }
        }
      }
    }

    if (!savedOnline) {
      final outbox = Hive.box('outboxBox');
      outbox.add({
        'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
        'entity': 'collections',
        'op': 'UPSERT',
        'uuid': uuid,
        'version': 1,
        'payload': map,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(savedOnline ? 'Collection submitted to server.' : 'Collection saved offline and queued.'),
      ),
    );
    Navigator.of(context).pop(true);
  }

  String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'c-$now-${(now % 100000).toString().padLeft(5, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final openInvoices = _openInvoicesOldestFirst();

    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
    final appliedSum = allocations.values.fold<num>(0, (s, v) => s + v);

    return FeatureScaffold(
      title: 'Take Payment',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Code: ${p.partyCode}'),
              leading: const Icon(Icons.storefront_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.payments_outlined), labelText: 'Amount'),
                    onChanged: (_) {
                      if (autoAllocate) {
                        final a = num.tryParse(amountCtrl.text.trim()) ?? 0;
                        setState(() => _applyAuto(a));
                      } else {
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'BANK', child: Text('Bank')),
                      DropdownMenuItem(value: 'MFS', child: Text('MFS')),
                    ],
                    onChanged: (v) => setState(() => method = v ?? 'CASH'),
                    decoration: const InputDecoration(labelText: 'Method'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(labelText: 'Reference (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text('${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          value: autoAllocate,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) {
                            setState(() {
                              autoAllocate = v;
                              if (v) _applyAuto(amount);
                            });
                          },
                          title: const Text('Auto allocate'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Allocation', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Applied: ${appliedSum.toStringAsFixed(2)} / ${amount.toStringAsFixed(2)}'),
                  const SizedBox(height: 10),
                  if (openInvoices.isEmpty) const Text('No due invoices found.'),
                  ...openInvoices.map((inv) {
                    final key = (inv['uuid'] ?? inv['id']).toString();
                    final due = _toNum(inv['due_amount']);
                    final applied = allocations[key] ?? 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(inv['invoice_no']?.toString() ?? '-'),
                      subtitle: Text('Due: ${due.toStringAsFixed(2)}'),
                      trailing: Text(applied.toStringAsFixed(2)),
                      onTap: () => _editLine(inv),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('Submit For Approval'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
