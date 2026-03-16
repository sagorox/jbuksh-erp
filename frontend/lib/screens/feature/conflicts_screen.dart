import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/local_store.dart';
import '../../core/sync_service.dart';
import 'feature_scaffold.dart';

class ConflictsScreen extends StatelessWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('conflicts');

    return FeatureScaffold(
      title: 'Conflicts',
      child: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (ctx, value, child) {
          final items = LocalStore.allBoxMaps('conflicts');
          if (items.isEmpty) {
            return const Center(child: Text('No conflicts.'));
          }

          items.sort((a, b) {
            final aTs = (a['received_at'] ?? '').toString();
            final bTs = (b['received_at'] ?? '').toString();
            return bTs.compareTo(aTs);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final c = items[i];
              final entity =
              (c['entity'] ?? c['entity_type'] ?? '-').toString();
              final uuid = (c['uuid'] ?? '-').toString();
              final serverVersion = (c['server_version'] ?? '-').toString();
              final message = (c['message'] ?? '').toString();

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text('$entity • $uuid'),
                  subtitle: Text(
                    message.isEmpty
                        ? 'Server v$serverVersion'
                        : 'Server v$serverVersion\n$message',
                  ),
                  isThreeLine: message.isNotEmpty,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'local') {
                        await _keepLocal(ctx, c);
                      } else if (v == 'server') {
                        await _keepServer(ctx, c);
                      } else if (v == 'view') {
                        _viewDiff(ctx, c);
                      }
                    },
                    itemBuilder:
                        (_) => const [
                      PopupMenuItem(
                        value: 'view',
                        child: Text('View Diff'),
                      ),
                      PopupMenuItem(
                        value: 'local',
                        child: Text('Keep Local'),
                      ),
                      PopupMenuItem(
                        value: 'server',
                        child: Text('Keep Server'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _viewDiff(BuildContext context, Map<String, dynamic> c) {
    final encoder = const JsonEncoder.withIndent('  ');
    final localPretty = encoder.convert((c['local'] ?? const <String, dynamic>{}));
    final serverPretty = encoder.convert((c['server'] ?? const <String, dynamic>{}));

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
        title: const Text('Conflict Diff'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Local',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                SelectableText(localPretty),
                const SizedBox(height: 12),
                const Text(
                  'Server',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                SelectableText(serverPretty),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _keepLocal(
      BuildContext context,
      Map<String, dynamic> c,
      ) async {
    final uuid = (c['uuid'] ?? '').toString();
    final entity = (c['entity'] ?? c['entity_type'] ?? '').toString();
    final local =
    (c['local'] is Map)
        ? (c['local'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    if (uuid.isEmpty || entity.isEmpty) return;

    await LocalStore.removeOutboxByUuid(uuid);

    await SyncService.enqueue(
      entity: entity,
      op: (c['op'] ?? 'UPSERT').toString(),
      uuid: uuid,
      version: int.tryParse((local['version'] ?? 1).toString()) ?? 1,
      payload: local,
      deviceId: LocalStore.deviceId(),
    );

    await LocalStore.removeConflictByUuid(uuid);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local version queued again for sync')),
      );
    }
  }

  Future<void> _keepServer(
      BuildContext context,
      Map<String, dynamic> c,
      ) async {
    final entity = (c['entity'] ?? c['entity_type'] ?? '').toString();
    final uuid = (c['uuid'] ?? '').toString();
    final server =
    (c['server'] is Map)
        ? (c['server'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    if (uuid.isEmpty || entity.isEmpty || server.isEmpty) return;

    await LocalStore.upsertEntitySnapshot(entity, server);
    await LocalStore.removeOutboxByUuid(uuid);
    await LocalStore.removeConflictByUuid(uuid);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server version applied locally')),
      );
    }
  }
}