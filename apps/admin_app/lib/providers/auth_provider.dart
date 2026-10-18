import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
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

  /// Restores session securely on startup
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _adminEmail = prefs.getString('admin_email');

      // 1. Read token securely from Keychain / DPAPI
      _token = await _secureStorage.read(key: 'admin_token');

      // 2. Migration fallback from legacy plaintext SharedPreferences
      if (_token == null || _token!.isEmpty) {
        final legacyToken = prefs.getString('admin_token');
        if (legacyToken != null && legacyToken.isNotEmpty) {
          _token = legacyToken;
          await _secureStorage.write(key: 'admin_token', value: legacyToken);
          await prefs.remove('admin_token');
        }
      }
      
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
      
      final token = result['token']?.toString() ?? '';
      final adminInfo = result['admin'];
      final adminEmail = adminInfo != null ? adminInfo['email']?.toString() : email;

      // Persist token in encrypted secure storage
      await _secureStorage.write(key: 'admin_token', value: token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_email', adminEmail ?? email);
      await prefs.remove('admin_token'); // Clean up any plaintext relic

      _token = token;
      _adminEmail = adminEmail ?? email;
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
      await _secureStorage.delete(key: 'admin_token');
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
      
      _secureStorage.delete(key: 'admin_token').catchError((_) {});
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
