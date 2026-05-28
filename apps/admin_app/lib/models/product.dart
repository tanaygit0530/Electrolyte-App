class Product {
  final int id;
  final String productCode;
  final String productName;
  final String? description;
  final int stockQuantity;
  final double productPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.productCode,
    required this.productName,
    this.description,
    required this.stockQuantity,
    required this.productPrice,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      productCode: json['product_code'] ?? '',
      productName: json['product_name'] ?? '',
      description: json['description'],
      stockQuantity: json['stock_quantity'] is int 
          ? json['stock_quantity'] 
          : int.parse(json['stock_quantity'].toString()),
      productPrice: json['product_price'] is double 
          ? json['product_price'] 
          : double.parse((json['product_price'] ?? 0.0).toString()),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_code': productCode,
      'product_name': productName,
      'description': description,
      'stock_quantity': stockQuantity,
      'product_price': productPrice,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
