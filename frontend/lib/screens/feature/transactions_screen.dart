import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String q = '';
  bool _loading = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _syncFromServer();
  }

  String _invoiceNo(Map<String, dynamic> m) {
    final serverNo = (m['server_invoice_no'] ?? '').toString().trim();
    if (serverNo.isNotEmpty) return serverNo;
    final no = (m['invoice_no'] ?? '').toString().trim();
    return no.isEmpty ? '-' : no;
  }

  bool _isTempInvoiceNo(Map<String, dynamic> m) {
    final serverNo = (m['server_invoice_no'] ?? '').toString().trim();
    final localNo = (m['invoice_no'] ?? '').toString().trim();
    return serverNo.isEmpty && localNo.startsWith('DRAFT-');
  }

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
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
      final res = await Api.getJson('/api/v1/invoices');
      final rows = _readList(res, ['invoices', 'items', 'data']);
      final box = Hive.box('invoices');
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
    final rows = LocalStore.allBoxMaps('invoices');
    final filtered = rows.where((e) {
      if (q.isEmpty) return true;
      final party = (e['party']?['name'] ?? e['party_name'] ?? '').toString();
      final s = '${_invoiceNo(e)} $party'.toLowerCase();
      return s.contains(q.toLowerCase());
    }).toList();

    filtered.sort((a, b) {
      final d1 = (a['invoice_date'] ?? '').toString();
      final d2 = (b['invoice_date'] ?? '').toString();
      final byDate = d2.compareTo(d1);
      if (byDate != 0) return byDate;

      final i1 = int.tryParse((a['id'] ?? '0').toString()) ?? 0;
      final i2 = int.tryParse((b['id'] ?? '0').toString()) ?? 0;
      return i2.compareTo(i1);
    });

    return filtered;
  }

  Map<String, dynamic> _findPartyForInvoice(Map<String, dynamic> inv) {
    final partyId = _toInt(inv['party_id'] ?? inv['party']?['id']);
    final parties = LocalStore.allBoxMaps('parties');

    for (final p in parties) {
      final pid = _toInt(p['id'] ?? p['server_id']);
      if (partyId != null && pid == partyId) return p;
    }

    return <String, dynamic>{};
  }

  String _invoiceSummaryText(Map<String, dynamic> inv) {
    final party = _findPartyForInvoice(inv);

    final items = (inv['items'] is List)
        ? (inv['items'] as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList()
        : <Map<String, dynamic>>[];

    final lines = <String>[
      'JBCL ERP Invoice Summary',
      'Invoice: ${_invoiceNo(inv)}',
      'Date: ${inv['invoice_date'] ?? '-'}',
      'Status: ${inv['status'] ?? '-'}',
      'Party: ${party['name'] ?? inv['party_name'] ?? '-'}',
      if ((party['phone'] ?? '').toString().trim().isNotEmpty)
        'Phone: ${party['phone']}',
      '',
      'Items:',
      if (items.isEmpty) '- No item rows',
      ...items.map((it) {
        final name =
        (it['name'] ?? it['product_name'] ?? it['sku'] ?? '-').toString();
        final qty = _toNum(it['qty']).toStringAsFixed(0);
        final rate = _toNum(it['unit_price']).toStringAsFixed(2);
        final total = _toNum(it['line_total']).toStringAsFixed(2);
        return '- $name | Qty: $qty | Rate: $rate | Total: $total';
      }),
      '',
      'Subtotal: ${_toNum(inv['subtotal']).toStringAsFixed(2)}',
      'Discount: ${_toNum(inv['discount_amount']).toStringAsFixed(2)}',
      'Net Total: ${_toNum(inv['net_total']).toStringAsFixed(2)}',
      'Received: ${_toNum(inv['received_amount']).toStringAsFixed(2)}',
      'Due: ${_toNum(inv['due_amount']).toStringAsFixed(2)}',
    ];

    return lines.join('\n');
  }

  String _dueReminderText(Map<String, dynamic> inv) {
    final party = _findPartyForInvoice(inv);
    final partyName = (party['name'] ?? inv['party_name'] ?? 'Customer').toString();
    final due = _toNum(inv['due_amount']).toStringAsFixed(2);

    return '''
প্রিয় $partyName,
আপনার Invoice ${_invoiceNo(inv)} এর বকেয়া টাকা Tk $due আছে।
তারিখ: ${inv['invoice_date'] ?? '-'}
অনুগ্রহ করে সুবিধামতো payment complete করুন।
ধন্যবাদ।
'''.trim();
  }

  Future<void> _copyText(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showMoreActions(Map<String, dynamic> inv) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Open Details'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamed(
                    RouteNames.transactionDetails,
                    arguments: inv,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Open Preview'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamed(
                    RouteNames.invoicePreview,
                    arguments: inv,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy Invoice Summary'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _copyText(
                    _invoiceSummaryText(inv),
                    'Invoice summary copied',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Copy Due Reminder'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _copyText(
                    _dueReminderText(inv),
                    'Due reminder copied',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _rows();

    return FeatureScaffold(
      title: 'Sales / Transactions',
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
          await Navigator.of(context).pushNamed(RouteNames.addSale);
          await _syncFromServer();
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Sale'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search invoice / party',
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
                ? const Center(child: Text('No transactions found'))
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) =>
              const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final inv = items[i];
                final invoiceNo = _invoiceNo(inv);
                final isTemp = _isTempInvoiceNo(inv);
                final status = (inv['status'] ?? '')
                    .toString()
                    .toUpperCase();
                final party =
                (inv['party']?['name'] ?? inv['party_name'] ?? '-')
                    .toString();
                final date = (inv['invoice_date'] ?? '-').toString();
                final total = _toNum(inv['net_total']);
                final due = _toNum(inv['due_amount']);
                final paid = due <= 0;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        party,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('Invoice: $invoiceNo | Date: $date'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Tk ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            paid
                                ? 'PAID'
                                : 'DUE Tk ${due.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: paid ? Colors.green : Colors.red,
                            ),
                          ),
                          if (isTemp || status == 'PENDING_APPROVAL')
                            Text(
                              isTemp ? 'TEMP' : status,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                          const SizedBox(height: 6),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            onSelected: (v) async {
                              if (v == 'details') {
                                Navigator.of(context).pushNamed(
                                  RouteNames.transactionDetails,
                                  arguments: inv,
                                );
                              } else if (v == 'print') {
                                Navigator.of(context).pushNamed(
                                  RouteNames.invoicePreview,
                                  arguments: inv,
                                );
                              } else if (v == 'share') {
                                await _copyText(
                                  _invoiceSummaryText(inv),
                                  'Invoice summary copied',
                                );
                              } else if (v == 'more') {
                                await _showMoreActions(inv);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'details',
                                child: Text('Open Details'),
                              ),
                              PopupMenuItem(
                                value: 'print',
                                child: Text('Print (PDF)'),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: Text('Share'),
                              ),
                              PopupMenuItem(
                                value: 'more',
                                child: Text('More'),
                              ),
                            ],
                            child: const Icon(Icons.more_horiz, size: 20),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pushNamed(
                        RouteNames.transactionDetails,
                        arguments: inv,
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