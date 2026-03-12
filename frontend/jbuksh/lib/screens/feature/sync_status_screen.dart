import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/local_store.dart';
import '../../core/sync_service.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  bool _busy = false;

  Future<void> _runPull() async {
    setState(() => _busy = true);
    try {
      final n = await SyncService.pull();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pull complete. Changes processed: $n')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pull failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runPush() async {
    setState(() => _busy = true);
    try {
      final auth = Hive.box('auth');
      final deviceId = (auth.get('deviceId') ?? 'android-device').toString();
      final r = await SyncService.push(deviceId: deviceId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Push complete. pushed=${r['pushed']}, conflicts=${r['conflicts']}, retried=${r['retried'] ?? 0}, skipped=${r['skipped'] ?? 0}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Push failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = Hive.box('cacheBox');
    final outbox = Hive.box('outboxBox');
    final conflicts = Hive.box('conflicts');

    return FeatureScaffold(
      title: 'Sync Status',
      actions: [
        IconButton(
          tooltip: 'Pull',
          onPressed: _busy ? null : _runPull,
          icon: const Icon(Icons.cloud_download_outlined),
        ),
        IconButton(
          tooltip: 'Push',
          onPressed: _busy ? null : _runPush,
          icon: const Icon(Icons.cloud_upload_outlined),
        ),
      ],
      child: AnimatedBuilder(
        animation: Listenable.merge([
          cache.listenable(),
          outbox.listenable(),
          conflicts.listenable(),
        ]),
        builder: (context, _) {
          final lastSyncAt = (cache.get('lastSyncAt') ?? '').toString();
          final outboxItems = LocalStore.allBoxMaps('outboxBox');

          outboxItems.sort((a, b) {
            final aTs = (a['queued_at'] ?? a['created_at_client'] ?? '')
                .toString();
            final bTs = (b['queued_at'] ?? b['created_at_client'] ?? '')
                .toString();
            return bTs.compareTo(aTs);
          });

          final retryPending =
              outboxItems.where((e) {
                final nextRetry = (e['next_retry_at'] ?? '').toString();
                return nextRetry.isNotEmpty;
              }).length;

          return ListView(
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
                        'Role: ${LocalStore.role().isEmpty ? 'N/A' : LocalStore.role()}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text('Last Sync At: ${lastSyncAt.isEmpty ? '-' : lastSyncAt}'),
                      const SizedBox(height: 6),
                      Text('Outbox Pending: ${outboxItems.length}'),
                      const SizedBox(height: 6),
                      Text('Conflicts: ${Hive.box('conflicts').length}'),
                      const SizedBox(height: 6),
                      Text('Retry Waiting: $retryPending'),
                      if (_busy) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => Navigator.pushNamed(
                                context,
                                RouteNames.conflicts,
                              ),
                              icon: const Icon(Icons.rule_outlined),
                              label: const Text('Conflict Center'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Outbox Queue',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (outboxItems.isEmpty)
                const Card(
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No pending changes.'),
                  ),
                )
              else
                ...outboxItems.take(50).map((e) {
                  final entity = (e['entity'] ?? '').toString();
                  final op = (e['op'] ?? '').toString();
                  final uuid = (e['uuid'] ?? '').toString();
                  final queuedAt =
                  (e['queued_at'] ?? e['created_at_client'] ?? '').toString();
                  final retryCount = (e['retry_count'] ?? 0).toString();
                  final nextRetryAt = (e['next_retry_at'] ?? '').toString();
                  final lastError = (e['last_error'] ?? '').toString();

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: Text('$entity - $op'),
                      subtitle: Text(
                        [
                          'uuid: $uuid',
                          queuedAt,
                          'retry_count: $retryCount',
                          if (nextRetryAt.isNotEmpty) 'next_retry_at: $nextRetryAt',
                          if (lastError.isNotEmpty) 'last_error: $lastError',
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'view') {
                            final payload = e['payload'];
                            final pretty = const JsonEncoder.withIndent(
                              '  ',
                            ).convert(payload);
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder:
                                  (_) => AlertDialog(
                                title: const Text('Outbox Payload'),
                                content: SingleChildScrollView(
                                  child: Text(pretty),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          } else if (v == 'remove') {
                            await LocalStore.removeOutboxByUuid(uuid);
                          }
                        },
                        itemBuilder:
                            (_) => const [
                          PopupMenuItem(
                            value: 'view',
                            child: Text('View payload'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove all by uuid'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}