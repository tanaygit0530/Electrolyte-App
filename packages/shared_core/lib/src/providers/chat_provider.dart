import 'package:flutter/material.dart';
import '../services/shared_api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<dynamic>? components;

  ChatMessage({
    required this.text, 
    required this.isUser, 
    DateTime? timestamp,
    this.components,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatProvider with ChangeNotifier {
  final SharedApiService _apiService = SharedApiService();
  final List<ChatMessage> _messages = [];
  String? _currentSessionId;
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentSessionId => _currentSessionId;

  ChatProvider() {
    _showGreeting();
  }

  void _showGreeting() {
    _messages.add(
      ChatMessage(
        text:
            "Hello! I'm your Spare Parts Assistant. How can I help you today?",
        isUser: false,
      ),
    );
  }

  Future<void> handleUserInput(String input) async {
    if (input.trim().isEmpty) return;

    _messages.add(ChatMessage(text: input, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getChatResponse(
        input,
        sessionId: _currentSessionId,
      );
      final reply = response['reply'] as String;
      final newSessionId = response['sessionId'] as String?;
      final components = response['components'] as List<dynamic>?;

      if (_currentSessionId == null && newSessionId != null) {
        _currentSessionId = newSessionId;
      }

      _messages.add(ChatMessage(text: reply, isUser: false, components: components));
    } catch (e) {
      _messages.add(
        ChatMessage(
          text:
              "Sorry, I had trouble connecting to the server. Please try again.",
          isUser: false,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSession(String sessionId) async {
    _isLoading = true;
    _currentSessionId = sessionId;
    _messages.clear();
    notifyListeners();

    try {
      final data = await _apiService.getSessionMessages(sessionId);
      for (var msg in data) {
        _messages.add(
          ChatMessage(
            text: msg['content'],
            isUser: msg['role'] == 'user',
            timestamp: DateTime.parse(msg['created_at']),
          ),
        );
      }
    } catch (e) {
      _messages.add(
        ChatMessage(text: "Failed to load chat history.", isUser: false),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void startNewChat() {
    _currentSessionId = null;
    _messages.clear();
    _showGreeting();
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _showGreeting();
    notifyListeners();
  }
}
