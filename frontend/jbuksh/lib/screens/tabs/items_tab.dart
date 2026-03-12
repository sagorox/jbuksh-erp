import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/auth_client.dart';
import '../../core/local_store.dart';
import '../../core/role_utils.dart';
import '../../models/product.dart';
import '../../routes.dart';

class ItemsTab extends StatefulWidget {
  const ItemsTab({super.key});

  @override
  State<ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<ItemsTab> {
  bool loading = true;
  String? err;
  List<Product> items = [];
  String q = '';
  bool lowOnly = false;
  String categoryFilter = 'All Categories';

  bool get canManageItems {
    final role = RoleUtils.normalize(LocalStore.role());
    return role == RoleUtils.superAdmin || role == RoleUtils.stockKeeper;
  }

  List<Product> _fromCache() {
    final box = Hive.box('products');
    return box.values
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      err = null;
      items = _fromCache();
    });

    try {
      final res = await AuthClient.get(Uri.parse('${Api.baseUrl}/api/v1/products'));
      if (res.statusCode != 200) {
        setState(() => err = 'Showing cached products');
        return;
      }

      final data = jsonDecode(res.body);
      final list = data is List ? data : (data['items'] ?? data['products'] ?? []);
      final rows = (list as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final box = Hive.box('products');
      for (final row in rows) {
        await box.put('${row['id'] ?? row['sku'] ?? DateTime.now().microsecondsSinceEpoch}', row);
      }
      items = rows.map(Product.fromJson).toList();
    } catch (_) {
      items = _fromCache();
      err = 'Showing cached products';
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = <String>{'All Categories'};
    for (final p in items) {
      final c = (p.categoryName ?? '').trim();
      if (c.isNotEmpty) categories.add(c);
    }

    final filtered = items.where((p) {
      if (lowOnly && p.reorderLevel > 0 && p.inStock > p.reorderLevel) return false;
      if (categoryFilter != 'All Categories' && (p.categoryName ?? '') != categoryFilter) return false;
      if (q.trim().isEmpty) return true;
      final s = '${p.name} ${p.sku} ${p.categoryName ?? ''}'.toLowerCase();
      return s.contains(q.trim().toLowerCase());
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search item / sku / category',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: lowOnly,
                  onSelected: (v) => setState(() => lowOnly = v),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: categoryFilter,
                  items: categories
                      .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => categoryFilter = v ?? 'All Categories'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                if (err != null)
                  Expanded(
                    child: Text(err!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
                if (canManageItems)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed(RouteNames.addEditItem);
                      if (!mounted) return;
                      await load();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No products match current filter')),
            )
          else
            ...filtered.map((p) {
              final lowStock = p.reorderLevel > 0 && p.inStock <= p.reorderLevel;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  onTap: () => Navigator.of(context).pushNamed(
                    RouteNames.productDetails,
                    arguments: {
                      'id': p.id,
                      'sku': p.sku,
                      'name': p.name,
                      'unit': p.unit,
                      'category': p.categoryName,
                      'category_id': p.categoryId,
                      'potency_tag': p.potencyTag,
                      'sale_price': p.salePrice,
                      'purchase_price': p.purchasePrice,
                      'reorder_level': p.reorderLevel,
                      'in_stock': p.inStock,
                    },
                  ),
                  title: Text(p.name),
                  subtitle: Text('SKU: ${p.sku} • Unit: ${p.unit ?? '-'} • Cat: ${p.categoryName ?? '-'}'),
                  trailing: canManageItems
                      ? PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await Navigator.of(context).pushNamed(
                                RouteNames.addEditItem,
                                arguments: {
                                  'id': p.id,
                                  'sku': p.sku,
                                  'name': p.name,
                                  'unit': p.unit,
                                  'category': p.categoryName,
                                  'category_id': p.categoryId,
                                  'potency_tag': p.potencyTag,
                                  'sale_price': p.salePrice,
                                  'purchase_price': p.purchasePrice,
                                  'reorder_level': p.reorderLevel,
                                  'in_stock': p.inStock,
                                },
                              );
                              if (!mounted) return;
                              await load();
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                          ],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Stock: ${p.inStock}'),
                              Text('Sale: ${p.salePrice}'),
                              if (lowStock) const Text('LOW', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Stock: ${p.inStock}'),
                            Text('Sale: ${p.salePrice}'),
                            if (lowStock) const Text('LOW', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
