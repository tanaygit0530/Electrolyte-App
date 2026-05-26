import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../models/upload_history.dart';
import '../utils/theme.dart';

class UploadHistoryScreen extends StatefulWidget {
  const UploadHistoryScreen({super.key});

  @override
  State<UploadHistoryScreen> createState() => _UploadHistoryScreenState();
}

class _UploadHistoryScreenState extends State<UploadHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchHistories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    // Format: DD/MM/YYYY HH:MM:SS
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  List<UploadHistory> _filterLogs(List<UploadHistory> logs) {
    if (_searchQuery.trim().isEmpty) return logs;
    return logs.where((log) {
      final fileMatch = log.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
      final userMatch = log.uploadedBy.toLowerCase().contains(_searchQuery.toLowerCase());
      return fileMatch || userMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = Provider.of<DashboardProvider>(context);

    final filteredStock = _filterLogs(dashboard.stockHistory);
    final filteredPrice = _filterLogs(dashboard.priceHistory);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historical Upload Logs',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete audit log records of administrative spreadsheet executions and synchronization statistics',
                      style: TextStyle(
                        fontSize: 14,
                        color: AdminTheme.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                
                // Refresh Logs Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.darkSurface,
                    foregroundColor: AdminTheme.accentTeal,
                    side: BorderSide(color: AdminTheme.accentTeal.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => dashboard.fetchHistories(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Logs', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Controls: Search & Tabs
            Row(
              children: [
                // Search Input
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search logs by file name or administrative email...',
                      prefixIcon: Icon(Icons.search, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 32),

                // Beautiful custom tab bar indicators
                Container(
                  width: 380,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AdminTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AdminTheme.textSecondary.withOpacity(0.15)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AdminTheme.tealGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AdminTheme.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: 'Stock Uploads'),
                      Tab(text: 'Price Uploads'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Logs Tables Views
            Expanded(
              child: Container(
                decoration: AdminTheme.glassBox(opacity: 0.1),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Stock Logs Table
                    _buildLogsTable(filteredStock, dashboard.isLoading, 'stock'),
                    
                    // Tab 2: Price Logs Table
                    _buildLogsTable(filteredPrice, dashboard.isLoading, 'price'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsTable(List<UploadHistory> logs, bool loading, String type) {
    if (loading && logs.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.accentTeal));
    }

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: AdminTheme.textSecondary.withOpacity(0.4), size: 48),
            const SizedBox(height: 16),
            const Text(
              'No upload history logs recorded in database.',
              style: TextStyle(color: AdminTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Column headers
        Container(
          color: AdminTheme.darkSurface.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: const Row(
            children: [
              SizedBox(width: 50, child: Text('ID', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
              Expanded(flex: 3, child: Text('Spreadsheet File Name', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
              Expanded(flex: 2, child: Text('Executed By', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
              SizedBox(width: 100, child: Text('Total Rows', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary), textAlign: TextAlign.right)),
              SizedBox(width: 100, child: Text('Success', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary), textAlign: TextAlign.right)),
              SizedBox(width: 100, child: Text('Errors', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary), textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('Sync Timestamp', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary), textAlign: TextAlign.right)),
            ],
          ),
        ),

        const Divider(height: 1),

        // Logs rows
        Expanded(
          child: ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: AdminTheme.textSecondary.withOpacity(0.08)),
            itemBuilder: (context, idx) {
              final log = logs[idx];
              final double successRate = log.totalRows > 0 ? (log.updatedRows / log.totalRows) : 0;
              final Color progressColor = successRate == 1.0 
                  ? AdminTheme.accentEmerald 
                  : (successRate > 0.8 ? AdminTheme.accentTeal : AdminTheme.errorColor);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        log.id.toString(), 
                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            type == 'stock' ? Icons.inventory_2_outlined : Icons.payments_outlined,
                            size: 16,
                            color: progressColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              log.fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textPrimary, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        log.uploadedBy,
                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        log.totalRows.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textPrimary, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        log.updatedRows.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.accentEmerald, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        log.failedRows.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: log.failedRows > 0 ? AdminTheme.errorColor : AdminTheme.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(log.uploadedAt),
                        style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
