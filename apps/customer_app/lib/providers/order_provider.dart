import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';

class OrderProvider with ChangeNotifier {
  final SharedApiService _apiService;
  List<OrderModel> _orders = [];
  bool _isLoading = false;

  OrderProvider([SharedApiService? apiService])
      : _apiService = apiService ?? SharedApiService();

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
