import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final AlertService _alertService = AlertService();
  User? _user;

  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> login(String tenantId, String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.login(tenantId, username, password);

    _isLoading = false;
    if (result['success']) {
      _user = result['user'];
      _error = null;
      notifyListeners();
      
      // Register Push Token
      await NotificationService().registerToken();
      
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Unregister Push Token
    await NotificationService().unregisterToken();
    
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final tenantId = prefs.getString('tenant_id');
    final employeeId = prefs.getString('employee_id');

    if (token != null && tenantId != null && employeeId != null) {
      // Restore user session if needed, or just return true to allow navigation
      // Ideally we would fetch user profile here if we want to populate _user
      return true;
    }
    return false;
  }
  Future<Map<String, dynamic>> triggerGenericSOS() async {
    final result = await _alertService.triggerSOSAlert(
      bookingId: null, 
      notes: "Emergency triggered from Login Screen"
    );
    return result;
  }
}
