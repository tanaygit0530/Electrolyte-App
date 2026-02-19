import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/spare_part.dart';
import '../models/order.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS simulator or web
  // Use 10.0.2.2 for Android Emulator, localhost for iOS simulator or web
  static const String baseUrl = 'http://10.0.2.2:5001';

  Future<List<SparePart>> getAllParts() async {
    final response = await http.get(Uri.parse('$baseUrl/parts'));
    if (response.statusCode == 200) {
      List data = json.decode(response.body);
      return data.map((item) => SparePart.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load parts');
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
}
