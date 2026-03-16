class Product {
  final int id;
  final String sku;
  final String name;
  final String? unit;
  final int? categoryId;
  final String? categoryName;
  final String? potencyTag;
  final num salePrice;
  final num purchasePrice;
  final num reorderLevel;
  final num inStock;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.categoryId,
    required this.categoryName,
    required this.potencyTag,
    required this.salePrice,
    required this.purchasePrice,
    required this.reorderLevel,
    required this.inStock,
  });

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static num _toNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String? _categoryName(dynamic category) {
    if (category == null) return null;
    if (category is Map) {
      final name = category['name'];
      if (name != null) return name.toString();
    }
    return category.toString();
  }

  factory Product.fromJson(Map<String, dynamic> j) {
    return Product(
      id: _toInt(j["id"]),
      sku: (j["sku"] ?? "").toString(),
      name: (j["name"] ?? "").toString(),
      unit: j["unit"]?.toString(),
      categoryId: j["category_id"] == null ? null : _toInt(j["category_id"]),
      categoryName: _categoryName(j["category"]),
      potencyTag: j["potency_tag"]?.toString(),
      salePrice: _toNum(j["sale_price"]),
      purchasePrice: _toNum(j["purchase_price"]),
      reorderLevel: _toNum(j["reorder_level"]),
      inStock: _toNum(j["in_stock"]),
    );
  }
}
