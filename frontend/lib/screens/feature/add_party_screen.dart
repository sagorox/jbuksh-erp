import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/api.dart';
import '../../core/local_store.dart';
import '../../core/role_utils.dart';
import '../../routes.dart';
import 'feature_scaffold.dart';

class AddPartyScreen extends StatefulWidget {
  const AddPartyScreen({super.key});

  @override
  State<AddPartyScreen> createState() => _AddPartyScreenState();
}

class _AddPartyScreenState extends State<AddPartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _credit = TextEditingController(text: '0');
  final _opening = TextEditingController(text: '0');

  num _toNum(String s) => num.tryParse(s.trim()) ?? 0;

  String _genPartyCode() {
    // Local temp code. Server authoritative code can override later via sync.
    final now = DateTime.now();
    return 'P${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  Future<void> _save({required bool submit}) async {
    if (!_formKey.currentState!.validate()) return;

    final partiesBox = Hive.box('parties');
    final outbox = Hive.box('outboxBox');
    final user = (Hive.box('auth').get('user') as Map?) ?? {};
    final territoryIds = ((user['territory_ids'] as List?) ?? const []).toList();
    final territoryId = territoryIds.isNotEmpty ? territoryIds.first : null;
    if (territoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No territory assigned to your user. Please contact admin.')),
      );
      return;
    }

    final now = DateTime.now();
    final partyCode = _genPartyCode();
    final map = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': partyCode,
      'territory_id': territoryId,
      'party_code': partyCode,
      'name': _name.text.trim(),
      'owner_name': _owner.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'credit_limit': _toNum(_credit.text),
      'opening_balance': _toNum(_opening.text),
      'is_active': 1,
      'created_at_client': now.toIso8601String(),
      'sync_status': 'dirty',
    };

    var savedOnline = false;
    if (submit) {
      try {
        final res = await Api.postJson('/api/v1/parties', {
          'territory_id': territoryId,
          'party_code': partyCode,
          'name': _name.text.trim(),
          'assigned_mpo_user_id': user['id'] ?? user['sub'],
        });
        final serverParty = (res['party'] is Map)
            ? (res['party'] as Map).cast<String, dynamic>()
            : null;
        if (serverParty != null) {
          final key = (serverParty['id'] ?? serverParty['uuid'] ?? partyCode).toString();
          await partiesBox.put(key, serverParty);
          savedOnline = true;
        }
      } catch (_) {
        savedOnline = false;
      }
    }

    if (!savedOnline) {
      await partiesBox.add(map);
      outbox.add({
        'entity': 'parties',
        'op': 'UPSERT',
        'uuid': partyCode,
        'version': 1,
        'payload': map,
        'created_at_client': DateTime.now().toIso8601String(),
      });
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedOnline
              ? 'Party saved to server.'
              : (submit ? 'Party saved + queued for sync' : 'Party saved offline'),
        ),
      ),
    );
    Navigator.of(context).pushNamedAndRemoveUntil(RouteNames.parties, (r) => r.isFirst);
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _phone.dispose();
    _address.dispose();
    _credit.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleUtils.normalize(LocalStore.role());
    final canCreate = role == RoleUtils.superAdmin ||
        role == RoleUtils.mpo ||
        role == RoleUtils.rsm ||
        role == RoleUtils.salesDept;

    return FeatureScaffold(
      title: 'Add Party',
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Party Name *', border: OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _owner,
                        decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _credit,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Credit Limit', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _opening,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Opening Balance', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!canCreate)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Your role does not allow creating parties.'),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canCreate ? () => _save(submit: false) : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: canCreate ? () => _save(submit: true) : null,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Save & Queue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Party code is temporary offline. Server will assign authoritative code/uuid after sync.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
