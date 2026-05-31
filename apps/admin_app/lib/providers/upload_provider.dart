import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/validators.dart';

class UploadErrorReport {
  final int rowNumber;
  final String productCode;
  final String errorMessage;

  UploadErrorReport({
    required this.rowNumber,
    required this.productCode,
    required this.errorMessage,
  });
}

class PreviewRow {
  final int rowNumber;
  final String productCode;
  final dynamic originalValue; // Stock quantity or price
  final String parsedValueDisplay;
  final bool isValid;
  final String? errorMessage;

  PreviewRow({
    required this.rowNumber,
    required this.productCode,
    required this.originalValue,
    required this.parsedValueDisplay,
    required this.isValid,
    this.errorMessage,
  });
}

class CellValueHolder {
  final dynamic value;
  CellValueHolder(this.value);
}

class UploadProvider extends ChangeNotifier {
  final ApiService _apiService;

  String? _fileName;
  String? _filePath;
  bool _isParsing = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  List<PreviewRow> _previewRows = [];
  List<Map<String, dynamic>> _validRowsPayload = [];
  List<UploadErrorReport> _failedRowsReport = [];
  Map<String, dynamic>? _uploadSummary;

  UploadProvider(this._apiService);

  String? get fileName => _fileName;
  String? get filePath => _filePath;
  bool get isParsing => _isParsing;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;

  List<PreviewRow> get previewRows => _previewRows;
  List<Map<String, dynamic>> get validRowsPayload => _validRowsPayload;
  List<UploadErrorReport> get failedRowsReport => _failedRowsReport;
  Map<String, dynamic>? get uploadSummary => _uploadSummary;

  /// Clear all parser states
  void resetState() {
    _fileName = null;
    _filePath = null;
    _isParsing = false;
    _isUploading = false;
    _uploadProgress = 0.0;
    _errorMessage = null;
    _previewRows = [];
    _validRowsPayload = [];
    _failedRowsReport = [];
    _uploadSummary = null;
    notifyListeners();
  }

