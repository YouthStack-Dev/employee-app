import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> login(String tenantId, String username, String password) async {
    try {
      final response = await _apiService.dio.post(ApiConstants.login, data: {
        'tenant_id': tenantId,
        'username': username,
        'password': password,
        'login_source': 'app',
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        print('LOGIN RESPONSE DATA: $data'); // DEBUG LOG
        
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        
        // Save token and user details
        final prefs = await SharedPreferences.getInstance();
        if (accessToken != null) {
          await prefs.setString('access_token', accessToken);
        }
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
        
        // CRITICAL FIX: Save the tenantId passed from the input argument
        await prefs.setString('tenant_id', tenantId);
        print('SAVED TENANT ID TO PREFS: $tenantId');
        
        final user = data['user'];
        print('USER OBJECT: $user'); 

        if (user != null) {
             final employee = user['employee'];
             
             if (employee != null && employee['employee_id'] != null) {
                 await prefs.setString('employee_id', employee['employee_id'].toString());
             }
        }
        
        return {
          'success': true,
          'user': User.fromJson(data),
          'access_token': accessToken,
        };
      }
      return {'success': false, 'error': 'Login failed'};
    } on DioException catch (e) {
      // Extract error message similar to React Native implementation
      String errorMessage = 'Login failed';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
             if (data['detail'] is Map && data['detail']['message'] != null) {
               errorMessage = data['detail']['message'];
             } else if (data['detail'] is String) {
               errorMessage = data['detail'];
             }
        }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final response = await _apiService.dio.post(ApiConstants.requestOtp, data: {
        'username': phoneNumber,
      });

      if (response.statusCode == 200) {
         if (response.data['data'] == null) {
            return {'success': false, 'error': 'Empty response from server'};
         }
         return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'error': 'Failed to send OTP'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to send OTP';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
            if (data['detail'] is Map && data['detail']['message'] != null) {
               errorMessage = data['detail']['message'];
            } else if (data['detail'] is String) {
               errorMessage = data['detail'];
            }
        }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String phoneNumber, String otp) async {
    try {
      final response = await _apiService.dio.post(ApiConstants.verifyOtp, data: {
        'username': phoneNumber,
        'otp': otp,
      });

      if (response.statusCode == 200) {
        if (response.data['data'] == null) {
            return {'success': false, 'error': 'Empty response from server'};
        }
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'error': 'Invalid OTP'};
    } on DioException catch (e) {
      String errorMessage = 'Invalid OTP';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
            if (data['detail'] is Map && data['detail']['message'] != null) {
               errorMessage = data['detail']['message'];
            } else if (data['detail'] is String) {
               errorMessage = data['detail'];
            }
        }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> selectTenant(String preAuthToken, String tenantId) async {
    try {
      final response = await _apiService.dio.post(
        ApiConstants.selectTenant,
        options: Options(headers: {'X-Pre-Auth-Token': preAuthToken}),
        data: {'tenant_id': tenantId},
      );

      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data == null) {
            return {'success': false, 'error': 'Empty response from server'};
        }
        
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        
        // Save token and user details
        final prefs = await SharedPreferences.getInstance();
        if (accessToken != null) {
          await prefs.setString('access_token', accessToken);
        }
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken);
        }
        
        await prefs.setString('tenant_id', tenantId);
        
        final user = data['user'];

        if (user != null) {
             final employee = user['employee'];
             if (employee != null && employee['employee_id'] != null) {
                 await prefs.setString('employee_id', employee['employee_id'].toString());
             }
        }
        
        return {
          'success': true,
          'user': User.fromJson(data),
          'access_token': accessToken,
        };
      }
      return {'success': false, 'error': 'Failed to select tenant'};
    } on DioException catch (e) {
      String errorMessage = 'Failed to select tenant';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
            if (data['detail'] is Map && data['detail']['message'] != null) {
               errorMessage = data['detail']['message'];
            } else if (data['detail'] is String) {
               errorMessage = data['detail'];
            }
        }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ---------------- Forgot password flow ----------------

  /// Step 1 — POST /api/v1/auth/employee/forgot-password
  /// Body: {tenant_id, email}. Always returns a generic message (enum-safe).
  Future<Map<String, dynamic>> forgotPassword(String tenantId, String email) async {
    try {
      final response = await _apiService.dio.post(ApiConstants.forgotPassword, data: {
        'tenant_id': tenantId,
        'email': email,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': response.data is Map ? response.data['message'] : null};
      }
      return {'success': false, 'error': 'Failed to send reset OTP'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e, 'Failed to send reset OTP')};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Step 2 — POST /api/v1/auth/employee/forgot-password/verify
  /// Body: {tenant_id, email, otp}. On success the backend issues a session
  /// (tokens) with password_change_required + a one-time password_set_token.
  /// We persist the tokens so the subsequent PUT /password is authenticated.
  Future<Map<String, dynamic>> verifyForgotPassword(String tenantId, String email, String otp) async {
    try {
      final response = await _apiService.dio.post(ApiConstants.forgotPasswordVerify, data: {
        'tenant_id': tenantId,
        'email': email,
        'otp': otp,
      });
      if (response.statusCode == 200) {
        final data = response.data['data'];
        if (data == null) return {'success': false, 'error': 'Empty response from server'};

        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];
        final passwordSetToken = data['password_set_token'];

        final prefs = await SharedPreferences.getInstance();
        if (accessToken != null) await prefs.setString('access_token', accessToken);
        if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('tenant_id', tenantId);

        final user = data['user'];
        if (user != null) {
          final employee = user['employee'];
          if (employee != null && employee['employee_id'] != null) {
            await prefs.setString('employee_id', employee['employee_id'].toString());
          }
        }

        return {
          'success': true,
          'user': User.fromJson(data),
          'password_set_token': passwordSetToken?.toString(),
        };
      }
      return {'success': false, 'error': 'Invalid OTP'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e, 'Invalid OTP')};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Step 3 — PUT /api/v1/auth/employee/password (Bearer)
  /// Body: {password_set_token, new_password, confirm_password}. The Bearer
  /// token is attached automatically by ApiService from the tokens persisted
  /// in step 2.
  Future<Map<String, dynamic>> setNewPassword({
    required String passwordSetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _apiService.dio.put(ApiConstants.setPassword, data: {
        'password_set_token': passwordSetToken,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': response.data is Map ? response.data['message'] : null};
      }
      return {'success': false, 'error': 'Failed to set password'};
    } on DioException catch (e) {
      return {'success': false, 'error': _parseError(e, 'Failed to set password')};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Shared error extractor for the fleet-manager response envelope.
  String _parseError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is Map && detail['message'] != null) return detail['message'].toString();
      if (data['message'] is String && (data['message'] as String).isNotEmpty) return data['message'];
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    if (e.response?.statusCode == 401) return 'Invalid or expired OTP. Please try again.';
    if (e.response?.statusCode == 400) return 'Reset link expired. Please restart the reset.';
    if (e.response?.statusCode == 429) return 'Too many attempts. Please wait a minute and retry.';
    return e.message ?? fallback;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
