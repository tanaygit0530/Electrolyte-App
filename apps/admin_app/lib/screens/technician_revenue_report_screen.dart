import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_core/shared_core.dart';
import '../providers/report_provider.dart';
import '../utils/theme.dart';

class TechnicianRevenueReportScreen extends StatefulWidget {
  const TechnicianRevenueReportScreen({super.key});

  @override
  State<TechnicianRevenueReportScreen> createState() => _TechnicianRevenueReportScreenState();
}

class _TechnicianRevenueReportScreenState extends State<TechnicianRevenueReportScreen> {
  // Sorting state
  String _sortColumn = 'date';
  bool _sortAscending = false;

  // Pagination state
  int _currentPage = 1;
  final int _rowsPerPage = 10;

  // Excel-style column filters state (key: column name, value: checked options)
  // An empty set or missing key means no filter is applied (all options checked by default)
  final Map<String, Set<String>> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      provider.fetchReport();
      provider.initWebSocket();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  dynamic _getSortVal(InvoiceModel inv, String col) {
    switch (col) {
      case 'invoiceNumber':
        return inv.invoiceNumber;
      case 'date':
        return inv.createdAt;
      case 'technician':
        return inv.technicianName;
      case 'customer':
        return inv.customerName;
      case 'caseId':
        return inv.caseId ?? '';
      case 'zipCode':
        return inv.zipCode;
      case 'brand':
        return inv.brand ?? '';
      case 'parts':
        return inv.partDescription ?? '';
      case 'itemPrice':
        return inv.productItemPrice ?? 0.0;
      case 'remark':
        return inv.remark;
      case 'mop':
        return inv.mop;
      case 'amount':
        return inv.totalAmount;
      default:
        return '';
    }
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<String> getUniqueValues(ReportProvider report, String key) {
    final values = <String>{};
    for (final inv in report.invoices) {
      switch (key) {
        case 'technician':
          values.add(inv.technicianName.isNotEmpty ? inv.technicianName : '(blank)');
          break;
        case 'mop':
          values.add(inv.mop.isNotEmpty ? inv.mop : '(blank)');
          break;
        case 'customer':
          values.add(inv.customerName.isNotEmpty ? inv.customerName : '(blank)');
          break;
        case 'invoiceNumber':
          values.add(inv.invoiceNumber.isNotEmpty ? inv.invoiceNumber : '(blank)');
          break;
        case 'zipCode':
          values.add(inv.zipCode.isNotEmpty ? inv.zipCode : '(blank)');
          break;
      }
    }
    final list = values.toList();
    list.sort();
    return list;
  }

  void _showFilterPopup(BuildContext context, String key, String title) {
    final report = Provider.of<ReportProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) {
        return _ExcelFilterDialog(
          columnKey: key,
          title: title,
          allItems: getUniqueValues(report, key),
          selectedItems: _activeFilters[key] ?? {},
          onChanged: (newSelection) {
            setState(() {
              if (newSelection.isEmpty) {
                _activeFilters.remove(key);
                if (key == 'technician') {
                  report.setSelectedTechnicians([]);
                } else if (key == 'mop') {
                  report.setSelectedMops([]);
                }
              } else {
                _activeFilters[key] = newSelection;
                // Keep backend in sync for Technicians and Mops to reflect in Excel download API
                if (key == 'technician') {
                  // Re-map (blank) back to empty string when synchronizing with backend
                  final list = newSelection.map((e) => e == '(blank)' ? '' : e).toList();
                  report.setSelectedTechnicians(list);
                } else if (key == 'mop') {
                  final list = newSelection.map((e) => e == '(blank)' ? '' : e).toList();
                  report.setSelectedMops(list);
                }
              }
              _currentPage = 1;
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = Provider.of<ReportProvider>(context);

    // Apply active column filters client-side
    final filteredInvoices = report.invoices.where((inv) {
      if (_activeFilters['technician'] != null && _activeFilters['technician']!.isNotEmpty) {
        final name = inv.technicianName.isNotEmpty ? inv.technicianName : '(blank)';
        if (!_activeFilters['technician']!.contains(name)) return false;
      }
      if (_activeFilters['mop'] != null && _activeFilters['mop']!.isNotEmpty) {
        final mop = inv.mop.isNotEmpty ? inv.mop : '(blank)';
        if (!_activeFilters['mop']!.contains(mop)) return false;
      }
      if (_activeFilters['customer'] != null && _activeFilters['customer']!.isNotEmpty) {
        final cust = inv.customerName.isNotEmpty ? inv.customerName : '(blank)';
        if (!_activeFilters['customer']!.contains(cust)) return false;
      }
      if (_activeFilters['invoiceNumber'] != null && _activeFilters['invoiceNumber']!.isNotEmpty) {
        final invNum = inv.invoiceNumber.isNotEmpty ? inv.invoiceNumber : '(blank)';
        if (!_activeFilters['invoiceNumber']!.contains(invNum)) return false;
      }
      if (_activeFilters['zipCode'] != null && _activeFilters['zipCode']!.isNotEmpty) {
        final zip = inv.zipCode.isNotEmpty ? inv.zipCode : '(blank)';
        if (!_activeFilters['zipCode']!.contains(zip)) return false;
      }
      return true;
    }).toList();

    // Re-calculate statistics based on filtered results
    double totalRevenue = 0.0;
    final technicians = <String>{};
    double cashRevenue = 0.0;
    double upiRevenue = 0.0;
    double otherRevenue = 0.0;

    for (final inv in filteredInvoices) {
      totalRevenue += inv.totalAmount;
      if (inv.technicianName.isNotEmpty) {
        technicians.add(inv.technicianName);
      }
      final mopUpper = inv.mop.toUpperCase();
      if (mopUpper == 'CASH') {
        cashRevenue += inv.totalAmount;
      } else if (mopUpper == 'UPI') {
        upiRevenue += inv.totalAmount;
      } else {
        otherRevenue += inv.totalAmount;
      }
    }
    int totalInvoices = filteredInvoices.length;
    int totalTechnicians = technicians.length;

    // Compute pivot summary based on filtered results
    final techMap = <String, double>{};
    for (final inv in filteredInvoices) {
      final name = inv.technicianName.isNotEmpty ? inv.technicianName : 'Unknown';
      techMap[name] = (techMap[name] ?? 0.0) + inv.totalAmount;
    }
    final pivotSummary = techMap.entries
        .map((e) => TechnicianPivot(e.key, e.value))
        .toList();
    pivotSummary.sort((a, b) => b.amount.compareTo(a.amount));

    // Sort the list
    final sortedInvoices = List<InvoiceModel>.from(filteredInvoices);
    if (_sortColumn.isNotEmpty) {
      sortedInvoices.sort((a, b) {
        final valA = _getSortVal(a, _sortColumn);
        final valB = _getSortVal(b, _sortColumn);
        if (valA is DateTime && valB is DateTime) {
          return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
        }
        if (valA is num && valB is num) {
          return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
        }
        return _sortAscending 
            ? valA.toString().compareTo(valB.toString()) 
            : valB.toString().compareTo(valA.toString());
      });
    }

    final totalRows = sortedInvoices.length;
    final totalPages = (totalRows / _rowsPerPage).ceil();
    final int startIdx = (_currentPage - 1) * _rowsPerPage;
    int endIdx = startIdx + _rowsPerPage;
    if (endIdx > totalRows) endIdx = totalRows;

    final paginatedInvoices = (totalRows > 0) 
        ? sortedInvoices.sublist(startIdx, endIdx) 
        : <InvoiceModel>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtitle Tagline
            Text(
              'Real-time financial audits, payment distribution charts, technician earnings, and export logs.',
              style: TextStyle(
                fontSize: 14,
                color: AdminTheme.textSecondary.withOpacity(0.8),
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 32),

            // 1. KPI Aggregate Summary Cards Section
            _buildSummaryStats(
              totalRevenue: totalRevenue,
              totalInvoices: totalInvoices,
              totalTechnicians: totalTechnicians,
              cashRevenue: cashRevenue,
              upiRevenue: upiRevenue,
              otherRevenue: otherRevenue,
            ),
            const SizedBox(height: 32),

            // 2. Main Split View: Records Table & Technician Grouped summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Detailed Records Table
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: AdminTheme.glassBox(radius: 12, opacity: 0.15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header section with total rows & export Excel button
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Invoice Revenue Logs ($totalRows Records Found)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminTheme.primaryYellow,
                                  foregroundColor: AdminTheme.darkBackground,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: () => _exportExcelReport(context, report),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text(
                                  'Export to Excel',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AdminTheme.borderColor),

                        // Main custom table
                        _buildInvoicesTable(paginatedInvoices, report.isLoading),

                        // Pagination controls footer
                        if (totalPages > 1) ...[
                          const Divider(height: 1, color: AdminTheme.borderColor),
                          _buildPaginationFooter(totalPages),
                        ]
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 32),

                // Technician Summary (Pivot) Pane
                SizedBox(
                  width: 340,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AdminTheme.glassBox(radius: 12, opacity: 0.15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Technician Revenue Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aggregated pivot calculations per worker.',
                          style: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.6), fontSize: 11, fontFamily: 'Poppins'),
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: AdminTheme.borderColor),
                        
                        // Pivot Rows
                        if (pivotSummary.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Center(
                              child: Text(
                                'No worker summaries available.',
                                style: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.4), fontFamily: 'Poppins', fontSize: 13),
                              ),
                            ),
                          )
                        else ...[
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pivotSummary.length,
                            separatorBuilder: (_, __) => const Divider(color: AdminTheme.borderColor, height: 1),
                            itemBuilder: (context, idx) {
                              final p = pivotSummary[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins', fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '₹${p.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryYellow, fontFamily: 'Poppins', fontSize: 14),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const Divider(color: AdminTheme.borderColor, height: 1),
                          Padding(
                            padding: const EdgeInsets.only(top: 18.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Grand Total',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Poppins', fontSize: 15),
                                ),
                                Text(
                                  '₹${totalRevenue.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryYellow, fontFamily: 'Poppins', fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Aggregate stats cards
  Widget _buildSummaryStats({
    required double totalRevenue,
    required int totalInvoices,
    required int totalTechnicians,
    required double cashRevenue,
    required double upiRevenue,
    required double otherRevenue,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Render responsive grid
        final double width = (constraints.maxWidth - 5 * 24) / 6;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(2)}', Icons.account_balance_wallet_rounded, AdminTheme.primaryYellow),
            _buildStatCard('Total Invoices', totalInvoices.toString(), Icons.receipt_long_rounded, AdminTheme.accentEmerald),
            _buildStatCard('Total Technicians', totalTechnicians.toString(), Icons.badge_rounded, Colors.blue),
            _buildStatCard('Cash Revenue', '₹${cashRevenue.toStringAsFixed(2)}', Icons.payments_rounded, Colors.amber),
            _buildStatCard('UPI Revenue', '₹${upiRevenue.toStringAsFixed(2)}', Icons.qr_code_2_rounded, Colors.purple),
            _buildStatCard('Other Revenue', '₹${otherRevenue.toStringAsFixed(2)}', Icons.credit_card_rounded, Colors.cyan),
          ].map((w) => SizedBox(width: width > 120 ? width : 120, child: w)).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.glassBox(radius: 12, opacity: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AdminTheme.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Poppins',
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Paginated Data Table UI
  Widget _buildInvoicesTable(List<InvoiceModel> invoices, bool loading) {
    if (loading && invoices.isEmpty) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: AdminTheme.primaryYellow)),
      );
    }

    if (invoices.isEmpty) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off_rounded, color: AdminTheme.textSecondary.withOpacity(0.4), size: 48),
              const SizedBox(height: 16),
              const Text(
                'No revenue invoices match current filters.',
                style: TextStyle(color: AdminTheme.textSecondary, fontSize: 15, fontFamily: 'Poppins'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header row (Sortable and Filterable columns)
          Container(
            color: AdminTheme.darkSurface,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                _buildHeaderCell('Invoice Number', 'invoiceNumber', 160, hasFilter: true),
                _buildHeaderCell('Invoice Date', 'date', 130),
                _buildHeaderCell('Technician Name', 'technician', 180, hasFilter: true),
                _buildHeaderCell('Customer Name', 'customer', 180, hasFilter: true),
                _buildHeaderCell('Case Number', 'caseId', 150),
                _buildHeaderCell('Zip / Postal Code', 'zipCode', 130, hasFilter: true),
                _buildHeaderCell('Product Description', 'brand', 180),
                _buildHeaderCell('Part Description', 'parts', 260),
                _buildHeaderCell('Product Item / ASP Price', 'itemPrice', 180, textAlign: TextAlign.right),
                _buildHeaderCell('Remark', 'remark', 180),
                _buildHeaderCell('MOP', 'mop', 110, hasFilter: true),
                _buildHeaderCell('Amount', 'amount', 130, textAlign: TextAlign.right),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminTheme.borderColor),

          // Invoices detail records rows
          SizedBox(
            width: 1980, // Sum of cell widths (160+130+180+180+150+130+180+260+180+180+110+130)
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AdminTheme.borderColor),
              itemBuilder: (context, idx) {
                final inv = invoices[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: idx % 2 == 0 ? AdminTheme.darkSurface.withOpacity(0.3) : Colors.transparent,
                  child: Row(
                    children: [
                      // Invoice Number
                      SizedBox(
                        width: 160,
                        child: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13, fontFamily: 'Poppins')),
                      ),
                      // Date
                      SizedBox(
                        width: 130,
                        child: Text(DateFormat('dd/MM/yyyy').format(inv.createdAt.toLocal()), style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontFamily: 'Poppins')),
                      ),
                      // Technician
                      SizedBox(
                        width: 180,
                        child: Text(inv.technicianName.isNotEmpty ? inv.technicianName : 'N/A', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis),
                      ),
                      // Customer
                      SizedBox(
                        width: 180,
                        child: Text(inv.customerName, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis),
                      ),
                      // Case ID
                      SizedBox(
                        width: 150,
                        child: Text(inv.caseId ?? '-', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontFamily: 'Poppins')),
                      ),
                      // Zip Code
                      SizedBox(
                        width: 130,
                        child: Text(inv.zipCode, style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontFamily: 'Poppins')),
                      ),
                      // Brand
                      SizedBox(
                        width: 180,
                        child: Text(inv.brand ?? 'Atomberg', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins')),
                      ),
                      // Parts Description
                      SizedBox(
                        width: 260,
                        child: Text(inv.partDescription ?? 'N/A', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis),
                      ),
                      // Unit Price
                      SizedBox(
                        width: 180,
                        child: Text('₹${(inv.productItemPrice ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'), textAlign: TextAlign.right),
                      ),
                      // Remark
                      SizedBox(
                        width: 180,
                        child: Text(inv.remark.isNotEmpty ? inv.remark : '-', style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 13, fontFamily: 'Poppins'), overflow: TextOverflow.ellipsis),
                      ),
                      // MOP
                      SizedBox(
                        width: 110,
                        child: _buildMopTag(inv.mop),
                      ),
                      // Amount
                      SizedBox(
                        width: 130,
                        child: Text('₹${inv.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryYellow, fontSize: 13, fontFamily: 'Poppins'), textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, String key, double width, {bool hasFilter = false, TextAlign textAlign = TextAlign.left}) {
    final bool isSorted = _sortColumn == key;
    final bool isFiltered = _activeFilters[key] != null && _activeFilters[key]!.isNotEmpty;

    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: textAlign == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Header Text & Sort Trigger
          InkWell(
            onTap: () => _onSort(key),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AdminTheme.primaryYellow,
                    fontFamily: 'Poppins',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isSorted 
                      ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) 
                      : Icons.swap_vert_rounded,
                  size: 13,
                  color: isSorted ? AdminTheme.primaryYellow : AdminTheme.textSecondary.withOpacity(0.4),
                ),
              ],
            ),
          ),
          
          if (hasFilter) ...[
            const SizedBox(width: 4),
            // Excel-style filter trigger icon
            InkWell(
              onTap: () => _showFilterPopup(context, key, text),
              child: Icon(
                isFiltered ? Icons.filter_alt_rounded : Icons.arrow_drop_down_rounded,
                size: 16,
                color: isFiltered ? AdminTheme.primaryYellow : AdminTheme.textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMopTag(String mop) {
    Color tagColor = Colors.grey;
    final String up = mop.toUpperCase();
    if (up == 'CASH') {
      tagColor = Colors.amber;
    } else if (up == 'UPI') {
      tagColor = Colors.purple;
    } else if (up.contains('BANK') || up.contains('TRANSFER')) {
      tagColor = Colors.blue;
    } else {
      tagColor = Colors.cyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.15),
        border: Border.all(color: tagColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        mop,
        style: TextStyle(color: tagColor, fontWeight: FontWeight.bold, fontSize: 10, fontFamily: 'Poppins'),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPaginationFooter(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage of $totalPages',
            style: const TextStyle(color: AdminTheme.textSecondary, fontSize: 12, fontFamily: 'Poppins'),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: _currentPage > 1 
                    ? () => setState(() => _currentPage--) 
                    : null,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: _currentPage < totalPages 
                    ? () => setState(() => _currentPage++) 
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Export spreadsheet controller interface
  Future<void> _exportExcelReport(BuildContext context, ReportProvider report) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Preparing and formatting Excel sheet...', style: TextStyle(color: AdminTheme.darkBackground, fontWeight: FontWeight.bold)),
        backgroundColor: AdminTheme.primaryYellow,
        behavior: SnackBarBehavior.floating,
        width: 320,
      ),
    );

    final success = await report.exportToExcel();
    
    if (mounted) {
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Excel report downloaded and saved successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AdminTheme.accentEmerald,
            behavior: SnackBarBehavior.floating,
            width: 380,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Excel export cancelled or failed.', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AdminTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            width: 320,
          ),
        );
      }
    }
  }
}

// Excel-style filter popup dialog
class _ExcelFilterDialog extends StatefulWidget {
  final String columnKey;
  final String title;
  final List<String> allItems;
  final Set<String> selectedItems;
  final Function(Set<String>) onChanged;

  const _ExcelFilterDialog({
    required this.columnKey,
    required this.title,
    required this.allItems,
    required this.selectedItems,
    required this.onChanged,
  });

  @override
  State<_ExcelFilterDialog> createState() => _ExcelFilterDialogState();
}

class _ExcelFilterDialogState extends State<_ExcelFilterDialog> {
  String _searchQuery = '';
  late Set<String> _tempSelected;

  @override
  void initState() {
    super.initState();
    // Excel behavior: if no filters applied, all items are checked by default
    if (widget.selectedItems.isEmpty) {
      _tempSelected = Set.from(widget.allItems);
    } else {
      _tempSelected = Set.from(widget.selectedItems);
    }
  }

  void _updateParent() {
    if (_tempSelected.length == widget.allItems.length) {
      widget.onChanged({});
    } else {
      widget.onChanged(_tempSelected);
    }
  }

  bool get _isSelectAllChecked {
    final searchFilteredItems = widget.allItems.where((item) {
      return item.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    if (searchFilteredItems.isEmpty) return false;
    return searchFilteredItems.every((item) => _tempSelected.contains(item));
  }

  void _toggleSelectAll(bool? checked) {
    final searchFilteredItems = widget.allItems.where((item) {
      return item.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    
    setState(() {
      if (checked == true) {
        _tempSelected.addAll(searchFilteredItems);
      } else {
        _tempSelected.removeAll(searchFilteredItems);
      }
    });
    _updateParent();
  }

  void _clearFilter() {
    setState(() {
      _tempSelected = Set.from(widget.allItems);
      _searchQuery = '';
    });
    _updateParent();
  }

  @override
  Widget build(BuildContext context) {
    final searchFilteredItems = widget.allItems.where((item) {
      return item.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: AdminTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminTheme.borderColor),
      ),
      child: Container(
        width: 320,
        height: 450,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter by ${widget.title}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search box
            TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AdminTheme.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                fillColor: AdminTheme.secondaryBg,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AdminTheme.primaryYellow),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Select All Row
            CheckboxListTile(
              title: const Text(
                '(Select All)',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Poppins'),
              ),
              value: _isSelectAllChecked,
              activeColor: AdminTheme.primaryYellow,
              checkColor: AdminTheme.darkBackground,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              onChanged: _toggleSelectAll,
            ),
            const Divider(color: AdminTheme.borderColor, height: 1),

            // Scrollable Checklist
            Expanded(
              child: searchFilteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No items found.',
                        style: TextStyle(color: AdminTheme.textSecondary.withOpacity(0.4), fontFamily: 'Poppins', fontSize: 12),
                      ),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        itemCount: searchFilteredItems.length,
                        itemBuilder: (context, idx) {
                          final item = searchFilteredItems[idx];
                          final isChecked = _tempSelected.contains(item);
                          return CheckboxListTile(
                            title: Text(
                              item,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Poppins'),
                            ),
                            value: isChecked,
                            activeColor: AdminTheme.primaryYellow,
                            checkColor: AdminTheme.darkBackground,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _tempSelected.add(item);
                                } else {
                                  _tempSelected.remove(item);
                                }
                              });
                              _updateParent();
                            },
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Clear Filter Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.secondaryBg,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AdminTheme.borderColor),
                ),
                elevation: 0,
              ),
              onPressed: _clearFilter,
              child: const Text(
                'Clear Filter',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
