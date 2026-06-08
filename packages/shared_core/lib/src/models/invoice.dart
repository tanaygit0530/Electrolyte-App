class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String technicianName;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final double subTotal;
  final double gstAmount;
  final double serviceCharge;
  final double totalAmount;
  final String? pdfUrl;
  final String status;
  final String? brand;
  final String? serialNumber;
  final String? caseId;
  final String? warrantyType;
  final String? preparedBy;
  final DateTime createdAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.technicianName,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    required this.subTotal,
    required this.gstAmount,
    required this.serviceCharge,
    required this.totalAmount,
    this.pdfUrl,
    required this.status,
    this.brand,
    this.serialNumber,
    this.caseId,
    this.warrantyType,
    this.preparedBy,
    required this.createdAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      technicianName: json['technicianName'] ?? '',
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'],
      customerPhone: json['customerPhone'],
      subTotal: double.tryParse(json['subTotal']?.toString() ?? '0') ?? 0.0,
      gstAmount: double.tryParse(json['gstAmount']?.toString() ?? '0') ?? 0.0,
      serviceCharge: double.tryParse(json['serviceCharge']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
      pdfUrl: json['pdfUrl'],
      status: json['status'] ?? '',
      brand: json['brand'],
      serialNumber: json['serialNumber'],
      caseId: json['caseId'],
      warrantyType: json['warrantyType'],
      preparedBy: json['preparedBy'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
