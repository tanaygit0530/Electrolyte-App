import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/service_records_provider.dart';
import '../utils/theme.dart';

class ServiceDataUploadScreen extends StatelessWidget {
  const ServiceDataUploadScreen({super.key});

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServiceRecordsProvider>();

    return Scaffold(
      backgroundColor: AdminTheme.darkBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Records & 60-Day Audit',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upload service job sheets (.xlsx / .csv) to sync database records and identify active 60-day service/warranty claims.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AdminTheme.textSecondary.withOpacity(0.85),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                if (provider.summary != null)
                  ElevatedButton.icon(
                    onPressed: () => provider.reset(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Upload New Sheet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.darkSurface,
                      foregroundColor: AdminTheme.textSecondary,
                      side: const BorderSide(color: AdminTheme.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Dropzone & File Ingestion Card
            _buildUploadCard(context, provider),

            const SizedBox(height: 24),

            // KPI Summary Cards (When processed)
            if (provider.summary != null) ...[
              _buildKpiSummaryRow(context, provider),
              const SizedBox(height: 28),
              _buildFoundEntriesSection(context, provider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context, ServiceRecordsProvider provider) {
    final hasFile = provider.fileName != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AdminTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminTheme.darkBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: hasFile ? AdminTheme.accentEmerald : AdminTheme.primaryYellow.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: Icon(
              hasFile ? Icons.file_present_rounded : Icons.cloud_upload_outlined,
              size: 48,
              color: hasFile ? AdminTheme.accentEmerald : AdminTheme.primaryYellow,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFile ? provider.fileName! : 'Select Service Sheet (.xlsx, .xls, .csv)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFile
                ? 'File size: ${_formatFileSize(provider.fileSizeBytes)} • Ready for ingestion'
                : 'Supports large files like Data.xlsx (up to 50MB, 100,000+ rows)',
            style: TextStyle(
              fontSize: 13,
              color: AdminTheme.textSecondary.withOpacity(0.8),
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),

          // Upload & Real-Time Background Job Processing Display
          if (provider.isUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (!provider.isProcessingJob && provider.uploadProgress > 0 && provider.uploadProgress < 1.0)
                    ? provider.uploadProgress
                    : null,
                minHeight: 8,
                backgroundColor: AdminTheme.darkBackground,
                valueColor: AlwaysStoppedAnimation<Color>(
                  provider.isProcessingJob ? AdminTheme.accentEmerald : AdminTheme.primaryYellow,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: provider.isProcessingJob ? AdminTheme.accentEmerald : AdminTheme.primaryYellow,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  provider.isProcessingJob
                      ? (provider.stageText ?? 'Processing service records on cloud server...')
                      : (provider.statusText ?? 'Uploading file...'),
                  style: TextStyle(
                    color: provider.isProcessingJob ? Colors.white : AdminTheme.primaryYellow,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            if (provider.isProcessingJob) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AdminTheme.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Rows Scanned
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dataset_outlined, size: 18, color: AdminTheme.primaryYellow),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.processedRows} Rows Scanned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: AdminTheme.borderColor),
                    // Repeat Risk Counter
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: AdminTheme.errorColor),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.liveFoundWithin60} Repeat Risk (<60d)',
                          style: const TextStyle(
                            color: AdminTheme.errorColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    Container(height: 20, width: 1, color: AdminTheme.borderColor),
                    // Safe Records Counter
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AdminTheme.accentEmerald),
                        const SizedBox(width: 8),
                        Text(
                          '${provider.liveOlderThan60} Safe (>60d)',
                          style: const TextStyle(
                            color: AdminTheme.accentEmerald,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Error Message
          if (provider.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.errorColor.withOpacity(0.12),
                border: Border.all(color: AdminTheme.errorColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AdminTheme.errorColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(color: AdminTheme.errorColor, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: provider.isUploading ? null : () => provider.pickServiceFile(),
                icon: const Icon(Icons.folder_open),
                label: Text(hasFile ? 'Change File' : 'Browse File'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AdminTheme.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (hasFile) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: provider.isUploading ? null : () => provider.uploadAndAudit(),
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Start Upload & 60-Day Audit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primaryYellow,
                    foregroundColor: AdminTheme.darkBackground,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryRow(BuildContext context, ServiceRecordsProvider provider) {
    final summary = provider.summary!;

    return Row(
      children: [
        // Total Records Processed
        Expanded(
          child: _buildKpiCard(
            title: 'Total Records Ingested',
            value: summary.totalRecords.toString(),
            subtitle: 'Processed from sheet',
            icon: Icons.list_alt_rounded,
            accentColor: AdminTheme.primaryYellow,
          ),
        ),
        const SizedBox(width: 16),
        // Found (Within 60 Days) - HIGHLIGHTED IN RED (REPEAT RISK - DO NOT CLOSE)
        Expanded(
          child: _buildKpiCard(
            title: 'Repeat Risk (< 60 Days)',
            value: summary.foundWithin60Days.toString(),
            subtitle: "Don't close call • Repeat risk",
            icon: Icons.warning_amber_rounded,
            accentColor: AdminTheme.errorColor,
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 16),
        // Older than 60 Days - SAFE TO CLOSE
        Expanded(
          child: _buildKpiCard(
            title: 'Safe to Close (> 60 Days)',
            value: summary.olderThan60Days.toString(),
            subtitle: 'Beyond 60 days • Safe to close',
            icon: Icons.check_circle_outline_rounded,
            accentColor: AdminTheme.accentEmerald,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AdminTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? accentColor.withOpacity(0.6) : AdminTheme.borderColor,
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AdminTheme.textSecondary.withOpacity(0.9),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isHighlighted ? accentColor : Colors.white,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AdminTheme.textSecondary.withOpacity(0.6),
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoundEntriesSection(BuildContext context, ServiceRecordsProvider provider) {
    final entries = provider.filteredEntries;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AdminTheme.errorColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Repeat Risk Serials (< 60 Days: ${provider.foundEntries.length} entries)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final path = await provider.exportCsv();
                  if (context.mounted && path != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('CSV Export saved to $path'),
                        backgroundColor: AdminTheme.errorColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Repeat Risk CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Search Field
          TextField(
            onChanged: (val) => provider.setSearchQuery(val),
            style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
            decoration: InputDecoration(
              hintText: 'Search by Serial Number, Customer Name, or Case Number...',
              prefixIcon: const Icon(Icons.search, color: AdminTheme.textSecondary),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AdminTheme.textSecondary),
                      onPressed: () => provider.setSearchQuery(''),
                    )
                  : null,
            ),
          ),

          const SizedBox(height: 20),

          // Table of Found Entries
          if (entries.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const Text(
                'No matching found entries.',
                style: TextStyle(color: AdminTheme.textSecondary, fontFamily: 'Poppins'),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AdminTheme.darkBackground),
                dataRowColor: WidgetStateProperty.all(AdminTheme.darkSurface),
                columnSpacing: 28,
                headingTextStyle: const TextStyle(
                  color: AdminTheme.primaryYellow,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                ),
                dataTextStyle: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 13,
                ),
                columns: const [
                  DataColumn(label: Text('Serial Number')),
                  DataColumn(label: Text('End Date')),
                  DataColumn(label: Text('Days Ago')),
                  DataColumn(label: Text('Case No')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Complaint')),
                  DataColumn(label: Text('Repair / Action')),
                  DataColumn(label: Text('Status')),
                ],
                rows: entries.take(100).map((entry) {
                  return DataRow(
                    cells: [
                      // Serial Number with copy icon
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.serialNumber,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AdminTheme.errorColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 14, color: AdminTheme.textSecondary),
                              tooltip: 'Copy Serial',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: entry.serialNumber));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Copied: ${entry.serialNumber}'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(entry.date)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminTheme.errorColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AdminTheme.errorColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${entry.daysAgo} days (Repeat Risk)',
                            style: const TextStyle(
                              color: AdminTheme.errorColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(entry.caseNumber ?? 'N/A')),
                      DataCell(Text(entry.customerName ?? 'N/A')),
                      DataCell(Text(entry.complaint ?? 'N/A')),
                      DataCell(Text(entry.repair ?? 'N/A')),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.status ?? 'N/A',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
