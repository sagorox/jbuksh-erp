import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/api.dart';
import 'feature_scaffold.dart';

class AdminTerritoryScreen extends StatefulWidget {
  const AdminTerritoryScreen({super.key});

  @override
  State<AdminTerritoryScreen> createState() => _AdminTerritoryScreenState();
}

class _AdminTerritoryScreenState extends State<AdminTerritoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _territories = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _cacheList(String key) {
    final raw = Hive.box('cacheBox').get(key);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _territories = Hive.box('territories')
          .values
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      _users = _cacheList('users');
      _assignments = _cacheList('territory_assignments');
    });
    try {
      final t = await _safeGet('/api/v1/geo/territories', fallback: '/api/v1/territories');
      final u = await Api.getJson('/api/v1/users');
      final users = _readList(u, ['users', 'items']);
      final assignments = await _loadAssignments(users);
      final territories = _readList(t, ['territories', 'items']);

      await Hive.box('cacheBox').put('users', users);
      await Hive.box('cacheBox').put('territory_assignments', assignments);
      final tBox = Hive.box('territories');
      for (final row in territories) {
        await tBox.put('${row['id'] ?? row['code']}', row);
      }

      setState(() {
        _territories = territories;
        _users = users;
        _assignments = assignments;
      });
    } catch (e) {
      setState(() => _error = 'Showing cached data');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadAssignments(
    List<Map<String, dynamic>> users,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (final u in users) {
      final userId = u['id'];
      if (userId == null) continue;
      try {
        final list = await Api.getJson('/api/v1/geo/users/$userId/territories');
        final territories = (list['territories'] as List?) ??
            (list['items'] as List?) ??
            const [];
        for (var i = 0; i < territories.length; i++) {
          final t = territories[i];
          if (t is! Map) continue;
          out.add({
            'user_id': userId,
            'territory_id': t['id'],
            'is_primary': i == 0 ? 1 : 0,
          });
        }
      } catch (_) {
        // best effort, skip a single user's territories on failure
      }
    }
    return out;
  }

  Future<Map<String, dynamic>> _safeGet(String path, {String? fallback}) async {
    try {
      return await Api.getJson(path);
    } catch (_) {
      if (fallback == null) rethrow;
      return Api.getJson(fallback);
    }
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> src, List<String> keys) {
    for (final k in keys) {
      final v = src[k];
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  Future<void> _createTerritory() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Territory create API is not available in current backend build.')),
    );
  }

  Future<void> _assignUser() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Territory assignment update API is not available in current backend build.')),
    );
  }

  String _territoryName(dynamic id) {
    final t = _territories.where((e) => e['id'] == id).cast<Map<String, dynamic>>().toList();
    return t.isEmpty ? '$id' : (t.first['name'] ?? id).toString();
  }

  String _userName(dynamic id) {
    final u = _users.where((e) => e['id'] == id).cast<Map<String, dynamic>>().toList();
    return u.isEmpty ? '$id' : (u.first['full_name'] ?? id).toString();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Territory Setup',
      actions: [
        IconButton(icon: const Icon(Icons.add_location_alt_outlined), onPressed: _createTerritory),
        IconButton(icon: const Icon(Icons.assignment_ind_outlined), onPressed: _assignUser),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ],
      child: _loading && _territories.isEmpty && _users.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text('Territories: ${_territories.length}'),
                    subtitle: Text('Assignments: ${_assignments.length} • Users: ${_users.length}'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Territories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._territories.map(
                  (t) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text((t['name'] ?? '-').toString()),
                      subtitle: Text('Code: ${t['code'] ?? '-'}'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._assignments.map(
                  (a) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: Icon((a['is_primary'] == 1) ? Icons.star : Icons.person_pin_circle_outlined),
                      title: Text(_userName(a['user_id'])),
                      subtitle: Text(_territoryName(a['territory_id'])),
                      trailing: (a['is_primary'] == 1) ? const Chip(label: Text('Primary')) : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
