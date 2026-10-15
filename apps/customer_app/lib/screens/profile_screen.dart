import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'technician_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('👤 Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryYellow,
              child: Icon(Icons.person, size: 60, color: Colors.black),
            ),
            const SizedBox(height: 16),
            Text(
              auth.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              auth.email ?? "technician@example.com",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildProfileItem(
              Icons.badge_outlined,
              auth.isAdmin ? "Administrator ID" : "Technician ID",
              auth.technicianId,
            ),
            _buildProfileItem(
              Icons.work_outline,
              "Account Role",
              auth.role,
            ),
            _buildProfileItem(
              Icons.phone_outlined,
              "Contact Number",
              auth.phone ?? "Not provided",
            ),
            _buildProfileItem(
              Icons.store_mall_directory_outlined,
              "Assigned Service Hub",
              "Authorized Service Center",
            ),
            if (auth.isAdmin) ...[
              const SizedBox(height: 16),
              Card(
                color: isDark ? AppTheme.darkCardColor : Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppTheme.primaryYellow.withValues(alpha: 0.6)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppTheme.primaryYellow,
                    child: Icon(Icons.admin_panel_settings, color: Colors.black, size: 22),
                  ),
                  title: const Text(
                    'Technician Management',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'Create credentials & manage technician accounts',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TechnicianManagementScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
            const Divider(height: 40),
            SwitchListTile(
              title: const Text("Dark Mode"),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.toggleTheme(value),
              activeThumbColor: AppTheme.primaryYellow,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red)),
              onTap: () {
                context.read<AuthProvider>().logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Logged out successfully!"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryYellow),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }
}
