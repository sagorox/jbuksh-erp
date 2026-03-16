import 'package:flutter/material.dart';

import '../../core/local_store.dart';
import '../../routes.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  bool _inCurrentMonth(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month;
  }

  Map<String, num> _monthlySales() {
    final now = DateTime.now();
    final months = <String, num>{
      _monthKey(now.subtract(const Duration(days: 60))): 0,
      _monthKey(now.subtract(const Duration(days: 30))): 0,
      _monthKey(now): 0,
    };

    for (final inv in LocalStore.allBoxMaps('invoices')) {
      final status = (inv['status'] ?? '').toString().toUpperCase();
      if (status == 'DECLINED' || status == 'CANCELLED') continue;
      final date = _parseDate(inv['invoice_date']);
      if (date == null) continue;
      final key = _monthKey(date);
      if (!months.containsKey(key)) continue;
      months[key] = _toNum(months[key]) + _toNum(inv['net_total']);
    }
    return months;
  }

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _monthLabel(String key) {
    final m = int.tryParse(key.split('-').last) ?? 1;
    const labels = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return labels[(m - 1).clamp(0, 11)];
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoices = LocalStore.allBoxMaps('invoices');
    final collections = LocalStore.allBoxMaps('collections');
    final expenses = LocalStore.allBoxMaps('expenses');
    final products = LocalStore.allBoxMaps('products');
    final parties = LocalStore.allBoxMaps('parties');

    num receivable = 0;
    for (final p in parties) {
      receivable += _toNum(p['receivable']);
    }
    if (receivable <= 0) {
      for (final i in invoices) {
        final status = (i['status'] ?? '').toString().toUpperCase();
        if (status == 'DECLINED' || status == 'CANCELLED') continue;
        receivable += _toNum(i['due_amount']);
      }
    }

    final payable = expenses
        .where((e) => _inCurrentMonth(_parseDate(e['expense_date'])))
        .fold<num>(0, (s, e) => s + _toNum(e['amount']));
    final monthSale = invoices.where((i) {
      final status = (i['status'] ?? '').toString().toUpperCase();
      if (status == 'DECLINED' || status == 'CANCELLED') return false;
      return _inCurrentMonth(_parseDate(i['invoice_date']));
    }).fold<num>(0, (s, i) => s + _toNum(i['net_total']));
    final monthCollection = collections.where((c) => _inCurrentMonth(_parseDate(c['collection_date']))).fold<num>(
          0,
          (s, c) => s + _toNum(c['amount']),
        );
    final stockValue = products.fold<num>(
      0,
      (s, p) => s + (_toNum(p['in_stock']) * _toNum(p['purchase_price'])),
    );

    final monthly = _monthlySales().entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              _summaryCard(
                title: "You'll Get",
                value: 'Tk ${receivable.toStringAsFixed(2)}',
                color: Colors.green,
                icon: Icons.arrow_downward_rounded,
              ),
              const SizedBox(width: 10),
              _summaryCard(
                title: "You'll Give",
                value: 'Tk ${payable.toStringAsFixed(2)}',
                color: Colors.red,
                icon: Icons.arrow_upward_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _summaryCard(
                title: 'Monthly Sale',
                value: 'Tk ${monthSale.toStringAsFixed(2)}',
                color: Colors.blue,
                icon: Icons.show_chart_rounded,
              ),
              const SizedBox(width: 10),
              _summaryCard(
                title: 'Monthly Collection',
                value: 'Tk ${monthCollection.toStringAsFixed(2)}',
                color: Colors.teal,
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Sale Overview',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 150,
                    child: _MonthlySalesBars(points: monthly.map((e) => e.value).toList()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: monthly
                        .map((e) => Text(_monthLabel(e.key), style: const TextStyle(fontSize: 12)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Stock Value'),
              subtitle: const Text('Based on local purchase price * in stock'),
              trailing: Text('Tk ${stockValue.toStringAsFixed(2)}'),
              onTap: () => Navigator.of(context).pushNamed(RouteNames.stockSummary),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Most Used Reports', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Sales'),
                        onPressed: () => Navigator.of(context).pushNamed(
                          RouteNames.reportFilter,
                          arguments: {'reportKey': 'Sales Report'},
                        ),
                      ),
                      ActionChip(
                        label: const Text('Day Book'),
                        onPressed: () => Navigator.of(context).pushNamed(
                          RouteNames.reportFilter,
                          arguments: {'reportKey': 'Day Book'},
                        ),
                      ),
                      ActionChip(
                        label: const Text('Stock Summary'),
                        onPressed: () => Navigator.of(context).pushNamed(
                          RouteNames.reportFilter,
                          arguments: {'reportKey': 'Stock Summary'},
                        ),
                      ),
                      ActionChip(
                        label: const Text('Party Statement'),
                        onPressed: () => Navigator.of(context).pushNamed(
                          RouteNames.reportFilter,
                          arguments: {'reportKey': 'Party Statement'},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _MonthlySalesBars extends StatelessWidget {
  final List<num> points;
  const _MonthlySalesBars({required this.points});

  @override
  Widget build(BuildContext context) {
    final safePoints = points.isEmpty ? const <num>[0, 0, 0] : points;
    final maxValue = safePoints.reduce((a, b) => a > b ? a : b);
    final scale = maxValue <= 0 ? 1 : maxValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: safePoints.map((v) {
        final h = (v / scale) * 120;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              height: h.toDouble().clamp(6, 120),
              decoration: BoxDecoration(
                color: const Color(0xFF246BFD),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
