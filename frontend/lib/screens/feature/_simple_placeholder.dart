import 'package:flutter/material.dart';
import 'feature_scaffold.dart';

class SimplePlaceholder extends StatelessWidget {
  final String title;
  final String message;
  const SimplePlaceholder({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
