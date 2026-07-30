import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../utils/file_saver.dart';

class TechnicianPivot {
  final String name;
  final double amount;
  TechnicianPivot(this.name, this.amount);
}

class ReportProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<InvoiceModel> _invoices = [];
  List<String> _techniciansList = [];
  List<TechnicianPivot> _pivotSummary = [];
  
  bool _isLoading = false;
  String? _errorMessage;

  // Aggregate Metrics
  double _totalRevenue = 0.0;
  int _totalInvoices = 0;
  int _totalTechnicians = 0;
  double _cashRevenue = 0.0;
  double _upiRevenue = 0.0;
  double _otherRevenue = 0.0;

  // Active Filters state
  List<String> _selectedTechnicians = [];
  List<String> _selectedMops = [];
  String _dateRange = 'thisMonth';
  DateTime? _startDate;
  DateTime? _endDate;
  String _customerSearch = '';
  String _invoiceSearch = '';

  // WebSocket support
  WebSocketChannel? _wsChannel;
  bool _isConnectingWs = false;
  Timer? _wsReconnectTimer;
  bool _disposed = false;

  ReportProvider(this._apiService);

  // Getters
  List<InvoiceModel> get invoices => _invoices;
  List<String> get techniciansList => _techniciansList;
  List<TechnicianPivot> get pivotSummary => _pivotSummary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get totalRevenue => _totalRevenue;
  int get totalInvoices => _totalInvoices;
  int get totalTechnicians => _totalTechnicians;
  double get cashRevenue => _cashRevenue;
  double get upiRevenue => _upiRevenue;
  double get otherRevenue => _otherRevenue;

  List<String> get selectedTechnicians => _selectedTechnicians;
  List<String> get selectedMops => _selectedMops;
  String get dateRange => _dateRange;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String get customerSearch => _customerSearch;
  String get invoiceSearch => _invoiceSearch;

  // Setters for filters
  void setSelectedTechnicians(List<String> list) {
    _selectedTechnicians = list;
    fetchReport();
  }

  void setSelectedMops(List<String> list) {
    _selectedMops = list;
    fetchReport();
  }

  void setDateRange(String value) {
    _dateRange = value;
    if (value != 'custom') {
      _startDate = null;
      _endDate = null;
    }
    fetchReport();
  }

  void setCustomDates(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    _dateRange = 'custom';
    fetchReport();
  }

  void setCustomerSearch(String query) {
    _customerSearch = query;
    fetchReport();
  }

  void setInvoiceSearch(String query) {
    _invoiceSearch = query;
    fetchReport();
  }

  void resetFilters() {
    _selectedTechnicians = [];
    _selectedMops = [];
    _dateRange = 'thisMonth';
    _startDate = null;
    _endDate = null;
    _customerSearch = '';
    _invoiceSearch = '';
    fetchReport();
  }

  Map<String, dynamic> _getFilterParams() {
    final params = <String, dynamic>{};
    
    if (_selectedTechnicians.isNotEmpty) {
      params['technicians'] = _selectedTechnicians.join(',');
    }
    if (_selectedMops.isNotEmpty) {
      params['mops'] = _selectedMops.join(',');
    }
    params['dateRange'] = _dateRange;
    if (_dateRange == 'custom') {
      if (_startDate != null) {
        params['startDate'] = _startDate!.toIso8601String().split('T').first;
      }
      if (_endDate != null) {
        params['endDate'] = _endDate!.toIso8601String().split('T').first;
      }
    }
    if (_customerSearch.trim().isNotEmpty) {
      params['customerSearch'] = _customerSearch.trim();
    }
    if (_invoiceSearch.trim().isNotEmpty) {
      params['invoiceSearch'] = _invoiceSearch.trim();
    }
    
    return params;
  }

  /// Fetch Technician Revenue Report
  Future<void> fetchReport({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final data = await _apiService.getTechnicianRevenueReport(_getFilterParams());
      
      // Parse Invoices
      final list = data['invoices'] as List? ?? [];
      _invoices = list.map((item) => InvoiceModel.fromJson(Map<String, dynamic>.from(item))).toList();
      
      // Parse techniciansList
      final techs = data['techniciansList'] as List? ?? [];
      _techniciansList = techs.map((e) => e.toString()).toList();
      
      // Parse summary stats
      final summary = data['summary'] as Map<String, dynamic>? ?? {};
      _totalRevenue = double.tryParse(summary['totalRevenue']?.toString() ?? '0') ?? 0.0;
      _totalInvoices = int.tryParse(summary['totalInvoices']?.toString() ?? '0') ?? 0;
      _totalTechnicians = int.tryParse(summary['totalTechnicians']?.toString() ?? '0') ?? 0;
      _cashRevenue = double.tryParse(summary['cashRevenue']?.toString() ?? '0') ?? 0.0;
      _upiRevenue = double.tryParse(summary['upiRevenue']?.toString() ?? '0') ?? 0.0;
      _otherRevenue = double.tryParse(summary['otherRevenue']?.toString() ?? '0') ?? 0.0;

      // Compute Pivot summary
      final techMap = <String, double>{};
      for (final inv in _invoices) {
        final name = inv.technicianName.isNotEmpty ? inv.technicianName : 'Unknown';
        techMap[name] = (techMap[name] ?? 0.0) + inv.totalAmount;
      }
      _pivotSummary = techMap.entries
          .map((e) => TechnicianPivot(e.key, e.value))
          .toList();
      _pivotSummary.sort((a, b) => b.amount.compareTo(a.amount));

    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      debugPrint('ReportProvider Fetch Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Download Excel Report
  Future<bool> exportToExcel() async {
    try {
      final response = await _apiService.exportExcelReport(_getFilterParams());
      final bytes = response.data as List<int>;
      
      final now = DateTime.now();
      final dd = now.day.toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final yyyy = now.year.toString();
      final defaultFileName = 'OW_Report_$dd-$mm-$yyyy.xlsx';

      return await saveReportFile(bytes, defaultFileName);
    } catch(e) {
      debugPrint('Excel Export Error: $e');
      return false;
    }
  }

  /// WebSocket Real-time Listener Initialization
  Future<void> initWebSocket() async {
    if (_disposed) return;
    if (_wsChannel != null || _isConnectingWs) return;

    _isConnectingWs = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('admin_token');

      if (token == null || token.isEmpty) {
        _isConnectingWs = false;
        return;
      }

      final wsUriStr = '${ApiService.wsUrl}/api/admin/dashboard/live?token=$token';
      debugPrint('Reports WebSocket connecting: $wsUriStr');

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUriStr));
      _isConnectingWs = false;

      _wsChannel!.stream.listen(
        (message) {
          _handleWsMessage(message);
        },
        onError: (err) {
          debugPrint('Reports WebSocket error: $err');
          _scheduleWsReconnect();
        },
        onDone: () {
          debugPrint('Reports WebSocket closed.');
          _scheduleWsReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Failed to init Reports WebSocket: $e');
      _isConnectingWs = false;
      _scheduleWsReconnect();
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      
      if (data['type'] == 'invoice_update') {
        debugPrint('WebSocket received invoice_update notification! Refreshing report silently...');
        fetchReport(silent: true);
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void _scheduleWsReconnect() {
    if (_disposed) return;
    
    _wsChannel = null;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('Attempting to reconnect Reports WebSocket...');
      initWebSocket();
    });
  }

  void closeWebSocket() {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnectingWs = false;
  }

  @override
  void dispose() {
    _disposed = true;
    closeWebSocket();
    super.dispose();
  }
}
