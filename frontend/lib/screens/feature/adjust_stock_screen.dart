import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/local_store.dart';
import 'feature_scaffold.dart';

class AdjustStockScreen extends StatefulWidget {
  const AdjustStockScreen({super.key});

  @override
  State<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends State<AdjustStockScreen> {
  Map<String, dynamic>? selected;
  String type = 'ADJUST'; // IN | OUT | ADJUST
  final qtyCtl = TextEditingController(text: '0');
  final noteCtl = TextEditingController();

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    qtyCtl.dispose();
    noteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (selected == null) return;
    final qty = _toNum(qtyCtl.text);
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Qty cannot be 0')));
      return;
    }

    final productId = selected!['id'];
    final productsBox = Hive.box('products');
    num currentStock = 0;
    bool found = false;

    for (int i = 0; i < productsBox.length; i++) {
      final v = productsBox.getAt(i);
      if (v is Map && v['id'] == productId) {
        currentStock = _toNum(v['in_stock']);
        found = true;
        break;
      }
    }
    if (!found) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found in local store')));
      return;
    }
    if (type == 'OUT' && qty > currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insufficient stock. Available: ${currentStock.toStringAsFixed(0)}')),
      );
      return;
    }

    // Update product in_stock
    for (int i = 0; i < productsBox.length; i++) {
      final v = productsBox.getAt(i);
      if (v is Map && v['id'] == productId) {
        final updated = Map<String, dynamic>.from(v.cast<String, dynamic>());
        final current = _toNum(updated['in_stock']);
        final delta = (type == 'OUT') ? -qty : qty;
        updated['in_stock'] = (current + delta);
        await productsBox.putAt(i, updated);
        break;
      }
    }

    // Add stock txn
    final txBox = Hive.box('stock_txns');
    final txn = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch,
      'product_id': productId,
      'txn_type': type,
      'qty': qty,
      'ref_type': 'ADJUST',
      'note': noteCtl.text.trim(),
      'txn_date': DateTime.now().toIso8601String(),
    };
    await txBox.add(txn);

    // Outbox queue for sync later
    final outbox = Hive.box('outboxBox');
    await outbox.add({
      'entity': 'stock_txns',
      'op': 'UPSERT',
      'payload': txn,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock adjusted (offline).')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final preset = ModalRoute.of(context)?.settings.arguments;
    final presetId = (preset is Map) ? preset['productId'] : null;

    return FeatureScaffold(
      title: 'Adjust Stock',
      child: ValueListenableBuilder(
        valueListenable: Hive.box('products').listenable(),
        builder: (context, value, child) {
          final products = LocalStore.allBoxMaps('products');
          if (selected == null && presetId != null) {
            selected = products.firstWhere((e) => e['id'] == presetId, orElse: () => {});
            if (selected!.isEmpty) selected = null;
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Item', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: selected,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: products
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text('${p['name'] ?? '-'}  (SKU: ${p['sku'] ?? '-'})'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => selected = v),
                      ),
                      const SizedBox(height: 12),
                      const Text('Type', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'IN', label: Text('IN')),
                          ButtonSegment(value: 'OUT', label: Text('OUT')),
                          ButtonSegment(value: 'ADJUST', label: Text('ADJUST')),
                        ],
                        selected: {type},
                        onSelectionChanged: (s) => setState(() => type = s.first),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Qty',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtl,
                        decoration: InputDecoration(
                          labelText: 'Note (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: selected == null ? null : _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

