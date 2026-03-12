import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../core/sync_service.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  bool loading = false;
  String? msg;
  String deviceId = 'android-device';

  Box get cache => Hive.box('cacheBox');
  Box get outbox => Hive.box('outboxBox');
  Box get conflicts => Hive.box('conflicts');

  Future<void> _push() async {
    setState(() {
      loading = true;
      msg = null;
    });
    try {
      final r = await SyncService.push(deviceId: deviceId);
      setState(() => msg = 'Push OK: pushed=${r['pushed']} conflicts=${r['conflicts']} skipped=${r['skipped'] ?? 0}');
    } catch (e) {
      setState(() => msg = 'Push failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _pull() async {
    setState(() {
      loading = true;
      msg = null;
    });
    try {
      final n = await SyncService.pull();
      setState(() => msg = 'Pull OK: applied=$n');
    } catch (e) {
      setState(() => msg = 'Pull failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSyncAt = cache.get('lastSyncAt')?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Status')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Device ID', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    controller: TextEditingController(text: deviceId),
                    onChanged: (v) => deviceId = v.trim().isEmpty ? deviceId : v.trim(),
                  ),
                  const SizedBox(height: 12),
                  Text('Last Sync: $lastSyncAt'),
                  const SizedBox(height: 8),
                  Text('Outbox Pending: ${outbox.length}'),
                  const SizedBox(height: 4),
                  Text('Conflicts: ${conflicts.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _pull,
                  icon: const Icon(Icons.download),
                  label: const Text('Pull'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : _push,
                  icon: const Icon(Icons.upload),
                  label: const Text('Push'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading) const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          )),
          if (msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(msg!, style: TextStyle(color: msg!.startsWith('Push failed') || msg!.startsWith('Pull failed') ? Colors.red : Colors.green)),
            ),
          const SizedBox(height: 16),
          _sectionTitle('Outbox (latest 20)'),
          ..._kvPreview(outbox, limit: 20),
          const SizedBox(height: 16),
          _sectionTitle('Conflicts (latest 20)'),
          ..._kvPreview(conflicts, limit: 20),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  List<Widget> _kvPreview(Box box, {int limit = 20}) {
    final keys = box.keys.map((e) => e.toString()).toList();
    keys.sort();
    final slice = keys.reversed.take(limit);

    if (keys.isEmpty) {
      return const [Text('—')];
    }

    return slice.map((k) {
      final v = box.get(k);
      final subtitle = (v is Map)
          ? (v['entity']?.toString() ?? v['uuid']?.toString() ?? '')
          : v.toString();
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(k, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await box.delete(k);
            if (mounted) setState(() {});
          },
        ),
      );
    }).toList();
  }
}
