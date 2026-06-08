import 'package:flutter/material.dart';
import '../services/shared_api_service.dart';
import '../models/invoice.dart';

class InvoiceProvider with ChangeNotifier {
  final SharedApiService _apiService = SharedApiService();
  List<InvoiceModel> _invoices = [];
  bool _isLoading = false;

  List<InvoiceModel> get invoices => _invoices;
  bool get isLoading => _isLoading;

  Future<void> fetchInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getInvoices();
      _invoices = data.map((item) => InvoiceModel.fromJson(item)).toList();
    } catch (e) {
      debugPrint("Error fetching invoices: $e");
      _invoices = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
