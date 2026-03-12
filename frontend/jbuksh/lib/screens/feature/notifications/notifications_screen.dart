import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../../core/api.dart';
import 'notification_model.dart';
import 'notifications_api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsApiService _api;

  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  int _unreadCount = 0;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _api = NotificationsApiService(
      baseUrl: Api.baseUrl,
      tokenProvider: _getToken,
    );
    _load();
  }

  Future<String?> _getToken() async {
    if (!Hive.isBoxOpen('auth')) return null;
    return Hive.box('auth').get('token')?.toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.fetchNotifications();
      if (!mounted) return;

      setState(() {
        _items = res.notifications;
        _unreadCount = res.unreadCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markOneRead(NotificationItem item) async {
    if (!item.unread) return;

    try {
      await _api.markRead(item.id);
      if (!mounted) return;

      setState(() {
        _items = _items.map((e) {
          if (e.id == item.id) {
            return e.copyWith(
              isRead: 1,
              readAt: DateTime.now(),
            );
          }
          return e;
        }).toList();

        _unreadCount = _items.where((e) => e.unread).length;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mark read failed: $e')),
      );
    }
  }

  Future<void> _markAllRead() async {
    setState(() {
      _markingAll = true;
    });

    try {
      await _api.markAllRead();
      if (!mounted) return;

      setState(() {
        _items = _items
            .map((e) => e.copyWith(isRead: 1, readAt: DateTime.now()))
            .toList();
        _unreadCount = 0;
        _markingAll = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _markingAll = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mark all read failed: $e')),
      );
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'APPROVAL':
        return Icons.approval;
      case 'DELIVERY':
        return Icons.local_shipping;
      case 'LOW_STOCK':
        return Icons.warning_amber_rounded;
      case 'NOTICE':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color _tileColor(NotificationItem item, BuildContext context) {
    if (item.unread) {
      return Theme.of(context).colorScheme.primary.withOpacity(0.08);
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications ($_unreadCount unread)'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: (_loading || _markingAll || _items.isEmpty || _unreadCount == 0)
                ? null
                : _markAllRead,
            child: _markingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Mark all'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.notifications_off_outlined, size: 48),
          SizedBox(height: 12),
          Center(child: Text('No notifications found')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];

        return Material(
          color: _tileColor(item, context),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(_iconForType(item.type)),
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: item.unread ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(item.body),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _SmallChip(label: item.type),
                    if (item.refType != null && item.refType!.trim().isNotEmpty)
                      _SmallChip(label: item.refType!),
                    if (item.createdAt != null)
                      _SmallChip(label: _formatDate(item.createdAt)),
                    if (item.unread)
                      const _SmallChip(label: 'UNREAD'),
                  ],
                ),
              ],
            ),
            trailing: item.unread
                ? TextButton(
                    onPressed: () => _markOneRead(item),
                    child: const Text('Read'),
                  )
                : const Icon(Icons.done, size: 18),
            onTap: () => _markOneRead(item),
          ),
        );
      },
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;

  const _SmallChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceVariant,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
