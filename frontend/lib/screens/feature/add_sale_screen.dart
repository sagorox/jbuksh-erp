import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../models/party.dart';
import '../../models/product.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class _CartLine {
  final Product product;
  num qty = 1;
  num freeQty = 0;
  num unitPrice;

  _CartLine({
    required this.product,
    required this.unitPrice,
  });

  num get lineTotal => max(0, qty) * max(0, unitPrice);

  Map<String, dynamic> toJson() => {
        'product_id': product.id,
        'sku': product.sku,
        'name': product.name,
        'qty': qty,
        'free_qty': freeQty,
        'unit_price': unitPrice,
        'line_total': lineTotal,
      };
}

class AddSaleScreen extends StatefulWidget {
  const AddSaleScreen({super.key});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  Party? party;
  final lines = <_CartLine>[];

  final discountPercentCtrl = TextEditingController(text: '0');
  final discountAmountCtrl = TextEditingController(text: '0');
  final receivedCtrl = TextEditingController(text: '0');

  String money(num v) => v.toStringAsFixed(2);

  List<Party> _parties() {
    return LocalStore.allBoxMaps('parties').map((e) => Party.fromJson(e)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<Product> _products() {
    return LocalStore.allBoxMaps('products').map((e) => Product.fromJson(e)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  num get subtotal => lines.fold<num>(0, (p, e) => p + e.lineTotal);

  num get discountPercent => num.tryParse(discountPercentCtrl.text.trim()) ?? 0;
  num get discountAmount => num.tryParse(discountAmountCtrl.text.trim()) ?? 0;
  num get receivedAmount => num.tryParse(receivedCtrl.text.trim()) ?? 0;

  num get computedDiscountFromPercent => subtotal * (max(0, discountPercent) / 100);

  num get netTotal {
    final d = max(0, discountAmount) + max(0, computedDiscountFromPercent);
    return max(0, subtotal - d);
  }

  num get dueAmount => max(0, netTotal - max(0, receivedAmount));

  String _tempInvoiceNo() {
    final now = DateTime.now();
    return 'DRAFT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  String _uuid() {
    final r = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final b = StringBuffer();
    for (var i = 0; i < 32; i++) {
      b.write(chars[r.nextInt(chars.length)]);
    }
    final s = b.toString();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> _pickParty() async {
    final items = _parties();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No parties in offline cache. Sync/bootstrap first.')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Party>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final filtered = items.where((p) {
              if (q.isEmpty) return true;
              final s = '${p.name} ${p.partyCode}'.toLowerCase();
              return s.contains(q.toLowerCase());
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search party',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setSt(() => q = v),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text(p.partyCode),
                            onTap: () => Navigator.of(ctx).pop(p),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen != null) setState(() => party = chosen);
  }

  Future<void> _addProduct() async {
    final items = _products();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products in offline cache. Sync/bootstrap first.')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final filtered = items.where((p) {
              if (q.isEmpty) return true;
              final s = '${p.name} ${p.sku}'.toLowerCase();
              return s.contains(q.toLowerCase());
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search item',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setSt(() => q = v),
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, index) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = filtered[i];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text('${p.sku} • ৳ ${money(p.salePrice)} • Stock ${p.inStock}'),
                            onTap: () => Navigator.of(ctx).pop(p),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (chosen == null) return;

    final existing = lines.where((l) => l.product.id == chosen.id).toList();
    if (existing.isNotEmpty) {
      setState(() => existing.first.qty += 1);
    } else {
      setState(() => lines.add(_CartLine(product: chosen, unitPrice: chosen.salePrice)));
    }
  }

  Future<Map<String, dynamic>?> _saveOnlineInvoice({
    required dynamic territoryId,
    required bool submit,
    required DateTime now,
  }) async {
    final create = await Api.postJson('/api/v1/invoices', {
      'territory_id': territoryId,
      'party_id': party!.id,
      'invoice_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'invoice_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00',
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'remarks': null,
    });

    final created = (create['invoice'] is Map)
        ? (create['invoice'] as Map).cast<String, dynamic>()
        : (create['data'] is Map)
            ? (create['data'] as Map).cast<String, dynamic>()
            : null;
    if (created == null || created['id'] == null) return null;

    final invoiceId = created['id'];
    final itemRows = lines
        .map((e) => {
              'product_id': e.product.id,
              'qty': e.qty,
              'free_qty': e.freeQty,
              'unit_price': e.unitPrice,
            })
        .toList();

    final addItems = await Api.postJson('/api/v1/invoices/$invoiceId/items', {'items': itemRows});
    final invWithItems = (addItems['invoice'] is Map)
        ? (addItems['invoice'] as Map).cast<String, dynamic>()
        : created;
    invWithItems['items'] = (addItems['items'] as List?) ?? lines.map((e) => e.toJson()).toList();
    invWithItems['party'] = {'id': party!.id, 'name': party!.name};
    invWithItems['party_name'] = party!.name;

    if (submit) {
      await Api.postJson('/api/v1/invoices/$invoiceId/submit', {});
      invWithItems['status'] = 'PENDING_APPROVAL';
    }

    return invWithItems;
  }

  Future<void> _saveDraft({required bool submit}) async {
    if (party == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a party first.')));
      return;
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least 1 item.')));
      return;
    }

    final now = DateTime.now();
    final invoiceNo = _tempInvoiceNo();
    final uuid = _uuid();
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final territoryIds = ((user['territory_ids'] as List?) ?? const []).toList();
    final territoryId = user['territory_id'] ?? user['territory']?['id'] ?? (territoryIds.isNotEmpty ? territoryIds.first : null);

    if (territoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No territory assigned to your user. Please contact admin.')),
      );
      return;
    }

    final map = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch, // offline draft sortable
      'uuid': uuid,
      'invoice_no': invoiceNo,
      'invoice_date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'invoice_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'status': submit ? 'PENDING_APPROVAL' : 'DRAFT',
      'mpo_user_id': user['id'] ?? user['sub'],
      'territory_id': territoryId,
      'party_id': party!.id,
      'party': {'id': party!.id, 'name': party!.name},
      'party_name': party!.name,
      'subtotal': subtotal,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'net_total': netTotal,
      'received_amount': receivedAmount,
      'due_amount': dueAmount,
      'items': lines.map((e) => e.toJson()).toList(),
      'version': 1,
      'updated_at_client': now.toIso8601String(),
    };

    final invoices = Hive.box('invoices');
    var savedOnline = false;
    try {
      if (submit) {
        final online = await _saveOnlineInvoice(
          territoryId: territoryId,
          submit: submit,
          now: now,
        );
        if (online != null) {
          final key = (online['id'] ?? online['uuid'] ?? uuid).toString();
          await invoices.put(key, online);
          savedOnline = true;
        }
      }
    } catch (_) {
      savedOnline = false;
    }

    if (!savedOnline) {
      await invoices.add(map);
    }

    if (submit && !savedOnline) {
      // Outbox placeholder (later sync engine will push)
      final outbox = Hive.box('outboxBox');
      final change = {
        'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
        'entity': 'invoices',
        'op': 'UPSERT',
        'uuid': uuid,
        'version': 1,
        'payload': map,
        'queued_at': now.toIso8601String(),
      };
      await outbox.add(change);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedOnline
              ? 'Sale submitted to server.'
              : (submit ? 'Submitted for approval (offline queued).' : 'Draft saved (offline).'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    discountPercentCtrl.dispose();
    discountAmountCtrl.dispose();
    receivedCtrl.dispose();
    super.dispose();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['party'] is Map && party == null) {
      final p = args['party'] as Map;
      setState(() {
        party = Party.fromJson(Map<String, dynamic>.from(p));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Add New Sale',
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              title: Text(party?.name ?? 'Select Party'),
              subtitle: Text(party == null ? 'Tap to choose customer/party' : 'Party Code: ${party!.partyCode}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickParty,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Billed Items', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (lines.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('No items yet. Tap “Add Item”.'),
                    )
                  else
                    ...lines.map((l) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('৳ ${money(l.unitPrice)} • SKU ${l.product.sku}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => l.qty = max(0, l.qty - 1)),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text(
                                l.qty.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => l.qty += 1),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) async {
                                if (v == 'edit') {
                                  await _editLine(l);
                                }
                                if (v == 'remove') {
                                  setState(() => lines.remove(l));
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit qty/price/free')),
                                PopupMenuItem(value: 'remove', child: Text('Remove')),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('৳ ${money(subtotal)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountPercentCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Discount %',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: discountAmountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Discount amount',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: receivedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Received amount',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Total', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('৳ ${money(netTotal)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Balance Due', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('৳ ${money(dueAmount)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.red)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveDraft(submit: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _saveDraft(submit: true),
                  icon: const Icon(Icons.send),
                  label: const Text('Submit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Offline-first: Save Draft keeps it local. Submit will also queue to Outbox for sync later.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushNamed(RouteNames.transactions);
            },
            child: const Text('Back to Transactions'),
          ),
        ],
      ),
    );
  }

  Future<void> _editLine(_CartLine l) async {
    final qtyCtrl = TextEditingController(text: l.qty.toString());
    final freeCtrl = TextEditingController(text: l.freeQty.toString());
    final priceCtrl = TextEditingController(text: l.unitPrice.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l.product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Qty'),
              ),
              TextField(
                controller: freeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Free qty'),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Unit price'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apply')),
          ],
        );
      },
    );

    if (ok == true) {
      setState(() {
        l.qty = num.tryParse(qtyCtrl.text.trim()) ?? l.qty;
        l.freeQty = num.tryParse(freeCtrl.text.trim()) ?? l.freeQty;
        l.unitPrice = num.tryParse(priceCtrl.text.trim()) ?? l.unitPrice;
      });
    }
  }
}
