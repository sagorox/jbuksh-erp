import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:jbuksh/core/api.dart';

import 'accounting_api_service.dart';
import 'accounting_models.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  late final AccountingApiService _api;

  bool _loading = true;
  bool _creating = false;
  String? _error;

  AccountingSummary? _summary;
  List<VoucherItem> _vouchers = const [];

  @override
  void initState() {
    super.initState();

    _api = AccountingApiService(
      baseUrl: Api.baseUrl,
      tokenProvider: _getToken,
    );

    _load();
  }

  Future<String?> _getToken() async {
    if (!Hive.isBoxOpen('auth')) return null;
    return Hive.box('auth').get('token')?.toString();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.fetchSummary(),
        _api.fetchVouchers(),
      ]);

      if (!mounted) return;

      setState(() {
        _summary = results[0] as AccountingSummary;
        _vouchers = (results[1] as VoucherListResponse).vouchers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showCreateVoucherDialog() async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    String voucherType = 'DEBIT';
    String status = 'POSTED';

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Voucher'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: voucherType,
                    decoration: const InputDecoration(
                      labelText: 'Voucher Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'DEBIT',
                        child: Text('DEBIT'),
                      ),
                      DropdownMenuItem(
                        value: 'CREDIT',
                        child: Text('CREDIT'),
                      ),
                    ],
                    onChanged: (v) {
                      voucherType = v ?? 'DEBIT';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                    ),
                    validator: (v) {
                      final value = double.tryParse((v ?? '').trim());
                      if (value == null || value <= 0) {
                        return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'POSTED',
                        child: Text('POSTED'),
                      ),
                      DropdownMenuItem(
                        value: 'DRAFT',
                        child: Text('DRAFT'),
                      ),
                    ],
                    onChanged: (v) {
                      status = v ?? 'POSTED';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                    maxLines: 3,
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
            ElevatedButton(
              onPressed: _creating
                  ? null
                  : () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(context, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (created != true) {
      amountController.dispose();
      descriptionController.dispose();
      return;
    }

    setState(() {
      _creating = true;
    });

    try {
      final now = DateTime.now();
      final voucherDate =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      await _api.createVoucher(
        voucherDate: voucherDate,
        voucherType: voucherType,
        amount: double.parse(amountController.text.trim()),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        status: status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher saved successfully'),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create failed: $e'),
        ),
      );
    } finally {
      amountController.dispose();
      descriptionController.dispose();

      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _creating ? null : _showCreateVoucherDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        if (_vouchers.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 100),
              child: Text('No vouchers found'),
            ),
          )
        else
          ..._vouchers.map(_buildVoucherTile),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final s = _summary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Total Vouchers: ${s?.total ?? 0}'),
            Text('Posted: ${s?.posted ?? 0}'),
            Text('Draft: ${s?.draft ?? 0}'),
            Text('Cancelled: ${s?.cancelled ?? 0}'),
            const SizedBox(height: 8),
            Text('Debit: ${(s?.debit ?? 0).toStringAsFixed(2)}'),
            Text('Credit: ${(s?.credit ?? 0).toStringAsFixed(2)}'),
            Text('Balance: ${(s?.balance ?? 0).toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherTile(VoucherItem item) {
    return Card(
      child: ListTile(
        title: Text(item.voucherNo),
        subtitle: Text(
          '${item.voucherType} • ${item.voucherDate} • ${item.status}',
        ),
        trailing: Text(item.amount.toStringAsFixed(2)),
      ),
    );
  }
}