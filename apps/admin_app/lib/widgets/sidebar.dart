import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AdminTheme.sidebarBg,
        border: Border(
          right: BorderSide(
            color: AdminTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Premium Branding / Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                // Bolt Logo with glow
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.primaryYellow.withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AdminTheme.primaryYellow.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: AdminTheme.primaryYellow,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Electrolyte',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Inventory Management',
                        style: TextStyle(
                          fontSize: 10,
                          color: AdminTheme.textSecondary.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: AdminTheme.borderColor, height: 1),
          ),
          const SizedBox(height: 24),

          // Menu Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  title: 'Daily Stock Upload',
                  isSelected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.payments_outlined,
                  activeIcon: Icons.payments,
                  title: 'Price Update Upload',
                  isSelected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  title: 'Upload Logs History',
                  isSelected: selectedIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  title: 'Chatbot',
                  isSelected: selectedIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  title: 'Invoice',
                  isSelected: selectedIndex == 5,
                  onTap: () => onDestinationSelected(5),
                ),
                const SizedBox(height: 10),
                _SidebarItem(
                  icon: Icons.manage_accounts_outlined,
                  activeIcon: Icons.manage_accounts,
                  title: 'User Management',
                  isSelected: selectedIndex == 6,
                  onTap: () => onDestinationSelected(6),
                ),
              ],
            ),
          ),

          // Bottom Account profile footer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AdminTheme.darkBackground.withOpacity(0.3),
              border: const Border(
                top: BorderSide(
                  color: AdminTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AdminTheme.darkSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AdminTheme.primaryYellow.withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: AdminTheme.primaryYellow,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: AdminTheme.textSecondary,
                              fontFamily: 'Poppins',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminTheme.errorColor,
                      side: const BorderSide(color: AdminTheme.errorColor, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      auth.logout();
                    },
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Logout Session',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: AdminTheme.primaryYellow.withOpacity(0.06),
          splashColor: AdminTheme.primaryYellow.withOpacity(0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected ? AdminTheme.primaryYellow : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AdminTheme.primaryYellow.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Yellow left indicator strip (only on selected item)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: isSelected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: isSelected ? AdminTheme.darkBackground : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: isSelected ? 12 : 0),
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AdminTheme.darkBackground : AdminTheme.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AdminTheme.darkBackground : AdminTheme.textSecondary,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
