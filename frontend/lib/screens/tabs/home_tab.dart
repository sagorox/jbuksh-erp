import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/api.dart';
import '../../core/auth_client.dart';
import '../../models/invoice.dart';
import '../../models/party.dart';
import '../../widgets/quick_links_card.dart';
import '../../widgets/search_bar_row.dart';
import '../../widgets/segmented_switch.dart';
import '../../widgets/txn_card.dart';
import '../../widgets/party_row.dart';
import '../../routes.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int seg = 0;
  bool loading = true;
  String? err;
  String q = '';
  List<Invoice> invoices = [];
  List<Party> parties = [];
  String money(num v) => v.toStringAsFixed(2);

  List<Invoice> _invoiceCache() => Hive.box('invoices').values.whereType<Map>().map((e) => Invoice.fromJson(e.cast<String, dynamic>())).toList();
  List<Party> _partyCache() => Hive.box('parties').values.whereType<Map>().map((e) => Party.fromJson(e.cast<String, dynamic>())).toList();

  Future<void> load() async {
    setState(() {
      loading = true;
      err = null;
      invoices = _invoiceCache();
      parties = _partyCache();
    });
    final errors = <String>[];
    try {
      final invRes = await AuthClient.get(Uri.parse('${Api.baseUrl}/api/v1/invoices'));
      final invData = jsonDecode(invRes.body);
      final invList = invData is List ? invData : (invData['items'] ?? invData['invoices'] ?? []);
      invoices = (invList as List).whereType<Map>().map((e) => Invoice.fromJson(Map<String, dynamic>.from(e))).toList();
      final box = Hive.box('invoices');
      for (final e in (invList as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(e);
        final key = '${row['id'] ?? row['uuid'] ?? DateTime.now().microsecondsSinceEpoch}';
        await box.put(key, row);
      }
    } catch (e) { errors.add('invoices offline'); }
    try {
      final pRes = await AuthClient.get(Uri.parse('${Api.baseUrl}/api/v1/parties'));
      final pData = jsonDecode(pRes.body);
      final pList = pData is List ? pData : (pData['items'] ?? pData['parties'] ?? []);
      parties = (pList as List).whereType<Map>().map((e) => Party.fromJson(Map<String, dynamic>.from(e))).toList();
      final box = Hive.box('parties');
      for (final e in (pList as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(e);
        final key = '${row['id'] ?? row['uuid'] ?? DateTime.now().microsecondsSinceEpoch}';
        await box.put(key, row);
      }
    } catch (e) { errors.add('parties offline'); }
    if (!mounted) return;
    setState(() {
      err = errors.isEmpty ? null : 'Showing cached data';
      loading = false;
    });
  }

  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = invoices.where((i) => q.isEmpty || ('${i.partyName} ${i.invoiceNo}'.toLowerCase().contains(q.toLowerCase()))).toList();
    final filteredParties = parties.where((p) => q.isEmpty || ('${p.name} ${p.partyCode}'.toLowerCase().contains(q.toLowerCase()))).toList();
    return Stack(children: [
      if (loading && invoices.isEmpty && parties.isEmpty)
        const Center(child: CircularProgressIndicator())
      else
        RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 90),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedSwitch(index: seg, labels: const ['Transaction Details', 'Party Details'], onChanged: (i) => setState(() { seg = i; q = ''; })),
              ),
              const SizedBox(height: 12),
              if (err != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(err!, style: const TextStyle(fontSize: 12, color: Colors.orange))),
              QuickLinksCard(items: seg == 0 ? [
                QuickLinkItem(icon: Icons.bookmark_add, label: 'Add Txn', onTap: () => Navigator.of(context).pushNamed(RouteNames.addSale)),
                QuickLinkItem(icon: Icons.receipt_long, label: 'Sale Report', onTap: () => Navigator.of(context).pushNamed(RouteNames.reportFilter, arguments: {'reportKey': 'Sales Report'})),
                QuickLinkItem(icon: Icons.settings, label: 'Txn Settings', onTap: () => Navigator.of(context).pushNamed(RouteNames.settings)),
                QuickLinkItem(icon: Icons.arrow_forward, label: 'Show All', onTap: () => Navigator.of(context).pushNamed(RouteNames.transactions)),
              ] : [
                QuickLinkItem(icon: Icons.currency_rupee, label: 'Take Payment', onTap: () => Navigator.of(context).pushNamed(RouteNames.collections)),
                QuickLinkItem(icon: Icons.assignment, label: 'Party State...', onTap: () => Navigator.of(context).pushNamed(RouteNames.reportFilter, arguments: {'reportKey': 'Party Statement'})),
                QuickLinkItem(icon: Icons.settings, label: 'Party Settings', onTap: () => Navigator.of(context).pushNamed(RouteNames.settings)),
                QuickLinkItem(icon: Icons.arrow_forward, label: 'Show All', onTap: () => Navigator.of(context).pushNamed(RouteNames.parties)),
              ]),
              SearchBarRow(hint: seg == 0 ? 'Search transactions' : 'Search parties', onChanged: (v) => setState(() => q = v), onFilterTap: () {}, onMoreTap: () {}),
              const SizedBox(height: 6),
              if (seg == 0)
                ...(filteredInvoices.isEmpty ? [const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No transactions')))] : filteredInvoices.map((inv) => TxnCard(party: 'CP: ${inv.partyName}', badge: inv.dueAmount > 0 ? 'SALE : UNPAID' : 'SALE : PAID', invoiceNo: inv.invoiceNo.isEmpty ? '-' : inv.invoiceNo, date: inv.invoiceDate.isEmpty ? '-' : inv.invoiceDate, totalLabel: 'Total', total: '৳ ${money(inv.netTotal)}', balanceLabel: 'Balance', balance: '৳ ${money(inv.dueAmount)}')))
              else
                ...(filteredParties.isEmpty ? [const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No parties')))] : filteredParties.map((p) => PartyRow(name: 'CP: ${p.name}', date: p.partyCode, amount: '৳ 0.00'))),
            ],
          ),
        ),
    ]);
  }
}
