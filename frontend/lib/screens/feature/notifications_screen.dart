import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/local_store.dart';
import 'feature_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Future<void> _markAllRead(List<Map<String, dynamic>> list) async {
    final box = Hive.box('notifications');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map) {
        final updated = Map<String, dynamic>.from(v.cast<String, dynamic>());
        updated['is_read'] = 1;
        await box.putAt(i, updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final userId = user['id'] ?? user['sub'];
    final role = (user['role'] ?? '').toString().toUpperCase();

    return FeatureScaffold(
      title: 'Notifications',
      child: ValueListenableBuilder(
        valueListenable: Hive.box('notifications').listenable(),
        builder: (context, value, child) {
          final list = LocalStore.allBoxMaps('notifications').where((n) {
            if (role == 'SUPER_ADMIN') return true;
            final uid = n['user_id'];
            return uid == null || uid == userId;
          }).toList();
          list.sort((a, b) => ((b['created_at'] ?? '') as String).compareTo((a['created_at'] ?? '') as String));

          if (list.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          final unreadCount = list.where((n) => (n['is_read'] ?? 0) != 1).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Text('Unread: $unreadCount', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(
                      onPressed: unreadCount == 0 ? null : () => _markAllRead(list),
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final n = list[i];
                    final title = (n['title'] ?? 'Notification').toString();
                    final body = (n['body'] ?? '').toString();
                    final type = (n['type'] ?? 'SYSTEM').toString();
                    final reason = (n['reason'] ?? '').toString();
                    final isRead = (n['is_read'] ?? 0) == 1;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: Icon(isRead ? Icons.notifications_none : Icons.notifications_active_outlined),
                        title: Row(
                          children: [
                            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                            const SizedBox(width: 8),
                            _typeChip(type, isRead: isRead),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(body.isEmpty ? '-' : body),
                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Reason: $reason', style: const TextStyle(fontWeight: FontWeight.w700)),
                            ]
                          ],
                        ),
                        trailing: isRead
                            ? null
                            : TextButton(
                                onPressed: () async {
                                  // mark read (local)
                                  final box = Hive.box('notifications');
                                  for (int j = 0; j < box.length; j++) {
                                    final v = box.getAt(j);
                                    if (v is Map && (v['id'] == n['id'] || (v['uuid'] ?? '').toString() == (n['uuid'] ?? '').toString())) {
                                      final updated = Map<String, dynamic>.from(v);
                                      updated['is_read'] = 1;
                                      await box.putAt(j, updated);
                                      break;
                                    }
                                  }
                                },
                                child: const Text('Mark read'),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _typeChip(String type, {required bool isRead}) {
    IconData icon;
    switch (type) {
      case 'APPROVAL':
        icon = Icons.verified_outlined;
        break;
      case 'DELIVERY':
        icon = Icons.local_shipping_outlined;
        break;
      case 'LOW_STOCK':
        icon = Icons.warning_amber_rounded;
        break;
      case 'NOTICE':
        icon = Icons.campaign_outlined;
        break;
      default:
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isRead ? Colors.black.withValues(alpha: 0.04) : Colors.blue.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}



