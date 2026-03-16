import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class TransactionDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const TransactionDetailsScreen({super.key, required this.invoice});

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  bool _actionBusy = false;

  String money(num v) => v.toStringAsFixed(2);

  Map<String, dynamic> get inv => widget.invoice;
  String get _invoiceUuid => (inv['uuid'] ?? '').toString();
  int? get _invoiceId => int.tryParse((inv['id'] ?? '').toString());

  String get invoiceNo {
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    if (serverNo.isNotEmpty) return serverNo;
    return (inv['invoice_no'] ?? '-').toString();
  }

  bool get isTempInvoiceNo {
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    return serverNo.isEmpty && invoiceNo.startsWith('DRAFT-');
  }

  String get status => (inv['status'] ?? '').toString();

  List<Map<String, dynamic>> get items {
    final raw = inv['items'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
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

  Map<String, dynamic> _findParty() {
    final partyId = _toInt(inv['party_id'] ?? inv['party']?['id']);
    final parties = LocalStore.allBoxMaps('parties');

    for (final p in parties) {
      final pid = _toInt(p['id'] ?? p['server_id']);
      if (partyId != null && pid == partyId) return p;
    }

    return <String, dynamic>{};
  }

  String _invoiceSummaryText() {
    final party = _findParty();

    final lines = <String>[
      'JBCL ERP Invoice Summary',
      'Invoice: $invoiceNo',
      'Date: ${inv['invoice_date'] ?? '-'}',
      'Status: ${inv['status'] ?? '-'}',
      'Party: ${party['name'] ?? inv['party_name'] ?? inv['party']?['name'] ?? '-'}',
      if ((party['phone'] ?? '').toString().trim().isNotEmpty)
        'Phone: ${party['phone']}',
      if ((party['address'] ?? '').toString().trim().isNotEmpty)
        'Address: ${party['address']}',
      '',
      'Items:',
      if (items.isEmpty) '- No items',
      ...items.map((it) {
        final name =
        (it['name'] ?? it['product_name'] ?? it['sku'] ?? '-').toString();
        final qty = _toNum(it['qty']).toStringAsFixed(0);
        final free = _toNum(it['free_qty']).toStringAsFixed(0);
        final rate = _toNum(it['unit_price']).toStringAsFixed(2);
        final total = _toNum(it['line_total']).toStringAsFixed(2);
        return '- $name | Qty: $qty | Free: $free | Rate: $rate | Total: $total';
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

  String _dueReminderText() {
    final party = _findParty();
    final partyName =
    (party['name'] ?? inv['party_name'] ?? inv['party']?['name'] ?? 'Customer')
        .toString();
    final due = _toNum(inv['due_amount']).toStringAsFixed(2);

    return '''
প্রিয় $partyName,
আপনার Invoice $invoiceNo এর বকেয়া টাকা Tk $due আছে।
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

  Future<void> _showShareActions() async {
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
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy Invoice Summary'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _copyText(_invoiceSummaryText(), 'Invoice summary copied');
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Copy Due Reminder'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _copyText(_dueReminderText(), 'Due reminder copied');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Open PDF Preview'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamed(
                    RouteNames.invoicePreview,
                    arguments: inv,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isSameInvoice(Map<String, dynamic> row) {
    final rowUuid = (row['uuid'] ?? '').toString();
    if (_invoiceUuid.isNotEmpty && rowUuid == _invoiceUuid) {
      return true;
    }

    final rowId = int.tryParse((row['id'] ?? '').toString());
    final id = _invoiceId;
    return id != null && rowId == id;
  }

  Future<Map<String, dynamic>?> _upsertLocalInvoice(
      Map<String, dynamic> patch,
      ) async {
    final box = Hive.box('invoices');

    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw.cast<String, dynamic>());
      if (!_isSameInvoice(row)) continue;

      final updated = <String, dynamic>{...row, ...patch};
      await box.put(key, updated);
      return updated;
    }

    final updated = <String, dynamic>{...inv, ...patch};
    final key = _invoiceUuid.isNotEmpty
        ? _invoiceUuid
        : (_invoiceId?.toString() ?? '');
    if (key.isNotEmpty) {
      await box.put(key, updated);
    } else {
      await box.add(updated);
    }
    return updated;
  }

  Future<bool> _removeLocalInvoice() async {
    final box = Hive.box('invoices');
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw.cast<String, dynamic>());
      if (_isSameInvoice(row)) {
        await box.delete(key);
        return true;
      }
    }
    return false;
  }

  Future<void> _queueInvoiceUpsert(Map<String, dynamic> payload) async {
    if (_invoiceUuid.isEmpty) return;

    await Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'invoice',
      'op': 'UPSERT',
      'uuid': _invoiceUuid,
      'version': (payload['version'] ?? 1),
      'payload': payload,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

  bool _isLikelyOffline(Object e) {
    final m = e.toString().toLowerCase();
    return m.contains('socketexception') ||
        m.contains('failed host lookup') ||
        m.contains('connection refused') ||
        m.contains('network is unreachable') ||
        m.contains('timed out') ||
        m.contains('clientexception');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _markSubmitted() async {
    if (_actionBusy) return;
    if (_invoiceUuid.isEmpty && _invoiceId == null) return;

    setState(() => _actionBusy = true);
    final now = DateTime.now().toIso8601String();

    try {
      final serverId = _invoiceId;
      if (serverId != null && !isTempInvoiceNo) {
        await Api.postJson('/api/v1/invoices/$serverId/submit', {});
        final updated = await _upsertLocalInvoice({
          'status': 'PENDING_APPROVAL',
          'updated_at_client': now,
          'sync_status': 'clean',
        });
        if (updated != null && mounted) {
          setState(() => widget.invoice.addAll(updated));
        }
        _showMessage('Submitted for approval.');
        return;
      }

      final updated = await _upsertLocalInvoice({
        'status': 'PENDING_APPROVAL',
        'updated_at_client': now,
        'sync_status': 'dirty',
      });
      if (updated != null) {
        await _queueInvoiceUpsert(updated);
        if (mounted) setState(() => widget.invoice.addAll(updated));
      }
      _showMessage('Submitted for approval (offline queued).');
    } catch (e) {
      if (_isLikelyOffline(e)) {
        final updated = await _upsertLocalInvoice({
          'status': 'PENDING_APPROVAL',
          'updated_at_client': now,
          'sync_status': 'dirty',
        });
        if (updated != null) {
          await _queueInvoiceUpsert(updated);
          if (mounted) setState(() => widget.invoice.addAll(updated));
        }
        _showMessage('No network. Submission queued.');
      } else {
        _showMessage(
          'Submit failed: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _cancelOrDeleteDraft() async {
    final canServerCancel = !isTempInvoiceNo && _invoiceId != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(canServerCancel ? 'Cancel invoice?' : 'Delete draft?'),
        content: Text(
          canServerCancel
              ? 'This will move the invoice to CANCELLED status.'
              : 'This will remove it from offline storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(canServerCancel ? 'Confirm Cancel' : 'Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (_actionBusy) return;

    setState(() => _actionBusy = true);
    final now = DateTime.now().toIso8601String();

    try {
      final serverId = _invoiceId;
      if (serverId != null && !isTempInvoiceNo) {
        await Api.postJson('/api/v1/invoices/$serverId/cancel', {});
        final updated = await _upsertLocalInvoice({
          'status': 'CANCELLED',
          'updated_at_client': now,
          'sync_status': 'clean',
        });
        if (updated != null && mounted) {
          setState(() => widget.invoice.addAll(updated));
        }
        _showMessage('Invoice cancelled.');
        return;
      }

      final removed = await _removeLocalInvoice();
      if (removed && mounted) {
        Navigator.of(context).pop();
      }
      _showMessage('Draft deleted.');
    } catch (e) {
      if (_isLikelyOffline(e)) {
        final updated = await _upsertLocalInvoice({
          'status': 'CANCELLED',
          'updated_at_client': now,
          'sync_status': 'dirty',
        });
        if (updated != null) {
          await _queueInvoiceUpsert(updated);
          if (mounted) setState(() => widget.invoice.addAll(updated));
        }
        _showMessage('No network. Cancellation queued.');
      } else {
        _showMessage(
          'Cancel failed: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partyName = ((inv['party']?['name']) ?? inv['party_name'] ?? '-')
        .toString();
    final date = (inv['invoice_date'] ?? '-').toString();
    final time = (inv['invoice_time'] ?? '').toString();
    final net = _toNum(inv['net_total']);
    final due = _toNum(inv['due_amount']);

    return FeatureScaffold(
      title: 'Transaction Details',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          partyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('Invoice: $invoiceNo')),
                      if (isTempInvoiceNo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'TEMP',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text('Date: $date${time.isEmpty ? '' : ' | $time'}'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Net Total',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Tk ${money(net)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Balance Due',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Tk ${money(due)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.red,
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
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('No items.'),
                    )
                  else
                    ...items.map((it) {
                      final name = (it['name'] ??
                          it['product_name'] ??
                          it['sku'] ??
                          '-')
                          .toString();
                      final qty = _toNum(it['qty']);
                      final free = _toNum(it['free_qty']);
                      final price = _toNum(it['unit_price']);
                      final total = _toNum(it['line_total']);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Qty ${qty.toStringAsFixed(0)} | Free ${free.toStringAsFixed(0)} | Price Tk ${money(price)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Tk ${money(total)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamed(RouteNames.invoicePreview, arguments: inv);
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showShareActions,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                  if (status == 'DRAFT')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _actionBusy ? null : _markSubmitted,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit For Approval'),
                    ),
                  if (status == 'DRAFT')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _actionBusy ? null : _cancelOrDeleteDraft,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(
                        (!isTempInvoiceNo && _invoiceId != null)
                            ? 'Cancel Invoice'
                            : 'Delete Draft',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(RouteNames.transactions),
            child: const Text('Back to Transactions'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.isEmpty ? 'UNKNOWN' : status;
    Color bg;
    Color fg;
    switch (s) {
      case 'DRAFT':
        bg = Colors.grey.shade200;
        fg = Colors.black87;
        break;
      case 'SUBMITTED':
      case 'PENDING_APPROVAL':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case 'APPROVED':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'DECLINED':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      case 'CANCELLED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        s,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: fg),
      ),
    );
  }
}