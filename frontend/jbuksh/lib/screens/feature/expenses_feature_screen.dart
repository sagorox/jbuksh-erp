import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../core/role_utils.dart';
import 'add_expense_screen.dart';
import 'feature_scaffold.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncFromServer();
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
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

  Future<void> _syncFromServer() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });

    try {
      final res = await Api.getJson('/api/v1/expenses');
      final rows = _readList(res, ['expenses', 'items', 'data']);
      final box = Hive.box('expenses');

      for (final row in rows) {
        final key = (row['id'] ?? row['uuid'])?.toString();
        if (key == null || key.isEmpty) {
          await box.add(row);
        } else {
          await box.put(key, row);
        }
      }
    } catch (e) {
      _syncError = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _headName(Map<String, dynamic> expense) {
    final direct = (expense['head_name'] ?? expense['head'] ?? '').toString();
    if (direct.isNotEmpty) return direct;

    final headId = expense['head_id'];
    final cached = (Hive.box('cacheBox').get('expense_heads') as List?) ?? const [];
    for (final h in cached) {
      if (h is Map && (h['id']?.toString() ?? '') == (headId?.toString() ?? '')) {
        final name = (h['name'] ?? '').toString();
        if (name.isNotEmpty) return name;
      }
    }

    return 'Expense';
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleUtils.normalize(LocalStore.role());
    final canAdd = role == RoleUtils.superAdmin ||
        role == RoleUtils.accounting ||
        role == RoleUtils.mpo ||
        role == RoleUtils.rsm;

    return FeatureScaffold(
      title: 'Expenses',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _syncing ? null : _syncFromServer,
        ),
      ],
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              backgroundColor: Colors.red,
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                );
                if (ok == true) {
                  await _syncFromServer();
                  if (mounted) setState(() {});
                }
              },
              label: const Text('Add Expense'),
              icon: const Icon(Icons.add),
            )
          : null,
      child: ValueListenableBuilder(
        valueListenable: Hive.box('expenses').listenable(),
        builder: (context, box, _) {
          final rows = LocalStore.allBoxMaps('expenses');
          rows.sort((a, b) => ((b['expense_date'] ?? '') as String)
              .compareTo((a['expense_date'] ?? '') as String));

          final monthTotal = rows
              .where((e) {
                final d = (e['expense_date'] ?? '').toString();
                final now = DateTime.now();
                final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
                return d.startsWith(key);
              })
              .fold<num>(0, (s, e) => s + _toNum(e['amount']));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('This month total', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(_syncing
                      ? 'Syncing server expenses...'
                      : (_syncError == null
                          ? 'Online + offline merged view'
                          : 'Showing cached data. $_syncError')),
                  trailing: Text(monthTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No expenses yet')),
                ),
              for (final e in rows)
                _ExpenseCard(
                  expense: e,
                  headName: _headName(e),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;
  final String headName;
  const _ExpenseCard({required this.expense, required this.headName});

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final date = (expense['expense_date'] ?? '').toString();
    final amount = _toNum(expense['amount']);
    final note = (expense['note'] ?? '').toString();
    final status = (expense['status'] ?? 'PENDING_APPROVAL').toString().toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text(headName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([date, if (note.isNotEmpty) note].join(' • ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            _StatusChip(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'DRAFT':
        bg = Colors.grey.shade200;
        fg = Colors.black87;
        break;
      case 'APPROVED':
        bg = Colors.green.withValues(alpha: 0.15);
        fg = Colors.green.shade800;
        break;
      case 'DECLINED':
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12),
      ),
    );
  }
}
