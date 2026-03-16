import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class StockSummaryScreen extends StatefulWidget {
  const StockSummaryScreen({super.key});

  @override
  State<StockSummaryScreen> createState() => _StockSummaryScreenState();
}

class _StockSummaryScreenState extends State<StockSummaryScreen> {
  String q = '';
  bool lowOnly = false;

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Stock Summary',
      actions: [
        IconButton(
          tooltip: 'Low stock',
          onPressed: () => setState(() => lowOnly = !lowOnly),
          icon: Icon(lowOnly ? Icons.filter_alt : Icons.filter_alt_outlined),
        ),
      ],
      child: ValueListenableBuilder(
        valueListenable: Hive.box('products').listenable(),
        builder: (context, value, child) {
          final products = LocalStore.allBoxMaps('products');

          final totalItems = products.length;
          final stockValue = products.fold<num>(0, (s, e) => s + (_toNum(e['in_stock']) * _toNum(e['purchase_price'])));
          final lowCount = products.where((e) => _toNum(e['reorder_level']) > 0 && _toNum(e['in_stock']) <= _toNum(e['reorder_level'])).length;

          var list = products;
          if (lowOnly) {
            list = list.where((e) => _toNum(e['reorder_level']) > 0 && _toNum(e['in_stock']) <= _toNum(e['reorder_level'])).toList();
          }
          if (q.trim().isNotEmpty) {
            final qq = q.trim().toLowerCase();
            list = list.where((e) {
              final name = (e['name'] ?? '').toString().toLowerCase();
              final sku = (e['sku'] ?? '').toString().toLowerCase();
              return name.contains(qq) || sku.contains(qq);
            }).toList();
          }
          list.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  Expanded(child: _summaryCard('Total Items', totalItems.toString())),
                  const SizedBox(width: 10),
                  Expanded(child: _summaryCard('Low Stock', lowCount.toString())),
                ],
              ),
              const SizedBox(height: 10),
              _summaryCard('Stock Value (Purchase)', stockValue.toStringAsFixed(2)),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search item (name / SKU)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: (v) => setState(() => q = v),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No items found.'),
                  ),
                )
              else
                ...list.map((p) {
                  final inStock = _toNum(p['in_stock']);
                  final reorder = _toNum(p['reorder_level']);
                  final low = reorder > 0 && inStock <= reorder;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      onTap: () => Navigator.of(context).pushNamed(RouteNames.productDetails, arguments: p),
                      leading: Icon(low ? Icons.warning_amber_rounded : Icons.inventory_2_outlined),
                      title: Text((p['name'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('SKU: ${(p['sku'] ?? '-')} â€¢ Unit: ${(p['unit'] ?? '-')}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('In stock: ${inStock.toStringAsFixed(0)}'),
                          Text('Sale: ${_toNum(p['sale_price']).toStringAsFixed(2)}'),
                          if (low) const Text('LOW', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(String label, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.black.withValues(alpha: 0.65))),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}


