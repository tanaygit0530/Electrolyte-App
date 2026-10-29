import 'dart:async';
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
  bool _isProcessing = false;
  String? _errorMessage;
  SerialCheckResult? _result;
  String? _currentSerial;
  File? _selectedImage;

  SerialCheckProvider(this._apiService);

  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  SerialCheckResult? get result => _result;
  String? get currentSerial => _currentSerial;
  File? get selectedImage => _selectedImage;

  /// Clean raw scanned text to isolate the serial number
  static String extractCleanSerial(String raw) {
    String text = raw.trim();
    // If multiline, take the first non-empty line or line with serial marker
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    for (final line in lines) {
      if (RegExp(r'(?:sr\.?\s*no\.?|sl\.?\s*no\.?|serial(?:\s*no\.?)?|s\/n)', caseSensitive: false)
          .hasMatch(line)) {
        text = line;
        break;
      }
    }
    if (lines.isNotEmpty &&
        !RegExp(r'(?:sr\.?\s*no\.?|sl\.?\s*no\.?|serial(?:\s*no\.?)?|s\/n)', caseSensitive: false)
            .hasMatch(text)) {
      text = lines.first;
    }

    // Remove common prefixes like 'SrNo.', 'Sr.No.', 'SL No:', 'Serial No:', 'Serial:', 'S/N:', etc.
    text = text.replaceFirst(
      RegExp(
        r'^(?:sr\.?\s*no\.?|sl\.?\s*no\.?|serial(?:\s*no\.?)?|s\/n)[\s\.:\-_]*',
        caseSensitive: false,
      ),
      '',
    );
    // Remove trailing semicolons or spaces
    text = text.trim();
    return text.toUpperCase();
  }

  /// Verify serial number with backend API
  Future<void> checkSerial(String rawSerial) async {
    // Prevent overlapping image-processing operations and duplicate API requests
    if (_isLoading || _isProcessing) return;
    _isProcessing = true;

    final cleanSerial = extractCleanSerial(rawSerial);
    if (cleanSerial.isEmpty) {
      _isLoading = false;
      _isProcessing = false;
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
    } on TimeoutException {
      _errorMessage =
          'Verification timed out. Please check your network connection and retry.';
      _result = null;
    } on SocketException {
      _errorMessage =
          'Network connection error. Please verify your connection and retry.';
      _result = null;
    } catch (e) {
      final rawMsg = e.toString().replaceFirst('Exception: ', '').trim();
      if (rawMsg.contains('TimeoutException') || rawMsg.contains('timed out')) {
        _errorMessage =
            'Verification timed out. Please check your network connection and retry.';
      } else if (rawMsg.contains('SocketException') ||
          rawMsg.contains('Failed host lookup') ||
          rawMsg.contains('Network is unreachable') ||
          rawMsg.contains('Connection refused') ||
          rawMsg.contains('ClientException')) {
        _errorMessage =
            'Network connection error. Please verify your connection and retry.';
      } else {
        _errorMessage = rawMsg.isNotEmpty
            ? rawMsg
            : 'Failed to verify serial number. Please try again.';
      }
      _result = null;
    } finally {
      _isLoading = false;
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Retry verifying the last attempted serial number without requiring app restart
  Future<void> retry() async {
    if (_currentSerial != null && _currentSerial!.isNotEmpty) {
      await checkSerial(_currentSerial!);
    } else {
      reset();
    }
  }

  /// Manually set an error message (e.g. from camera detection timeout)
  void setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear the current error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Pick an image from gallery, scan for barcode/QR, and check serial
  Future<void> pickAndScanImage(MobileScannerController scannerController) async {
    if (_isLoading || _isProcessing) return;
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
      final BarcodeCapture? capture =
          await scannerController.analyzeImage(file.path);

      if (capture != null && capture.barcodes.isNotEmpty) {
        final rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null && rawValue.trim().isNotEmpty) {
          _isLoading = false;
          await checkSerial(rawValue);
          return;
        }
      }

      // If no barcode or QR was found in the image
      _isLoading = false;
      _errorMessage =
          'No barcode or QR code detected in the selected image. Please try another image or enter the serial number manually.';
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage =
          'Failed to analyze image: ${e.toString().replaceFirst('Exception: ', '')}';
      notifyListeners();
    }
  }

  /// Reset state
  void reset() {
    _isLoading = false;
    _isProcessing = false;
    _errorMessage = null;
    _result = null;
    _currentSerial = null;
    _selectedImage = null;
    notifyListeners();
  }
}
