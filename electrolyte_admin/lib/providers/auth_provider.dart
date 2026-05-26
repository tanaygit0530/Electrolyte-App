import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _sessionExpired = false;
  String? _adminEmail;
  String? _token;
  String? _errorMessage;

  AuthProvider(this._apiService) {
    // Register the session expiration interceptor callback
    _apiService.onSessionExpired = _handleSessionExpired;
    checkAuthStatus();
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get sessionExpired => _sessionExpired;
  String? get adminEmail => _adminEmail;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  /// Restores session from local storage on startup
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('admin_token');
      _adminEmail = prefs.getString('admin_email');
      
      if (_token != null && _token!.isNotEmpty) {
        _isAuthenticated = true;
      }
    } catch (e) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Secure credentials login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();

    try {
      final result = await _apiService.login(email, password);
      
      final token = result['token'];
      final adminInfo = result['admin'];
      final adminEmail = adminInfo != null ? adminInfo['email'] : email;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', token);
      await prefs.setString('admin_email', adminEmail);

      _token = token;
      _adminEmail = adminEmail;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear session credentials
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('admin_token');
      await prefs.remove('admin_email');

      _token = null;
      _adminEmail = null;
      _isAuthenticated = false;
    } catch (e) {
      // Handle cache eviction error silently
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Session expired handler triggered by the API response interceptor
  void _handleSessionExpired() {
    if (_isAuthenticated) {
      _token = null;
      _adminEmail = null;
      _isAuthenticated = false;
      _sessionExpired = true;
      
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('admin_token');
        prefs.remove('admin_email');
      });
      
      notifyListeners();
    }
  }

  void resetSessionExpiredFlag() {
    _sessionExpired = false;
    notifyListeners();
  }
}
