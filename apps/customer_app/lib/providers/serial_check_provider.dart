import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_core/shared_core.dart';
import '../models/serial_check_result.dart';

class SerialCheckProvider extends ChangeNotifier {
  final SharedApiService _apiService;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  String? _errorMessage;
  SerialCheckResult? _result;
  String? _currentSerial;
  File? _selectedImage;

  SerialCheckProvider(this._apiService);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SerialCheckResult? get result => _result;
  String? get currentSerial => _currentSerial;
  File? get selectedImage => _selectedImage;

  /// Clean raw scanned text to isolate the serial number
  static String extractCleanSerial(String raw) {
    String text = raw.trim();
    // If multiline, take the first non-empty line or line with serial marker
    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (final line in lines) {
      if (RegExp(r'(?:sr\.?\s*no\.?|sl\.?\s*no\.?|serial)', caseSensitive: false).hasMatch(line)) {
        text = line;
        break;
      }
    }
    if (lines.isNotEmpty && !RegExp(r'(?:sr\.?\s*no\.?|sl\.?\s*no\.?|serial)', caseSensitive: false).hasMatch(text)) {
      text = lines.first;
    }

    // Remove common prefixes like 'SrNo.', 'Sr.No.', 'SL No:', 'Serial No:', etc.
    text = text.replaceFirst(RegExp(r'^(?:sr\.?\s*no\.?|sl\.?\s*no\.?|serial\s*no\.?|s\/n)[\s\.:\-_]*', caseSensitive: false), '');
    // Remove trailing semicolons or spaces
    text = text.trim();
    return text.toUpperCase();
  }

  /// Verify serial number with backend API
  Future<void> checkSerial(String rawSerial) async {
    final cleanSerial = extractCleanSerial(rawSerial);
    if (cleanSerial.isEmpty) {
      _errorMessage = 'Please enter or scan a valid serial number.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _currentSerial = cleanSerial;
    notifyListeners();

    try {
      final json = await _apiService.checkSerialNumber(cleanSerial);
      _result = SerialCheckResult.fromJson(json);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _result = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pick an image from gallery, scan for barcode/QR, and check serial
  Future<void> pickAndScanImage(MobileScannerController scannerController) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (file == null) return;

      _selectedImage = File(file.path);
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Analyze image with mobile_scanner
      final BarcodeCapture? capture = await scannerController.analyzeImage(file.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        final rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.trim().isNotEmpty) {
          await checkSerial(rawValue);
          return;
        }
      }

      // If no barcode or QR was found in the image
      _isLoading = false;
      _errorMessage = 'No barcode or QR code detected in the selected image. Please try another image or enter the serial number manually.';
      notifyListeners();

    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to analyze image: ${e.toString().replaceFirst('Exception: ', '')}';
      notifyListeners();
    }
  }

  /// Reset state
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _result = null;
    _currentSerial = null;
    _selectedImage = null;
    notifyListeners();
  }
}
