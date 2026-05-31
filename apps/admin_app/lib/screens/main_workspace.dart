import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_core/shared_core.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/sidebar.dart';
import 'dashboard_screen.dart';
import 'stock_upload_screen.dart';
import 'price_upload_screen.dart';
import 'upload_history_screen.dart';
import 'admin_chatbot_screen.dart';
import 'admin_billing_screen.dart';
import '../utils/theme.dart';

class MainWorkspace extends StatefulWidget {
  const MainWorkspace({super.key});

  @override
  State<MainWorkspace> createState() => _MainWorkspaceState();
}

class _MainWorkspaceState extends State<MainWorkspace> {
  int _selectedIndex = 0;

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'System Telemetry Dashboard';
      case 1:
        return 'Daily Stock Import';
      case 2:
        return 'Price Catalogue Update';
      case 3:
        return 'Historical Upload Logs';
      case 4:
        return 'Chatbot AI Assistant';
      case 5:
        return 'Invoice Generator';
      default:
        return 'Admin Control Panel';
    }
  }

  void _triggerRefresh(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);
    final upload = Provider.of<UploadProvider>(context, listen: false);

    switch (_selectedIndex) {
      case 0:
        dashboard.refreshDashboard();
        break;
      case 1:
      case 2:
        upload.resetState();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Module reset and cleared successfully!', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
            backgroundColor: AdminTheme.primaryYellow,
            behavior: SnackBarBehavior.floating,
            width: 320,
          ),
        );
        break;
      case 3:
        dashboard.fetchHistories();
        break;
      case 4:
        Provider.of<ChatHistoryProvider>(context, listen: false).fetchSessions();
        Provider.of<ChatProvider>(context, listen: false).startNewChat();
        break;
    }
  }

  bool _isPageLoading(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);
    final upload = Provider.of<UploadProvider>(context);

    switch (_selectedIndex) {
      case 0:
        return dashboard.isLoading;
      case 1:
      case 2:
        return upload.isParsing || upload.isUploading;
      case 3:
        return dashboard.isLoading;
      case 4:
        return Provider.of<ChatHistoryProvider>(context).isLoading || Provider.of<ChatProvider>(context).isLoading;
      default:
        return false;
    }
  }

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
                child: const Text('Return to Login', style: TextStyle(color: AdminTheme.primaryYellow, fontWeight: FontWeight.bold)),
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
      const AdminChatbotScreen(),
      const AdminBillingScreen(),
    ];

    final bool isLoading = _isPageLoading(context);

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
              child: Column(
                children: [
                  // Sleek glassmorphic Top App Bar with bottom border
                  Container(
                    height: 84,
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: const BoxDecoration(
                      color: AdminTheme.sidebarBg,
                      border: Border(
                        bottom: BorderSide(
                          color: AdminTheme.borderColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Screen Page Title
                        Text(
                          _getPageTitle(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            letterSpacing: -0.5,
                          ),
                        ),
                        
                        // Right: Actions Deck (Refresh, Profile, Avatar, Logout)
                        Row(
                          children: [
                            // Refresh/Action button with glow hover
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.darkSurface,
                                foregroundColor: AdminTheme.primaryYellow,
                                side: BorderSide(color: AdminTheme.primaryYellow.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _triggerRefresh(context),
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AdminTheme.primaryYellow,
                                      ),
                                    )
                                  : Icon(
                                      (_selectedIndex == 1 || _selectedIndex == 2)
                                          ? Icons.cleaning_services_rounded
                                          : Icons.refresh_rounded,
                                      size: 16,
                                    ),
                              label: Text(
                                (_selectedIndex == 1 || _selectedIndex == 2)
                                    ? 'Reset Screen'
                                    : 'Refresh Panel',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Poppins'),
                              ),
                            ),
                            const SizedBox(width: 24),
                            
                            // Separator
                            Container(
                              height: 24,
                              width: 1,
                              color: AdminTheme.borderColor,
                            ),
                            const SizedBox(width: 24),

                            // Admin Profile Data
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Administrator',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                Text(
                                  auth.adminEmail ?? 'admin@electrolyte.com',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AdminTheme.textSecondary.withOpacity(0.8),
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),

                            // Avatar with glowing yellow border
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AdminTheme.primaryYellow, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AdminTheme.primaryYellow.withOpacity(0.15),
                                    blurRadius: 6,
                                  )
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 18,
                                backgroundColor: AdminTheme.darkSurface,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: AdminTheme.primaryYellow,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Logout session icon button
                            IconButton(
                              icon: const Icon(Icons.power_settings_new_rounded),
                              color: AdminTheme.errorColor,
                              iconSize: 22,
                              tooltip: 'Logout Session',
                              onPressed: () {
                                auth.logout();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Active screen contents
                  Expanded(
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
                                  AdminTheme.primaryYellow.withOpacity(0.02),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Screen mapping
                        screens[_selectedIndex],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
