import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/sidebar.dart';
import 'dashboard_screen.dart';
import 'stock_upload_screen.dart';
import 'price_upload_screen.dart';
import 'upload_history_screen.dart';
import '../utils/theme.dart';

class MainWorkspace extends StatefulWidget {
  const MainWorkspace({super.key});

  @override
  State<MainWorkspace> createState() => _MainWorkspaceState();
}

class _MainWorkspaceState extends State<MainWorkspace> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // Session Expiration Handler dialog
    if (auth.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        auth.resetSessionExpiredFlag();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AdminTheme.darkSurface,
            title: const Row(
              children: [
                Icon(Icons.lock_clock_outlined, color: AdminTheme.errorColor, size: 28),
                SizedBox(width: 12),
                Text('Session Expired'),
              ],
            ),
            content: const Text(
              'Your administrative security token has expired or is no longer valid. For your protection, you have been automatically logged out. Please log in again to restore access.',
              style: TextStyle(height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Return to Login', style: TextStyle(color: AdminTheme.accentTeal, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      });
    }

    // Navigated screens mapping
    final List<Widget> screens = [
      DashboardScreen(onNavigate: (idx) {
        setState(() {
          _selectedIndex = idx;
        });
      }),
      const StockUploadScreen(),
      const PriceUploadScreen(),
      const UploadHistoryScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar on the left
          AdminSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _selectedIndex = idx;
              });
            },
          ),
          
          // Expanded workspace contents on the right
          Expanded(
            child: Container(
              color: AdminTheme.darkBackground,
              child: Stack(
                children: [
                  // Slate ambient visual backgrounds
                  Positioned(
                    top: -150,
                    right: -150,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AdminTheme.accentTeal.withOpacity(0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Indexed screens mapping
                  screens[_selectedIndex],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
