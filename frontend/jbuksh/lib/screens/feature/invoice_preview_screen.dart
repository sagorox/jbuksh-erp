import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import 'feature_scaffold.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  bool _busyPdf = false;
  bool _busyShare = false;
  String? _generatedPdfUrl;

  num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

  String _invoiceNo(Map<String, dynamic> inv) {
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    if (serverNo.isNotEmpty) return serverNo;
    return (inv['invoice_no'] ?? '-').toString();
  }

  bool _isTemp(Map<String, dynamic> inv) {
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    final localNo = (inv['invoice_no'] ?? '').toString().trim();
    return serverNo.isEmpty && localNo.startsWith('DRAFT-');
  }

  int? _serverInvoiceId(Map<String, dynamic> inv) {
    final raw = inv['server_id'] ?? inv['id'];
    if (raw == null) return null;
    return int.tryParse(raw.toString());
  }

  String _absoluteFileUrl(String pdfUrl) {
    if (pdfUrl.startsWith('http://') || pdfUrl.startsWith('https://')) {
      return pdfUrl;
    }
    final base = Api.baseUrl.endsWith('/')
        ? Api.baseUrl.substring(0, Api.baseUrl.length - 1)
        : Api.baseUrl;
    final path = pdfUrl.startsWith('/') ? pdfUrl : '/$pdfUrl';
    return '$base$path';
  }

  Future<void> _generatePdf() async {
    final invoice = widget.invoice;
    final serverId = _serverInvoiceId(invoice);

    if (serverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'এই invoice এখনো server-এ sync হয়নি, তাই PDF generate করা যাবে না।',
          ),
        ),
      );
      return;
    }

    try {
      setState(() => _busyPdf = true);

      final res = await Api.postJson(
        '/api/v1/invoices/$serverId/generate-pdf',
        {},
      );

      final pdfUrl = (res['pdf_url'] ?? '').toString().trim();
      if (pdfUrl.isEmpty) {
        throw Exception('PDF URL পাওয়া যায়নি');
      }

      final fullUrl = _absoluteFileUrl(pdfUrl);

      if (!mounted) return;
      setState(() => _generatedPdfUrl = fullUrl);

      await Clipboard.setData(ClipboardData(text: fullUrl));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF link copied')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF generate failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPdf = false);
      }
    }
  }

  Future<void> _shareSummary() async {
    final invoice = widget.invoice;
    final partyId = invoice['party_id'] ?? invoice['party']?['id'];
    final party = LocalStore.allBoxMaps('parties').firstWhere(
          (p) => (p['id'] ?? p['server_id']) == partyId,
      orElse: () => <String, dynamic>{},
    );

    final items = (invoice['items'] is List)
        ? (invoice['items'] as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList()
        : <Map<String, dynamic>>[];

    final lines = <String>[
      'JBCL ERP Invoice',
      'Invoice: ${_invoiceNo(invoice)}',
      'Date: ${invoice['invoice_date'] ?? '-'}',
      'Status: ${invoice['status'] ?? '-'}',
      'Party: ${party['name'] ?? invoice['party_name'] ?? '-'}',
      'Phone: ${party['phone'] ?? '-'}',
      'Address: ${party['address'] ?? '-'}',
      '',
      'Items:',
      ...items.map((it) {
        final name =
        (it['name'] ?? it['product_name'] ?? it['sku'] ?? '-').toString();
        final qty = _toNum(it['qty']).toStringAsFixed(0);
        final rate = _toNum(it['unit_price']).toStringAsFixed(2);
        final total = _toNum(it['line_total']).toStringAsFixed(2);
        return '- $name | Qty: $qty | Rate: $rate | Total: $total';
      }),
      '',
      'Subtotal: ${_toNum(invoice['subtotal']).toStringAsFixed(2)}',
      'Discount: ${_toNum(invoice['discount_amount']).toStringAsFixed(2)}',
      'Net Total: ${_toNum(invoice['net_total']).toStringAsFixed(2)}',
      'Received: ${_toNum(invoice['received_amount']).toStringAsFixed(2)}',
      'Due: ${_toNum(invoice['due_amount']).toStringAsFixed(2)}',
      if ((_generatedPdfUrl ?? '').trim().isNotEmpty) '',
      if ((_generatedPdfUrl ?? '').trim().isNotEmpty) 'PDF: $_generatedPdfUrl',
    ];

    try {
      setState(() => _busyShare = true);
      await Clipboard.setData(ClipboardData(text: lines.join('\n')));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice summary copied to clipboard')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyShare = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final partyId = invoice['party_id'] ?? invoice['party']?['id'];

    final party = LocalStore.allBoxMaps('parties').firstWhere(
          (p) => (p['id'] ?? p['server_id']) == partyId,
      orElse: () => <String, dynamic>{},
    );

    final items = (invoice['items'] is List)
        ? (invoice['items'] as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList()
        : <Map<String, dynamic>>[];

    final invoiceNo = _invoiceNo(invoice);
    final isTemp = _isTemp(invoice);

    return FeatureScaffold(
      title: 'Invoice Preview',
      actions: [
        IconButton(
          tooltip: _busyPdf ? 'Generating PDF...' : 'Generate PDF',
          onPressed: _busyPdf ? null : _generatePdf,
          icon: _busyPdf
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.picture_as_pdf_outlined),
        ),
        IconButton(
          tooltip: _busyShare ? 'Copying...' : 'Copy Summary',
          onPressed: _busyShare ? null : _shareSummary,
          icon: _busyShare
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.share_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if ((_generatedPdfUrl ?? '').trim().isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generated PDF',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(_generatedPdfUrl!),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _generatedPdfUrl!),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PDF link copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy Link'),
                    ),
                  ],
                ),
              ),
            ),
          if ((_generatedPdfUrl ?? '').trim().isNotEmpty)
            const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company: JBCL',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('Invoice: $invoiceNo')),
                      if (isTemp)
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
                  Text('Date: ${invoice['invoice_date'] ?? '-'}'),
                  Text('Status: ${(invoice['status'] ?? '-').toString()}'),
                  const Divider(height: 20),
                  Text(
                    'Party: ${party['name'] ?? invoice['party_name'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if ((party['phone'] ?? '').toString().isNotEmpty)
                    Text('Phone: ${party['phone']}'),
                  if ((party['address'] ?? '').toString().isNotEmpty)
                    Text('Address: ${party['address']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              (it['name'] ??
                                  it['product_name'] ??
                                  it['sku'] ??
                                  '-')
                                  .toString(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_toNum(it['qty']).toStringAsFixed(0)} x ${_toNum(it['unit_price']).toStringAsFixed(2)}',
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _toNum(it['line_total']).toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  _kv('Subtotal', _toNum(invoice['subtotal']).toStringAsFixed(2)),
                  _kv(
                    'Discount',
                    _toNum(invoice['discount_amount']).toStringAsFixed(2),
                  ),
                  _kv(
                    'Net Total',
                    _toNum(invoice['net_total']).toStringAsFixed(2),
                    bold: true,
                  ),
                  _kv(
                    'Received',
                    _toNum(invoice['received_amount']).toStringAsFixed(2),
                  ),
                  _kv(
                    'Due',
                    _toNum(invoice['due_amount']).toStringAsFixed(2),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    final st = TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: st)),
          Text(v, style: st),
        ],
      ),
    );
  }
}