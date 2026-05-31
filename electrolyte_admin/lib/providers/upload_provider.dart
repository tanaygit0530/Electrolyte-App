import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
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

  /// Selects an Excel file from the local desktop environment
  Future<bool> pickExcelFile() async {
    resetState();
    
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
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

  /// Parses the DAILY STOCK SHEET:
  /// Extracts Product Code (fallback index 4) + Quantity On Hand (fallback index 6)
  /// Ignores prices.
  Future<void> parseStockSheet() async {
    if (_filePath == null) return;
    
    _isParsing = true;
    _previewRows = [];
    _validRowsPayload = [];
    _failedRowsReport = [];
    _errorMessage = null;
    notifyListeners();

    String activeSheetName = 'Unknown';
    int activeRowNumber = -1;

    try {
      final file = File(_filePath!);
      var bytes = file.readAsBytesSync();
      bytes = _preprocessXlsxBytes(bytes);
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception('Selected Excel workbook contains no tables/sheets.');
      }

      final sheetName = excel.tables.keys.first;
      activeSheetName = sheetName;
      final table = excel.tables[sheetName];
      if (table == null) {
        throw Exception('Could not read table data for sheet "$sheetName".');
      }

      final rows = table.rows;
      if (rows.isEmpty) {
        throw Exception('The sheet "$sheetName" contains no rows.');
      }

      final firstRow = rows[0];
      if (firstRow == null || firstRow.isEmpty) {
        throw Exception('Could not read header row in sheet "$sheetName".');
      }

      // 1. Detect headers or use fallback indices
      int codeColIndex = 4; // Fallback
      int qtyColIndex = 6;  // Fallback
      
      for (int i = 0; i < firstRow.length; i++) {
        final cell = firstRow[i];
        if (cell == null || cell.value == null) continue;
        final cellVal = cell.value.toString().toLowerCase().trim();
        if (cellVal.contains('product code') || cellVal == 'code' || cellVal == 'product_code') {
          codeColIndex = i;
        } else if (cellVal.contains('quantity on hand') || cellVal == 'qty' || cellVal == 'quantity' || cellVal.contains('quantityonhand')) {
          qtyColIndex = i;
        }
      }

      // Set to track duplicate product codes in this spreadsheet
      final Set<String> processedCodes = {};

      // 2. Parse data rows starting from row index 1 (skipping header)
      for (int r = 1; r < table.maxRows; r++) {
        activeRowNumber = r + 1;
        if (r >= rows.length) break;
        final row = rows[r];
        if (row == null || row.isEmpty) continue;

        // Skip completely empty rows
        final bool isRowEmpty = row.every((cell) {
          if (cell == null || cell.value == null) return true;
          return cell.value.toString().trim().isEmpty;
        });
        if (isRowEmpty) continue;

        final rawCode = row.length > codeColIndex ? row[codeColIndex]?.value : null;
        final rawQty = row.length > qtyColIndex ? row[qtyColIndex]?.value : null;

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
          final err = qtyParseResult['error']?.toString() ?? 'Invalid quantity format';
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
    } catch (e, stack) {
      print('=== EXCEL PARSING ERROR ===');
      print(e);
      print(stack);
      print('===========================');
      
      String parsedDetails = 'Sheet: $activeSheetName';
      if (activeRowNumber > 0) {
        parsedDetails += ', Row: $activeRowNumber';
      }
      
      try {
        final logFile = File('/Users/tanaypatil/Electrolyte-App/parsing_error.log');
        logFile.writeAsStringSync('Error: $e\nParsed Details: $parsedDetails\n\nStack Trace:\n$stack');
      } catch (_) {}
      
      if (e.toString().contains('Null check operator') && stack.toString().contains('_parseTable')) {
        _errorMessage = 'Excel decoding failed: Workbook relation resolution issue.\n\n'
            'The excel parser failed to load the sheet file "$activeSheetName" due to path mismatches in the workbook relations.\n\n'
            'We attempted in-memory ZIP target path normalization, but the structure is corrupted. Please try re-saving this file as a standard Excel (.xlsx) workbook using MS Excel or Google Sheets to normalize the file structure.';
      } else if (e.toString().contains('Null check operator')) {
        _errorMessage = 'Excel parsing failed: Null value encountered at $parsedDetails.\n\n'
            'The Excel sheet contains missing or null cell values in a required column. Please review row $activeRowNumber and ensure all columns (Product Code and Stock Quantity) have valid data.';
      } else {
        _errorMessage = 'Excel parsing failed at $parsedDetails: $e';
      }
    } finally {
      _isParsing = false;
      notifyListeners();
    }
  }

  /// Parses the PRICE UPDATE SHEET:
  /// Extracts Product Code (fallback index 1) + Customer Price (fallback index 3)
  /// Ignores ASP prices, removes currency symbols, converts to double decimal.
  Future<void> parsePriceSheet() async {
    if (_filePath == null) return;

    _isParsing = true;
    _previewRows = [];
    _validRowsPayload = [];
    _failedRowsReport = [];
    _errorMessage = null;
    notifyListeners();

    String activeSheetName = 'Unknown';
    int activeRowNumber = -1;

    try {
      final file = File(_filePath!);
      var bytes = file.readAsBytesSync();
      bytes = _preprocessXlsxBytes(bytes);
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception('Selected Excel workbook contains no tables/sheets.');
      }

      final sheetName = excel.tables.keys.first;
      activeSheetName = sheetName;
      final table = excel.tables[sheetName];
      if (table == null) {
        throw Exception('Could not read table data for sheet "$sheetName".');
      }

      final rows = table.rows;
      if (rows.isEmpty) {
        throw Exception('The sheet "$sheetName" contains no rows.');
      }

      final firstRow = rows[0];
      if (firstRow == null || firstRow.isEmpty) {
        throw Exception('Could not read header row in sheet "$sheetName".');
      }

      // 1. Detect headers or use fallback indices
      int codeColIndex = 1;  // Fallback
      int priceColIndex = 3; // Fallback

      for (int i = 0; i < firstRow.length; i++) {
        final cell = firstRow[i];
        if (cell == null || cell.value == null) continue;
        final cellVal = cell.value.toString().toLowerCase().trim();
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
      for (int r = 1; r < table.maxRows; r++) {
        activeRowNumber = r + 1;
        if (r >= rows.length) break;
        final row = rows[r];
        if (row == null || row.isEmpty) continue;

        // Skip completely empty rows
        final bool isRowEmpty = row.every((cell) {
          if (cell == null || cell.value == null) return true;
          return cell.value.toString().trim().isEmpty;
        });
        if (isRowEmpty) continue;

        final rawCode = row.length > codeColIndex ? row[codeColIndex]?.value : null;
        final rawPrice = row.length > priceColIndex ? row[priceColIndex]?.value : null;

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
          final err = priceParseResult['error']?.toString() ?? 'Invalid price format';
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
    } catch (e, stack) {
      print('=== EXCEL PARSING ERROR ===');
      print(e);
      print(stack);
      print('===========================');
      
      String parsedDetails = 'Sheet: $activeSheetName';
      if (activeRowNumber > 0) {
        parsedDetails += ', Row: $activeRowNumber';
      }
      
      try {
        final logFile = File('/Users/tanaypatil/Electrolyte-App/parsing_error.log');
        logFile.writeAsStringSync('Error: $e\nParsed Details: $parsedDetails\n\nStack Trace:\n$stack');
      } catch (_) {}
      
      if (e.toString().contains('Null check operator') && stack.toString().contains('_parseTable')) {
        _errorMessage = 'Excel decoding failed: Workbook relation resolution issue.\n\n'
            'The excel parser failed to load the sheet file "$activeSheetName" due to path mismatches in the workbook relations.\n\n'
            'We attempted in-memory ZIP target path normalization, but the structure is corrupted. Please try re-saving this file as a standard Excel (.xlsx) workbook using MS Excel or Google Sheets to normalize the file structure.';
      } else if (e.toString().contains('Null check operator')) {
        _errorMessage = 'Excel parsing failed: Null value encountered at $parsedDetails.\n\n'
            'The Excel sheet contains missing or null cell values in a required column. Please review row $activeRowNumber and ensure all columns (Product Code and Price) have valid data.';
      } else {
        _errorMessage = 'Excel parsing failed at $parsedDetails: $e';
      }
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
        fileName: '${_fileName?.replaceAll('.xlsx', '').replaceAll('.xls', '')}_failed_report.csv',
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

  /// Programmatically strips out Excel "<tableParts>" and structural formatting
  /// elements from the XLSX worksheet XML files. This completely bypasses the
  /// known internal bug in the `excel` library's parser, enabling users to upload
  /// zebra-striped or formatted Excel files without experiencing null pointer crashes.
  Uint8List _preprocessXlsxBytes(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final List<ArchiveFile> filesToReplace = [];
      bool modified = false;

      for (final file in archive) {
        if (file.isFile &&
            file.name.startsWith('xl/worksheets/sheet') &&
            file.name.endsWith('.xml')) {
          final rawContent = file.content as List<int>;
          final content = utf8.decode(rawContent, allowMalformed: true);

          if (content.contains('<tableParts')) {
            final updatedContent = content.replaceAll(
              RegExp(r'<tableParts[^>]*>([\s\S]*?)<\/tableParts>|<tableParts[^>]*\/>'),
              '',
            );
            final sanitizedBytes = utf8.encode(updatedContent);
            final newFile = ArchiveFile(
              file.name,
              sanitizedBytes.length,
              sanitizedBytes,
            );
            
            // Retain original metadata
            newFile.mode = file.mode;
            newFile.lastModTime = file.lastModTime;
            newFile.compress = file.compress;
            
            filesToReplace.add(newFile);
            modified = true;
          }
        }
      }

      if (modified) {
        for (final newFile in filesToReplace) {
          archive.addFile(newFile);
        }
        
        final encoded = ZipEncoder().encode(archive);
        if (encoded != null) {
          return Uint8List.fromList(encoded);
        }
      }
    } catch (e) {
      print('=== XLSX PREPROCESSING FAILED ===: $e');
    }
    return bytes;
  }
}
