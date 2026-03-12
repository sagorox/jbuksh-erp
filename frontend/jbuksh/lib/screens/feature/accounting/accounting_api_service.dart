import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:jbuksh/core/offline_cache.dart';

import 'accounting_models.dart';

class AccountingApiService {
  final String baseUrl;
  final Future<String?> Function() tokenProvider;

  AccountingApiService({
    required this.baseUrl,
    required this.tokenProvider,
  });

  Future<AccountingSummary> fetchSummary() async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/accounting/summary');

    try {
      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      final data = _decode(response);
      _throwIfNeeded(response, data, 'Failed to load accounting summary');
      return AccountingSummary.fromJson(data);
    } on SocketException {
      return AccountingSummary.fromJson(
        OfflineCache.forPath('/api/v1/accounting/summary'),
      );
    }
  }

  Future<VoucherListResponse> fetchVouchers() async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/accounting/vouchers');

    try {
      final response = await http.get(
        uri,
        headers: _headers(token),
      );

      final data = _decode(response);
      _throwIfNeeded(response, data, 'Failed to load vouchers');
      final rows = (data['vouchers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      await _cacheRows(rows);
      return VoucherListResponse.fromJson(data);
    } on SocketException {
      return VoucherListResponse.fromJson(
        OfflineCache.forPath('/api/v1/accounting/vouchers'),
      );
    }
  }

  Future<VoucherItem> createVoucher({
    required String voucherDate,
    required String voucherType,
    required double amount,
    String? description,
    String status = 'POSTED',
  }) async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/accounting/vouchers');

    try {
      final response = await http.post(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'voucher_date': voucherDate,
          'voucher_type': voucherType,
          'amount': amount,
          'description': description,
          'status': status,
        }),
      );

      final data = _decode(response);
      _throwIfNeeded(response, data, 'Failed to create voucher');
      final voucher = Map<String, dynamic>.from(data['voucher'] ?? {});
      await _upsertVoucher(voucher);
      return VoucherItem.fromJson(voucher);
    } on SocketException {
      final voucher = _buildLocalVoucher(
        voucherDate: voucherDate,
        voucherType: voucherType,
        amount: amount,
        description: description,
        status: status,
      );
      await _upsertVoucher(voucher);
      await _queueVoucher('CREATE', voucher);
      return VoucherItem.fromJson(voucher);
    }
  }

  Future<VoucherItem> updateVoucherStatus({
    required int id,
    required String status,
  }) async {
    final token = await tokenProvider();
    final uri = Uri.parse('$baseUrl/api/v1/accounting/vouchers/$id/status');

    try {
      final response = await http.patch(
        uri,
        headers: _headers(token),
        body: jsonEncode({
          'status': status,
        }),
      );

      final data = _decode(response);
      _throwIfNeeded(response, data, 'Failed to update voucher status');
      final voucher = Map<String, dynamic>.from(data['voucher'] ?? {});
      await _upsertVoucher(voucher);
      return VoucherItem.fromJson(voucher);
    } on SocketException {
      final box = Hive.box('vouchers');
      Map<String, dynamic>? voucher;
      for (final key in box.keys) {
        final v = box.get(key);
        if (v is Map && '${v['id'] ?? ''}' == '$id') {
          voucher = Map<String, dynamic>.from(v.cast<String, dynamic>());
          voucher['status'] = status;
          await box.put(key, voucher);
          break;
        }
      }
      voucher ??= {
        'id': id,
        'voucher_no': 'V-$id',
        'voucher_date': DateTime.now().toIso8601String().substring(0, 10),
        'voucher_type': 'DEBIT',
        'amount': 0,
        'status': status,
        'lines': const [],
      };
      await _queueVoucher('STATUS', {'id': id, 'status': status});
      return VoucherItem.fromJson(voucher);
    }
  }

  Future<void> _cacheRows(List<Map<String, dynamic>> rows) async {
    if (!Hive.isBoxOpen('vouchers')) return;
    final box = Hive.box('vouchers');
    for (final row in rows) {
      await box.put('${row['id'] ?? row['voucher_no']}', row);
    }
  }

  Future<void> _upsertVoucher(Map<String, dynamic> voucher) async {
    if (!Hive.isBoxOpen('vouchers')) return;
    final box = Hive.box('vouchers');
    await box.put('${voucher['id'] ?? voucher['voucher_no']}', voucher);
  }

  Map<String, dynamic> _buildLocalVoucher({
    required String voucherDate,
    required String voucherType,
    required double amount,
    String? description,
    required String status,
  }) {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch;
    return {
      'id': id,
      'uuid': 'local-voucher-$id',
      'voucher_no': 'OFF-$id',
      'voucher_date': voucherDate,
      'voucher_type': voucherType,
      'amount': amount,
      'description': description,
      'status': status,
      'posted_at': now.toIso8601String(),
      'lines': [
        {
          'debit': voucherType.toUpperCase() == 'DEBIT' ? amount : 0,
          'credit': voucherType.toUpperCase() == 'CREDIT' ? amount : 0,
        }
      ],
      'offline_created': true,
    };
  }

  Future<void> _queueVoucher(String op, Map<String, dynamic> payload) async {
    if (!Hive.isBoxOpen('outboxBox')) return;
    final outbox = Hive.box('outboxBox');
    await outbox.add({
      'entity': 'voucher',
      'op': op,
      'uuid': payload['uuid'] ?? payload['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  void _throwIfNeeded(
      http.Response response,
      Map<String, dynamic> data,
      String fallback,
      ) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message']?.toString() ?? fallback);
    }
  }
}
