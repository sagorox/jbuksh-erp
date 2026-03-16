import 'package:flutter/material.dart';

import 'feature_scaffold.dart';

class VoucherDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> voucher;
  const VoucherDetailsScreen({super.key, required this.voucher});

  num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final lines = (voucher['lines'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList() ??
        <Map<String, dynamic>>[];
    final totalDr = lines.fold<num>(0, (s, l) => s + _toNum(l['debit']));
    final totalCr = lines.fold<num>(0, (s, l) => s + _toNum(l['credit']));

    return FeatureScaffold(
      title: 'Voucher Details',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(
                (voucher['voucher_no'] ?? '-').toString(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${voucher['voucher_type'] ?? '-'} | ${voucher['voucher_date'] ?? '-'} | ${voucher['ref_type'] ?? '-'}',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.balance),
              title: const Text('Totals'),
              trailing: Text('Dr ${totalDr.toStringAsFixed(2)} / Cr ${totalCr.toStringAsFixed(2)}'),
            ),
          ),
          const SizedBox(height: 12),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No voucher lines.'),
            )
          else
            ...lines.map(
              (l) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: Text('${l['account_code'] ?? '-'} | ${l['account_name'] ?? '-'}'),
                  subtitle: Text('Party: ${(l['party_id'] ?? '-').toString()}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Dr ${_toNum(l['debit']).toStringAsFixed(2)}'),
                      Text('Cr ${_toNum(l['credit']).toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
