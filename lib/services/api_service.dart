import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../main.dart';

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token'; // Adjust prefix if needed
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired or invalid, try to refresh
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');
          final tenantId = prefs.getString('tenant_id');

          if (refreshToken != null) {
            try {
              // Use a separate Dio instance to avoid infinite loops and interceptor clashes
              final refreshDio = Dio();
              
              // Add tenant_id if required by backend
              final dataPayload = {'refresh_token': refreshToken};
              if (tenantId != null) {
                 dataPayload['tenant_id'] = tenantId;
              }

              final response = await refreshDio.post(
                '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
                data: dataPayload,
                options: Options(headers: {'Content-Type': 'application/json'}),
              );

              if (response.statusCode == 200) {
                final data = response.data['data'];
                if (data != null && data['access_token'] != null) {
                   final newAccessToken = data['access_token'];
                   final newRefreshToken = data['refresh_token'];
                   
                   await prefs.setString('access_token', newAccessToken);
                   if (newRefreshToken != null) {
                      await prefs.setString('refresh_token', newRefreshToken);
                   }

                   // Update the authorization header and retry the original request
                   final options = e.requestOptions;
                   options.headers['Authorization'] = 'Bearer $newAccessToken';
                   
                   final retryResponse = await _dio.fetch(options);
                   return handler.resolve(retryResponse);
                }
              }
              // If it reaches here, the refresh logic failed to get an access token
              throw Exception('Invalid token refresh response format');
            } catch (refreshError) {
              // If refresh fails, clear tokens so the user is forced to log in again
              await prefs.remove('access_token');
              await prefs.remove('refresh_token');
              
              // Force redirect to LoginScreen using global navigator key
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
            }
          } else {
             // If no refresh token, force logout
             await prefs.remove('access_token');
             navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
          }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
