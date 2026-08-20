import 'dart:convert';
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
  String? _passwordSetToken; // held in memory between forgot-verify and set-password

  // OTP multi-tenant flow
  List<Map<String, dynamic>>? _availableTenants;
  String? _preAuthToken;
  bool _needsTenantSelection = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get passwordSetToken => _passwordSetToken;
  List<Map<String, dynamic>>? get availableTenants => _availableTenants;
  bool get needsTenantSelection => _needsTenantSelection;

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
      
      // Register Push Token in background (don't block login)
      NotificationService().registerToken();
      
      return true;
    } else {
      _error = result['error'];
      notifyListeners();
      return false;
    }
  }

  // ---------------- Forgot password flow ----------------

  /// Step 1: request a reset OTP for {tenantId, email}.
  Future<bool> forgotPassword(String tenantId, String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _authService.forgotPassword(tenantId, email);
    _isLoading = false;
    if (result['success'] == true) {
      notifyListeners();
      return true;
    }
    _error = result['error'];
    notifyListeners();
    return false;
  }

  /// Step 2: verify the reset OTP. On success the session is established
  /// (tokens persisted by the service) and a one-time password_set_token is
  /// held for step 3.
  Future<bool> verifyForgotPassword(String tenantId, String email, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _authService.verifyForgotPassword(tenantId, email, otp);
    _isLoading = false;
    if (result['success'] == true) {
      _user = result['user'];
      _passwordSetToken = result['password_set_token']?.toString();
      notifyListeners();
      return true;
    }
    _error = result['error'];
    notifyListeners();
    return false;
  }

  /// Step 3: set the new password. On success the user is fully logged in;
  /// registers the push token like a normal login.
  Future<bool> setNewPassword(String newPassword, String confirmPassword) async {
    if (_passwordSetToken == null) {
      _error = 'Your reset session expired. Please start again.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await _authService.setNewPassword(
      passwordSetToken: _passwordSetToken!,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    _isLoading = false;
    if (result['success'] == true) {
      _passwordSetToken = null;
      NotificationService().registerToken();
      notifyListeners();
      return true;
    }
    _error = result['error'];
    notifyListeners();
    return false;
  }

  /// Tenants the employee can switch to (persisted at login per API docs —
  /// the list already excludes the current tenant).
  Future<List<Map<String, dynamic>>> getSwitchableTenants() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('available_tenants');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  /// POST /auth/employee/switch-tenant — swaps session to another tenant
  /// without re-authentication. Service persists new tokens + tenant config.
  Future<bool> switchTenant(String tenantId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.switchTenant(tenantId);

    _isLoading = false;
    if (result['success'] == true) {
      _user = result['user'];
      _error = null;
      notifyListeners();
      NotificationService().registerToken();
      return true;
    }
    _error = result['error'];
    notifyListeners();
    return false;
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

    final name = prefs.getString('name');
    final email = prefs.getString('email');
    final phone = prefs.getString('phone');
    final address = prefs.getString('address');
    final tenantName = prefs.getString('tenant_name');

    Map<String, dynamic>? rawEmployeeData;
    final raw = prefs.getString('raw_employee_data');
    if (raw != null) {
      try {
        rawEmployeeData = Map<String, dynamic>.from(jsonDecode(raw));
      } catch (_) {}
    }

    final savedLat = double.tryParse(prefs.getString('latitude') ?? '');
    final savedLng = double.tryParse(prefs.getString('longitude') ?? '');
    final latitude = savedLat ?? _toDouble(rawEmployeeData?['latitude']);
    final longitude = savedLng ?? _toDouble(rawEmployeeData?['longitude']);

    if (token != null && tenantId != null && employeeId != null) {
      _user = User(
        employeeId: int.tryParse(employeeId),
        tenantId: tenantId,
        gender: prefs.getString('gender'),
        name: name,
        email: email,
        phone: phone,
        address: address,
        tenantName: tenantName,
        latitude: latitude,
        longitude: longitude,
        rawEmployeeData: rawEmployeeData,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
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
    _needsTenantSelection = false;
    _availableTenants = null;
    _preAuthToken = null;
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

    // Multiple tenants — store and let UI choose
    if (availableTenants.length > 1) {
      _availableTenants = availableTenants.cast<Map<String, dynamic>>();
      _preAuthToken = preAuthToken;
      _needsTenantSelection = true;
      _isLoading = false;
      notifyListeners();
      return false;
    }

    // 2. Single tenant — auto-select
    final firstTenant = availableTenants[0];
    if (firstTenant is! Map || firstTenant['tenant_id'] == null) {
        _isLoading = false;
        _error = 'Invalid tenant data received.';
        notifyListeners();
        return false;
    }

    final tenantId = firstTenant['tenant_id'];

    // 3. Select Tenant -> Get Access Token & User Profile
    final loginResult = await _authService.selectTenant(preAuthToken, tenantId);

    _isLoading = false;
    if (loginResult['success']) {
      _user = loginResult['user'];
      _error = null;
      _needsTenantSelection = false;
      _availableTenants = null;
      _preAuthToken = null;
      notifyListeners();
      NotificationService().registerToken();
      return true;
    } else {
      _error = loginResult['error'];
      _needsTenantSelection = false;
      _availableTenants = null;
      _preAuthToken = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> selectOtpTenant(String tenantId) async {
    if (_preAuthToken == null) {
      _error = 'Session expired. Please restart login.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    final loginResult = await _authService.selectTenant(_preAuthToken!, tenantId);

    _isLoading = false;
    _needsTenantSelection = false;
    _availableTenants = null;
    _preAuthToken = null;

    if (loginResult['success']) {
      _user = loginResult['user'];
      _error = null;
      notifyListeners();
      NotificationService().registerToken();
      return true;
    } else {
      _error = loginResult['error'];
      notifyListeners();
      return false;
    }
  }
}
