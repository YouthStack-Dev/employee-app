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
  Future<Map<String, dynamic>> triggerGenericSOS({int? bookingId}) async {
    final result = await _alertService.triggerSOSAlert(
      bookingId: bookingId, 
      notes: bookingId != null ? "Emergency triggered during booking #$bookingId" : "Emergency triggered from App"
    );
    return result;
  }
  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    // ------------------ ACTUAL API LOGIC ------------------
    final result = await _authService.sendOtp(phoneNumber);
    _isLoading = false;
    
    if (result['success']) {
       notifyListeners();
       return true;
    } else {
       _error = result['error'];
       notifyListeners();
       return false;
    }
  }

  Future<bool> verifyOtp(String phoneNumber, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. Verify OTP -> Get Pre-Auth Token & Tenant List
    final verifyResult = await _authService.verifyOtp(phoneNumber, otp);
    
    if (!verifyResult['success']) {
       _isLoading = false;
       _error = verifyResult['error'];
       notifyListeners();
       return false;
    }

    final data = verifyResult['data'];
    final preAuthToken = data['pre_auth_token'];
    final List availableTenants = data['available_tenants'] ?? [];

    if (availableTenants.isEmpty) {
       _isLoading = false;
       _error = 'No tenants found for this user.';
       notifyListeners();
       return false;
    }

    // 2. Auto-Select First Tenant (Assumption for current UI flow)
    final tenantId = availableTenants[0]['tenant_id'];

    // 3. Select Tenant -> Get Access Token & User Profile
    final loginResult = await _authService.selectTenant(preAuthToken, tenantId);

    _isLoading = false;
    if (loginResult['success']) {
      _user = loginResult['user'];
      _error = null;
      notifyListeners();
      await NotificationService().registerToken();
      return true;
    } else {
      _error = loginResult['error'];
      notifyListeners();
      return false;
    }
  }
}
