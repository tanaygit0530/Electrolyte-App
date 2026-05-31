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
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome / Description bar
              Text(
                'Real-time overview of your Electrolyte database metrics and active inventory status',
                style: TextStyle(
                  fontSize: 14,
                  color: AdminTheme.textSecondary.withOpacity(0.9),
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 32),

              // Telemetry Cards Grid (Premium responsive row style)
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Distinct Products',
                      value: dashboard.totalProducts.toString(),
                      icon: Icons.category_rounded,
                      accentColor: AdminTheme.primaryYellow,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StatCard(
                      title: 'Total Stock Quantity',
                      value: dashboard.totalStock.toString(),
                      icon: Icons.inventory_2_rounded,
                      accentColor: AdminTheme.secondaryYellow,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StatCard(
                      title: 'Last Stock Upload',
                      value: _formatDate(dashboard.lastStockUpload),
                      icon: Icons.cloud_done_rounded,
                      accentColor: AdminTheme.successColor,
                      isDate: true,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _StatCard(
                      title: 'Last Price Upload',
                      value: _formatDate(dashboard.lastPriceUpload),
                      icon: Icons.payments_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      isDate: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Quick Control Center / Actions Heading
              const Text(
                'Database Control Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),
              
              // Action Cards Grid
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: 350,
                    child: _ActionCard(
                      title: 'Daily Stock Import',
                      description: 'Everyday quick upload to sync stock levels only. Price indices will remain completely unaffected.',
                      icon: Icons.upload_file_rounded,
                      buttonText: 'Open Stock Module',
                      color: AdminTheme.primaryYellow,
                      onPressed: () => widget.onNavigate(1),
                    ),
                  ),
                  SizedBox(
                    width: 350,
                    child: _ActionCard(
                      title: 'Price Catalogue Update',
                      description: 'Upload revised lists when parts pricing changes (typically every 3-6 months) to match customer price indices.',
                      icon: Icons.price_change_rounded,
                      buttonText: 'Open Pricing Module',
                      color: AdminTheme.primaryYellow,
                      onPressed: () => widget.onNavigate(2),
                    ),
                  ),
                  SizedBox(
                    width: 350,
                    child: _ActionCard(
                      title: 'Audit Logs & Histories',
                      description: 'Review transaction logs, evict cache files, download error reports, and search historical database updates.',
                      icon: Icons.document_scanner_rounded,
                      buttonText: 'Open History Module',
                      color: AdminTheme.primaryYellow,
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
  final Color accentColor;
  final bool isDate;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.isDate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      decoration: BoxDecoration(
        color: AdminTheme.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Left yellow glowing bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(
                color: accentColor,
              ),
            ),
            
            // Decorative background icon
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                icon,
                size: 96,
                color: accentColor.withOpacity(0.03),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 22, right: 22, bottom: 22),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AdminTheme.textSecondary,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
                        ),
                        child: Icon(icon, size: 16, color: accentColor),
                      ),
                    ],
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isDate ? 13 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      letterSpacing: isDate ? 0 : -0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
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
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 270,
        padding: const EdgeInsets.all(28.0),
        decoration: BoxDecoration(
          color: AdminTheme.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? AdminTheme.primaryYellow.withOpacity(0.6) : AdminTheme.borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered 
                  ? AdminTheme.primaryYellow.withOpacity(0.08) 
                  : Colors.black.withOpacity(0.25),
              blurRadius: _isHovered ? 20 : 16,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(widget.icon, size: 36, color: AdminTheme.primaryYellow),
                const SizedBox(height: 14),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminTheme.textSecondary,
                    height: 1.4,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primaryYellow,
                  foregroundColor: AdminTheme.darkBackground,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // 12px rounded buttons matching spec
                  ),
                ),
                onPressed: widget.onPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.buttonText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
