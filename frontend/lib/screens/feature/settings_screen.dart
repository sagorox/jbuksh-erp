import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../login_screen.dart';
import '../../core/token_store.dart';
import 'feature_scaffold.dart';
import '../../routes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await TokenStore.clear();
    await Hive.box('auth').clear();
    await Hive.box('territories').clear();
    await Hive.box('products').clear();
    await Hive.box('parties').clear();
    await Hive.box('invoices').clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final settingsBox = Hive.box('settings');
    final apiBaseUrl =
    (settingsBox.get('api_base_url') ?? 'Using build default').toString();

    return FeatureScaffold(
      title: 'Settings',
      child: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text((user['full_name'] ?? 'User').toString()),
            subtitle: Text('Role: ${(user['role'] ?? 'N/A').toString()}'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lan_outlined),
            title: const Text('API Base URL'),
            subtitle: Text(apiBaseUrl),
            onTap: () async {
              final ctrl = TextEditingController(
                text: (settingsBox.get('api_base_url') ?? '').toString(),
              );

              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Set API Base URL'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.0.10:3000',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await settingsBox.put('api_base_url', ctrl.text.trim());
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );

              if (ok == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API base URL updated')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Status'),
            subtitle: const Text('Outbox queue, pending sync, and conflicts'),
            onTap: () => Navigator.pushNamed(context, RouteNames.syncStatus),
          ),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Conflict Center'),
            subtitle: const Text('Resolve local vs server mismatch manually'),
            onTap: () => Navigator.pushNamed(context, RouteNames.conflicts),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notifications'),
            subtitle: const Text('Open in-app notifications and updates'),
            onTap: () => Navigator.pushNamed(context, RouteNames.notifications),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}