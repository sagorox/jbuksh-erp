import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  String q = '';
  bool _loading = false;
  bool _busy = false;
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

  List<Map<String, dynamic>> _readList(
    Map<String, dynamic> src,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = src[k];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    return const [];
  }

  Future<void> _syncFromServer() async {
    setState(() {
      _loading = true;
      _syncError = null;
    });

    try {
      final res = await Api.getJson('/api/v1/collections');
      final rows = _readList(res, ['collections', 'items', 'data']);
      final box = Hive.box('collections');
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
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _rows() {
    final rows = LocalStore.allBoxMaps('collections');
    final filtered = rows.where((e) {
      if (q.isEmpty) return true;
      final collectionNo = (e['collection_no'] ?? '').toString();
      final party = (e['party']?['name'] ?? e['party_name'] ?? '').toString();
      final s = '$collectionNo $party'.toLowerCase();
      return s.contains(q.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final d1 = (a['collection_date'] ?? '').toString();
      final d2 = (b['collection_date'] ?? '').toString();
      final byDate = d2.compareTo(d1);
      if (byDate != 0) return byDate;

      final i1 = int.tryParse((a['id'] ?? '0').toString()) ?? 0;
      final i2 = int.tryParse((b['id'] ?? '0').toString()) ?? 0;
      return i2.compareTo(i1);
    });

    return filtered;
  }

  Future<void> _openTakePayment() async {
    final parties = LocalStore.allBoxMaps('parties')
      ..sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ),
      );

    if (parties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No parties found. Please sync or add party first.'),
        ),
      );
      return;
    }

    Map<String, dynamic>? chosen;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          builder: (ctx, scroll) => Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Select Party',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: parties.length,
                  itemBuilder: (_, i) {
                    final p = parties[i];
                    return ListTile(
                      title: Text(p['name']?.toString() ?? '-'),
                      subtitle: Text(p['party_code']?.toString() ?? ''),
                      onTap: () {
                        chosen = p;
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await Navigator.of(
        context,
      ).pushNamed(RouteNames.takePayment, arguments: chosen);
      await _syncFromServer();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cols = _rows();

    return FeatureScaffold(
      title: 'Collections',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loading || _busy ? null : _syncFromServer,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        onPressed: _busy ? null : _openTakePayment,
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Take Payment'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search collection / party',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          if (_syncError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Showing cached data. $_syncError',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ),
          Expanded(
            child: _loading && cols.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : cols.isEmpty
                ? const Center(child: Text('No collections found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cols.length,
                    itemBuilder: (ctx, i) {
                      final c = cols[i];
                      final amount = _toNum(c['amount']);
                      final date = (c['collection_date'] ?? '-').toString();
                      final party =
                          (c['party']?['name'] ?? c['party_name'] ?? '-')
                              .toString();
                      final method = (c['method'] ?? 'CASH')
                          .toString()
                          .toUpperCase();
                      final status = (c['status'] ?? '')
                          .toString()
                          .toUpperCase();

                      Color statusColor() {
                        if (status == 'APPROVED') return Colors.green;
                        if (status == 'DECLINED') return Colors.red;
                        return Colors.orange;
                      }

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.payments_outlined),
                          title: Text('Tk ${amount.toStringAsFixed(2)}'),
                          subtitle: Text('$date • $party'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(method),
                              if (status.isNotEmpty)
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
