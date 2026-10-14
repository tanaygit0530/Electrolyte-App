import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_core/shared_core.dart';

class AuthProvider extends ChangeNotifier {
  final SharedApiService _apiService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _sessionExpired = false;
  String? _email;
  int? _id;
  String? _role;
  String? _phone;
  String? _token;
  String? _errorMessage;

  AuthProvider(this._apiService) {
    _apiService.onSessionExpired = _handleSessionExpired;
    checkAuthStatus();
  }

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get sessionExpired => _sessionExpired;
  String? get email => _email;
  int? get id => _id;
  String get role => (_role != null && _role!.isNotEmpty)
      ? '${_role![0].toUpperCase()}${_role!.substring(1)}'
      : 'Technician';
  String? get phone => _phone;
  String? get token => _token;
  String? get errorMessage => _errorMessage;

  String get name => _getNameFromEmail(_email);

  String _getNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return "Technician";
    final part = email.split('@')[0];
    final words = part.split(RegExp(r'[\._-]'));
    return words.map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _email = prefs.getString('customer_email');
      _id = prefs.getInt('customer_id');
      _role = prefs.getString('customer_role');
      _phone = prefs.getString('customer_phone');

      // 1. Read token from secure Keychain/Keystore
      _token = await _secureStorage.read(key: 'customer_token');

      // 2. Migration fallback from legacy plaintext SharedPreferences
      if (_token == null || _token!.isEmpty) {
        final legacyToken = prefs.getString('customer_token');
        if (legacyToken != null && legacyToken.isNotEmpty) {
          _token = legacyToken;
          await _secureStorage.write(key: 'customer_token', value: legacyToken);
          await prefs.remove('customer_token');
        }
      }

      if (_token != null && _token!.isNotEmpty) {
        _isAuthenticated = true;
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();

    try {
      final result = await _apiService.login(email.trim(), password);
      
      final token = result['token'] as String;
      final userInfo = result['user'];
      final userEmail = userInfo != null ? userInfo['email'] as String : email;
      final userRole = userInfo != null ? (userInfo['role'] as String? ?? 'technician') : 'technician';
      final userPhone = userInfo != null ? userInfo['phone'] as String? : null;
      
      int? userId;
      if (userInfo != null && userInfo['id'] != null) {
        userId = userInfo['id'] as int;
      }

      // Secure storage write
      await _secureStorage.write(key: 'customer_token', value: token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_email', userEmail);
      await prefs.setString('customer_role', userRole);
      if (userPhone != null) {
        await prefs.setString('customer_phone', userPhone);
      }
      if (userId != null) {
        await prefs.setInt('customer_id', userId);
      }

      _token = token;
      _email = userEmail;
      _id = userId;
      _role = userRole;
      _phone = userPhone;
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

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _secureStorage.delete(key: 'customer_token');
      _apiService.resetClient();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_email');
      await prefs.remove('customer_id');
      await prefs.remove('customer_role');
      await prefs.remove('customer_phone');

      _token = null;
      _email = null;
      _id = null;
      _role = null;
      _phone = null;
      _isAuthenticated = false;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleSessionExpired() {
    if (_isAuthenticated) {
      _token = null;
      _email = null;
      _id = null;
      _isAuthenticated = false;
      _sessionExpired = true;

      _secureStorage.delete(key: 'customer_token');
      _apiService.resetClient();

      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('customer_email');
        prefs.remove('customer_id');
      });

      notifyListeners();
    }
  }

  void resetSessionExpiredFlag() {
    _sessionExpired = false;
    notifyListeners();
  }
}
