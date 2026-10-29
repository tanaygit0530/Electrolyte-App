class SerialCheckResult {
  final bool success;
  final String status;
  final bool isWithin60Days;
  final bool repeatRisk;
  final bool canCloseCall;
  final int? daysAgo;
  final String serialNumber;
  final String? serviceDate;
  final String? lastServiceDate;
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
    this.lastServiceDate,
    this.message,
    this.record,
  });

  factory SerialCheckResult.fromJson(Map<String, dynamic> json) {
    final within60 = json['isWithin60Days'] == true || json['repeatRisk'] == true;
    final statusStr = json['status']?.toString() ?? (within60 ? 'REPEAT RISK' : 'SAFE TO CLOSE');
    final canClose = json['canCloseCall'] ?? (!within60 && statusStr != 'REVIEW NEEDED');
    final svcDate = json['lastServiceDate']?.toString() ?? json['serviceDate']?.toString();

    return SerialCheckResult(
      success: json['success'] ?? false,
      status: statusStr,
      isWithin60Days: within60,
      repeatRisk: json['repeatRisk'] ?? within60,
      canCloseCall: canClose,
      daysAgo: json['daysAgo'] != null ? int.tryParse(json['daysAgo'].toString()) : null,
      serialNumber: json['serialNumber']?.toString() ?? '',
      serviceDate: svcDate,
      lastServiceDate: svcDate,
      message: json['message']?.toString(),
      record: json['record'] != null ? Map<String, dynamic>.from(json['record']) : null,
    );
  }

  /// When previous service date is invalid or in the future
  bool get isReviewNeeded => status == 'REVIEW NEEDED' || (!isWithin60Days && !canCloseCall);

  /// When an SR No is found within 60 days, it is a repeat risk (RED, do not close call)
  bool get isRepeatRisk => isWithin60Days || repeatRisk;

  /// When an SR No is beyond 60 days (or no prior record), it is safe to close (GREEN)
  bool get isSafeToClose => !isRepeatRisk && !isReviewNeeded && canCloseCall;
}

