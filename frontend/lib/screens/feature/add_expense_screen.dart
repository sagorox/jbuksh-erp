import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../core/role_utils.dart';
import 'feature_scaffold.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _heads = const [];
  bool _loadingHeads = true;
  int? _headId;
  DateTime date = DateTime.now();
  bool draft = false;

  @override
  void initState() {
    super.initState();
    _loadHeads();
  }

  String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'e-$now-${(now % 100000).toString().padLeft(5, '0')}';
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

  Future<void> _loadHeads() async {
    setState(() => _loadingHeads = true);
    try {
      final res = await Api.getJson('/api/v1/expenses/heads');
      final rows = _readList(res, ['heads', 'items', 'data']);
      if (rows.isNotEmpty) {
        _heads = rows;
        _headId = int.tryParse((rows.first['id'] ?? '').toString());
        await Hive.box('cacheBox').put('expense_heads', rows);
      }
    } catch (_) {
      final cached = (Hive.box('cacheBox').get('expense_heads') as List?) ?? const [];
      final rows = cached.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      if (rows.isNotEmpty) {
        _heads = rows;
        _headId = int.tryParse((rows.first['id'] ?? '').toString());
      }
    } finally {
      if (mounted) setState(() => _loadingHeads = false);
    }
  }

  String _headNameById(int? id) {
    for (final h in _heads) {
      if ((h['id']?.toString() ?? '') == (id?.toString() ?? '')) {
        return (h['name'] ?? 'Expense').toString();
      }
    }
    return 'Expense';
  }

  Future<void> _save() async {
    final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount')));
      return;
    }

    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final uuid = _uuid();
    final now = DateTime.now();
    final territoryIds = ((user['territory_ids'] as List?) ?? const []).toList();
    final territoryId = user['territory_id'] ??
        user['territory']?['id'] ??
        (territoryIds.isNotEmpty ? territoryIds.first : null);

    if (territoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No territory assigned to your user. Please contact admin.')),
      );
      return;
    }

    if (_headId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense head not loaded yet.')),
      );
      return;
    }

    final map = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': uuid,
      'user_id': user['id'] ?? user['sub'],
      'territory_id': territoryId,
      'expense_date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'head_id': _headId,
      'head_name': _headNameById(_headId),
      'amount': amount,
      'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      'status': draft ? 'DRAFT' : 'PENDING_APPROVAL',
      'posting_status': 'UNPOSTED',
      'version': 1,
      'updated_at_client': now.toIso8601String(),
    };

    final box = Hive.box('expenses');
    var savedOnline = false;

    if (!draft) {
      try {
        final created = await Api.postJson('/api/v1/expenses', {
          'territory_id': territoryId,
          'expense_date': map['expense_date'],
          'head_id': _headId,
          'amount': amount,
          'note': map['note'],
        });

        final serverExpense = (created['expense'] is Map)
            ? (created['expense'] as Map).cast<String, dynamic>()
            : null;

        if (serverExpense != null) {
          // Submit endpoint may not be enabled in backend yet; fallback silently.
          try {
            await Api.postJson('/api/v1/expenses/${serverExpense['id']}/submit', {});
            serverExpense['status'] = 'PENDING_APPROVAL';
          } catch (_) {
            serverExpense['status'] = (serverExpense['status'] ?? 'DRAFT').toString();
          }

          serverExpense['head_name'] = _headNameById(_headId);
          final key = (serverExpense['id'] ?? serverExpense['uuid'] ?? uuid).toString();
          await box.put(key, serverExpense);
          savedOnline = true;
        }
      } catch (_) {
        savedOnline = false;
      }
    }

    if (!savedOnline) {
      await box.add(map);
      if (!draft) {
        Hive.box('outboxBox').add({
          'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
          'entity': 'expenses',
          'op': 'UPSERT',
          'uuid': uuid,
          'version': 1,
          'payload': map,
          'created_at': now.toIso8601String(),
        });
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(savedOnline
            ? 'Expense saved to server.'
            : (draft ? 'Expense draft saved locally.' : 'Expense queued offline.')),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleUtils.normalize(LocalStore.role());
    final isAccounting = role == RoleUtils.accounting || role == RoleUtils.superAdmin;

    return FeatureScaffold(
      title: 'Add Expense',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadingHeads ? null : _loadHeads,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadingHeads)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: _headId,
                    items: _heads
                        .map((h) => DropdownMenuItem<int>(
                              value: int.tryParse((h['id'] ?? '').toString()),
                              child: Text((h['name'] ?? '-').toString()),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _headId = v),
                    decoration: const InputDecoration(labelText: 'Expense head'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.payments_outlined),
                      labelText: 'Amount',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Note (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
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
                    label: Text(
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isAccounting)
                    SwitchListTile(
                      value: draft,
                      onChanged: (v) => setState(() => draft = v),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Save as draft'),
                      subtitle: const Text('Draft stays local only'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(draft ? 'Save Draft' : 'Submit'),
          ),
        ],
      ),
    );
  }
}
