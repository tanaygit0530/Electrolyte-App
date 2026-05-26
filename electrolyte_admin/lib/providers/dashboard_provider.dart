import 'package:flutter/material.dart';
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

  DashboardProvider(this._apiService);

  int get totalProducts => _totalProducts;
  int get totalStock => _totalStock;
  DateTime? get lastStockUpload => _lastStockUpload;
  DateTime? get lastPriceUpload => _lastPriceUpload;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<UploadHistory> get stockHistory => _stockHistory;
  List<UploadHistory> get priceHistory => _priceHistory;

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
  }
}
