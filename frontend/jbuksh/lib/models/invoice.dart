class Invoice {
  final int id;
  final String invoiceNo;
  final String invoiceDate;
  final num netTotal;
  final num dueAmount;
  final String partyName;

  Invoice({
    required this.id,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.netTotal,
    required this.dueAmount,
    required this.partyName,
  });

  // ডাটা টাইপ কনভার্সন সেফ রাখার জন্য হেল্পার মেথড
  static num _toNum(dynamic v) {
    if (v == null) return 0; //
    if (v is num) return v; //
    if (v is String) return num.tryParse(v) ?? 0; //
    return 0; //
  }

  factory Invoice.fromJson(Map<String, dynamic> j) {
    // backend response shape অনুযায়ী flexible parsing
    final party = j["party"] ?? {}; //
    
    return Invoice(
      id: j["id"] ?? 0, //
      invoiceNo: (j["server_invoice_no"] ?? j["invoice_no"] ?? "").toString(), //
      invoiceDate: (j["invoice_date"] ?? "").toString(), //
      // হেল্পার মেথড ব্যবহার করে num ফিল্ডগুলো পার্স করা হয়েছে
      netTotal: _toNum(j["net_total"]), //
      dueAmount: _toNum(j["due_amount"]), //
      partyName: (party["name"] ?? j["party_name"] ?? "-").toString(), //
    );
  }
}
