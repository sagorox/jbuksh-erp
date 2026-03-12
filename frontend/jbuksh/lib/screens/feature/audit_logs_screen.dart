import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../routes.dart';
import 'feature_scaffold.dart';

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('audit_logs');

    return FeatureScaffold(
      title: 'Audit Logs',
      actions: [
        IconButton(
          tooltip: 'Clear local logs',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Clear local logs?'),
                content: const Text(
                  'This clears only offline demo logs stored on device.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            );

            if (ok == true) {
              await box.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cleared local audit logs')),
                );
              }
            }
          },
          icon: const Icon(Icons.delete_outline),
        ),
      ],
      child: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, value, child) {
          final items = <Map<String, dynamic>>[];

          for (final v in box.values) {
            if (v is Map) {
              items.add(v.cast<String, dynamic>());
            }
          }

          items.sort(
                (a, b) => (b['created_at'] ?? '')
                .toString()
                .compareTo((a['created_at'] ?? '').toString()),
          );

          if (items.isEmpty) {
            return const Center(
              child: Text('No logs yet. Actions like delivery update add logs.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final e = items[index];
              final type = (e['entity_type'] ?? '').toString();
              final action = (e['action'] ?? '').toString();
              final when = (e['created_at'] ?? '').toString();
              final id = (e['entity_id'] ?? '').toString();

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.manage_search_outlined),
                  title: Text('$type • $action'),
                  subtitle: Text('id: $id\n$when'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      RouteNames.auditLogDetails,
                      arguments: e,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}