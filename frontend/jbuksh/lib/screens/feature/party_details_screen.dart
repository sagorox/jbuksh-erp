import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../models/party.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class PartyDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> party;
  const PartyDetailsScreen({super.key, required this.party});

  @override
  State<PartyDetailsScreen> createState() => _PartyDetailsScreenState();
}

class _PartyDetailsScreenState extends State<PartyDetailsScreen> {
  late Party p;

  bool _loading = false;
  String? _syncError;
  Map<String, dynamic>? _liveSummary;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _collections = [];

  @override
  void initState() {
    super.initState();
    p = Party.fromJson(widget.party);
    _invoices = _partyInvoicesLocal();
    _collections = _partyCollectionsLocal();
    _loadPartyData();
  }

  String _invoiceNo(Map<String, dynamic> inv) {
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    if (serverNo.isNotEmpty) return serverNo;
    return (inv['invoice_no'] ?? '-').toString();
  }

  bool _isTempInvoiceNo(Map<String, dynamic> inv) {
    final serverNo = (inv['server_invoice_no'] ?? '').toString().trim();
    final localNo = (inv['invoice_no'] ?? '').toString().trim();
    return serverNo.isEmpty && localNo.startsWith('DRAFT-');
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

  bool _sameParty(Map<String, dynamic> e) {
    final pid = _toInt(e['party_id'] ?? e['party']?['id']);
    return pid != null && pid == p.id;
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

  Map<String, dynamic>? _extractSummary(Map<String, dynamic> src) {
    final s = src['summary'];
    if (s is Map) return s.cast<String, dynamic>();
    if (src.isNotEmpty) return src;
    return null;
  }

  List<Map<String, dynamic>> _partyInvoicesLocal() {
    final all = LocalStore.allBoxMaps('invoices');
    final out = all.where(_sameParty).toList();
    out.sort(
      (a, b) => (b['invoice_date'] ?? '').toString().compareTo(
        (a['invoice_date'] ?? '').toString(),
      ),
    );
    return out;
  }

  List<Map<String, dynamic>> _partyCollectionsLocal() {
    final all = LocalStore.allBoxMaps('collections');
    final out = all.where(_sameParty).toList();
    out.sort(
      (a, b) => (b['collection_date'] ?? '').toString().compareTo(
        (a['collection_date'] ?? '').toString(),
      ),
    );
    return out;
  }

  Future<void> _mergeIntoBox(
    String boxName,
    List<Map<String, dynamic>> rows,
  ) async {
    final box = Hive.box(boxName);
    for (final row in rows) {
      final key = (row['id'] ?? row['uuid'])?.toString();
      if (key == null || key.isEmpty) {
        await box.add(row);
      } else {
        await box.put(key, row);
      }
    }
  }

  Future<void> _loadPartyData() async {
    setState(() {
      _loading = true;
      _syncError = null;
    });

    var nextInvoices = _partyInvoicesLocal();
    var nextCollections = _partyCollectionsLocal();
    Map<String, dynamic>? nextSummary = _liveSummary;
    final errors = <String>[];

    try {
      final invRes = await Api.getJson('/api/v1/invoices?party_id=${p.id}');
      final invRows = _readList(invRes, [
        'invoices',
        'items',
        'data',
      ]).where(_sameParty).toList();
      if (invRows.isNotEmpty) {
        nextInvoices = invRows;
        await _mergeIntoBox('invoices', invRows);
      }
    } catch (e) {
      errors.add('invoices: ${e.toString().replaceAll('Exception: ', '')}');
    }

    try {
      final colRes = await Api.getJson('/api/v1/collections?party_id=${p.id}');
      final colRows = _readList(colRes, [
        'collections',
        'items',
        'data',
      ]).where(_sameParty).toList();
      if (colRows.isNotEmpty) {
        nextCollections = colRows;
        await _mergeIntoBox('collections', colRows);
      }
    } catch (e) {
      errors.add('collections: ${e.toString().replaceAll('Exception: ', '')}');
    }

    try {
      final summaryRes = await Api.getJson('/api/v1/parties/${p.id}/summary');
      nextSummary = _extractSummary(summaryRes);
    } catch (e) {
      errors.add('summary: ${e.toString().replaceAll('Exception: ', '')}');
    }

    nextInvoices.sort(
      (a, b) => (b['invoice_date'] ?? '').toString().compareTo(
        (a['invoice_date'] ?? '').toString(),
      ),
    );
    nextCollections.sort(
      (a, b) => (b['collection_date'] ?? '').toString().compareTo(
        (a['collection_date'] ?? '').toString(),
      ),
    );

    if (!mounted) return;
    setState(() {
      _invoices = nextInvoices;
      _collections = nextCollections;
      _liveSummary = nextSummary;
      _syncError = errors.isEmpty
          ? null
          : 'Showing mixed cache: ${errors.join(' | ')}';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoices = _invoices;
    final collections = _collections;

    final activeInvoices = invoices.where((e) {
      final st = (e['status'] ?? '').toString().toUpperCase();
      return st != 'CANCELLED' && st != 'DECLINED';
    }).toList();

    final dueLocal = activeInvoices.fold<num>(
      0,
      (s, e) => s + _toNum(e['due_amount']),
    );
    final salesLocal = activeInvoices.fold<num>(
      0,
      (s, e) => s + _toNum(e['net_total']),
    );
    final paidLocal = collections.fold<num>(
      0,
      (s, e) => s + _toNum(e['amount']),
    );

    final receivable = _toNum(
      _liveSummary?['receivable'] ??
          _liveSummary?['due'] ??
          _liveSummary?['balance_due'] ??
          dueLocal,
    );
    final totalSales = _toNum(
      _liveSummary?['total_sales'] ??
          _liveSummary?['sales_total'] ??
          salesLocal,
    );
    final paid = _toNum(
      _liveSummary?['total_paid'] ?? _liveSummary?['paid'] ?? paidLocal,
    );

    final lastInvoice = invoices.isNotEmpty
        ? (invoices.first['invoice_date'] ?? '-')
        : '-';
    final lastPay = collections.isNotEmpty
        ? (collections.first['collection_date'] ?? '-')
        : '-';

    return FeatureScaffold(
      title: 'Party Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loading ? null : _loadPartyData,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _HeaderCard(p: p),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          if (_syncError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _syncError!,
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Receivable',
                  value: receivable.toStringAsFixed(2),
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Paid',
                  value: paid.toStringAsFixed(2),
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryCard(
            title: 'Total Sales',
            value: totalSales.toStringAsFixed(2),
            icon: Icons.shopping_cart_checkout_outlined,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SmallInfo(title: 'Last invoice', value: '$lastInvoice'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallInfo(title: 'Last payment', value: '$lastPay'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed(
                          RouteNames.takePayment,
                          arguments: widget.party,
                        )
                        .then((_) => _loadPartyData());
                  },
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Take Payment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed(
                          RouteNames.addSale,
                          arguments: {'party': widget.party},
                        )
                        .then((_) => _loadPartyData());
                  },
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Add Sale'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle(title: 'Invoices'),
          ...invoices
              .take(10)
              .map(
                (inv) => _InvoiceTile(
                  inv: inv,
                  invoiceNo: _invoiceNo(inv),
                  isTemp: _isTempInvoiceNo(inv),
                ),
              ),
          if (invoices.length > 10)
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(RouteNames.transactions);
              },
              child: const Text('See all transactions'),
            ),
          const SizedBox(height: 12),
          const _SectionTitle(title: 'Payments'),
          ...collections.take(10).map((c) => _PaymentTile(map: c)),
          if (collections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No payments yet.'),
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Party p;
  const _HeaderCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Code: ${p.partyCode}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                if ((p.phone ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(p.phone!, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            if ((p.address ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                p.address!,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.7)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  final String title;
  final String value;
  const _SmallInfo({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Map<String, dynamic> inv;
  final String invoiceNo;
  final bool isTemp;
  const _InvoiceTile({
    required this.inv,
    required this.invoiceNo,
    required this.isTemp,
  });

  @override
  Widget build(BuildContext context) {
    final status = (inv['status'] ?? '').toString();
    final due = (inv['due_amount'] ?? 0).toString();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(invoiceNo)),
            if (isTemp)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
        subtitle: Text('Date: ${inv['invoice_date'] ?? '-'} | Due: $due'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(status, style: const TextStyle(fontSize: 11)),
        ),
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(RouteNames.transactionDetails, arguments: inv);
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Map<String, dynamic> map;
  const _PaymentTile({required this.map});

  @override
  Widget build(BuildContext context) {
    final method = (map['method'] ?? 'CASH').toString();
    final amount = (map['amount'] ?? 0).toString();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text('Tk $amount'),
        subtitle: Text('Date: ${map['collection_date'] ?? '-'} | $method'),
      ),
    );
  }
}
