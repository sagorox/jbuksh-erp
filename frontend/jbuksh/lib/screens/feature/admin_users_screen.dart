import 'package:flutter/material.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = _searchCtrl.text.trim();
      final res =
      await Api.getJson('/api/v1/users${q.isEmpty ? '' : '?q=$q'}');

      final items = ((res['users'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

      setState(() => _users = items);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _readItems(String path, String key) async {
    final res = await Api.getJson(path);
    return ((res[key] as List?) ?? res['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> _openCreateDialog() async {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');

    String role = 'MPO';

    List<Map<String, dynamic>> divisions = [];
    List<Map<String, dynamic>> districts = [];
    List<Map<String, dynamic>> zones = [];
    List<Map<String, dynamic>> areas = [];
    List<Map<String, dynamic>> territories = [];

    int? divisionId;
    int? districtId;
    int? zoneId;
    int? areaId;
    int? territoryId;

    try {
      divisions = await _readItems('/api/v1/geo/divisions', 'divisions');
      if (divisions.isEmpty) {
        divisions = await _readItems('/api/v1/geo/divisions', 'items');
      }

      zones = await _readItems('/api/v1/geo/zones', 'zones');
      if (zones.isEmpty) {
        zones = await _readItems('/api/v1/geo/zones', 'items');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geo data load failed: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> loadDistricts(int id) async {
            final res = await Api.getJson('/api/v1/geo/districts?division_id=$id');
            final list = ((res['districts'] as List?) ?? res['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();

            setLocal(() {
              districts = list;
              districtId = null;
              territories = [];
              territoryId = null;
            });
          }

          Future<void> loadAreas(int id) async {
            final res = await Api.getJson('/api/v1/geo/areas?zone_id=$id');
            final list = ((res['areas'] as List?) ?? res['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();

            setLocal(() {
              areas = list;
              areaId = null;
              territories = [];
              territoryId = null;
            });
          }

          Future<void> loadTerritories() async {
            if (districtId == null || areaId == null) {
              setLocal(() {
                territories = [];
                territoryId = null;
              });
              return;
            }

            final res = await Api.getJson(
              '/api/v1/geo/territories?area_id=$areaId&district_id=$districtId',
            );

            final list = ((res['territories'] as List?) ?? res['items'] as List? ?? const [])
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();

            setLocal(() {
              territories = list;
              territoryId = null;
            });
          }

          return AlertDialog(
            title: const Text('Create User'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
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
                      ]
                          .map(
                            (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setLocal(() => role = v ?? 'MPO'),
                      decoration: const InputDecoration(labelText: 'Role'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: divisionId,
                      items: divisions
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text((e['name_en'] ?? e['name_bn'] ?? '-').toString()),
                        ),
                      )
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setLocal(() {
                          divisionId = v;
                          districtId = null;
                          territories = [];
                          territoryId = null;
                        });
                        await loadDistricts(v);
                      },
                      decoration: const InputDecoration(labelText: 'Division *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: districtId,
                      items: districts
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text((e['name_en'] ?? e['name_bn'] ?? '-').toString()),
                        ),
                      )
                          .toList(),
                      onChanged: (v) async {
                        setLocal(() => districtId = v);
                        await loadTerritories();
                      },
                      decoration: const InputDecoration(labelText: 'District *'),
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
                          territories = [];
                          territoryId = null;
                        });
                        await loadAreas(v);
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
                      onChanged: (v) async {
                        setLocal(() => areaId = v);
                        await loadTerritories();
                      },
                      decoration: const InputDecoration(labelText: 'Area *'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: territoryId,
                      items: territories
                          .map(
                            (e) => DropdownMenuItem<int>(
                          value: (e['id'] as num).toInt(),
                          child: Text('${e['name'] ?? '-'} (${e['code'] ?? '-'})'),
                        ),
                      )
                          .toList(),
                      onChanged: (v) => setLocal(() => territoryId = v),
                      decoration: const InputDecoration(labelText: 'Territory *'),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Division, District, Zone, Area, Territory ছাড়া user create হবে না',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
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

    if (nameCtrl.text.trim().isEmpty ||
        phoneCtrl.text.trim().isEmpty ||
        passCtrl.text.trim().isEmpty ||
        divisionId == null ||
        districtId == null ||
        zoneId == null ||
        areaId == null ||
        territoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('সব required field পূরণ করতে হবে')),
        );
      }
      return;
    }

    try {
      await Api.postJson('/api/v1/users', {
        'full_name': nameCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'password': passCtrl.text.trim(),
        'role': role,
        'division_id': divisionId,
        'district_id': districtId,
        'zone_id': zoneId,
        'area_id': areaId,
        'territory_id': territoryId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User created successfully')),
        );
      }

      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> user) async {
    final id = user['id'];
    final next =
    (user['is_active'] == 1 || user['is_active'] == true) ? 0 : 1;

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

  String _geoSummary(Map<String, dynamic> u) {
    final divisionId = u['division_id']?.toString() ?? '-';
    final districtId = u['district_id']?.toString() ?? '-';
    final zoneId = u['zone_id']?.toString() ?? '-';
    final areaId = u['area_id']?.toString() ?? '-';
    final territoryId = u['territory_id']?.toString() ?? '-';

    return 'D:$divisionId • Dist:$districtId • Z:$zoneId • A:$areaId • T:$territoryId';
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Users & Roles',
      actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        IconButton(
          icon: const Icon(Icons.person_add_alt_1),
          onPressed: _openCreateDialog,
        ),
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _load,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            )
                : _users.isEmpty
                ? const Center(child: Text('No users found'))
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final u = _users[index];
                final active = u['is_active'] == 1 ||
                    u['is_active'] == true;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (u['full_name'] ?? 'U')
                            .toString()
                            .substring(0, 1)
                            .toUpperCase(),
                      ),
                    ),
                    title: Text((u['full_name'] ?? '-').toString()),
                    subtitle: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${u['phone'] ?? '-'} • ${u['role'] ?? '-'}'),
                        const SizedBox(height: 4),
                        Text(_geoSummary(u)),
                      ],
                    ),
                    trailing: Switch(
                      value: active,
                      onChanged: (_) => _toggleStatus(u),
                    ),
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