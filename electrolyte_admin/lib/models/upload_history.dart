class UploadHistory {
  final int id;
  final String fileName;
  final String uploadedBy;
  final int totalRows;
  final int updatedRows;
  final int failedRows;
  final DateTime uploadedAt;
  final String type; // 'stock' or 'price'

  UploadHistory({
    required this.id,
    required this.fileName,
    required this.uploadedBy,
    required this.totalRows,
    required this.updatedRows,
    required this.failedRows,
    required this.uploadedAt,
    required this.type,
  });

  factory UploadHistory.fromJson(Map<String, dynamic> json, String type) {
    return UploadHistory(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      fileName: json['file_name'] ?? '',
      uploadedBy: json['uploaded_by'] ?? '',
      totalRows: json['total_rows'] is int 
          ? json['total_rows'] 
          : int.parse(json['total_rows'].toString()),
      updatedRows: json['updated_rows'] is int 
          ? json['updated_rows'] 
          : int.parse(json['updated_rows'].toString()),
      failedRows: json['failed_rows'] is int 
          ? json['failed_rows'] 
          : int.parse(json['failed_rows'].toString()),
      uploadedAt: json['uploaded_at'] != null 
          ? DateTime.parse(json['uploaded_at']).toLocal() 
          : DateTime.now(),
      type: type,
    );
  }
}
