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

  /// Defensive parser to safely handle both pre-parsed Maps and raw JSON Strings
  Map<String, dynamic> _parseMapResponse(dynamic data) {
    if (data == null) return {};
    if (data is String) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } on FormatException {
        final trimmed = data.trim();
        if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html') || trimmed.startsWith('<body')) {
          throw const FormatException('Server returned an HTML error response instead of JSON. Check the backend server console logs for details.');
        }
        rethrow;
      }
    }
    return Map<String, dynamic>.from(data);
  }

  /// Defensive parser to safely handle both pre-parsed Lists and raw JSON Strings
  List<dynamic> _parseListResponse(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      try {
        return json.decode(data) as List<dynamic>;
      } on FormatException {
        final trimmed = data.trim();
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
}
