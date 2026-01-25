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
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['data'];
        print('LOGIN RESPONSE DATA: $data'); // DEBUG LOG
        
        final accessToken = data['access_token'];
        
        // Save token and user details
        final prefs = await SharedPreferences.getInstance();
        if (accessToken != null) {
          await prefs.setString('access_token', accessToken);
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
