import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AddEditItemScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  const AddEditItemScreen({super.key, this.product});

  @override
  State<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends State<AddEditItemScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController skuCtl;
  late final TextEditingController nameCtl;
  late final TextEditingController unitCtl;
  late final TextEditingController categoryCtl;
  late final TextEditingController saleCtl;
  late final TextEditingController purchaseCtl;
  late final TextEditingController reorderCtl;
  late final TextEditingController stockCtl;
  late final TextEditingController potencyCtl;

  bool saving = false;

  bool get isEdit => widget.product != null;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product ?? {};
    skuCtl = TextEditingController(text: (p['sku'] ?? '').toString());
    nameCtl = TextEditingController(text: (p['name'] ?? '').toString());
    unitCtl = TextEditingController(text: (p['unit'] ?? 'pcs').toString());
    categoryCtl = TextEditingController(
      text: (p['category'] is Map ? p['category']['name'] : p['category'] ?? '').toString(),
    );
    saleCtl = TextEditingController(text: _toNum(p['sale_price']).toString());
    purchaseCtl = TextEditingController(text: _toNum(p['purchase_price']).toString());
    reorderCtl = TextEditingController(text: _toNum(p['reorder_level']).toString());
    stockCtl = TextEditingController(text: _toNum(p['in_stock']).toString());
    potencyCtl = TextEditingController(text: (p['potency_tag'] ?? '').toString());
  }

  @override
  void dispose() {
    skuCtl.dispose();
    nameCtl.dispose();
    unitCtl.dispose();
    categoryCtl.dispose();
    saleCtl.dispose();
    purchaseCtl.dispose();
    reorderCtl.dispose();
    stockCtl.dispose();
    potencyCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => saving = true);
    final now = DateTime.now();
    final p = widget.product ?? {};
    final id = p['id'] == null ? -now.millisecondsSinceEpoch : _toInt(p['id']);
    final uuid = (p['uuid'] ?? 'p-${now.microsecondsSinceEpoch}').toString();

    final map = <String, dynamic>{
      'id': id,
      'uuid': uuid,
      'sku': skuCtl.text.trim(),
      'name': nameCtl.text.trim(),
      'unit': unitCtl.text.trim().isEmpty ? 'pcs' : unitCtl.text.trim(),
      'category': categoryCtl.text.trim().isEmpty ? null : {'name': categoryCtl.text.trim()},
      'category_id': p['category_id'],
      'potency_tag': potencyCtl.text.trim().isEmpty ? null : potencyCtl.text.trim(),
      'sale_price': _toNum(saleCtl.text.trim()),
      'purchase_price': _toNum(purchaseCtl.text.trim()),
      'reorder_level': _toNum(reorderCtl.text.trim()),
      'in_stock': _toNum(stockCtl.text.trim()),
      'is_active': 1,
      'updated_at_client': now.toIso8601String(),
    };

    final products = Hive.box('products');
    bool replaced = false;
    for (int i = 0; i < products.length; i++) {
      final v = products.getAt(i);
      if (v is Map && ((v['id'] == id) || ((v['uuid'] ?? '').toString() == uuid))) {
        await products.putAt(i, map);
        replaced = true;
        break;
      }
    }
    if (!replaced) {
      await products.add(map);
    }

    final outbox = Hive.box('outboxBox');
    await outbox.add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'products',
      'op': 'UPSERT',
      'uuid': uuid,
      'version': (p['version'] ?? 1),
      'payload': map,
      'created_at': now.toIso8601String(),
    });

    if (!mounted) return;
    setState(() => saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Item' : 'Add New Item')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextFormField(
              controller: skuCtl,
              decoration: const InputDecoration(labelText: 'SKU', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: categoryCtl,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: unitCtl,
              decoration: const InputDecoration(labelText: 'Unit', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: potencyCtl,
              decoration: const InputDecoration(labelText: 'Potency Tag', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: saleCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Sale Price', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: purchaseCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Purchase Price', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reorderCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reorder Level', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: stockCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'In Stock', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(saving ? 'Saving...' : 'Save Item'),
            ),
          ],
        ),
      ),
    );
  }
}
