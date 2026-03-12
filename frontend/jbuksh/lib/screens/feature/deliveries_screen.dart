import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/local_store.dart';
import 'feature_scaffold.dart';

class DeliveriesScreen extends StatelessWidget {
  const DeliveriesScreen({super.key});

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _deliveryForInvoice(String invoiceUuid) {
    final box = Hive.box('deliveries');
    final existing = box.get(invoiceUuid);
    if (existing is Map) return existing.cast<String, dynamic>();
    return {
      'invoice_uuid': invoiceUuid,
      'status': 'PACKED',
      'packed_at': DateTime.now().toIso8601String(),
      'dispatched_at': null,
      'delivered_at': null,
      'stock_out_done': false,
      'stock_out_at': null,
    };
  }

  Future<void> _applyStockOutForDelivery(
    Map<String, dynamic> invoice,
    Map<String, dynamic> delivery,
  ) async {
    if (delivery['stock_out_done'] == true) return;

    final items = (invoice['items'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList() ??
        const <Map<String, dynamic>>[];
    if (items.isEmpty) return;

    final productsBox = Hive.box('products');
    final stockBox = Hive.box('stock_txns');
    final outbox = Hive.box('outboxBox');
    final now = DateTime.now().toIso8601String();

    for (final line in items) {
      final productId = line['product_id'];
      final lineSku = (line['sku'] ?? '').toString();
      final moveQty = _toNum(line['qty']) + _toNum(line['free_qty']);
      if (moveQty <= 0) continue;

      dynamic foundKey;
      Map<String, dynamic>? foundProduct;
      for (final key in productsBox.keys) {
        final raw = productsBox.get(key);
        if (raw is! Map) continue;
        final p = raw.cast<String, dynamic>();
        final idMatch = productId != null && p['id'] == productId;
        final skuMatch = lineSku.isNotEmpty && (p['sku']?.toString() ?? '') == lineSku;
        if (idMatch || skuMatch) {
          foundKey = key;
          foundProduct = Map<String, dynamic>.from(p);
          break;
        }
      }
      if (foundKey == null || foundProduct == null) continue;

      final current = _toNum(foundProduct['in_stock']);
      final nextStock = current - moveQty;
      foundProduct['in_stock'] = nextStock < 0 ? 0 : nextStock;
      await productsBox.put(foundKey, foundProduct);

      final txn = <String, dynamic>{
        'id': DateTime.now().microsecondsSinceEpoch,
        'product_id': foundProduct['id'],
        'txn_type': 'OUT',
        'qty': moveQty,
        'ref_type': 'DELIVERY',
        'ref_id': delivery['invoice_uuid'],
        'note': 'Delivery confirmed',
        'txn_date': now,
      };
      await stockBox.add(txn);
      await outbox.add({
        'entity': 'stock_txns',
        'op': 'UPSERT',
        'payload': txn,
        'created_at': now,
      });
    }

    delivery['stock_out_done'] = true;
    delivery['stock_out_at'] = now;
    await Hive.box('deliveries').put(delivery['invoice_uuid'], delivery);
  }

  void _saveDelivery(BuildContext context, Map<String, dynamic> delivery) {
    Hive.box('deliveries').put(delivery['invoice_uuid'], delivery);

    Hive.box('audit_logs').add({
      'created_at': DateTime.now().toIso8601String(),
      'entity_type': 'DELIVERY',
      'entity_id': delivery['invoice_uuid'],
      'action': 'UPDATE',
      'before_json': null,
      'after_json': delivery,
    });

    Hive.box('outboxBox').add({
      'queued_at': DateTime.now().toIso8601String(),
      'entity': 'delivery',
      'op': 'UPSERT',
      'uuid': delivery['invoice_uuid'],
      'payload': delivery,
    });

    Hive.box('notifications').add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'title': 'Delivery updated',
      'body': 'Invoice ${delivery['invoice_uuid']} -> ${delivery['status']}',
      'type': 'DELIVERY',
      'ref_type': 'DELIVERY',
      'ref_id': delivery['invoice_uuid'],
      'is_read': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Delivery updated: ${delivery['status']}')));
  }

  @override
  Widget build(BuildContext context) {
    final invoicesBox = Hive.box('invoices');
    final deliveriesBox = Hive.box('deliveries');

    return FeatureScaffold(
      title: 'Deliveries',
      actions: [
        IconButton(
          tooltip: 'Info',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Stock Policy'),
              content: const Text('Stock will be reduced only when delivery is confirmed as DELIVERED.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          ),
          icon: const Icon(Icons.info_outline),
        )
      ],
      child: AnimatedBuilder(
        animation: Listenable.merge([
          invoicesBox.listenable(),
          deliveriesBox.listenable(),
        ]),
        builder: (context, _) {
          final invoices = LocalStore.allBoxMaps('invoices')
              .where((e) {
                final status = (e['status'] ?? '').toString();
                return status == 'APPROVED' || status == 'PRINTED';
              })
              .toList();
          invoices.sort((a, b) => (b['invoice_date'] ?? '').toString().compareTo((a['invoice_date'] ?? '').toString()));

          if (invoices.isEmpty) {
            return const Center(child: Text('No invoices ready for delivery.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final inv = invoices[index];
              final uuid = (inv['uuid'] ?? inv['invoice_no'] ?? index.toString()).toString();
              final partyRaw = inv['party'];
              final partyFromObj = partyRaw is Map ? (partyRaw['name'] ?? '').toString() : '';
              final partyName = (inv['party_name'] ?? partyFromObj).toString();
              final net = (inv['net_total'] ?? inv['net'] ?? 0).toString();

              final delivery = _deliveryForInvoice(uuid);
              final status = (delivery['status'] ?? 'PACKED').toString();

              Color chipColor(String s) {
                if (s == 'DELIVERED') return Colors.green;
                if (s == 'DISPATCHED') return Colors.blue;
                return Colors.orange;
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Invoice: ${inv['invoice_no'] ?? uuid}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Chip(
                            label: Text(status),
                            side: BorderSide(color: chipColor(status).withValues(alpha: 0.2)),
                            backgroundColor: chipColor(status).withValues(alpha: 0.12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Party: ${partyName.isEmpty ? '-' : partyName}'),
                      Text('Net: $net'),
                      if (delivery['packed_at'] != null) Text('Packed: ${delivery['packed_at']}'),
                      if (delivery['dispatched_at'] != null) Text('Dispatched: ${delivery['dispatched_at']}'),
                      if (delivery['delivered_at'] != null) Text('Delivered: ${delivery['delivered_at']}'),
                      if (delivery['stock_out_done'] == true && delivery['stock_out_at'] != null)
                        Text('Stock out posted: ${delivery['stock_out_at']}'),
                      const SizedBox(height: 10),
                      _Timeline(status: status),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: status == 'PACKED'
                                  ? () {
                                      delivery['status'] = 'DISPATCHED';
                                      delivery['dispatched_at'] = DateTime.now().toIso8601String();
                                      _saveDelivery(context, delivery);
                                    }
                                  : null,
                              child: const Text('Dispatch'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: status == 'DISPATCHED'
                                  ? () async {
                                      delivery['status'] = 'DELIVERED';
                                      delivery['delivered_at'] = DateTime.now().toIso8601String();
                                      _saveDelivery(context, delivery);
                                      await _applyStockOutForDelivery(inv, delivery);
                                    }
                                  : null,
                              child: const Text('Confirm Delivered'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final String status;
  const _Timeline({required this.status});

  int _step(String s) {
    if (s == 'DELIVERED') return 3;
    if (s == 'DISPATCHED') return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final step = _step(status);
    Widget dot(bool active) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.blue : Colors.grey.shade300,
          ),
        );

    Widget line(bool active) => Expanded(
          child: Container(
            height: 2,
            color: active ? Colors.blue.withValues(alpha: 0.6) : Colors.grey.shade300,
          ),
        );

    TextStyle label(bool active) => TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          color: active ? Colors.black : Colors.black54,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            dot(step >= 1),
            line(step >= 2),
            dot(step >= 2),
            line(step >= 3),
            dot(step >= 3),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Packed', style: label(step >= 1)),
            Text('Dispatched', style: label(step >= 2)),
            Text('Delivered', style: label(step >= 3)),
          ],
        ),
      ],
    );
  }
}

