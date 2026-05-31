import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/upload_provider.dart';
import '../providers/dashboard_provider.dart';
import '../utils/theme.dart';

class StockUploadScreen extends StatefulWidget {
  const StockUploadScreen({super.key});

  @override
  State<StockUploadScreen> createState() => _StockUploadScreenState();
}

class _StockUploadScreenState extends State<StockUploadScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL'; // 'ALL', 'VALID', 'INVALID'

  @override
  void initState() {
    super.initState();
    // Reset state on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UploadProvider>(context, listen: false).resetState();
    });
  }

  void _handlePickAndParse() async {
    final upload = Provider.of<UploadProvider>(context, listen: false);
    final success = await upload.pickExcelFile();
    if (success) {
      await upload.parseStockSheet();
    }
  }

  void _handleSubmit() async {
    final upload = Provider.of<UploadProvider>(context, listen: false);
    final success = await upload.submitStockUpdates();
    
    if (mounted) {
      if (success) {
        // Trigger dashboard stats refresh
        Provider.of<DashboardProvider>(context, listen: false).refreshDashboard();
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AdminTheme.darkSurface,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AdminTheme.accentEmerald, size: 28),
                SizedBox(width: 12),
                Text('Stock Sync Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Stock Sheet "${upload.fileName}" has been processed successfully!'),
                const SizedBox(height: 16),
                Text('• Successfully updated rows: ${upload.uploadSummary?['updatedRows'] ?? 0}'),
                Text('• Failed rows skipped: ${upload.uploadSummary?['failedRows'] ?? 0}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  upload.resetState();
                },
                child: const Text('Back to Dashboard', style: TextStyle(color: AdminTheme.accentTeal)),
              )
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(upload.errorMessage ?? 'Bulk upload transmission failed.'),
            backgroundColor: AdminTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            width: 380,
          ),
        );
      }
    }
  }

  void _handleExportCsv() async {
    final upload = Provider.of<UploadProvider>(context, listen: false);
    final success = await upload.exportFailedRowsCsv();
    
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed rows report CSV exported successfully!'),
          backgroundColor: AdminTheme.accentEmerald,
          behavior: SnackBarBehavior.floating,
          width: 320,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final upload = Provider.of<UploadProvider>(context);

    // Filter rows based on search query and status filter
    final filteredRows = upload.previewRows.where((row) {
      final codeMatch = row.productCode.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_statusFilter == 'VALID') return codeMatch && row.isValid;
      if (_statusFilter == 'INVALID') return codeMatch && !row.isValid;
      return codeMatch;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Stock Import module',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Match parts using codes to update stock levels. Price catalogs will remain completely unchanged.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AdminTheme.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                if (upload.fileName != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.darkSurface,
                      foregroundColor: AdminTheme.errorColor,
                      side: BorderSide(color: AdminTheme.errorColor.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => upload.resetState(),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Reset Module', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // Drop zone or Main upload trigger
            if (upload.fileName == null)
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: _handlePickAndParse,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 380),
                      decoration: BoxDecoration(
                        color: AdminTheme.darkSurface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AdminTheme.accentTeal.withOpacity(0.3),
                          width: 2,
                          style: BorderStyle.solid, // Flat clean border matching slate look
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AdminTheme.accentTeal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.upload_file_rounded,
                              size: 64,
                              color: AdminTheme.accentTeal,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Daily Stock Excel Sheet Selection',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Click to pick a spreadsheet from your system\nSupports .xlsx and .xls sheets',
                            style: TextStyle(
                              fontSize: 13,
                              color: AdminTheme.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              // Spreadsheet Parsing View
              if (upload.isParsing)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AdminTheme.accentTeal),
                        SizedBox(height: 20),
                        Text(
                          'Parsing Excel Sheet rows and running auditing validations...',
                          style: TextStyle(color: AdminTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else if (upload.errorMessage != null && upload.previewRows.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 48),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            upload.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AdminTheme.textPrimary, 
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => upload.resetState(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Main split preview / report screen
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Grid Preview Table (70% Width)
                      Expanded(
                        flex: 7,
                        child: Container(
                          decoration: AdminTheme.glassBox(opacity: 0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Grid Header Control Bar
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    // Search Bar
                                    Expanded(
                                      child: TextField(
                                        onChanged: (val) {
                                          setState(() {
                                            _searchQuery = val;
                                          });
                                        },
                                        decoration: const InputDecoration(
                                          hintText: 'Search by Product Code...',
                                          prefixIcon: Icon(Icons.search, size: 18),
                                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Filter Tabs
                                    _FilterButton(
                                      label: 'All (${upload.previewRows.length})',
                                      isSelected: _statusFilter == 'ALL',
                                      onTap: () => setState(() => _statusFilter = 'ALL'),
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterButton(
                                      label: 'Valid (${upload.validRowsPayload.length})',
                                      isSelected: _statusFilter == 'VALID',
                                      onTap: () => setState(() => _statusFilter = 'VALID'),
                                      activeColor: AdminTheme.accentEmerald,
                                    ),
                                    const SizedBox(width: 8),
                                    _FilterButton(
                                      label: 'Errors (${upload.failedRowsReport.length})',
                                      isSelected: _statusFilter == 'INVALID',
                                      onTap: () => setState(() => _statusFilter = 'INVALID'),
                                      activeColor: AdminTheme.errorColor,
                                    ),
                                  ],
                                ),
                              ),
                              
                              const Divider(height: 1),

                              // Table Headings
                              Container(
                                color: AdminTheme.darkSurface.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: const Row(
                                  children: [
                                    SizedBox(width: 50, child: Text('Row', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
                                    SizedBox(width: 120, child: Text('Part Code', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
                                    SizedBox(width: 120, child: Text('Raw Stock', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
                                    SizedBox(width: 120, child: Text('Parsed Qty', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
                                    Expanded(child: Text('Auditing Status', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textSecondary))),
                                  ],
                                ),
                              ),

                              // Preview rows list
                              Expanded(
                                child: filteredRows.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No items match your active search/filter criteria.',
                                          style: TextStyle(color: AdminTheme.textSecondary),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: filteredRows.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.transparent),
                                        itemBuilder: (context, idx) {
                                          final row = filteredRows[idx];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                            color: row.isValid 
                                                ? Colors.transparent 
                                                : AdminTheme.errorColor.withOpacity(0.04),
                                            child: Row(
                                              children: [
                                                SizedBox(width: 50, child: Text(row.rowNumber.toString(), style: const TextStyle(color: AdminTheme.textSecondary))),
                                                SizedBox(width: 120, child: Text(row.productCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textPrimary))),
                                                SizedBox(width: 120, child: Text(row.originalValue.toString(), style: const TextStyle(color: AdminTheme.textSecondary))),
                                                SizedBox(width: 120, child: Text(row.parsedValueDisplay, style: TextStyle(fontWeight: FontWeight.bold, color: row.isValid ? AdminTheme.accentTeal : AdminTheme.errorColor))),
                                                Expanded(
                                                  child: row.isValid
                                                      ? const Row(
                                                          children: [
                                                            Icon(Icons.check_circle_outline, color: AdminTheme.accentEmerald, size: 16),
                                                            SizedBox(width: 6),
                                                            Text('Valid ready to sync', style: TextStyle(color: AdminTheme.accentEmerald, fontSize: 13)),
                                                          ],
                                                        )
                                                      : Row(
                                                          children: [
                                                            const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 16),
                                                            SizedBox(width: 6),
                                                            Expanded(
                                                              child: Text(
                                                                row.errorMessage ?? 'Invalid data',
                                                                style: const TextStyle(color: AdminTheme.errorColor, fontSize: 13),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 24),

                      // 2. Audit Control Summary Box (30% Width)
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Summary stats card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AdminTheme.glassBox(opacity: 0.15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Upload Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                                  const SizedBox(height: 20),
                                  _SummaryRow(label: 'Total Sheet Rows', value: upload.previewRows.length.toString()),
                                  const SizedBox(height: 12),
                                  _SummaryRow(label: 'Valid updates ready', value: upload.validRowsPayload.length.toString(), color: AdminTheme.accentEmerald),
                                  const SizedBox(height: 12),
                                  _SummaryRow(label: 'Errors blocked', value: upload.failedRowsReport.length.toString(), color: upload.failedRowsReport.isNotEmpty ? AdminTheme.errorColor : AdminTheme.textSecondary),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),

                            // Failed row exporter box
                            if (upload.failedRowsReport.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: AdminTheme.glassBox(
                                  borderColor: AdminTheme.errorColor.withOpacity(0.2),
                                  opacity: 0.08,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: AdminTheme.errorColor, size: 20),
                                        SizedBox(width: 8),
                                        Text('Auditing Error Log', style: TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.errorColor)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${upload.failedRowsReport.length} rows contain negative stock values, blank codes, formats, or duplicate product entries. Fix these in Excel before sync, or download an error report.',
                                      style: const TextStyle(fontSize: 12, color: AdminTheme.textSecondary, height: 1.4),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AdminTheme.errorColor.withOpacity(0.12),
                                          foregroundColor: AdminTheme.errorColor,
                                          elevation: 0,
                                          side: const BorderSide(color: AdminTheme.errorColor),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: _handleExportCsv,
                                        icon: const Icon(Icons.download_rounded, size: 16),
                                        label: const Text('Export Failures CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const Spacer(),

                            // Main actions submission control block
                            if (upload.isUploading) ...[
                              Text(
                                'Syncing: ${(upload.uploadProgress * 100).toStringAsFixed(0)}% uploaded...',
                                style: const TextStyle(fontSize: 13, color: AdminTheme.accentTeal, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: upload.uploadProgress,
                                  backgroundColor: AdminTheme.darkSurface,
                                  color: AdminTheme.accentTeal,
                                  minHeight: 8,
                                ),
                              ),
                            ] else
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: upload.validRowsPayload.isEmpty ? null : _handleSubmit,
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      gradient: upload.validRowsPayload.isEmpty ? null : AdminTheme.tealGradient,
                                      color: upload.validRowsPayload.isEmpty ? Colors.grey.withOpacity(0.2) : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Container(
                                      alignment: Alignment.center,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.sync, color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Commit Stock Sync',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            ]
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor = AdminTheme.accentTeal,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : AdminTheme.textSecondary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : AdminTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color = AdminTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AdminTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
