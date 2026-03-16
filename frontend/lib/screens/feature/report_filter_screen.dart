import 'package:flutter/material.dart';
import 'feature_scaffold.dart';
import '../../routes.dart';
import '../../core/local_store.dart';

class ReportFilterScreen extends StatefulWidget {
  final String reportKey;
  final dynamic presetPartyId;
  const ReportFilterScreen({super.key, required this.reportKey, this.presetPartyId});

  @override
  State<ReportFilterScreen> createState() => _ReportFilterScreenState();
}

class _ReportFilterScreenState extends State<ReportFilterScreen> {
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  int? partyId;
  String? status;

  List<Map<String, dynamic>> _parties() => LocalStore.allBoxMaps('parties');
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final v = widget.presetPartyId;
    if (v is int) partyId = v;
    if (v is String) partyId = int.tryParse(v);
  }

  @override
  Widget build(BuildContext context) {
    final parties = _parties();

    return FeatureScaffold(
      title: 'Report Filters',
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.reportKey, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: from, firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (picked != null) setState(() => from = picked);
                          },
                          icon: const Icon(Icons.date_range),
                          label: Text('From: ${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: to, firstDate: DateTime(2020), lastDate: DateTime(2100));
                            if (picked != null) setState(() => to = picked);
                          },
                          icon: const Icon(Icons.date_range_outlined),
                          label: Text('To: ${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: partyId,
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('All parties')),
                      ...parties.map((p) => DropdownMenuItem<int?>(
                            value: _toInt(p['id']),
                            child: Text('${p['name'] ?? '-'}'),
                          )),
                    ],
                    onChanged: (v) => setState(() => partyId = v),
                    decoration: const InputDecoration(labelText: 'Party (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text('All status')),
                      DropdownMenuItem<String?>(value: 'DRAFT', child: Text('DRAFT')),
                      DropdownMenuItem<String?>(value: 'SUBMITTED', child: Text('SUBMITTED')),
                      DropdownMenuItem<String?>(value: 'PENDING_APPROVAL', child: Text('PENDING_APPROVAL')),
                      DropdownMenuItem<String?>(value: 'APPROVED', child: Text('APPROVED')),
                      DropdownMenuItem<String?>(value: 'DECLINED', child: Text('DECLINED')),
                    ],
                    onChanged: (v) => setState(() => status = v),
                    decoration: const InputDecoration(labelText: 'Invoice status (optional)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(context).pushNamed(
                RouteNames.reportResult,
                arguments: {
                  'reportKey': widget.reportKey,
                  'from': from.toIso8601String(),
                  'to': to.toIso8601String(),
                  'partyId': partyId,
                  'status': status,
                },
              );
            },
            icon: const Icon(Icons.search),
            label: const Text('Run Report'),
          ),
        ],
      ),
    );
  }
}
