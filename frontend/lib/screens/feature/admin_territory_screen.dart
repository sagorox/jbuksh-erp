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

  List<Map<String, dynamic>> _divisions = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _areas = [];

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

  Future<List<Map<String, dynamic>>> _readItems(String path, String key) async {
    final res = await Api.getJson(path);
    return ((res[key] as List?) ?? res['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  List<Map<String, dynamic>> _boxMaps(String name) {
    if (!Hive.isBoxOpen(name)) return const [];
    return Hive.box(name)
        .values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _territories = _boxMaps('territories');
      _users = _cacheList('users');
      _assignments = _cacheList('territory_assignments');
      _divisions = _cacheList('divisions');
      _districts = _cacheList('districts');
      _zones = _cacheList('zones');
      _areas = _cacheList('areas');
    });

    try {
      final territoryRes = await Api.getJson('/api/v1/geo/territories');
      final userRes = await Api.getJson('/api/v1/users');

      final territories = ((territoryRes['territories'] as List?) ??
          territoryRes['items'] as List? ??
          const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      final users = ((userRes['users'] as List?) ??
          userRes['items'] as List? ??
          const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      final divisions = await _readItems('/api/v1/geo/divisions', 'divisions');
      final districts = await _readItems('/api/v1/geo/districts', 'districts');
      final zones = await _readItems('/api/v1/geo/zones', 'zones');
      final areas = await _readItems('/api/v1/geo/areas', 'areas');

      final assignments = await _loadAssignments(users);

      final cacheBox = Hive.box('cacheBox');
      await cacheBox.put('users', users);
      await cacheBox.put('territory_assignments', assignments);
      await cacheBox.put('divisions', divisions);
      await cacheBox.put('districts', districts);
      await cacheBox.put('zones', zones);
      await cacheBox.put('areas', areas);

      final tBox = Hive.box('territories');
      for (final row in territories) {
        await tBox.put('${row['id'] ?? row['code']}', row);
      }

      if (!mounted) return;
      setState(() {
        _territories = territories;
        _users = users;
        _assignments = assignments;
        _divisions = divisions;
        _districts = districts;
        _zones = zones;
        _areas = areas;
      });
    } catch (_) {
      if (!mounted) return;
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
        final res = await Api.getJson('/api/v1/geo/users/$userId/territories');
        final territories = ((res['territories'] as List?) ??
            res['items'] as List? ??
            const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

        for (final t in territories) {
          final assignment =
          t['assignment'] is Map ? (t['assignment'] as Map) : const {};
          out.add({
            'user_id': userId,
            'territory_id': t['id'],
            'is_primary': (assignment['is_primary'] == 1 ||
                assignment['is_primary'] == true)
                ? 1
                : 0,
          });
        }
      } catch (_) {
        // ignore single user failure
      }
    }
    return out;
  }

  String _findName(
      List<Map<String, dynamic>> rows,
      dynamic id, {
        List<String> keys = const ['name', 'name_en', 'name_bn'],
      }) {
    for (final row in rows) {
      if (row['id'] == id) {
        for (final key in keys) {
          final val = row[key];
          if (val != null && val.toString().trim().isNotEmpty) {
            return val.toString();
          }
        }
      }
    }
    return id?.toString() ?? '-';
  }

  String _territoryName(dynamic id) {
    return _findName(_territories, id, keys: const ['name']);
  }

  String _userName(dynamic id) {
    return _findName(_users, id, keys: const ['full_name', 'name']);
  }

  String _districtName(dynamic id) {
    return _findName(_districts, id,
        keys: const ['name_en', 'name_bn', 'name']);
  }

  String _areaName(dynamic id) {
    return _findName(_areas, id, keys: const ['name']);
  }

  Future<void> _createTerritory() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();

    List<Map<String, dynamic>> districts = [];
    List<Map<String, dynamic>> areas = [];
    List<Map<String, dynamic>> zones = List.of(_zones);
    List<Map<String, dynamic>> divisions = List.of(_divisions);

    int? divisionId;
    int? districtId;
    int? zoneId;
    int? areaId;

    if (divisions.isEmpty || zones.isEmpty) {
      try {
        divisions = await _readItems('/api/v1/geo/divisions', 'divisions');
        zones = await _readItems('/api/v1/geo/zones', 'zones');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
        return;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> loadDistrictsByDivision(int id) async {
            final list = await _readItems(
              '/api/v1/geo/districts?division_id=$id',
              'districts',
            );
            setLocal(() {
              districts = list;
              districtId = null;
            });
          }

          Future<void> loadAreasByZone(int id) async {
            final list = await _readItems('/api/v1/geo/areas?zone_id=$id', 'areas');
            setLocal(() {
              areas = list;
              areaId = null;
            });
          }

          return AlertDialog(
            title: const Text('Create Territory'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: divisionId,
                      items: divisions
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text(
                            (e['name_en'] ?? e['name_bn'] ?? '-').toString(),
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setLocal(() {
                          divisionId = v;
                          districtId = null;
                          districts = [];
                        });
                        await loadDistrictsByDivision(v);
                      },
                      decoration:
                      const InputDecoration(labelText: 'Division *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: districtId,
                      items: districts
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text(
                            (e['name_en'] ?? e['name_bn'] ?? '-').toString(),
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setLocal(() => districtId = v),
                      decoration:
                      const InputDecoration(labelText: 'District *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: zoneId,
                      items: zones
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text((e['name'] ?? '-').toString()),
                        ),
                      )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setLocal(() {
                          zoneId = v;
                          areaId = null;
                          areas = [];
                        });
                        await loadAreasByZone(v);
                      },
                      decoration: const InputDecoration(labelText: 'Zone *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: areaId,
                      items: areas
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text((e['name'] ?? '-').toString()),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setLocal(() => areaId = v),
                      decoration: const InputDecoration(labelText: 'Area *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                      const InputDecoration(labelText: 'Territory name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: codeCtrl,
                      decoration:
                      const InputDecoration(labelText: 'Territory code'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    if (districtId == null ||
        areaId == null ||
        nameCtrl.text.trim().isEmpty ||
        codeCtrl.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('District, Area, Name, Code required'),
        ),
      );
      return;
    }

    try {
      await Api.postJson('/api/v1/geo/territories', {
        'district_id': districtId,
        'area_id': areaId,
        'name': nameCtrl.text.trim(),
        'code': codeCtrl.text.trim(),
        'is_active': 1,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Territory created successfully')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _assignUser() async {
    if (_users.isEmpty || _territories.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Users or territories not loaded')),
      );
      return;
    }

    int? userId;
    int? territoryId;
    bool isPrimary = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          final assignableUsers = _users
              .where(
                (u) => ['MPO', 'RSM']
                .contains((u['role'] ?? '').toString().toUpperCase()),
          )
              .toList();

          return AlertDialog(
            title: const Text('Assign Territory'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: userId,
                      items: assignableUsers
                          .map(
                            (u) => DropdownMenuItem<int>(
                          value: (u['id'] as num).toInt(),
                          child: Text(
                            '${u['full_name']} (${u['role']})',
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setLocal(() => userId = v),
                      decoration: const InputDecoration(labelText: 'User *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: territoryId,
                      items: _territories
                          .map(
                            (t) => DropdownMenuItem<int>(
                          value: (t['id'] as num).toInt(),
                          child: Text(
                            '${t['name']} (${t['code']})',
                          ),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setLocal(() => territoryId = v),
                      decoration:
                      const InputDecoration(labelText: 'Territory *'),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isPrimary,
                      onChanged: (v) => setLocal(() => isPrimary = v ?? true),
                      title: const Text('Make primary'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Assign'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true || userId == null || territoryId == null) return;

    try {
      await Api.postJson('/api/v1/geo/users/$userId/territories', {
        'territory_id': territoryId,
        'is_primary': isPrimary ? 1 : 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Territory assigned successfully')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Territory Setup',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_location_alt_outlined),
          onPressed: _createTerritory,
        ),
        IconButton(
          icon: const Icon(Icons.assignment_ind_outlined),
          onPressed: _assignUser,
        ),
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
              child: Text(
                _error!,
                style:
                const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Text('Territories: ${_territories.length}'),
              subtitle: Text(
                'Assignments: ${_assignments.length} • Users: ${_users.length}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Territories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._territories.map(
                (t) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text((t['name'] ?? '-').toString()),
                subtitle: Text(
                  'Code: ${t['code'] ?? '-'}\nDistrict: ${_districtName(t['district_id'])} • Area: ${_areaName(t['area_id'])}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Assignments',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._assignments.map(
                (a) => Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(
                  (a['is_primary'] == 1)
                      ? Icons.star
                      : Icons.person_pin_circle_outlined,
                ),
                title: Text(_userName(a['user_id'])),
                subtitle: Text(_territoryName(a['territory_id'])),
                trailing: (a['is_primary'] == 1)
                    ? const Chip(label: Text('Primary'))
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}