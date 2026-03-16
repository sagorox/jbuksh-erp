import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../routes.dart';
import 'feature_scaffold.dart';

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final voucherBox = Hive.box('vouchers');
    final coaBox = Hive.box('coa_accounts');

    return FeatureScaffold(
      title: 'Accounting',
      child: AnimatedBuilder(
        animation: Listenable.merge([
          voucherBox.listenable(),
          coaBox.listenable(),
        ]),
        builder: (context, _) {
          final vouchers = voucherBox.values
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
            ..sort((a, b) => (b['posted_at'] ?? '').toString().compareTo((a['posted_at'] ?? '').toString()));
          
          final coaCount = coaBox.length;

          final totalDr = vouchers.fold<num>(0, (s, v) {
            final lines = ((v['lines'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>());
            return s + lines.fold<num>(0, (x, l) => x + _toNum(l['debit']));
          });
          
          final totalCr = vouchers.fold<num>(0, (s, v) {
            final lines = ((v['lines'] as List?) ?? const [])
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>());
            return s + lines.fold<num>(0, (x, l) => x + _toNum(l['credit']));
          });

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Voucher Summary', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Entries: ${vouchers.length} • COA: $coaCount'),
                  trailing: Text('Dr ${totalDr.toStringAsFixed(2)}\nCr ${totalCr.toStringAsFixed(2)}', textAlign: TextAlign.right),
                ),
              ),
              const SizedBox(height: 12),
              if (vouchers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No accounting vouchers yet.')),
                )
              else
                ...vouchers.map((v) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        onTap: () => Navigator.of(context).pushNamed(RouteNames.voucherDetails, arguments: v),
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text('${v['voucher_no'] ?? '-'} • ${v['voucher_type'] ?? '-'}'),
                        subtitle: Text('${v['voucher_date'] ?? '-'} • ${v['ref_type'] ?? '-'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Lines ${(v['lines'] as List?)?.length ?? 0}'),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}