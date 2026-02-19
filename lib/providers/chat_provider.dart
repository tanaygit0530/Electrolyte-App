import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  ChatProvider() {
    _messages.add(
      ChatMessage(
        text:
            "Hello! I'm your AI Spare Parts Assistant. How can I help you today?",
        isUser: false,
      ),
    );
  }

  Future<void> handleUserInput(String input) async {
    if (input.trim().isEmpty) return;

    // Add user message
    _messages.add(ChatMessage(text: input, isUser: true));
    _isLoading = true;
    notifyListeners();

    try {
      // Get AI response from backend
      final reply = await _apiService.getChatResponse(input);

      // Add bot message
      _messages.add(ChatMessage(text: reply, isUser: false));
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

  void clearChat() {
    _messages.clear();
    _messages.add(
      ChatMessage(text: "Chat cleared. How can I help you now?", isUser: false),
    );
    notifyListeners();
  }
}
