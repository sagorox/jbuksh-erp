class Party {
  final int id;
  final String name;
  final String partyCode;

  // Optional fields (used by Party screens/details + sync payloads)
  final String? ownerName;
  final String? phone;
  final String? address;
  final double creditLimit;
  final double openingBalance;
  final int? territoryId;

  Party({
    required this.id,
    required this.name,
    required this.partyCode,
    this.ownerName,
    this.phone,
    this.address,
    this.creditLimit = 0,
    this.openingBalance = 0,
    this.territoryId,
  });

  factory Party.fromJson(Map<String, dynamic> j) {
    return Party(
      id: j['id'] ?? 0,
      name: (j['name'] ?? '').toString(),
      partyCode: (j['party_code'] ?? j['partyCode'] ?? '').toString(),
      ownerName: (j['owner_name'] ?? j['ownerName'])?.toString(),
      phone: (j['phone'] ?? j['mobile'])?.toString(),
      address: (j['address'] ?? j['address_text'])?.toString(),
      creditLimit: _toDouble(j['credit_limit'] ?? j['creditLimit']),
      openingBalance: _toDouble(j['opening_balance'] ?? j['openingBalance']),
      territoryId: _toInt(j['territory_id'] ?? j['territoryId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'party_code': partyCode,
      'owner_name': ownerName,
      'phone': phone,
      'address': address,
      'credit_limit': creditLimit,
      'opening_balance': openingBalance,
      'territory_id': territoryId,
    };
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
