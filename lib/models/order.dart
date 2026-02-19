class OrderModel {
  final String id;
  final String partCode;
  final String partName;
  final int quantity;
  final double price;
  final double gst;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.partCode,
    required this.partName,
    required this.quantity,
    required this.price,
    required this.gst,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      partCode: json['part_code'],
      partName: json['part_name'],
      quantity: json['quantity'],
      price: double.parse(json['price'].toString()),
      gst: double.parse(json['gst'].toString()),
      totalAmount: double.parse(json['total_amount'].toString()),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
