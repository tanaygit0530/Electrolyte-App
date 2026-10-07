class SparePart {
  final String id;
  final String partName;
  final String partCode;
  final String model;
  final double price;
  final int stockQuantity;
  final String status;

  SparePart({
    required this.id,
    required this.partName,
    required this.partCode,
    required this.model,
    required this.price,
    required this.stockQuantity,
    required this.status,
  });

  factory SparePart.fromJson(Map<String, dynamic> json) {
    final qty = int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0;
    return SparePart(
      id: json['id']?.toString() ?? '',
      partName: json['part_name']?.toString() ?? '',
      partCode: json['part_code']?.toString() ?? '',
      model: json['model']?.toString() ?? 'N/A',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      stockQuantity: qty,
      status: json['status']?.toString() ?? (qty > 0 ? 'Available' : 'Out of Stock'),
    );
  }
}