  /// Selects an Excel or CSV file from the local desktop environment
  Future<bool> pickExcelFile() async {
    resetState();
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        _fileName = result.files.single.name;
        _filePath = result.files.single.path;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Error picking file: $e';
      notifyListeners();
    }
    return false;
  }

  List<List<String>> _parseCsvString(String csvContent) {
    final List<List<String>> result = [];
    final RegExp lineRegex = RegExp(r'\r?\n');
    final List<String> lines = csvContent.split(lineRegex);
    
    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      
      final List<String> row = [];
      final StringBuffer cell = StringBuffer();
      bool inQuotes = false;
      
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(cell.toString().trim());
          cell.clear();
        } else {
          cell.write(char);
        }
      }
      row.add(cell.toString().trim());
      result.add(row);
    }
    return result;
  }

  /// Parses the DAILY STOCK SHEET:
  /// Extracts Product Code (fallback index 4) + Quantity On Hand (fallback index 6)
  /// Supports Excel and CSV formats.
  Future<void> parseStockSheet() async {
    if (_filePath == null) return;
    
    _isParsing = true;
    _previewRows = [];
    _validRowsPayload = [];
    _failedRowsReport = [];
    _errorMessage = null;
    notifyListeners();

    try {
      final file = File(_filePath!);
      final isCsv = _fileName?.toLowerCase().endsWith('.csv') ?? false;
      final List<List<CellValueHolder>> rowsData = [];

      if (isCsv) {
        String csvContent;
        try {
          csvContent = await file.readAsString(encoding: utf8);
        } catch (_) {
          csvContent = await file.readAsString(encoding: latin1);
        }
        final parsed = _parseCsvString(csvContent);
        for (var csvRow in parsed) {
          rowsData.add(csvRow.map((cell) => CellValueHolder(cell)).toList());
        }
      } else {
        final bytes = file.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        if (excel.tables.isEmpty) {
          throw Exception('Selected Excel workbook contains no tables/sheets.');
        }

        final sheetName = excel.tables.keys.first;
        final table = excel.tables[sheetName]!;

        if (table.maxRows <= 1) {
          throw Exception('The sheet "$sheetName" is empty.');
        }

        for (var r in table.rows) {
          rowsData.add(r.map((cell) => CellValueHolder(cell?.value)).toList());
        }
      }

      // 1. Detect headers or use fallback indices
      int codeColIndex = 4; // Fallback
      int qtyColIndex = 6;  // Fallback
      
      final firstRow = rowsData[0];
      for (int i = 0; i < firstRow.length; i++) {
        final cellVal = firstRow[i].value?.toString().toLowerCase().trim() ?? '';
        if (cellVal.contains('product code') || cellVal == 'code' || cellVal == 'product_code') {
          codeColIndex = i;
        } else if (cellVal.contains('quantity on hand') || cellVal == 'qty' || cellVal == 'quantity' || cellVal.contains('quantityonhand')) {
          qtyColIndex = i;
        }
      }

      // Set to track duplicate product codes in this spreadsheet
      final Set<String> processedCodes = {};

      // 2. Parse data rows starting from row index 1 (skipping header)
      for (int r = 1; r < rowsData.length; r++) {
        final row = rowsData[r];
        if (row.isEmpty) continue;

        // Skip completely empty rows
        final bool isRowEmpty = row.every((cell) => cell.value == null || cell.value.toString().trim().isEmpty);
        if (isRowEmpty) continue;

        final rawCode = row.length > codeColIndex ? row[codeColIndex].value : null;
        final rawQty = row.length > qtyColIndex ? row[qtyColIndex].value : null;

        final codeErr = ExcelValidators.validateProductCode(rawCode);
        final code = rawCode?.toString().trim() ?? '';

        if (codeErr != null) {
          final errReport = UploadErrorReport(
            rowNumber: r + 1,
            productCode: code.isEmpty ? 'N/A' : code,
            errorMessage: codeErr,
          );
          _failedRowsReport.add(errReport);
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code.isEmpty ? 'N/A' : code,
            originalValue: rawQty ?? '',
            parsedValueDisplay: 'ERROR',
            isValid: false,
            errorMessage: codeErr,
          ));
          continue;
        }

        // Duplicate code validation
        if (processedCodes.contains(code)) {
          const dupErr = 'Duplicate product code found in spreadsheet';
          _failedRowsReport.add(UploadErrorReport(
            rowNumber: r + 1,
            productCode: code,
            errorMessage: dupErr,
          ));
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code,
            originalValue: rawQty ?? '',
            parsedValueDisplay: 'ERROR',
            isValid: false,
            errorMessage: dupErr,
          ));
          continue;
        }

        final qtyParseResult = ExcelValidators.validateAndParseStock(rawQty);
        
        if (qtyParseResult.containsKey('error')) {
          final err = qtyParseResult['error']!;
          _failedRowsReport.add(UploadErrorReport(
            rowNumber: r + 1,
            productCode: code,
            errorMessage: err,
          ));
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code,
            originalValue: rawQty ?? '',
            parsedValueDisplay: 'ERROR',
            isValid: false,
            errorMessage: err,
          ));
        } else {
          final parsedQty = qtyParseResult['value'] as int;
          processedCodes.add(code);
          _validRowsPayload.add({
            'productCode': code,
            'stockQuantity': parsedQty,
          });
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code,
            originalValue: rawQty ?? '',
            parsedValueDisplay: parsedQty.toString(),
            isValid: true,
          ));
        }
      }
    } catch (e) {
      _errorMessage = 'Sheet parsing failed: $e';
    } finally {
      _isParsing = false;
      notifyListeners();
    }
  }

  /// Parses the PRICE UPDATE SHEET:
  /// Extracts Product Code (fallback index 1) + Customer Price (fallback index 3)
  /// Ignores ASP prices, removes currency symbols, converts to double decimal.
  /// Supports Excel and CSV formats.
  Future<void> parsePriceSheet() async {
    if (_filePath == null) return;

    _isParsing = true;
    _previewRows = [];
    _validRowsPayload = [];
    _failedRowsReport = [];
    _errorMessage = null;
    notifyListeners();

    try {
      final file = File(_filePath!);
      final isCsv = _fileName?.toLowerCase().endsWith('.csv') ?? false;
      final List<List<CellValueHolder>> rowsData = [];

      if (isCsv) {
        String csvContent;
        try {
          csvContent = await file.readAsString(encoding: utf8);
        } catch (_) {
          csvContent = await file.readAsString(encoding: latin1);
        }
        final parsed = _parseCsvString(csvContent);
        for (var csvRow in parsed) {
          rowsData.add(csvRow.map((cell) => CellValueHolder(cell)).toList());
        }
      } else {
        final bytes = file.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        if (excel.tables.isEmpty) {
          throw Exception('Selected Excel workbook contains no tables/sheets.');
        }

        final sheetName = excel.tables.keys.first;
        final table = excel.tables[sheetName]!;

        if (table.maxRows <= 1) {
          throw Exception('The sheet "$sheetName" is empty.');
        }

        for (var r in table.rows) {
          rowsData.add(r.map((cell) => CellValueHolder(cell?.value)).toList());
        }
      }

      // 1. Detect headers or use fallback indices
      int codeColIndex = 1;  // Fallback
      int priceColIndex = 3; // Fallback

      final firstRow = rowsData[0];
      for (int i = 0; i < firstRow.length; i++) {
        final cellVal = firstRow[i].value?.toString().toLowerCase().trim() ?? '';
        if (cellVal.contains('product code') || cellVal == 'code' || cellVal == 'product_code') {
          codeColIndex = i;
        } else if (cellVal.contains('customer price') || cellVal == 'price' || cellVal == 'customer_price' || cellVal == 'asp price') {
          // If the header specifically is Customer Price
          if (cellVal.contains('customer price') || cellVal == 'price') {
            priceColIndex = i;
          }
        }
      }

      final Set<String> processedCodes = {};

      // 2. Parse data rows skipping header row
      for (int r = 1; r < rowsData.length; r++) {
        final row = rowsData[r];
        if (row.isEmpty) continue;

        // Skip completely empty rows
        final bool isRowEmpty = row.every((cell) => cell.value == null || cell.value.toString().trim().isEmpty);
        if (isRowEmpty) continue;

        final rawCode = row.length > codeColIndex ? row[codeColIndex].value : null;
        final rawPrice = row.length > priceColIndex ? row[priceColIndex].value : null;

        final codeErr = ExcelValidators.validateProductCode(rawCode);
        final code = rawCode?.toString().trim() ?? '';

        if (codeErr != null) {
          _failedRowsReport.add(UploadErrorReport(
            rowNumber: r + 1,
            productCode: code.isEmpty ? 'N/A' : code,
            errorMessage: codeErr,
          ));
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code.isEmpty ? 'N/A' : code,
            originalValue: rawPrice ?? '',
            parsedValueDisplay: 'ERROR',
            isValid: false,
            errorMessage: codeErr,
          ));
          continue;
        }

        // Duplicate code validation
        if (processedCodes.contains(code)) {
          const dupErr = 'Duplicate product code found in spreadsheet';
          _failedRowsReport.add(UploadErrorReport(
            rowNumber: r + 1,
            productCode: code,
            errorMessage: dupErr,
          ));
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code,
            originalValue: rawPrice ?? '',
            parsedValueDisplay: 'ERROR',
            isValid: false,
            errorMessage: dupErr,
          ));
          continue;
        }

        final priceParseResult = ExcelValidators.validateAndParsePrice(rawPrice);

        if (priceParseResult.containsKey('error')) {
          final err = priceParseResult['error']!;
          _failedRowsReport.add(UploadErrorReport(
            rowNumber: r + 1,
            productCode: code,
            errorMessage: err,
          ));
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code,
            originalValue: rawPrice ?? '',
            parsedValueDisplay: 'ERROR',
            isValid: false,
            errorMessage: err,
          ));
        } else {
          final parsedPrice = priceParseResult['value'] as double;
          processedCodes.add(code);
          _validRowsPayload.add({
            'productCode': code,
            'productPrice': parsedPrice,
          });
          _previewRows.add(PreviewRow(
            rowNumber: r + 1,
            productCode: code,
            originalValue: rawPrice ?? '',
            parsedValueDisplay: 'INR ${parsedPrice.toStringAsFixed(2)}',
            isValid: true,
          ));
        }
      }
    } catch (e) {
      _errorMessage = 'Sheet parsing failed: $e';
    } finally {
      _isParsing = false;
      notifyListeners();
    }
  }

  /// Sends valid daily stock JSON rows to backend
  Future<bool> submitStockUpdates() async {
    if (_validRowsPayload.isEmpty || _fileName == null) {
      _errorMessage = 'No valid rows parsed to upload.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.uploadStock(
        _fileName!,
        _validRowsPayload,
        (sent, total) {
          _uploadProgress = sent / total;
          notifyListeners();
        },
      );
      
      _uploadSummary = result['summary'];
      
      // Update errors returned by backend (e.g. database code not found failures)
      if (_uploadSummary != null && _uploadSummary!['errors'] != null) {
        final List serverErrs = _uploadSummary!['errors'];
        for (var err in serverErrs) {
          final String sCode = err['productCode'] ?? '';
          final String sMsg = err['error'] ?? 'Database error';
          
          _failedRowsReport.add(UploadErrorReport(
            rowNumber: 0, // Server reports do not have row numbers
            productCode: sCode,
            errorMessage: sMsg,
          ));

          // Mark corresponding row in preview rows as invalid
          for (int i = 0; i < _previewRows.length; i++) {
            if (_previewRows[i].productCode == sCode) {
              _previewRows[i] = PreviewRow(
                rowNumber: _previewRows[i].rowNumber,
                productCode: _previewRows[i].productCode,
                originalValue: _previewRows[i].originalValue,
                parsedValueDisplay: 'FAILED',
                isValid: false,
                errorMessage: sMsg,
              );
            }
          }
        }
      }

      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sends valid price updates JSON rows to backend
  Future<bool> submitPriceUpdates() async {
    if (_validRowsPayload.isEmpty || _fileName == null) {
      _errorMessage = 'No valid rows parsed to upload.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _uploadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _apiService.uploadPrice(
        _fileName!,
        _validRowsPayload,
        (sent, total) {
          _uploadProgress = sent / total;
          notifyListeners();
        },
      );

      _uploadSummary = result['summary'];

      // Process database error lines from server response
      if (_uploadSummary != null && _uploadSummary!['errors'] != null) {
        final List serverErrs = _uploadSummary!['errors'];
        for (var err in serverErrs) {
          final String sCode = err['productCode'] ?? '';
          final String sMsg = err['error'] ?? 'Database error';

          _failedRowsReport.add(UploadErrorReport(
            rowNumber: 0,
            productCode: sCode,
            errorMessage: sMsg,
          ));

          for (int i = 0; i < _previewRows.length; i++) {
            if (_previewRows[i].productCode == sCode) {
              _previewRows[i] = PreviewRow(
                rowNumber: _previewRows[i].rowNumber,
                productCode: _previewRows[i].productCode,
                originalValue: _previewRows[i].originalValue,
                parsedValueDisplay: 'FAILED',
                isValid: false,
                errorMessage: sMsg,
              );
            }
          }
        }
      }

      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  /// Generates and exports failed rows as a CSV file to the admin's machine
  Future<bool> exportFailedRowsCsv() async {
    if (_failedRowsReport.isEmpty) return false;

    try {
      // 1. Build CSV string
      final buffer = StringBuffer();
      buffer.writeln('Row,Product Code,Error Details');
      for (var report in _failedRowsReport) {
        final rowStr = report.rowNumber > 0 ? report.rowNumber.toString() : 'Server';
        // Clean CSV escape
        final cleanedErr = report.errorMessage.replaceAll('"', '""');
        buffer.writeln('$rowStr,${report.productCode},"$cleanedErr"');
      }

      // 2. Select save path on Desktop
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Failed Rows CSV Log',
        fileName: '${_fileName?.replaceAll('.xlsx', '').replaceAll('.xls', '').replaceAll('.csv', '')}_failed_report.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsString(buffer.toString());
        return true;
      }
    } catch (e) {
      _errorMessage = 'Failed to export CSV: $e';
      notifyListeners();
    }
    return false;
  }
}
