import 'package:flutter/material.dart';

class QuickLinkItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const QuickLinkItem({required this.icon, required this.label, required this.onTap});
}

class QuickLinksCard extends StatelessWidget {
  final List<QuickLinkItem> items;
  const QuickLinksCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quick Links", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: items.map((e) {
                return Expanded(
                  child: InkWell(
                    onTap: e.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(e.icon, color: const Color(0xFF1976D2)),
                          ),
                          const SizedBox(height: 8),
                          Text(e.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}