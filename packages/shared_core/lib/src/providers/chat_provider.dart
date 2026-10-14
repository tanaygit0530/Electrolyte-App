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
  final SharedApiService _apiService;
  final List<ChatMessage> _messages = [];
  String? _currentSessionId;
  bool _isLoading = false;
  int _messageSeq = 0;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentSessionId => _currentSessionId;

  ChatProvider([SharedApiService? apiService])
      : _apiService = apiService ?? SharedApiService() {
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
    final trimmed = input.trim();
    if (trimmed.isEmpty || _isLoading) return;

    final seq = ++_messageSeq;
    _messages.add(ChatMessage(text: trimmed, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.getChatResponse(
        trimmed,
        sessionId: _currentSessionId,
      );
      if (seq != _messageSeq) return;

      final reply = response['reply'] as String;
      final newSessionId = response['sessionId'] as String?;
      final components = response['components'] as List<dynamic>?;

      if (_currentSessionId == null && newSessionId != null) {
        _currentSessionId = newSessionId;
      }

      _messages.add(ChatMessage(text: reply, isUser: false, components: components));
    } catch (e) {
      if (seq != _messageSeq) return;
      _messages.add(
        ChatMessage(
          text:
              "Sorry, I had trouble connecting to the server. Please try again.",
          isUser: false,
        ),
      );
    } finally {
      if (seq == _messageSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadSession(String sessionId) async {
    final seq = ++_messageSeq;
    _isLoading = true;
    _currentSessionId = sessionId;
    _messages.clear();
    notifyListeners();

    try {
      final data = await _apiService.getSessionMessages(sessionId);
      if (seq != _messageSeq) return;
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
      if (seq != _messageSeq) return;
      _messages.add(
        ChatMessage(text: "Failed to load chat history.", isUser: false),
      );
    } finally {
      if (seq == _messageSeq) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void startNewChat() {
    _messageSeq++;
    _isLoading = false;
    _currentSessionId = null;
    _messages.clear();
    _showGreeting();
    notifyListeners();
  }

  void clearChat() {
    _messageSeq++;
    _isLoading = false;
    _messages.clear();
    _showGreeting();
    notifyListeners();
  }
}
