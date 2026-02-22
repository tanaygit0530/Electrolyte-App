import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Adjust these imports to your actual paths
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Assuming ThemeProvider has isDarkMode and toggleTheme
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Fallback if AppTheme.primaryYellow isn't defined in this snippet
    const primaryColor = Color(0xFFFFC107); 

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Profile', // Removed the amateur emoji
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            _buildProfileHeader(primaryColor, isDark),
            const SizedBox(height: 32),
            _buildSection(
              context: context,
              title: "Contact Information",
              children: [
                _buildInfoTile(Icons.phone_outlined, "Mobile Number", "+91 98765 43210", primaryColor),
                _buildDivider(),
                _buildInfoTile(Icons.location_on_outlined, "Service Center", "Mumbai Hub, MH", primaryColor),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context: context,
              title: "App Settings",
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: isDark ? primaryColor : Colors.grey.shade700),
                  ),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.toggleTheme(value),
                  activeColor: primaryColor,
                  activeTrackColor: primaryColor.withOpacity(0.3),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildLogoutButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Color primaryColor, bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: primaryColor.withOpacity(0.15),
                child: Icon(Icons.person_rounded, size: 60, color: primaryColor),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.grey.shade900 : Colors.white, width: 3),
              ),
              child: const Icon(Icons.verified_rounded, size: 16, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          "Tanay Patil",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "TECH-2024-001",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required BuildContext context, required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, indent: 64, color: Colors.grey.withOpacity(0.2));
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
        label: const Text(
          "Logout securely",
          style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.redAccent.withOpacity(0.05),
        ),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Logout feature coming soon"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}