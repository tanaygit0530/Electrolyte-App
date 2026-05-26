import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../utils/theme.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).refreshDashboard();
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No uploads recorded';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row (Wrap-enabled for small widths)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 20,
                runSpacing: 20,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Telemetry Dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Real-time overview of your Electrolyte database metrics and active inventory status',
                        style: TextStyle(
                          fontSize: 14,
                          color: AdminTheme.textSecondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  
                  // Refresh Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.darkSurface,
                      foregroundColor: AdminTheme.accentTeal,
                      side: BorderSide(color: AdminTheme.accentTeal.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      dashboard.refreshDashboard();
                    },
                    icon: dashboard.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AdminTheme.accentTeal,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      'Refresh Panel',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Telemetry Cards Grid (Beautiful wrapping behavior)
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: 250,
                    child: _StatCard(
                      title: 'Total Distinct Products',
                      value: dashboard.totalProducts.toString(),
                      icon: Icons.category,
                      gradient: AdminTheme.blueGradient,
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _StatCard(
                      title: 'Total Stock Quantity',
                      value: dashboard.totalStock.toString(),
                      icon: Icons.inventory,
                      gradient: AdminTheme.tealGradient,
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _StatCard(
                      title: 'Last Stock Upload',
                      value: _formatDate(dashboard.lastStockUpload),
                      icon: Icons.cloud_done,
                      gradient: AdminTheme.emeraldGradient,
                      isDate: true,
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: _StatCard(
                      title: 'Last Price Upload',
                      value: _formatDate(dashboard.lastPriceUpload),
                      icon: Icons.payments,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                      ),
                      isDate: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Quick Control Center / Actions Heading
              const Text(
                'Database Control Actions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              
              // Action Cards Grid (Responsive Wrapping layout)
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: 340,
                    child: _ActionCard(
                      title: 'Daily Stock Import',
                      description: 'Everyday quick upload to sync stock levels only. Price indices will remain completely unaffected.',
                      icon: Icons.upload_file_rounded,
                      buttonText: 'Open Stock Module',
                      color: AdminTheme.accentTeal,
                      onPressed: () => widget.onNavigate(1),
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: _ActionCard(
                      title: 'Price Catalogue Update',
                      description: 'Upload revised lists when parts pricing changes (typically every 3-6 months) to match customer price indices.',
                      icon: Icons.price_change_rounded,
                      buttonText: 'Open Pricing Module',
                      color: AdminTheme.accentBlue,
                      onPressed: () => widget.onNavigate(2),
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: _ActionCard(
                      title: 'Audit Logs & Histories',
                      description: 'Review transaction logs, evict cache files, download error reports, and search historical database updates.',
                      icon: Icons.document_scanner_rounded,
                      buttonText: 'Open History Module',
                      color: const Color(0xFF8B5CF6),
                      onPressed: () => widget.onNavigate(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final bool isDate;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.isDate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: AdminTheme.glassBox(opacity: 0.15),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              icon,
              size: 100,
              color: AdminTheme.textSecondary.withOpacity(0.04),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AdminTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 16, color: Colors.white),
                    ),
                  ],
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isDate ? 14 : 32,
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.textPrimary,
                    letterSpacing: isDate ? 0 : -1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String buttonText;
  final Color color;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.buttonText,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260, // Increased height to ensure zero vertical overflow
      padding: const EdgeInsets.all(28.0),
      decoration: AdminTheme.glassBox(opacity: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminTheme.textSecondary,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withOpacity(0.12),
              foregroundColor: color,
              elevation: 0,
              side: BorderSide(color: color.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
