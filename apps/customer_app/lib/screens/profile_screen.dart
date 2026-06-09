import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'package:shared_ui/shared_ui.dart';

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
            // _buildProfileItem(Icons.badge, "Technician ID", auth.id != null ? "TECH-00${auth.id}" : "TECH-2024-001"),
            _buildProfileItem(Icons.phone, "Mobile Number", "+91 99999 99999"),
            _buildProfileItem(
              Icons.location_on,
              "Service Center",
              "Mumbai Hub, MH",
            ),
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
