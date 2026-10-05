class SerialCheckResult {
  final bool success;
  final String status;
  final bool isWithin60Days;
  final bool repeatRisk;
  final bool canCloseCall;
  final int? daysAgo;
  final String serialNumber;
  final String? serviceDate;
  final String? message;
  final Map<String, dynamic>? record;

  SerialCheckResult({
    required this.success,
    required this.status,
    required this.isWithin60Days,
    this.repeatRisk = false,
    this.canCloseCall = true,
    this.daysAgo,
    required this.serialNumber,
    this.serviceDate,
    this.message,
    this.record,
  });

  factory SerialCheckResult.fromJson(Map<String, dynamic> json) {
    final within60 = json['isWithin60Days'] == true || json['repeatRisk'] == true;
    return SerialCheckResult(
      success: json['success'] ?? false,
      status: json['status']?.toString() ?? (within60 ? 'REPEAT RISK' : 'SAFE TO CLOSE'),
      isWithin60Days: within60,
      repeatRisk: json['repeatRisk'] ?? within60,
      canCloseCall: json['canCloseCall'] ?? !within60,
      daysAgo: json['daysAgo'] != null ? int.tryParse(json['daysAgo'].toString()) : null,
      serialNumber: json['serialNumber']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString(),
      message: json['message']?.toString(),
      record: json['record'] != null ? Map<String, dynamic>.from(json['record']) : null,
    );
  }

  /// When an SR No is found within 60 days, it is a repeat risk (RED, do not close call)
  bool get isRepeatRisk => isWithin60Days;

  /// When an SR No is beyond 60 days (or no prior record), it is safe to close (GREEN)
  bool get isSafeToClose => !isWithin60Days;
}
