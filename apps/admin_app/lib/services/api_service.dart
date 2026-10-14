import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/upload_history.dart';

class ApiService {
  final Dio _dio = Dio();
  static const String _defaultUrl = 'http://localhost:5001';
  
  Function()? onSessionExpired;

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    
    // Setup interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('admin_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            if (onSessionExpired != null) {
              onSessionExpired!();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return _defaultUrl;
  }

  static String get wsUrl {
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    } else {
      return base.replaceFirst('http://', 'ws://');
    }
  }

  /// Defensive parser to safely handle both pre-parsed Maps and raw JSON Strings
  Map<String, dynamic> _parseMapResponse(dynamic data) {
    if (data == null) return {};
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return {};
      try {
        return json.decode(trimmed) as Map<String, dynamic>;
      } on FormatException {
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html') || trimmed.startsWith('<body')) {
          throw const FormatException('Server returned an HTML error response instead of JSON. Check the backend server console logs for details.');
        }
        rethrow;
      }
    }
    if (data is List<int>) {
      try {
        final decodedString = utf8.decode(data);
        if (decodedString.trim().isEmpty) return {};
        return json.decode(decodedString) as Map<String, dynamic>;
      } catch (_) {
        return {'error': 'Binary data received instead of JSON.'};
      }
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// Defensive parser to safely handle both pre-parsed Lists and raw JSON Strings
  List<dynamic> _parseListResponse(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return [];
      try {
        return json.decode(trimmed) as List<dynamic>;
      } on FormatException {
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html') || trimmed.startsWith('<body')) {
          throw const FormatException('Server returned an HTML error response instead of JSON. Check the backend server console logs for details.');
        }
        rethrow;
      }
    }
    return data as List<dynamic>;
  }

  /// Secure Admin Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/admin/login',
        data: {'email': email, 'password': password},
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Network/Server connection error';
      throw Exception(msg);
    }
  }

  /// Fetch Dashboard metrics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get('$baseUrl/api/admin/dashboard');
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to load dashboard statistics';
      throw Exception(msg);
    }
  }

  /// Bulk Stock Quantity Upload
  Future<Map<String, dynamic>> uploadStock(
    String fileName, 
    List<Map<String, dynamic>> rows,
    void Function(int sent, int total)? onProgress,
  ) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/admin/upload-stock',
        data: {
          'fileName': fileName,
          'rows': rows,
        },
        onSendProgress: onProgress,
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      print('=== DIO EXCEPTION DETECTED (STOCK UPLOAD) ===');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Response Status: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      print('=============================================');
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Stock upload transaction failed';
      throw Exception(msg);
    }
  }

  /// Bulk Price Upload
  Future<Map<String, dynamic>> uploadPrice(
    String fileName, 
    List<Map<String, dynamic>> rows,
    void Function(int sent, int total)? onProgress,
  ) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/admin/upload-price',
        data: {
          'fileName': fileName,
          'rows': rows,
        },
        onSendProgress: onProgress,
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      print('=== DIO EXCEPTION DETECTED (PRICE UPLOAD) ===');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Response Status: ${e.response?.statusCode}');
      print('Response Data: ${e.response?.data}');
      print('=============================================');
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Price update transaction failed';
      throw Exception(msg);
    }
  }

  /// Fetch Daily Stock Upload Logs
  Future<List<UploadHistory>> getStockHistory() async {
    try {
      final response = await _dio.get('$baseUrl/api/admin/stock-history');
      final list = _parseListResponse(response.data);
      return list.map((item) => UploadHistory.fromJson(item, 'stock')).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to retrieve stock logs';
      throw Exception(msg);
    }
  }

  /// Fetch Price Upload Logs
  Future<List<UploadHistory>> getPriceHistory() async {
    try {
      final response = await _dio.get('$baseUrl/api/admin/price-history');
      final list = _parseListResponse(response.data);
      return list.map((item) => UploadHistory.fromJson(item, 'price')).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to retrieve price logs';
      throw Exception(msg);
    }
  }

  /// Fetch all users
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await _dio.get('$baseUrl/api/admin/users');
      final list = _parseListResponse(response.data);
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to retrieve users list';
      throw Exception(msg);
    }
  }

  /// Create a new user
  Future<Map<String, dynamic>> createUser(String email, String password, String role) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/admin/users',
        data: {'email': email, 'password': password, 'role': role},
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to create user';
      throw Exception(msg);
    }
  }

  /// Get Technician Revenue Report
  Future<Map<String, dynamic>> getTechnicianRevenueReport(Map<String, dynamic> queryParams) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/admin/reports/technician-revenue',
        queryParameters: queryParams,
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to load technician revenue report';
      throw Exception(msg);
    }
  }

  /// Export Report to Excel
  Future<Response> exportExcelReport(Map<String, dynamic> queryParams) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/admin/reports/export-excel',
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.bytes),
      );
      return response;
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to export Excel report';
      throw Exception(msg);
    }
  }

  /// Upload Bulk Service Data File (.xlsx / .csv) and audit 60-day window
  Future<Map<String, dynamic>> uploadServiceFile(
    String filePath,
    String fileName,
    void Function(int sent, int total)? onProgress,
  ) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '$baseUrl/api/service-records/upload',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 15),
          receiveTimeout: const Duration(minutes: 15),
        ),
        onSendProgress: onProgress,
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final isTimeout = e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout;
      final msg = parsed['error'] ??
          (isTimeout
              ? 'The server took longer than expected to finish processing this large dataset. The background ingestion may still be running in the cloud database. Please verify your internet connection or check the Upload History.'
              : statusCode == 502
                  ? 'Server Error (502 Bad Gateway): The server ran out of memory or restarted while processing the file. Please deploy the streaming update to Render or upload a smaller file.'
                  : statusCode == 504
                      ? 'Server Error (504 Gateway Timeout): The upload took too long to complete.'
                      : 'Service records upload failed: ${e.message}');
      throw Exception(msg);
    }
  }

  /// Poll Background Service Data Ingestion Job Status
  Future<Map<String, dynamic>> getServiceJobStatus(String jobId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/service-records/job-status/$jobId',
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to check background audit status: ${e.message}';
      throw Exception(msg);
    }
  }

  /// Get Found Service Entries currently within 60 days
  Future<Map<String, dynamic>> getFoundServiceEntries({int limit = 100, int offset = 0, String? search}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/service-records/found-entries',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return _parseMapResponse(response.data);
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to load found service entries';
      throw Exception(msg);
    }
  }

  /// Export Found Service Entries to CSV
  Future<Response> exportFoundServiceRecordsCsv() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/service-records/export-found',
        options: Options(responseType: ResponseType.bytes),
      );
      return response;
    } on DioException catch (e) {
      final data = e.response?.data;
      final parsed = data != null ? _parseMapResponse(data) : {};
      final msg = parsed['error'] ?? 'Failed to export found records CSV';
      throw Exception(msg);
    }
  }
}
