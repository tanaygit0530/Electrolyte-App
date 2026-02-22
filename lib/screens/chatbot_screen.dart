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
  static const Color _primaryColor = Color(0xFFFFC107);

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), 
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invexa Assistant',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
                ),
                Text(
                  'Online',
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_rounded),
            tooltip: 'New Chat',
            onPressed: () {
              chatProvider.startNewChat();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'report') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted.')),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'report',
                child: Text('Report Issue'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                // Add 1 to itemCount if loading to show the typing indicator at the bottom
                itemCount: chatProvider.messages.length + (chatProvider.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  // If we are at the end of the list and currently loading, show the indicator
                  if (index == chatProvider.messages.length && chatProvider.isLoading) {
                    return _buildTypingIndicator(isDark);
                  }
                  
                  final message = chatProvider.messages[index];
                  return _ChatBubble(
                    message: message.text,
                    isUser: message.isUser,
                    isDark: isDark,
                  );
                },
              ),
            ),
            _buildInputArea(chatProvider, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B263B) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.zero,
          ),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey)),
            ),
            const SizedBox(width: 12),
            Text("Invexa is typing...", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: "Ask about spare parts...",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    provider.handleUserInput(value.trim());
                    _controller.clear();
                    _scrollToBottom();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 2), // Aligns icon center with a single-line text input
            decoration: const BoxDecoration(
              color: _primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.black87), // High contrast icon
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  provider.handleUserInput(_controller.text.trim());
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

  const _ChatBubble({
    required this.message,
    required this.isUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isUser 
        ? const Color(0xFFFFC107) 
        : (isDark ? const Color(0xFF1B263B) : Colors.white);
        
    // Enforcing High Contrast: If background is Amber, text MUST be dark.
    final textColor = isUser 
        ? Colors.black87 
        : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 16,
          left: isUser ? 64 : 0,
          right: isUser ? 0 : 64,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
          border: isUser ? null : Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: isUser ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          message,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.4, // Improves readability for longer AI responses
          ),
        ),
      ),
    );
  }
}