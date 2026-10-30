import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/spare_part.dart';
import '../models/order.dart';

class SharedApiService {
  static final SharedApiService _instance = SharedApiService._internal();
  factory SharedApiService() => _instance;
  SharedApiService._internal();

  http.Client _client = http.Client();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Duration _timeout = const Duration(seconds: 15);
  final Duration _longTimeout = const Duration(seconds: 60);

  /// Closes and resets the HTTP client connection pool
  void resetClient() {
    _client.close();
    _client = http.Client();
  }

  Function()? onSessionExpired;

  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // In production release builds, default to live backend URL
    if (kReleaseMode) {
      return 'https://electrolyte-app-backend.onrender.com';
    }

    if (kIsWeb) return 'http://localhost:5001';

    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5001';
      if (Platform.isIOS) return 'http://localhost:5001';
    } catch (_) {}

    return 'http://localhost:5001';
  }

  Future<Map<String, String>> _getHeaders({Map<String, String>? extraHeaders}) async {
    final headers = <String, String>{};
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    try {
      // 1. Read token securely from Keychain / Keystore
      String? token = await _secureStorage.read(key: 'customer_token') ??
          await _secureStorage.read(key: 'admin_token');

      // 2. Fallback to legacy SharedPreferences if migrating
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('customer_token') ?? prefs.getString('admin_token');
      }

      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<http.Response> _get(String url, {Duration? timeout}) async {
    final headers = await _getHeaders();
    final response = await _client.get(Uri.parse(url), headers: headers).timeout(timeout ?? _timeout);
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }
    return response;
  }

  Future<http.Response> _post(String url, {Map<String, String>? headers, Object? body, Duration? timeout}) async {
    final mergedHeaders = await _getHeaders(extraHeaders: headers);
    final response = await _client.post(Uri.parse(url), headers: mergedHeaders, body: body).timeout(timeout ?? _timeout);
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }
    return response;
  }

  Future<http.Response> _delete(String url, {Map<String, String>? headers, Object? body, Duration? timeout}) async {
    final mergedHeaders = await _getHeaders(extraHeaders: headers);
    final response = await _client.delete(Uri.parse(url), headers: mergedHeaders, body: body).timeout(timeout ?? _timeout);
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }
    return response;
  }

  /// Secure Customer (Technician / Admin) Login
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': identifier.trim(), 'identifier': identifier.trim(), 'password': password}),
    ).timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      Map<String, dynamic> errorData = {};
      try {
        errorData = json.decode(response.body);
      } catch (_) {}
      throw Exception(errorData['error'] ?? 'Authentication failed');
    }
  }

  /// Request password reset verification email
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email.trim()}),
    ).timeout(_timeout);

    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to request password reset');
    }
  }

  /// Reset password using received code/token
  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'token': token.trim(), 'newPassword': newPassword}),
    ).timeout(_timeout);

    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to reset password');
    }
  }

  /// Change password for currently authenticated user
  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final response = await _post(
      '$baseUrl/api/auth/change-password',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to change password');
    }
  }

  Future<List<SparePart>> getAllParts() async {
    final response = await _get('$baseUrl/api/parts');
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load parts');
    }
  }

  Future<List<SparePart>> searchParts(String query) async {
    final uri = Uri.parse('$baseUrl/api/parts/search').replace(
      queryParameters: {'q': query},
    );
    final response = await _get(uri.toString());
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to search parts');
    }
  }

  Future<SparePart?> getPartByCode(String code) async {
    final response = await _get('$baseUrl/api/parts/$code');
    if (response.statusCode == 200) {
      return SparePart.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load part');
    }
  }

  Future<Map<String, dynamic>> createOrder(
    String partCode,
    int quantity,
  ) async {
    final response = await _post(
      '$baseUrl/api/orders',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'part_code': partCode, 'quantity': quantity}),
    );
    return json.decode(response.body);
  }

  Future<List<OrderModel>> getAllOrders() async {
    final response = await _get('$baseUrl/api/orders');
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => OrderModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load orders');
    }
  }

  Future<Map<String, dynamic>> getChatResponse(
    String message, {
    String? sessionId,
  }) async {
    try {
      final response = await _post(
        '$baseUrl/api/chat',
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': message, 'sessionId': sessionId}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Network error. Please check your connection.");
    }
  }

  Future<List<dynamic>> getChatSessions() async {
    final response = await _get('$baseUrl/api/chat/sessions');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  Future<List<dynamic>> getSessionMessages(String sessionId) async {
    final response = await _get('$baseUrl/api/chat/sessions/$sessionId/messages');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> payload,
  ) async {
    final response = await _post(
      '$baseUrl/api/invoice',
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
      timeout: _longTimeout, // 60-second timeout for PDF generation
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create invoice');
    }
  }

  Future<List<dynamic>> getInvoices() async {
    final response = await _get('$baseUrl/api/invoice');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['invoices'] ?? [];
    } else {
      throw Exception('Failed to load invoices');
    }
  }

  /// Check if a serial number has a service record within the last 60 days
  Future<Map<String, dynamic>> checkSerialNumber(String serialNumber, {Duration? timeout}) async {
    final clean = Uri.encodeComponent(serialNumber.trim());
    final stopwatch = Stopwatch()..start();
    final url = '$baseUrl/api/service-records/check/$clean';
    try {
      final response = await _get(url, timeout: timeout);
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[SharedApiService] GET /api/service-records/check/ -> ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        try {
          final err = json.decode(response.body);
          throw Exception(err['error'] ?? 'Failed to check serial number');
        } catch (e) {
          if (e is Exception && !e.toString().contains('FormatException')) {
            rethrow;
          }
          throw Exception('Server returned status ${response.statusCode}');
        }
      }
    } on TimeoutException {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[SharedApiService] GET /api/service-records/check/ timed out after ${stopwatch.elapsedMilliseconds}ms');
      }
      throw TimeoutException('Verification request timed out. Please check your network connection and retry.');
    } catch (e) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('[SharedApiService] GET /api/service-records/check/ failed in ${stopwatch.elapsedMilliseconds}ms: $e');
      }
      rethrow;
    }
  }

  /// Create technician credentials (Admin only)
  Future<Map<String, dynamic>> createTechnician(Map<String, dynamic> data) async {
    final response = await _post(
      '$baseUrl/api/admin/users',
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    final body = json.decode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return body;
    } else {
      throw Exception(body['error'] ?? 'Failed to create technician account');
    }
  }

  /// Fetch all users / technicians (Admin only)
  Future<List<dynamic>> getTechnicians() async {
    final response = await _get('$baseUrl/api/admin/users');
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load technicians list');
    }
  }

  /// Update / allow technician status (Admin only)
  Future<Map<String, dynamic>> updateUserStatus(int userId, bool isActive) async {
    final mergedHeaders = await _getHeaders(extraHeaders: {'Content-Type': 'application/json'});
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/admin/users/$userId/status'),
      headers: mergedHeaders,
      body: json.encode({'isActive': isActive}),
    ).timeout(_timeout);
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }
    final body = json.decode(response.body);
    if (response.statusCode == 200) {
      return body;
    } else {
      throw Exception(body['error'] ?? 'Failed to update user status');
    }
  }

  /// Preview next auto-generated Technician ID (Admin only)
  Future<String> getNextTechnicianId() async {
    try {
      final response = await _get('$baseUrl/api/admin/next-technician-id');
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['nextId'] ?? 'TECH-0001';
      }
    } catch (_) {}
    return 'TECH-0001';
  }

  /// Delete technician / user account by numeric ID or Technician ID (Admin only)
  Future<Map<String, dynamic>> deleteTechnician(dynamic idOrTechId) async {
    final cleanId = Uri.encodeComponent(idOrTechId.toString().trim());
    final response = await _delete('$baseUrl/api/admin/users/$cleanId');
    Map<String, dynamic> body = {};
    try {
      if (response.body.isNotEmpty) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      }
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final msg = body['error'] ?? 'Server error (${response.statusCode}): ${response.reasonPhrase ?? response.body}';
      throw Exception(msg);
    }
  }
}

