import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../models/upload_history.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _apiService;

  int _totalProducts = 0;
  int _totalStock = 0;
  DateTime? _lastStockUpload;
  DateTime? _lastPriceUpload;
  bool _isLoading = false;
  String? _errorMessage;

  List<UploadHistory> _stockHistory = [];
  List<UploadHistory> _priceHistory = [];

  WebSocketChannel? _wsChannel;
  bool _isConnectingWs = false;
  Timer? _wsReconnectTimer;
  bool _disposed = false;

  DashboardProvider(this._apiService);

  int get totalProducts => _totalProducts;
  int get totalStock => _totalStock;
  DateTime? get lastStockUpload => _lastStockUpload;
  DateTime? get lastPriceUpload => _lastPriceUpload;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<UploadHistory> get stockHistory => _stockHistory;
  List<UploadHistory> get priceHistory => _priceHistory;

  /// Closes active WebSocket connection and reconnect timer
  void closeWebSocket() {
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnectingWs = false;
  }

  /// Initializes secure WebSocket connection for dashboard telemetry updates
  Future<void> initWebSocket() async {
    if (_disposed) return;
    
    // Check if we are already connecting or connected
    if (_wsChannel != null || _isConnectingWs) return;

    _isConnectingWs = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('admin_token');

      if (token == null || token.isEmpty) {
        debugPrint('Dashboard WebSocket initialization skipped: Missing token');
        _isConnectingWs = false;
        return;
      }

      final wsUriStr = '${ApiService.wsUrl}/api/admin/dashboard/live?token=$token';
      debugPrint('Connecting to Dashboard WebSocket: $wsUriStr');

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUriStr));
      _isConnectingWs = false;

      _wsChannel!.stream.listen(
        (message) {
          _handleWsMessage(message);
        },
        onError: (err) {
          debugPrint('Dashboard WebSocket encountered error: $err');
          _scheduleWsReconnect();
        },
        onDone: () {
          debugPrint('Dashboard WebSocket connection closed.');
          _scheduleWsReconnect();
        },
        cancelOnError: true,
      );

    } catch (e) {
      debugPrint('Failed to initialize Dashboard WebSocket connection: $e');
      _isConnectingWs = false;
      _scheduleWsReconnect();
    }
  }

  void _handleWsMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      
      _totalProducts = data['totalProducts'] ?? 0;
      _totalStock = data['totalStock'] ?? 0;
      
      _lastStockUpload = data['lastStockUpload'] != null 
          ? DateTime.parse(data['lastStockUpload'] as String).toLocal() 
          : null;
          
      _lastPriceUpload = data['lastPriceUpload'] != null 
          ? DateTime.parse(data['lastPriceUpload'] as String).toLocal() 
          : null;

      debugPrint('Dashboard stats updated in real-time: Total Products = $_totalProducts, Total Stock = $_totalStock');
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing Dashboard WebSocket message: $e');
    }
  }

  void _scheduleWsReconnect() {
    if (_disposed) return;
    
    _wsChannel = null;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('Attempting to reconnect Dashboard WebSocket...');
      initWebSocket();
    });
  }

  /// Loads card aggregates from the database
  Future<void> fetchDashboardStats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final stats = await _apiService.getDashboardStats();
      _totalProducts = stats['totalProducts'] ?? 0;
      _totalStock = stats['totalStock'] ?? 0;
      
      _lastStockUpload = stats['lastStockUpload'] != null 
          ? DateTime.parse(stats['lastStockUpload']).toLocal() 
          : null;
          
      _lastPriceUpload = stats['lastPriceUpload'] != null 
          ? DateTime.parse(stats['lastPriceUpload']).toLocal() 
          : null;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads full logs for both daily stock uploads and price updates
  Future<void> fetchHistories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _stockHistory = await _apiService.getStockHistory();
      _priceHistory = await _apiService.getPriceHistory();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Unified dashboard reload
  Future<void> refreshDashboard() async {
    await fetchDashboardStats();
    await fetchHistories();
    initWebSocket(); // Ensure real-time connection is active
  }

  @override
  void dispose() {
    _disposed = true;
    closeWebSocket();
    super.dispose();
  }
}
