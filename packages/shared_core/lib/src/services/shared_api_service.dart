import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spare_part.dart';
import '../models/order.dart';

class SharedApiService {
  static final SharedApiService _instance = SharedApiService._internal();
  factory SharedApiService() => _instance;
  SharedApiService._internal();

  final http.Client _client = http.Client();
  final Duration _timeout = const Duration(seconds: 15);

  Function()? onSessionExpired;

  static String get baseUrl {
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('customer_token') ?? prefs.getString('admin_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers;
  }

  Future<http.Response> _get(String url) async {
    final headers = await _getHeaders();
    final response = await _client.get(Uri.parse(url), headers: headers).timeout(_timeout);
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }
    return response;
  }

  Future<http.Response> _post(String url, {Map<String, String>? headers, Object? body}) async {
    final mergedHeaders = await _getHeaders(extraHeaders: headers);
    final response = await _client.post(Uri.parse(url), headers: mergedHeaders, body: body).timeout(_timeout);
    if (response.statusCode == 401) {
      onSessionExpired?.call();
    }
    return response;
  }

  /// Secure Customer (Technician) Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
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

  Future<List<SparePart>> getAllParts() async {
    final response = await _get('$baseUrl/parts');
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load parts');
    }
  }

  Future<List<SparePart>> searchParts(String query) async {
    final response = await _get('$baseUrl/parts/search?q=$query');
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to search parts');
    }
  }

  Future<SparePart?> getPartByCode(String code) async {
    final response = await _get('$baseUrl/parts/$code');
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
      '$baseUrl/order',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'part_code': partCode, 'quantity': quantity}),
    );
    return json.decode(response.body);
  }

  Future<List<OrderModel>> getAllOrders() async {
    final response = await _get('$baseUrl/orders');
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
        '$baseUrl/chat',
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
    final response = await _get('$baseUrl/chat/sessions');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  Future<List<dynamic>> getSessionMessages(String sessionId) async {
    final response = await _get('$baseUrl/chat/sessions/$sessionId/messages');
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
      '$baseUrl/invoice',
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create invoice');
    }
  }

  Future<List<dynamic>> getInvoices() async {
    final response = await _get('$baseUrl/invoice');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['invoices'] ?? [];
    } else {
      throw Exception('Failed to load invoices');
    }
  }
}
