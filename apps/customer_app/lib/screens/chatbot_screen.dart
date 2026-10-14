import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Start new chat',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () {
              context.read<ChatProvider>().startNewChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatProvider.messages.length,
              itemBuilder: (context, index) {
                final message = chatProvider.messages[index];
                return _ChatBubble(
                  message: message.text,
                  isUser: message.isUser,
                  isDark: isDark,
                  components: message.components,
                );
              },
            ),
          ),
          if (chatProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(),
            ),
          _buildInputArea(chatProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B263B) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: TextField(
                controller: _controller,
                enabled: !provider.isLoading,
                decoration: const InputDecoration(
                  hintText: "Search for spare parts",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: provider.isLoading
                    ? null
                    : (value) {
                        final text = value.trim();
                        if (text.isNotEmpty) {
                          provider.handleUserInput(text);
                          _controller.clear();
                          _scrollToBottom();
                        }
                      },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: provider.isLoading ? Colors.grey : const Color(0xFFFFC107),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: 'Send message',
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: provider.isLoading
                  ? null
                  : () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        provider.handleUserInput(text);
                        _controller.clear();
                        _scrollToBottom();
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isDark;
  final List<dynamic>? components;

  const _ChatBubble({
    required this.message,
    required this.isUser,
    required this.isDark,
    this.components,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isUser ? 'You said: $message' : 'Assistant replied: $message',
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? const Color(0xFFFFC107)
                  : (isDark ? const Color(0xFF1B263B) : const Color(0xFFEEEEEE)),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                bottomLeft: !isUser ? Radius.zero : const Radius.circular(20),
              ),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: isUser
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
          if (components != null && components!.any((comp) => (comp['stock_quantity'] ?? 0) > 0))
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                children: components!
                    .where((comp) => (comp['stock_quantity'] ?? 0) > 0)
                    .map<Widget>((comp) {
                  return Card(
                    color: isDark ? const Color(0xFF2B3A55) : Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  comp['part_name'] ?? 'Unknown Part',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: comp['status'] == 'Available' 
                                      ? Colors.green.withValues(alpha: 0.2) 
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  comp['status'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: comp['status'] == 'Available' 
                                        ? Colors.green 
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Code: ${comp['part_code'] ?? 'N/A'} | Model: ${comp['model'] ?? 'N/A'}",
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Qty: ${comp['stock_quantity']?.toString() ?? '0'} | Loc: ${comp['location'] ?? 'N/A'}",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFC107),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    ),
    );
  }
}
