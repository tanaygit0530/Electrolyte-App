class SerialCheckResult {
  final bool success;
  final String status; // 'FOUND' or 'NOT FOUND'
  final bool isWithin60Days;
  final int? daysAgo;
  final String serialNumber;
  final String? serviceDate;
  final String? message;
  final Map<String, dynamic>? record;

  SerialCheckResult({
    required this.success,
    required this.status,
    required this.isWithin60Days,
    this.daysAgo,
    required this.serialNumber,
    this.serviceDate,
    this.message,
    this.record,
  });

  factory SerialCheckResult.fromJson(Map<String, dynamic> json) {
    return SerialCheckResult(
      success: json['success'] ?? false,
      status: json['status'] ?? 'NOT FOUND',
      isWithin60Days: json['isWithin60Days'] ?? false,
      daysAgo: json['daysAgo'] != null ? int.tryParse(json['daysAgo'].toString()) : null,
      serialNumber: json['serialNumber']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString(),
      message: json['message']?.toString(),
      record: json['record'] != null ? Map<String, dynamic>.from(json['record']) : null,
    );
  }

  bool get isFound => status.toUpperCase() == 'FOUND' && isWithin60Days;
}
