class AccountingSummary {
  final bool ok;
  final int total;
  final int posted;
  final int cancelled;
  final int draft;
  final double debit;
  final double credit;
  final double balance;

  AccountingSummary({
    required this.ok,
    required this.total,
    required this.posted,
    required this.cancelled,
    required this.draft,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory AccountingSummary.fromJson(Map<String, dynamic> json) {
    final counts = Map<String, dynamic>.from(json['counts'] ?? {});
    final totals = Map<String, dynamic>.from(json['totals'] ?? {});

    return AccountingSummary(
      ok: json['ok'] == true,
      total: _toInt(counts['total']),
      posted: _toInt(counts['posted']),
      cancelled: _toInt(counts['cancelled']),
      draft: _toInt(counts['draft']),
      debit: _toDouble(totals['debit']),
      credit: _toDouble(totals['credit']),
      balance: _toDouble(totals['balance']),
    );
  }
}

class VoucherItem {
  final int id;
  final String voucherNo;
  final String voucherDate;
  final String voucherType;
  final double amount;
  final int? territoryId;
  final int? partyId;
  final int? userId;
  final String? referenceType;
  final int? referenceId;
  final String? description;
  final String status;
  final String? approvedAt;
  final int? createdBy;
  final int version;
  final String? createdAt;
  final String? updatedAt;

  VoucherItem({
    required this.id,
    required this.voucherNo,
    required this.voucherDate,
    required this.voucherType,
    required this.amount,
    required this.territoryId,
    required this.partyId,
    required this.userId,
    required this.referenceType,
    required this.referenceId,
    required this.description,
    required this.status,
    required this.approvedAt,
    required this.createdBy,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VoucherItem.fromJson(Map<String, dynamic> json) {
    return VoucherItem(
      id: _toInt(json['id']),
      voucherNo: (json['voucher_no'] ?? '').toString(),
      voucherDate: (json['voucher_date'] ?? '').toString(),
      voucherType: (json['voucher_type'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      territoryId: json['territory_id'] == null ? null : _toInt(json['territory_id']),
      partyId: json['party_id'] == null ? null : _toInt(json['party_id']),
      userId: json['user_id'] == null ? null : _toInt(json['user_id']),
      referenceType: json['reference_type']?.toString(),
      referenceId: json['reference_id'] == null ? null : _toInt(json['reference_id']),
      description: json['description']?.toString(),
      status: (json['status'] ?? '').toString(),
      approvedAt: json['approved_at']?.toString(),
      createdBy: json['created_by'] == null ? null : _toInt(json['created_by']),
      version: _toInt(json['version']),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class VoucherListResponse {
  final bool ok;
  final List<VoucherItem> vouchers;

  VoucherListResponse({
    required this.ok,
    required this.vouchers,
  });

  factory VoucherListResponse.fromJson(Map<String, dynamic> json) {
    final rows = (json['vouchers'] as List<dynamic>? ?? [])
        .map((e) => VoucherItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return VoucherListResponse(
      ok: json['ok'] == true,
      vouchers: rows,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse('${value ?? 0}') ?? 0;
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse('${value ?? 0}') ?? 0;
}