import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';

class AdminChatbotScreen extends StatefulWidget {
  const AdminChatbotScreen({super.key});

  @override
  State<AdminChatbotScreen> createState() => _AdminChatbotScreenState();
}

class _AdminChatbotScreenState extends State<AdminChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatHistoryProvider>().fetchSessions();
    });
  }

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
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final historyProvider = context.watch<ChatHistoryProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        children: [
          // Left Side: Chat History Sessions Panel
          Container(
            width: 320,
            decoration: const BoxDecoration(
              color: AdminTheme.sidebarBg,
              border: Border(
                right: BorderSide(color: AdminTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Sessions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_comment_rounded, color: AdminTheme.primaryYellow, size: 20),
                        tooltip: 'Start New Chat',
                        onPressed: () {
                          chatProvider.startNewChat();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Started a new conversation session.', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
                              backgroundColor: AdminTheme.primaryYellow,
                              behavior: SnackBarBehavior.floating,
                              width: 280,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1, color: AdminTheme.borderColor),
                
                // Session List
                Expanded(
                  child: historyProvider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AdminTheme.primaryYellow))
                      : historyProvider.sessions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  'No previous chat history found.',
                                  style: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.6), fontSize: 13, fontFamily: 'Poppins'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              itemCount: historyProvider.sessions.length,
                              itemBuilder: (context, index) {
                                final session = historyProvider.sessions[index];
                                final isCurrent = chatProvider.currentSessionId == session.id;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: () async {
                                      await chatProvider.loadSession(session.id);
                                      _scrollToBottom();
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isCurrent ? AdminTheme.darkSurface : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isCurrent ? AdminTheme.primaryYellow.withOpacity(0.3) : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.chat_bubble_outline_rounded,
                                                size: 14,
                                                color: isCurrent ? AdminTheme.primaryYellow : AdminTheme.textSecondary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  session.title,
                                                  style: TextStyle(
                                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                                    color: isCurrent ? Colors.white : AdminTheme.textSecondary,
                                                    fontSize: 13,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              DateFormat('dd MMM yyyy, hh:mm a').format(session.updatedAt.toLocal()),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AdminTheme.textSecondary.withOpacity(0.5),
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),

          // Right Side: Active Chat Stream Panel
          Expanded(
            child: Container(
              color: AdminTheme.darkBackground,
              child: Column(
                children: [
                  // Active Chat Thread
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      itemCount: chatProvider.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatProvider.messages[index];
                        return _buildChatBubble(message);
                      },
                    ),
                  ),

                  // Loading State Indicator
                  if (chatProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 40),
                      child: LinearProgressIndicator(color: AdminTheme.primaryYellow, backgroundColor: AdminTheme.darkSurface),
                    ),

                  // Input Box Deck
                  _buildInputArea(chatProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isBot = !message.isUser;
    
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.5,
            ),
            decoration: BoxDecoration(
              color: isBot ? AdminTheme.darkSurface : AdminTheme.primaryYellow,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: isBot ? Radius.zero : const Radius.circular(16),
                bottomRight: !isBot ? Radius.zero : const Radius.circular(16),
              ),
              border: Border.all(
                color: isBot ? AdminTheme.borderColor : AdminTheme.primaryYellow,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: isBot ? Colors.white : AdminTheme.darkBackground,
                fontSize: 14,
                fontFamily: 'Poppins',
                height: 1.4,
                fontWeight: isBot ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          
          // Display Component cards if returned by AI spare parts bot (e.g. details cards for product specs)
          if (isBot && message.components != null && message.components!.isNotEmpty)
            _buildSparePartComponentList(message.components!),
        ],
      ),
    );
  }

  Widget _buildSparePartComponentList(List<dynamic> components) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 12),
      width: MediaQuery.of(context).size.width * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: components.map((comp) {
          final isAvailable = comp['status'] == 'Available';
          final statusColor = isAvailable ? AdminTheme.accentEmerald : AdminTheme.errorColor;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AdminTheme.glassBox(radius: 12, opacity: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          comp['part_name'] ?? 'Unknown Part Name',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          comp['status'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Part Code: ${comp['part_code'] ?? 'N/A'} | Model Compatibility: ${comp['model'] ?? 'N/A'}",
                    style: TextStyle(
                      fontSize: 12,
                      color: AdminTheme.textSecondary.withOpacity(0.7),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Rate: ₹${comp['price']?.toString() ?? '0.00'}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.primaryYellow,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (isAvailable)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryYellow,
                            foregroundColor: AdminTheme.darkBackground,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Exporting order specification is coming soon.', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
                                backgroundColor: AdminTheme.primaryYellow,
                                behavior: SnackBarBehavior.floating,
                                width: 340,
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_cart_rounded, size: 14),
                          label: const Text('Export Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea(ChatProvider provider) {
    return Container(
      padding: const EdgeInsets.only(left: 40, right: 40, bottom: 36, top: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.secondaryBg.withOpacity(0.6),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AdminTheme.borderColor),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search spare parts or ask product compatibility queries...",
                  hintStyle: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.5), fontFamily: 'Poppins'),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    provider.handleUserInput(value);
                    _controller.clear();
                    _scrollToBottom();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 52,
            width: 52,
            decoration: const BoxDecoration(
              color: AdminTheme.primaryYellow,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: AdminTheme.darkBackground),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  provider.handleUserInput(_controller.text);
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
