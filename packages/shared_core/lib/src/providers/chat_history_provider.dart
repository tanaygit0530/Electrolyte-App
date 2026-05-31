import 'package:flutter/material.dart';
import '../services/shared_api_service.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;

  ChatSession({required this.id, required this.title, required this.updatedAt});

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'] ?? 'New Chat',
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class ChatHistoryProvider with ChangeNotifier {
  final SharedApiService _apiService = SharedApiService();
  List<ChatSession> _sessions = [];
  bool _isLoading = false;

  List<ChatSession> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> fetchSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getChatSessions();
      _sessions = data.map((item) => ChatSession.fromJson(item)).toList();
    } catch (e) {
      _sessions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
