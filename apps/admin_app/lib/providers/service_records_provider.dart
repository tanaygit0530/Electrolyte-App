import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/service_record_entry.dart';
import '../services/api_service.dart';

class ServiceRecordsProvider extends ChangeNotifier {
  final ApiService _apiService;

  String? _fileName;
  String? _filePath;
  int? _fileSizeBytes;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _statusText;
  String? _errorMessage;

  // Real-time background job polling state
  bool _isProcessingJob = false;
  int _processedRows = 0;
  int _liveFoundWithin60 = 0;
  int _liveOlderThan60 = 0;
  String? _stageText;

  ServiceUploadSummary? _summary;
  List<ServiceRecordEntry> _foundEntries = [];
  String _searchQuery = '';

  ServiceRecordsProvider(this._apiService);

  String? get fileName => _fileName;
  String? get filePath => _filePath;
  int? get fileSizeBytes => _fileSizeBytes;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get statusText => _statusText;
  String? get errorMessage => _errorMessage;

  bool get isProcessingJob => _isProcessingJob;
  int get processedRows => _processedRows;
  int get liveFoundWithin60 => _liveFoundWithin60;
  int get liveOlderThan60 => _liveOlderThan60;
  String? get stageText => _stageText;

  ServiceUploadSummary? get summary => _summary;
  List<ServiceRecordEntry> get foundEntries => _foundEntries;
  String get searchQuery => _searchQuery;

  List<ServiceRecordEntry> get filteredEntries {
    if (_searchQuery.trim().isEmpty) return _foundEntries;
    final q = _searchQuery.trim().toUpperCase();
    return _foundEntries.where((e) {
      return e.serialNumber.toUpperCase().contains(q) ||
          (e.customerName != null && e.customerName!.toUpperCase().contains(q)) ||
          (e.caseNumber != null && e.caseNumber!.toUpperCase().contains(q));
    }).toList();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  /// Pick an Excel (.xlsx, .xls) or CSV file
  Future<bool> pickServiceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (file.path != null) {
          _filePath = file.path;
          _fileName = file.name;
          _fileSizeBytes = file.size;
          _errorMessage = null;
          _summary = null;
          _foundEntries = [];
          _isProcessingJob = false;
          _processedRows = 0;
          _liveFoundWithin60 = 0;
          _liveOlderThan60 = 0;
          _stageText = null;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to pick file: $e';
      notifyListeners();
      return false;
    }
  }

  /// Upload file and execute 60-day service audit with real-time progress polling
  Future<bool> uploadAndAudit() async {
    if (_filePath == null || _fileName == null) {
      _errorMessage = 'Please select a file first.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _isProcessingJob = false;
    _processedRows = 0;
    _liveFoundWithin60 = 0;
    _liveOlderThan60 = 0;
    _stageText = null;
    _uploadProgress = 0.0;
    _statusText = 'Uploading $_fileName...';
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.uploadServiceFile(
        _filePath!,
        _fileName!,
        (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            if (_uploadProgress >= 1.0) {
              _statusText = 'File uploaded 100%. Starting background audit...';
            } else {
              _statusText = 'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%';
            }
            notifyListeners();
          }
        },
      );

      final jobId = response['jobId'] as String?;
      if (jobId != null && jobId.isNotEmpty) {
        // Asynchronous Job Flow: Poll status with real-time counters
        _isProcessingJob = true;
        _stageText = 'Initializing audit on cloud server...';
        notifyListeners();

        bool isDone = false;
        while (!isDone) {
          await Future.delayed(const Duration(milliseconds: 1200));
          final statusRes = await _apiService.getServiceJobStatus(jobId);
          final job = statusRes['job'] as Map<String, dynamic>? ?? {};

          final status = job['status'] as String? ?? 'processing';
          _stageText = job['stage'] as String? ?? 'Auditing service records...';
          _processedRows = (job['processedRows'] as num?)?.toInt() ?? _processedRows;
          _liveFoundWithin60 = (job['foundWithin60Days'] as num?)?.toInt() ?? _liveFoundWithin60;
          _liveOlderThan60 = (job['olderThan60Days'] as num?)?.toInt() ?? _liveOlderThan60;
          notifyListeners();

          if (status == 'completed') {
            isDone = true;
            final summaryMap = job['summary'] as Map<String, dynamic>?;
            if (summaryMap != null) {
              _summary = ServiceUploadSummary.fromJson(summaryMap);
            }
            final entriesList = job['foundEntries'] as List<dynamic>?;
            if (entriesList != null) {
              _foundEntries = entriesList.map((e) => ServiceRecordEntry.fromJson(e as Map<String, dynamic>)).toList();
            } else {
              _foundEntries = [];
            }
          } else if (status == 'failed') {
            isDone = true;
            final err = job['error'] as String? ?? 'Service audit failed on cloud server.';
            throw Exception(err);
          }
        }
      } else {
        // Fallback for legacy direct response
        final summaryMap = response['summary'] as Map<String, dynamic>?;
        if (summaryMap != null) {
          _summary = ServiceUploadSummary.fromJson(summaryMap);
        }
        final entriesList = response['foundEntries'] as List<dynamic>?;
        if (entriesList != null) {
          _foundEntries = entriesList.map((e) => ServiceRecordEntry.fromJson(e as Map<String, dynamic>)).toList();
        } else {
          _foundEntries = [];
        }
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isUploading = false;
      _isProcessingJob = false;
      _statusText = null;
      notifyListeners();
    }
  }

  /// Export found entries as CSV
  Future<String?> exportCsv() async {
    try {
      final response = await _apiService.exportFoundServiceRecordsCsv();
      final bytes = response.data;
      if (bytes == null) return null;

      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/Found_Serials_60_Days_$timestamp.csv');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      _errorMessage = 'Failed to export CSV: $e';
      notifyListeners();
      return null;
    }
  }

  /// Reset provider state
  void reset() {
    _fileName = null;
    _filePath = null;
    _fileSizeBytes = null;
    _isUploading = false;
    _uploadProgress = 0.0;
    _statusText = null;
    _errorMessage = null;
    _summary = null;
    _foundEntries = [];
    _searchQuery = '';
    notifyListeners();
  }
}
