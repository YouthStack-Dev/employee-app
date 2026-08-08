import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Helper to extract user-friendly error from DioException for auth endpoints.
String _authError(DioException e, String fallback) {
  return ApiError.resolve(e, feature: 'auth', fallback: fallback);
}

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
                 if (employee['gender'] != null) {
                   await prefs.setString('gender', employee['gender'].toString());
                 }
                 if (employee['name'] != null) {
                   await prefs.setString('name', employee['name'].toString());
                 }
                 if (employee['email'] != null) {
                   await prefs.setString('email', employee['email'].toString());
                 }
                 final phone = employee['contact_number'] ?? employee['phone_number'] ?? employee['phone'];
                 if (phone != null) {
                   await prefs.setString('phone', phone.toString());
                 }
                 final address = employee['address'] ?? employee['home_address'];
                  if (address != null) {
                    await prefs.setString('address', address.toString());
                  }
                  await prefs.setString('raw_employee_data', jsonEncode(employee));
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
      return {'success': false, 'error': _authError(e, AppErrorMessages.loginFailed)};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
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
      return {'success': false, 'error': _authError(e, AppErrorMessages.otpFailed)};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
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
      return {'success': false, 'error': _authError(e, 'OTP verification failed. Please request a new OTP and try again.')};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
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
                 if (employee['gender'] != null) {
                   await prefs.setString('gender', employee['gender'].toString());
                 }
                 if (employee['name'] != null) {
                   await prefs.setString('name', employee['name'].toString());
                 }
                 if (employee['email'] != null) {
                   await prefs.setString('email', employee['email'].toString());
                 }
                 final phone = employee['contact_number'] ?? employee['phone_number'] ?? employee['phone'];
                  if (phone != null) {
                    await prefs.setString('phone', phone.toString());
                  }
                  final address = employee['address'] ?? employee['home_address'];
                  if (address != null) {
                    await prefs.setString('address', address.toString());
                  }
                  await prefs.setString('raw_employee_data', jsonEncode(employee));
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
      return {'success': false, 'error': _authError(e, 'Failed to select organization. Please try again.')};
    } catch (e) {
      return {'success': false, 'error': 'Something went wrong. Please try again.'};
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
            if (employee['gender'] != null) {
              await prefs.setString('gender', employee['gender'].toString());
            }
            if (employee['name'] != null) {
              await prefs.setString('name', employee['name'].toString());
            }
            if (employee['email'] != null) {
              await prefs.setString('email', employee['email'].toString());
            }
            final phone = employee['contact_number'] ?? employee['phone_number'] ?? employee['phone'];
            if (phone != null) {
              await prefs.setString('phone', phone.toString());
            }
            final address = employee['address'] ?? employee['home_address'];
            if (address != null) {
              await prefs.setString('address', address.toString());
            }
            await prefs.setString('raw_employee_data', jsonEncode(employee));
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
    return ApiError.resolve(e, feature: 'auth', fallback: fallback);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
