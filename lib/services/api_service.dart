import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/spare_part.dart';
import '../models/order.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static String get baseUrl {
    // 1. Allow overriding via command line (e.g., flutter run --dart-define=API_URL=http://192.168.1.5:5001)
    const String envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;

    // 2. Automatically detect Emulator / Simulator / Web
    if (kIsWeb) return 'http://localhost:5001';
    
    try {
      if (Platform.isAndroid) return 'http://192.168.1.36:5001'; // Default for Android Emulator 192.168.1.36
      if (Platform.isIOS) return 'http://localhost:5001';     // Default for iOS Simulator
    } catch (e) {
      // Fallback if Platform check fails
    }
    
    return 'http://localhost:5001';
  }

  Future<List<SparePart>> getAllParts() async {
    final response = await http.get(Uri.parse('$baseUrl/parts'));
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load parts');
    }
  }

  Future<List<SparePart>> searchParts(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/parts/search?q=$query'));
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to search parts');
    }
  }

  Future<SparePart?> getPartByCode(String code) async {
    final response = await http.get(Uri.parse('$baseUrl/parts/$code'));
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
    final response = await http.post(
      Uri.parse('$baseUrl/order'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'part_code': partCode, 'quantity': quantity}),
    );
    return json.decode(response.body);
  }

  Future<List<OrderModel>> getAllOrders() async {
    final response = await http.get(Uri.parse('$baseUrl/orders'));
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
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
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
    final response = await http.get(Uri.parse('$baseUrl/chat/sessions'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  Future<List<dynamic>> getSessionMessages(String sessionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/sessions/$sessionId/messages'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse('$baseUrl/invoice'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create invoice');
    }
  }
}
