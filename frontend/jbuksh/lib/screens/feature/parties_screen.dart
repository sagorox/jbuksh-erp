import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  String q = '';
  bool _loading = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncFromServer();
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
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
      final res = await Api.getJson('/api/v1/parties');
      final rows = _readList(res, ['parties', 'items', 'data']);

      final box = Hive.box('parties');
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
    final rows = LocalStore.allBoxMaps('parties');
    final filtered = rows.where((p) {
      if (q.isEmpty) return true;
      final name = (p['name'] ?? '').toString();
      final code = (p['party_code'] ?? p['partyCode'] ?? '').toString();
      final phone = (p['phone'] ?? p['mobile'] ?? '').toString();
      final s = '$name $code $phone'.toLowerCase();
      return s.contains(q.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final an = (a['name'] ?? '').toString().toLowerCase();
      final bn = (b['name'] ?? '').toString().toLowerCase();
      return an.compareTo(bn);
    });

    return filtered;
  }

  Map<String, dynamic> _mapForDetails(Map<String, dynamic> src) {
    return {
      'id': _toInt(src['id']) ?? 0,
      'uuid': src['uuid'],
      'party_code': (src['party_code'] ?? src['partyCode'] ?? '').toString(),
      'name': (src['name'] ?? '').toString(),
      'owner_name': src['owner_name'] ?? src['ownerName'],
      'phone': src['phone'] ?? src['mobile'],
      'address': src['address'] ?? src['address_text'],
      'credit_limit': src['credit_limit'] ?? src['creditLimit'] ?? 0,
      'opening_balance': src['opening_balance'] ?? src['openingBalance'] ?? 0,
      'territory_id': src['territory_id'] ?? src['territoryId'],
    };
  }

  bool _sameParty(Map<String, dynamic> party, Map<String, dynamic> row) {
    final partyId = _toInt(party['id']);
    final rowPartyId = _toInt(row['party_id'] ?? row['party']?['id']);
    return partyId != null && rowPartyId == partyId;
  }

  List<Map<String, dynamic>> _partyInvoices(Map<String, dynamic> party) {
    final rows = LocalStore.allBoxMaps('invoices').where((e) {
      return _sameParty(party, e);
    }).toList();

    rows.sort((a, b) {
      final d1 = (a['invoice_date'] ?? '').toString();
      final d2 = (b['invoice_date'] ?? '').toString();
      return d2.compareTo(d1);
    });

    return rows;
  }

  num _partyDue(Map<String, dynamic> party) {
    final invoices = _partyInvoices(party);

    final active = invoices.where((e) {
      final st = (e['status'] ?? '').toString().toUpperCase();
      return st != 'CANCELLED' && st != 'DECLINED';
    });

    return active.fold<num>(0, (sum, e) => sum + _toNum(e['due_amount']));
  }

  String _lastInvoiceNo(Map<String, dynamic> party) {
    final invoices = _partyInvoices(party);
    if (invoices.isEmpty) return '-';

    final inv = invoices.first;
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    if (serverNo.isNotEmpty) return serverNo;
    return (inv['invoice_no'] ?? '-').toString();
  }

  String _lastInvoiceDate(Map<String, dynamic> party) {
    final invoices = _partyInvoices(party);
    if (invoices.isEmpty) return '-';
    return (invoices.first['invoice_date'] ?? '-').toString();
  }

  String _buildReminderText(Map<String, dynamic> party) {
    final name = (party['name'] ?? 'Customer').toString();
    final due = _partyDue(party).toStringAsFixed(2);
    final lastInv = _lastInvoiceNo(party);
    final lastDate = _lastInvoiceDate(party);

    return '''
প্রিয় $name,
আপনার কাছে বর্তমানে মোট বকেয়া Tk $due আছে।
সর্বশেষ Invoice: $lastInv
তারিখ: $lastDate
অনুগ্রহ করে সুবিধামতো payment complete করুন।
ধন্যবাদ।
'''.trim();
  }

  Future<void> _copyReminder(Map<String, dynamic> party) async {
    final text = _buildReminderText(party);
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _rows();

    return FeatureScaffold(
      title: 'Parties',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _syncFromServer,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).pushNamed(RouteNames.addParty);
          await _syncFromServer();
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Party'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search party / code',
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
            child: _loading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const Center(child: Text('No parties found'))
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final raw = items[i];
                final map = _mapForDetails(raw);

                final partyId = _toInt(map['id']);
                final name = (map['name'] ?? '-').toString();
                final code = (map['party_code'] ?? '').toString();
                final phone = (map['phone'] ?? '').toString();
                final due = _partyDue(map).toStringAsFixed(2);

                final sub =
                    'Code: $code${phone.isEmpty ? '' : ' | $phone'} | Due: Tk $due';

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.store_mall_directory_outlined),
                      ),
                      title: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(sub),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'details') {
                            Navigator.of(context).pushNamed(
                              RouteNames.partyDetails,
                              arguments: map,
                            );
                          } else if (v == 'payment') {
                            Navigator.of(context).pushNamed(
                              RouteNames.takePayment,
                              arguments: map,
                            );
                          } else if (v == 'statement') {
                            Navigator.of(context).pushNamed(
                              RouteNames.reportFilter,
                              arguments: {
                                'reportKey': 'Party Statement',
                                'partyId': partyId,
                              },
                            );
                          } else if (v == 'reminder') {
                            await _copyReminder(map);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'details',
                            child: Text('Details'),
                          ),
                          PopupMenuItem(
                            value: 'payment',
                            child: Text('Take Payment'),
                          ),
                          PopupMenuItem(
                            value: 'statement',
                            child: Text('Party Statement'),
                          ),
                          PopupMenuItem(
                            value: 'reminder',
                            child: Text('Send Reminder'),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pushNamed(
                        RouteNames.partyDetails,
                        arguments: map,
                      ),
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