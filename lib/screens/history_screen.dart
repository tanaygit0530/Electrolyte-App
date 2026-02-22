import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../providers/chat_history_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/navigation_provider.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Centralized primary color to avoid hardcoded hex scattering.
  // Ideally, move this to your ThemeData.
  static const Color _primaryColor = Color(0xFFFFC107);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrders();
      context.read<ChatHistoryProvider>().fetchSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: const Text(
            'History',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
            ),
          ),
          bottom: const TabBar(
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: [
              Tab(
                child: Text(
                  "Orders",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              Tab(
                child: Text(
                  "Chats",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
            indicatorColor: _primaryColor,
            labelColor: _primaryColor,
            unselectedLabelColor: Colors.grey,
            splashFactory: NoSplash.splashFactory, // Cleaner tap interaction
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor.withOpacity(0.1),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _primaryColor),
                tooltip: 'Refresh History',
                onPressed: () {
                  context.read<OrderProvider>().fetchOrders();
                  context.read<ChatHistoryProvider>().fetchSessions();
                },
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildOrderHistory(),
            _buildChatHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistory() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const _LoadingState(message: "Fetching your orders...");
        }
        if (provider.orders.isEmpty) {
          return const _EmptyState(
            icon: Icons.shopping_bag_outlined,
            title: "No Orders Yet",
            subtitle: "When you place an order, it will appear here.",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: provider.orders.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = provider.orders[index];
            return _EnhancedHistoryCard(
              title: order.partName,
              subtitle: "Order ID: ${order.id.substring(0, 8).toUpperCase()}",
              date: DateFormat('dd MMM yyyy • hh:mm a').format(order.createdAt),
              status: order.status,
              icon: Icons.local_shipping_outlined,
              primaryColor: _primaryColor,
              onTap: () {
                // TODO: Implement Order Detail Navigation
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChatHistory() {
    return Consumer<ChatHistoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const _LoadingState(message: "Loading conversations...");
        }
        if (provider.sessions.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: "No Conversations",
            subtitle: "Start a chat to see your history here.",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: provider.sessions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final session = provider.sessions[index];
            return _EnhancedHistoryCard(
              title: session.title,
              subtitle: "Chat Session",
              date: DateFormat('dd MMM yyyy • hh:mm a').format(session.updatedAt),
              status: "View",
              icon: Icons.forum_outlined,
              primaryColor: _primaryColor,
              onTap: () async {
                final chatProvider = context.read<ChatProvider>();
                final navProvider = context.read<NavigationProvider>();
                await chatProvider.loadSession(session.id);
                navProvider.setIndex(0);
              },
            );
          },
        );
      },
    );
  }
}

/// A highly polished, modern card widget that replaces the generic ListTile.
class _EnhancedHistoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final String status;
  final IconData icon;
  final VoidCallback onTap;
  final Color primaryColor;

  const _EnhancedHistoryCard({
    required this.title,
    required this.subtitle,
    required this.date,
    required this.status,
    required this.icon,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            
            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status & Action Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A dedicated empty state widget that looks intentional.
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cleaner loading state rather than a floating raw spinner.
class _LoadingState extends StatelessWidget {
  final String message;

  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}