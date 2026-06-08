import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _apiService;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  UserProvider(this._apiService) {
    fetchUsers();
  }

  List<Map<String, dynamic>> get users => _users;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _users = await _apiService.getUsers();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _users = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser(String email, String password, String role) async {
    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.createUser(email.trim(), password, role);
      _isCreating = false;
      notifyListeners();
      await fetchUsers(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isCreating = false;
      notifyListeners();
      return false;
    }
  }
}
