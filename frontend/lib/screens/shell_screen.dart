import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/sync_service.dart';
import '../core/token_store.dart';
import '../routes.dart';
import 'login_screen.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/items_tab.dart';
import 'tabs/menu_tab.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int idx = 0;
  bool _syncing = false;

  final tabs = const [
    HomeTab(),
    DashboardTab(),
    ItemsTab(),
    MenuTab(),
  ];

  @override
  void initState() {
    super.initState();
    _runBackgroundSync();
  }

  Future<void> _runBackgroundSync() async {
    if (_syncing) return;
    setState(() => _syncing = true);

    try {
      await SyncService.syncAll();
    } catch (e) {
      debugPrint('Shell background sync failed: $e');
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> logout() async {
    await TokenStore.clear();

    final boxesToClear = <String>[
      'auth',
      'territories',
      'categories',
      'products',
      'product_batches',
      'parties',
      'invoices',
      'collections',
      'expenses',
      'stock_txns',
      'attendance',
      'audit_logs',
      'deliveries',
      'notifications',
      'vouchers',
      'cacheBox',
      'outboxBox',
      'conflicts',
    ];

    for (final name in boxesToClear) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final userId = user['id'] ?? user['sub'];
    final role = (user['role'] ?? '').toString().toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text("J. BUKSH & COMF"),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: _syncing ? null : _runBackgroundSync,
            icon: _syncing
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.sync),
          ),
          ValueListenableBuilder(
            valueListenable: Hive.box('notifications').listenable(),
            builder: (context, value, child) {
              final unread = Hive.box('notifications').values.where((e) {
                if (e is! Map) return false;
                final m = e.cast<dynamic, dynamic>();
                final isRead = (m['is_read'] ?? 0) == 1;
                if (isRead) return false;
                if (role == 'SUPER_ADMIN') return true;
                final uid = m['user_id'];
                return uid == null || uid == userId;
              }).length;

              return IconButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(RouteNames.notifications),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (unread > 0)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: tabs[idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) => setState(() => idx = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: "Items",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: "Menu"),
        ],
      ),
    );
  }
}