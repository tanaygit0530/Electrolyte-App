import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_api_service.dart';
import '../models/invoice.dart';

class InvoiceProvider with ChangeNotifier {
  final SharedApiService _apiService = SharedApiService();
  List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  bool _isUsingCache = false;
  DateTime? _lastCacheTime;

  List<InvoiceModel> get invoices => _invoices;
  bool get isLoading => _isLoading;
  bool get isUsingCache => _isUsingCache;
  DateTime? get lastCacheTime => _lastCacheTime;

  Future<void> fetchInvoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _apiService.getInvoices();
      _invoices = data.map((item) => InvoiceModel.fromJson(item)).toList();
      _isUsingCache = false;
      _lastCacheTime = DateTime.now();

      // Persist to local cache for offline availability
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_invoices_data', json.encode(data));
        await prefs.setString('cached_invoices_time', _lastCacheTime!.toIso8601String());
      } catch (cacheErr) {
        debugPrint("Error writing invoices to cache: $cacheErr");
      }
    } catch (e) {
      debugPrint("Error fetching invoices online: $e. Falling back to local cache.");
      // Attempt to load from offline cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('cached_invoices_data');
        final cachedTimeStr = prefs.getString('cached_invoices_time');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final List<dynamic> cachedData = json.decode(cachedJson);
          _invoices = cachedData.map((item) => InvoiceModel.fromJson(item)).toList();
          _isUsingCache = true;
          if (cachedTimeStr != null) {
            _lastCacheTime = DateTime.tryParse(cachedTimeStr);
          }
        } else {
          _invoices = [];
        }
      } catch (cacheReadErr) {
        debugPrint("Error reading offline invoice cache: $cacheReadErr");
        _invoices = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
