import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/local_store.dart';
import 'feature_scaffold.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, dynamic>? _today;

  String _yyyyMmDd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'a-$now-${(now % 100000).toString().padLeft(5, '0')}';
  }

  void _loadToday() {
    final box = Hive.box('attendance');
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final uid = user['id'] ?? user['sub'];
    final todayKey = _yyyyMmDd(DateTime.now());

    Map<String, dynamic>? found;
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map) {
        final m = v.cast<String, dynamic>();
        if ((m['user_id'] == uid) &&
            (m['att_date'] == todayKey) &&
            (m['is_deleted'] != true)) {
          found = m;
          break;
        }
      }
    }

    setState(() => _today = found);
  }

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _ensureRow() async {
    if (_today != null) return;
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final territoryIds = ((user['territory_ids'] as List?) ?? const []).toList();
    final territoryId = user['territory_id'] ??
        user['territory']?['id'] ??
        (territoryIds.isNotEmpty ? territoryIds.first : null);

    if (territoryId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No territory assigned to your user. Please contact admin.'),
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final row = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': _uuid(),
      'user_id': user['id'] ?? user['sub'],
      'territory_id': territoryId,
      'att_date': _yyyyMmDd(now),
      'check_in_at': null,
      'check_out_at': null,
      'status': 'PRESENT',
      'note': null,
      'approval_status': 'DRAFT',
      'version': 1,
      'updated_at_client': now.toIso8601String(),
    };

    await Hive.box('attendance').add(row);
    _loadToday();
  }

  Future<void> _updateToday(Map<String, dynamic> updated) async {
    final box = Hive.box('attendance');
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map) {
        final m = v.cast<String, dynamic>();
        if ((m['uuid'] ?? '').toString() == (updated['uuid'] ?? '').toString()) {
          await box.putAt(i, updated);
          break;
        }
      }
    }
    _loadToday();
  }

  Future<void> _checkIn() async {
    await _ensureRow();
    if (_today == null) return;

    final now = DateTime.now();
    final updated = Map<String, dynamic>.from(_today!);
    updated['check_in_at'] ??= now.toIso8601String();
    updated['updated_at_client'] = now.toIso8601String();
    await _updateToday(updated);
  }

  Future<void> _checkOut() async {
    await _ensureRow();
    if (_today == null) return;
    if (!mounted) return;

    final now = DateTime.now();
    final updated = Map<String, dynamic>.from(_today!);
    if (updated['check_in_at'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in first')),
      );
      return;
    }
    updated['check_out_at'] ??= now.toIso8601String();
    updated['updated_at_client'] = now.toIso8601String();
    await _updateToday(updated);
  }

  Future<void> _submit() async {
    await _ensureRow();
    if (_today == null) return;
    if (!mounted) return;

    final row = Map<String, dynamic>.from(_today!);
    if (row['check_in_at'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in first')),
      );
      return;
    }

    row['approval_status'] = 'SUBMITTED';
    row['updated_at_client'] = DateTime.now().toIso8601String();
    await _updateToday(row);

    await Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'attendance',
      'op': 'UPSERT',
      'uuid': row['uuid'],
      'version': row['version'] ?? 1,
      'payload': row,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitted for approval')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = LocalStore.role();
    final isManager = role == 'RSM' || role == 'SUPER_ADMIN';

    final t = _today;
    final checkIn = (t?['check_in_at'] ?? '').toString();
    final checkOut = (t?['check_out_at'] ?? '').toString();
    final appr = (t?['approval_status'] ?? 'DRAFT').toString();

    return FeatureScaffold(
      title: 'Attendance',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: Text(
                'Today: ${_yyyyMmDd(DateTime.now())}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                isManager
                    ? 'Approval status: $appr — manager approval flow Approvals screen থেকে handle হবে।'
                    : 'Approval status: $appr',
              ),
              trailing: _Chip(appr),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _KV(
                          label: 'Check-in',
                          value: checkIn.isEmpty
                              ? '-'
                              : checkIn.split('.').first.replaceAll('T', ' '),
                        ),
                      ),
                      Expanded(
                        child: _KV(
                          label: 'Check-out',
                          value: checkOut.isEmpty
                              ? '-'
                              : checkOut.split('.').first.replaceAll('T', ' '),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: appr == 'SUBMITTED' ? null : _checkIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Check In'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: appr == 'SUBMITTED' ? null : _checkOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Check Out'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: appr == 'SUBMITTED' ? null : _submit,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Submit for Approval'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Note'),
              subtitle: Text(
                'Attendance entry এখন local storage এবং outbox queue তে save হচ্ছে। '
                    'Sync engine run হলে server approval flow এ যাবে।',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;
  const _KV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String status;
  const _Chip(this.status);

  @override
  Widget build(BuildContext context) {
    final isSubmitted = status == 'SUBMITTED';
    final bg = isSubmitted
        ? Colors.orange.withValues(alpha: 0.15)
        : Colors.blue.withValues(alpha: 0.12);
    final fg = isSubmitted ? Colors.orange.shade800 : Colors.blue.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 12),
      ),
    );
  }
}