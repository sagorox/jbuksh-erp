import 'package:flutter/material.dart';

class SegmentedSwitch extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const SegmentedSwitch({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          // ignore: deprecated_member_use
          BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFFFE8EC) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? const Color(0xFFE53935) : const Color(0xFFE0E0E0)),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      // ignore: deprecated_member_use
                      color: active ? const Color(0xFFE53935) : cs.onSurface.withValues(alpha: .55),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
