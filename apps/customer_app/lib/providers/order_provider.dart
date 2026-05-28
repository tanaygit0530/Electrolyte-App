import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_core/shared_core.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      _orders = await _apiService.getAllOrders();
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
