import 'package:flutter/material.dart';
// Adjust these imports to match your actual paths
// import '../services/api_service.dart';
// import '../models/spare_part.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // 1. ISOLATE THE FUTURE
  // By declaring this here and setting it in initState, it only runs ONCE per screen load.
  late Future<List<dynamic>> _alertsFuture; // Replace dynamic with SparePart
  // final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  void _fetchAlerts() {
    // Replace with your actual API call:
    // _alertsFuture = _apiService.getAllParts();
    
    // Mock data for demonstration
    _alertsFuture = Future.delayed(
      const Duration(milliseconds: 800),
      () => [
        {'partName': 'Compressor Unit', 'partCode': 'CMP-88', 'model': 'LG Refrigerator', 'stockQuantity': 0, 'status': 'Out of Stock'},
        {'partName': 'Display Panel', 'partCode': 'DP-001', 'model': 'Galaxy S21', 'stockQuantity': 3, 'status': 'Low'},
        {'partName': 'Water Filter', 'partCode': 'WF-12', 'model': 'Whirlpool XL', 'stockQuantity': 1, 'status': 'Low'},
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Inventory Alerts',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _fetchAlerts()),
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>( // Replace dynamic with SparePart
        future: _alertsFuture, // Safely referencing the isolated future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final parts = snapshot.data ?? [];
          final criticalParts = parts.where((p) => p['status'] == 'Out of Stock' || p['status'] == 'Low').toList(); // Adjust logic to p.status for your model

          if (criticalParts.isEmpty) {
            return _buildEmptyState();
          }

          // Sort so "Out of Stock" (Critical) appears at the top
          criticalParts.sort((a, b) {
            if (a['status'] == 'Out of Stock' && b['status'] != 'Out of Stock') return -1;
            if (a['status'] != 'Out of Stock' && b['status'] == 'Out of Stock') return 1;
            return 0;
          });

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: criticalParts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final part = criticalParts[index];
              return _AlertCard(part: part);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_rounded, size: 64, color: Colors.green),
          ),
          const SizedBox(height: 24),
          const Text(
            "Inventory Healthy",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            "All spare parts are sufficiently stocked.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          const Text("Failed to load alerts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _fetchAlerts()),
            icon: const Icon(Icons.refresh),
            label: const Text("Try Again"),
          )
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final dynamic part; // Replace with SparePart

  const _AlertCard({required this.part});

  @override
  Widget build(BuildContext context) {
    // Replace array access with your model properties (e.g., part.status)
    final bool isOutOfStock = part['status'] == 'Out of Stock';
    
    final Color statusColor = isOutOfStock ? Colors.redAccent : Colors.orange.shade700;
    final Color bgColor = isOutOfStock ? Colors.red.shade50 : Colors.orange.shade50;
    final IconData statusIcon = isOutOfStock ? Icons.error_outline_rounded : Icons.warning_amber_rounded;
    final String statusText = isOutOfStock ? "OUT OF STOCK" : "LOW STOCK";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Text(
                  "Qty: ${part['stockQuantity']}",
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Body Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part['partName'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.3),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildDataColumn("Code", part['partCode']),
                    Container(width: 1, height: 30, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildDataColumn("Model", part['model']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}