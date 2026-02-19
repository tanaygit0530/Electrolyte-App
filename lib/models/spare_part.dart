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
    return SparePart(
      id: json['id'],
      partName: json['part_name'],
      partCode: json['part_code'],
      model: json['model'],
      price: double.parse(json['price'].toString()),
      stockQuantity: json['stock_quantity'],
      status: json['status'],
    );
  }
}
