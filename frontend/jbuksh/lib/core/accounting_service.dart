import 'package:hive/hive.dart';

class AccountingService {
  static const String _vouchersBox = 'vouchers';
  static const String _coaBox = 'coa_accounts';

  static Future<void> ensureCoaSeeded() async {
    final box = Hive.box(_coaBox);
    if (box.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    final coa = <Map<String, dynamic>>[
      {'code': 'CASH', 'name': 'Cash', 'type': 'ASSET'},
      {'code': 'BANK', 'name': 'Bank', 'type': 'ASSET'},
      {'code': 'MFS', 'name': 'MFS', 'type': 'ASSET'},
      {'code': 'AR', 'name': 'Accounts Receivable', 'type': 'ASSET'},
      {'code': 'INV', 'name': 'Inventory', 'type': 'ASSET'},
      {'code': 'AP', 'name': 'Accounts Payable', 'type': 'LIABILITY'},
      {'code': 'SALES', 'name': 'Sales Revenue', 'type': 'INCOME'},
      {'code': 'COGS', 'name': 'Cost of Goods Sold', 'type': 'EXPENSE'},
      {'code': 'EXP', 'name': 'Operating Expense', 'type': 'EXPENSE'},
    ];

    for (final a in coa) {
      await box.add({
        'id': -DateTime.now().millisecondsSinceEpoch,
        'code': a['code'],
        'name': a['name'],
        'type': a['type'],
        'is_active': 1,
        'created_at': now,
      });
    }
  }

  static String _voucherNo(String type) {
    final now = DateTime.now();
    final d = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return '$type-$d-${now.millisecondsSinceEpoch.toString().substring(8)}';
  }

  static Future<void> _saveVoucher(Map<String, dynamic> voucher) async {
    final box = Hive.box(_vouchersBox);
    await box.add(voucher);

    // Queue accounting posting for sync engine
    await Hive.box('outboxBox').add({
      'deviceId': Hive.box('auth').get('deviceId') ?? 'unknown',
      'entity': 'vouchers',
      'op': 'UPSERT',
      'uuid': voucher['uuid'],
      'version': 1,
      'payload': voucher,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>> postInvoiceApproved(Map<String, dynamic> invoice) async {
    final now = DateTime.now();
    final net = _toNum(invoice['net_total']);
    final voucher = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': 'v-${now.microsecondsSinceEpoch}',
      'voucher_no': _voucherNo('SV'),
      'voucher_type': 'SV',
      'voucher_date': (invoice['invoice_date'] ?? now.toIso8601String().substring(0, 10)).toString(),
      'ref_type': 'INVOICE',
      'ref_id': invoice['id'] ?? invoice['uuid'],
      'narration': 'Auto post on invoice approval',
      'posted_at': now.toIso8601String(),
      'lines': [
        {
          'account_code': 'AR',
          'account_name': 'Accounts Receivable',
          'party_id': invoice['party_id'] ?? invoice['party']?['id'],
          'debit': net,
          'credit': 0,
        },
        {
          'account_code': 'SALES',
          'account_name': 'Sales Revenue',
          'party_id': null,
          'debit': 0,
          'credit': net,
        },
      ],
    };
    await _saveVoucher(voucher);
    return voucher;
  }

  static Future<Map<String, dynamic>> postCollectionApproved(Map<String, dynamic> collection) async {
    final now = DateTime.now();
    final amount = _toNum(collection['amount']);
    final method = (collection['method'] ?? 'CASH').toString().toUpperCase();
    final cashAccount = method == 'BANK'
        ? 'BANK'
        : method == 'MFS'
            ? 'MFS'
            : 'CASH';
    final voucher = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': 'v-${now.microsecondsSinceEpoch}',
      'voucher_no': _voucherNo('CV'),
      'voucher_type': 'CV',
      'voucher_date': (collection['collection_date'] ?? now.toIso8601String().substring(0, 10)).toString(),
      'ref_type': 'COLLECTION',
      'ref_id': collection['id'] ?? collection['uuid'],
      'narration': 'Auto post on collection approval',
      'posted_at': now.toIso8601String(),
      'lines': [
        {
          'account_code': cashAccount,
          'account_name': cashAccount,
          'party_id': null,
          'debit': amount,
          'credit': 0,
        },
        {
          'account_code': 'AR',
          'account_name': 'Accounts Receivable',
          'party_id': collection['party_id'] ?? collection['party']?['id'],
          'debit': 0,
          'credit': amount,
        },
      ],
    };
    await _saveVoucher(voucher);
    return voucher;
  }

  static Future<Map<String, dynamic>> postExpenseApproved(Map<String, dynamic> expense) async {
    final now = DateTime.now();
    final amount = _toNum(expense['amount']);
    final head = (expense['head'] ?? 'Expense').toString();
    final voucher = <String, dynamic>{
      'id': -now.millisecondsSinceEpoch,
      'uuid': 'v-${now.microsecondsSinceEpoch}',
      'voucher_no': _voucherNo('BV'),
      'voucher_type': 'BV',
      'voucher_date': (expense['expense_date'] ?? now.toIso8601String().substring(0, 10)).toString(),
      'ref_type': 'EXPENSE',
      'ref_id': expense['id'] ?? expense['uuid'],
      'narration': 'Auto post on expense approval',
      'posted_at': now.toIso8601String(),
      'lines': [
        {
          'account_code': 'EXP',
          'account_name': head,
          'party_id': null,
          'debit': amount,
          'credit': 0,
        },
        {
          'account_code': 'CASH',
          'account_name': 'Cash',
          'party_id': null,
          'debit': 0,
          'credit': amount,
        },
      ],
    };
    await _saveVoucher(voucher);
    return voucher;
  }

  static num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }
}
