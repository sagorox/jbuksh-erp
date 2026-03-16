import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/api.dart';
import '../../core/role_utils.dart';
import 'feature_scaffold.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _territories = [];

  String get _role => RoleUtils.normalize((((Hive.box('auth').get('user') as Map?) ?? const {})['role'] ?? '').toString());
  bool get _canManage => _role == RoleUtils.superAdmin || _role == RoleUtils.rsm;

  @override
  void initState() { super.initState(); _load(); }

  List<Map<String, dynamic>> _cachedList(String key) {
    final raw = Hive.box('cacheBox').get(key);
    if (raw is List) return raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _schedules = _cachedList('schedules');
      _users = _cachedList('users');
      _territories = Hive.box('territories').values.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    });
    try {
      final sched = await Api.getJson(_canManage ? '/api/v1/schedules' : '/api/v1/schedules/my');
      final users = _canManage ? await Api.getJson('/api/v1/users') : {'users': []};
      final territories = _canManage ? await Api.getJson('/api/v1/geo/territories') : {'territories': []};
      _schedules = (((sched['schedules'] ?? sched['items']) as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      _users = ((users['users'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      _territories = ((territories['territories'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      await Hive.box('cacheBox').put('schedules', _schedules);
      await Hive.box('cacheBox').put('users', _users);
      final tBox = Hive.box('territories');
      for (final t in _territories) { await tBox.put('${t['id'] ?? t['code']}', t); }
    } catch (e) {
      _error = 'Showing cached data';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createSchedule() async { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline read available. Create/assign needs online server.'))); }
  Future<void> _assignSchedule() async { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline read available. Create/assign needs online server.'))); }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: 'Work Schedule',
      actions: [if (_canManage) IconButton(icon: const Icon(Icons.playlist_add), onPressed: _createSchedule), if (_canManage) IconButton(icon: const Icon(Icons.assignment_ind), onPressed: _assignSchedule), IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      child: _loading && _schedules.isEmpty ? const Center(child: CircularProgressIndicator()) : _schedules.isEmpty ? Center(child: Text(_error ?? 'No schedule found')) : ListView(
        padding: const EdgeInsets.all(12),
        children: [if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.orange))), ..._schedules.map((s) {
          final data = (s['schedule'] is Map) ? (s['schedule'] as Map).cast<String, dynamic>() : s;
          final subtitle = _canManage ? '${data['start_date'] ?? '-'} → ${data['end_date'] ?? '-'}' : '${data['start_date'] ?? '-'} → ${data['end_date'] ?? '-'} • Territory ${s['territory_id'] ?? '-'}';
          return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: ListTile(leading: const Icon(Icons.event_note_outlined), title: Text((data['name'] ?? 'Schedule').toString()), subtitle: Text(subtitle)));
        })],
      ),
    );
  }
}
