class ServiceRecordEntry {
  final String serialNumber;
  final String date;
  final int daysAgo;
  final String? caseNumber;
  final String? customerName;
  final String? complaint;
  final String? repair;
  final String? status;

  ServiceRecordEntry({
    required this.serialNumber,
    required this.date,
    required this.daysAgo,
    this.caseNumber,
    this.customerName,
    this.complaint,
    this.repair,
    this.status,
  });

  factory ServiceRecordEntry.fromJson(Map<String, dynamic> json) {
    return ServiceRecordEntry(
      serialNumber: json['serialNumber']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      daysAgo: int.tryParse(json['daysAgo']?.toString() ?? '0') ?? 0,
      caseNumber: json['caseNumber']?.toString(),
      customerName: json['customerName']?.toString(),
      complaint: json['complaint']?.toString(),
      repair: json['repair']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class ServiceUploadSummary {
  final int totalRecords;
  final int foundWithin60Days;
  final int olderThan60Days;

  ServiceUploadSummary({
    required this.totalRecords,
    required this.foundWithin60Days,
    required this.olderThan60Days,
  });

  factory ServiceUploadSummary.fromJson(Map<String, dynamic> json) {
    return ServiceUploadSummary(
      totalRecords: int.tryParse(json['totalRecords']?.toString() ?? '0') ?? 0,
      foundWithin60Days: int.tryParse(json['foundWithin60Days']?.toString() ?? '0') ?? 0,
      olderThan60Days: int.tryParse(json['olderThan60Days']?.toString() ?? '0') ?? 0,
    );
  }
}
