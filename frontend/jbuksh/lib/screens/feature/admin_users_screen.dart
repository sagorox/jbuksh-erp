import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import 'feature_scaffold.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _cachedUsers() {
    final raw = Hive.box('cacheBox').get('users');
    if (raw is List) {
      final rows = raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q.isEmpty) return rows;
      return rows.where((e) {
        final name = (e['full_name'] ?? '').toString().toLowerCase();
        final phone = (e['phone'] ?? '').toString().toLowerCase();
        final role = (e['role'] ?? '').toString().toLowerCase();
        return name.contains(q) || phone.contains(q) || role.contains(q);
      }).toList();
    }
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _users = _cachedUsers();
    });
    try {
      final q = _searchCtrl.text.trim();
      final res = await Api.getJson('/api/v1/users${q.isEmpty ? '' : '?q=$q'}');
      final items = ((res['users'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      await Hive.box('cacheBox').put('users', items);
      setState(() => _users = items);
    } catch (e) {
      setState(() {
        _error = 'Showing cached users';
        _users = _cachedUsers();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    String role = 'MPO';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
                const SizedBox(height: 10),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 10),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    'SUPER_ADMIN',
                    'RSM',
                    'SALES_DEPT',
                    'ACCOUNTING',
                    'STOCK_KEEPER',
                    'MPO',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setLocal(() => role = v ?? 'MPO'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await Api.postJson('/api/v1/users', {
        'full_name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'password': passCtrl.text,
        'role': role,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created')));
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final id = user['id'];
    final next = (user['is_active'] == 1 || user['is_active'] == true) ? 0 : 1;
    try {
      await Api.patchJson('/api/v1/users/$id/status', {'is_active': next});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Users & Roles',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: _openCreateDialog),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name / phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.send), onPressed: _load),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          Expanded(
            child: _loading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('No users found'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          final active = u['is_active'] == 1 || u['is_active'] == true;
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text((u['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase()),
                              ),
                              title: Text((u['full_name'] ?? '-').toString()),
                              subtitle: Text('${u['phone'] ?? '-'} • ${u['role'] ?? '-'}'),
                              trailing: Switch(value: active, onChanged: (_) => _toggleStatus(u)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
