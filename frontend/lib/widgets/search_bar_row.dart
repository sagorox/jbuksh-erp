import 'package:flutter/material.dart';

class SearchBarRow extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onMoreTap;

  const SearchBarRow({
    super.key,
    required this.hint,
    this.onChanged,
    this.onFilterTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                ),
              ),
            ),
            Container(width: 1, height: 24, color: Colors.grey.shade300),
            IconButton(
              onPressed: onFilterTap,
              icon: const Icon(Icons.filter_list, color: Color(0xFF1976D2)),
            ),
            IconButton(
              onPressed: onMoreTap,
              icon: const Icon(Icons.more_vert, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}