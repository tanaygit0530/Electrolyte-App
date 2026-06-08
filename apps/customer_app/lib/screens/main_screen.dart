import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import '../providers/order_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
import 'chatbot_screen.dart';
import 'history_screen.dart';
import 'billing_screen.dart';
import 'profile_screen.dart';
import 'alerts_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().fetchOrders();
    });
  }

  final List<Widget> _screens = [
    const ChatbotScreen(),
    const HistoryScreen(),
    const BillingScreen(),
    const ProfileScreen(),
    const AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();
    final auth = context.watch<AuthProvider>();

    if (auth.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        auth.resetSessionExpiredFlag();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Session Expired'),
              ],
            ),
            content: const Text(
              'Your security token has expired or is no longer valid. For your protection, you have been logged out automatically. Please log in again to restore access.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Return to Login', style: TextStyle(color: AppTheme.primaryYellow, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      });
    }

    return Scaffold(
      body: IndexedStack(index: navProvider.selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navProvider.selectedIndex,
        onTap: (index) => navProvider.setIndex(index),

        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFFC107),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Bill',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
