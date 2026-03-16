import 'package:flutter/material.dart';

class TxnCard extends StatelessWidget {
  final String party;
  final String badge; // SALE: UNPAID / PAYIN: UNUSED
  final String invoiceNo;
  final String date;
  final String totalLabel;
  final String total;
  final String balanceLabel;
  final String balance;

  const TxnCard({
    super.key,
    required this.party,
    required this.badge,
    required this.invoiceNo,
    required this.date,
    required this.totalLabel,
    required this.total,
    required this.balanceLabel,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    party,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text("#$invoiceNo", style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(badge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF6C00))),
                ),
                const Spacer(),
                Text(date, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _kv(totalLabel, total),
                ),
                Expanded(
                  child: _kv(balanceLabel, balance),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.print, color: Colors.grey)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.share, color: Colors.grey)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ],
    );
  }
}