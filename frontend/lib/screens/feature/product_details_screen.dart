import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  bool _refreshing = false;
  bool _creating = false;
  String? _serverNote;

  int? get _productId {
    final raw = widget.product['id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  String get _productUuid => (widget.product['uuid'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshBatchesFromServer(silent: true);
    });
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String _toStr(dynamic v) => (v ?? '').toString();

  String _fmtNum(num v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  Future<void> _refreshBatchesFromServer({bool silent = false}) async {
    final pid = _productId;
    if (pid == null) return;

    if (!silent && mounted) {
      setState(() => _refreshing = true);
    }

    try {
      final res = await Api.getJson('/api/v1/products/$pid/batches');
      final rows = (res['batches'] as List?) ?? const [];
      final box = Hive.box('product_batches');

      final existingKeys = box.keys.toList();
      for (final key in existingKeys) {
        final raw = box.get(key);
        if (raw is! Map) continue;
        final m = raw.cast<String, dynamic>();
        if (_sameProduct(m)) {
          await box.delete(key);
        }
      }

      for (final item in rows) {
        if (item is! Map) continue;
        final row = item.cast<String, dynamic>();

        final normalized = <String, dynamic>{
          ...jsonDecode(jsonEncode(row)) as Map<String, dynamic>,
          'source': 'server',
          'sync_status': 'SYNCED',
          'local_only': 0,
          'last_synced_at': DateTime.now().toUtc().toIso8601String(),
        };

        final key = row['id']?.toString() ??
            row['uuid']?.toString() ??
            row['batch_no']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString();

        await box.put(key, normalized);
      }

      Hive.box('cacheBox').put(
        'product_batches_last_sync_$pid',
        DateTime.now().toUtc().toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _serverNote = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverNote = 'Offline cache shown';
        });
      }
      debugPrint('Batch refresh failed: $e');
    } finally {
      if (!silent && mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  bool _sameProduct(Map<String, dynamic> row) {
    final pid = _productId;
    final rowPid = row['product_id'];
    final rowProductUuid = _toStr(row['product_uuid']);
    if (pid != null && rowPid != null && rowPid.toString() == pid.toString()) {
      return true;
    }
    if (_productUuid.isNotEmpty &&
        rowProductUuid.isNotEmpty &&
        rowProductUuid == _productUuid) {
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _allBatchesForThisProduct() {
    final box = Hive.box('product_batches');
    final rows = box.values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where(_sameProduct)
        .toList();

    rows.sort((a, b) {
      final ae = _toStr(a['expiry_date']);
      final be = _toStr(b['expiry_date']);
      final cmp = ae.compareTo(be);
      if (cmp != 0) return cmp;
      return _toInt(b['id']).compareTo(_toInt(a['id']));
    });

    return rows;
  }

  String _expiryStatus(Map<String, dynamic> row) {
    final raw = _toStr(row['expiry_status']).trim().toUpperCase();
    if (raw.isNotEmpty) return raw;

    final expiry = _toStr(row['expiry_date']).trim();
    if (expiry.isEmpty) return 'NO_EXPIRY';

    final dt = DateTime.tryParse(expiry);
    if (dt == null) return 'NO_EXPIRY';

    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanExpiry = DateTime(dt.year, dt.month, dt.day);

    if (cleanExpiry.isBefore(cleanToday)) return 'EXPIRED';

    final diff = cleanExpiry.difference(cleanToday).inDays;
    if (diff <= 30) return 'NEAR_EXPIRY';
    return 'VALID';
  }

  Future<void> _showAddBatchDialog() async {
    final pid = _productId;
    if (pid == null) return;

    final batchNoCtl = TextEditingController();
    final mfgCtl = TextEditingController();
    final expiryCtl = TextEditingController();
    final qtyCtl = TextEditingController();
    final costCtl = TextEditingController();
    final noteCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Batch'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: batchNoCtl,
                    decoration: const InputDecoration(labelText: 'Batch No'),
                    validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Batch no লাগবে' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: mfgCtl,
                    decoration: const InputDecoration(
                      labelText: 'MFG Date (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: expiryCtl,
                    decoration: const InputDecoration(
                      labelText: 'Expiry Date (YYYY-MM-DD)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: qtyCtl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty'),
                    validator: (v) {
                      final n = double.tryParse((v ?? '').trim());
                      if (n == null || n <= 0) return 'Valid qty দাও';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: costCtl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Unit Cost'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: noteCtl,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      batchNoCtl.dispose();
      mfgCtl.dispose();
      expiryCtl.dispose();
      qtyCtl.dispose();
      costCtl.dispose();
      noteCtl.dispose();
      return;
    }

    setState(() => _creating = true);

    final localUuid =
        'local-batch-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';

    final localRow = <String, dynamic>{
      'uuid': localUuid,
      'id': null,
      'product_id': pid,
      'product_uuid': _productUuid.isEmpty ? null : _productUuid,
      'batch_no': batchNoCtl.text.trim(),
      'mfg_date': mfgCtl.text.trim().isEmpty ? null : mfgCtl.text.trim(),
      'expiry_date':
      expiryCtl.text.trim().isEmpty ? null : expiryCtl.text.trim(),
      'qty': double.parse(qtyCtl.text.trim()),
      'remaining_qty': double.parse(qtyCtl.text.trim()),
      'unit_cost': costCtl.text.trim().isEmpty
          ? 0
          : (double.tryParse(costCtl.text.trim()) ?? 0),
      'status': 'ACTIVE',
      'note': noteCtl.text.trim().isEmpty ? null : noteCtl.text.trim(),
      'source': 'local',
      'local_only': 1,
      'sync_status': 'PENDING_CREATE',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await Hive.box('product_batches').put(localUuid, localRow);

      try {
        await Api.postJson('/api/v1/products/$pid/batches', {
          'batch_no': localRow['batch_no'],
          'mfg_date': localRow['mfg_date'],
          'expiry_date': localRow['expiry_date'],
          'qty': localRow['qty'],
          'unit_cost': localRow['unit_cost'],
          'note': localRow['note'],
        });

        await _refreshBatchesFromServer(silent: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Batch server এ save হয়েছে')),
          );
        }
      } catch (e) {
        await Hive.box('outboxBox').put(localUuid, {
          'entity': 'product_batch',
          'op': 'UPSERT',
          'uuid': localUuid,
          'version': 1,
          'payload': localRow,
          'created_at_client': DateTime.now().toUtc().toIso8601String(),
          'queued_at': DateTime.now().toUtc().toIso8601String(),
          'retry_count': 0,
          'next_retry_at': null,
          'last_error': 'Awaiting product_batch sync support',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Batch local এ save হয়েছে। পরে sync হবে.',
              ),
            ),
          );
        }
      }
    } finally {
      batchNoCtl.dispose();
      mfgCtl.dispose();
      expiryCtl.dispose();
      qtyCtl.dispose();
      costCtl.dispose();
      noteCtl.dispose();

      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  Widget _metric(String label, String value, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String k, String v, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg ?? Colors.black.withValues(alpha: 0.05),
      ),
      child: Text('$k: $v', style: const TextStyle(fontSize: 12)),
    );
  }

  Color _expiryBg(String status) {
    switch (status) {
      case 'EXPIRED':
        return Colors.red.withValues(alpha: 0.12);
      case 'NEAR_EXPIRY':
        return Colors.orange.withValues(alpha: 0.16);
      case 'VALID':
        return Colors.green.withValues(alpha: 0.12);
      default:
        return Colors.black.withValues(alpha: 0.05);
    }
  }

  Color _syncBg(String status) {
    switch (status) {
      case 'SYNCED':
        return Colors.green.withValues(alpha: 0.12);
      case 'PENDING_CREATE':
        return Colors.orange.withValues(alpha: 0.14);
      default:
        return Colors.black.withValues(alpha: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pid = widget.product['id'];

    return FeatureScaffold(
      title: 'Item Details',
      actions: [
        IconButton(
          tooltip: 'Adjust Stock',
          onPressed: () => Navigator.of(context).pushNamed(
            RouteNames.adjustStock,
            arguments: {'productId': pid},
          ),
          icon: const Icon(Icons.tune),
        ),
        IconButton(
          tooltip: 'Refresh batch from server',
          onPressed: _refreshing ? null : () => _refreshBatchesFromServer(),
          icon: _refreshing
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.sync),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _showAddBatchDialog,
        label: const Text('Add Batch'),
        icon: _creating
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.add),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          Hive.box('products').listenable(),
          Hive.box('stock_txns').listenable(),
          Hive.box('product_batches').listenable(),
        ]),
        builder: (context, _) {
          final products = LocalStore.allBoxMaps('products');
          final p = products.firstWhere(
                (e) =>
            pid != null &&
                (e['id'] == pid ||
                    (e['uuid'] ?? '').toString() ==
                        (widget.product['uuid'] ?? '').toString()),
            orElse: () => widget.product,
          );

          final name = (p['name'] ?? '-').toString();
          final sku = (p['sku'] ?? '-').toString();
          final unit = (p['unit'] ?? '-').toString();
          final potency = (p['potency_tag'] ?? '').toString();

          final inStock = _toNum(p['in_stock']);
          final salePrice = _toNum(p['sale_price']);
          final purchasePrice = _toNum(p['purchase_price']);
          final reorder = _toNum(p['reorder_level']);
          final stockValue = inStock * purchasePrice;

          final txnsAll = LocalStore.allBoxMaps('stock_txns');
          final txns = txnsAll
              .where((t) => pid != null && (t['product_id'] == pid))
              .toList()
            ..sort(
                  (a, b) => (b['txn_date'] ?? '')
                  .toString()
                  .compareTo((a['txn_date'] ?? '').toString()),
            );

          final batches = _allBatchesForThisProduct();
          final totalBatchQty =
          batches.fold<num>(0, (sum, x) => sum + _toNum(x['qty']));
          final totalRemaining = batches.fold<num>(
            0,
                (sum, x) => sum + _toNum(x['remaining_qty']),
          );
          final nearExpiryCount =
              batches.where((e) => _expiryStatus(e) == 'NEAR_EXPIRY').length;
          final expiredCount =
              batches.where((e) => _expiryStatus(e) == 'EXPIRED').length;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _chip('SKU', sku),
                          _chip('Unit', unit),
                          if (potency.isNotEmpty) _chip('Tag', potency),
                          if (_serverNote != null) _chip('Mode', _serverNote!),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              'In Stock',
                              inStock.toStringAsFixed(0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              'Stock Value',
                              stockValue.toStringAsFixed(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              'Sale Price',
                              salePrice.toStringAsFixed(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              'Purchase Price',
                              purchasePrice.toStringAsFixed(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              'Reorder Level',
                              reorder.toStringAsFixed(0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              'Batch / Expiry',
                              '${batches.length} batches',
                              subtitle:
                              'Local first view • online হলে latest update নেবে',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              'Batch Qty',
                              _fmtNum(totalBatchQty),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              'Remaining',
                              _fmtNum(totalRemaining),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _metric(
                              'Near Expiry',
                              '$nearExpiryCount',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _metric(
                              'Expired',
                              '$expiredCount',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Batch List',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (batches.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No batch found in local cache yet.'),
                  ),
                )
              else
                ...batches.map((b) {
                  final expiryStatus = _expiryStatus(b);
                  final syncStatus = _toStr(b['sync_status']).isEmpty
                      ? 'SYNCED'
                      : _toStr(b['sync_status']);
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _toStr(b['batch_no']).isEmpty
                                      ? '-'
                                      : _toStr(b['batch_no']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _chip(
                                'Expiry',
                                expiryStatus,
                                bg: _expiryBg(expiryStatus),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                'Sync',
                                syncStatus,
                                bg: _syncBg(syncStatus),
                              ),
                              _chip('Qty', _fmtNum(_toNum(b['qty']))),
                              _chip(
                                'Remaining',
                                _fmtNum(_toNum(b['remaining_qty'])),
                              ),
                              _chip(
                                'Unit Cost',
                                _fmtNum(_toNum(b['unit_cost'])),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_toStr(b['mfg_date']).isNotEmpty)
                            Text('MFG: ${_toStr(b['mfg_date'])}'),
                          if (_toStr(b['expiry_date']).isNotEmpty)
                            Text('Expiry: ${_toStr(b['expiry_date'])}'),
                          if (_toStr(b['status']).isNotEmpty)
                            Text('Status: ${_toStr(b['status'])}'),
                          if (_toStr(b['note']).isNotEmpty)
                            Text('Note: ${_toStr(b['note'])}'),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Text(
                'Stock Transactions',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (txns.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No stock movements yet.'),
                  ),
                )
              else
                ...txns.take(50).map(
                      (t) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Icon(
                        (t['txn_type'] ?? '').toString() == 'OUT'
                            ? Icons.south_east
                            : Icons.north_east,
                      ),
                      title: Text(
                        '${t['txn_type'] ?? '-'} • Qty ${_toNum(t['qty']).toStringAsFixed(0)}',
                      ),
                      subtitle:
                      Text('${t['ref_type'] ?? 'MANUAL'} • ${t['txn_date'] ?? ''}'),
                    ),
                  ),
                ),
              const SizedBox(height: 70),
            ],
          );
        },
      ),
    );
  }
}