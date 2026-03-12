import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feature_scaffold.dart';

class AuditLogDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> log;

  const AuditLogDetailsScreen({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final encoder = const JsonEncoder.withIndent('  ');

    String pretty(dynamic v) {
      if (v == null) return 'null';
      try {
        return encoder.convert(v);
      } catch (_) {
        return v.toString();
      }
    }

    final entityType = (log['entity_type'] ?? '').toString();
    final entityId = (log['entity_id'] ?? '').toString();
    final action = (log['action'] ?? '').toString();
    final when = (log['created_at'] ?? '').toString();

    final beforeJson = log['before_json'];
    final afterJson = log['after_json'];

    final copyText = [
      'JBCL ERP Audit Log',
      'Entity Type: $entityType',
      'Entity ID: $entityId',
      'Action: $action',
      'At: ${when.isEmpty ? '—' : when}',
      '',
      'Before:',
      pretty(beforeJson),
      '',
      'After:',
      pretty(afterJson),
      '',
      'Full Log:',
      pretty(log),
    ].join('\n');

    return FeatureScaffold(
      title: 'Audit Log',
      actions: [
        IconButton(
          tooltip: 'Copy full log JSON',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: copyText));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audit log copied')),
            );
          },
          icon: const Icon(Icons.copy_all_outlined),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$entityType • $action',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Entity ID: $entityId'),
                  Text('At: ${when.isEmpty ? '—' : when}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Before',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _JsonBox(text: pretty(beforeJson)),
          const SizedBox(height: 12),
          const Text(
            'After',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _JsonBox(text: pretty(afterJson)),
          const SizedBox(height: 12),
          const Text(
            'Full Log',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          _JsonBox(text: pretty(log)),
        ],
      ),
    );
  }
}

class _JsonBox extends StatelessWidget {
  final String text;

  const _JsonBox({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}