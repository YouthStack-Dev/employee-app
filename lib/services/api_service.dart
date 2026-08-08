import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../main.dart';
import 'connectivity_service.dart';

/// User-friendly error messages based on DioException type.
class ApiError {
  static String getUserMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please check your internet and try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending data. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server is taking too long to respond. Please try again.';
      case DioExceptionType.connectionError:
        return 'Unable to reach the server. Please check your internet connection.';
      case DioExceptionType.badResponse:
        return _parseServerError(e.response);
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return 'No internet connection. Please check your WiFi or mobile data.';
        }
        return 'Something went wrong. Please try again.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static String _parseServerError(Response? response) {
    if (response == null) return 'Server error. Please try again.';

    final data = response.data;
    if (data is Map) {
      // Backend error format: {"detail": {"message": "...", "error_code": "..."}}
      if (data['detail'] is Map) {
        return data['detail']['message']?.toString() ?? 'Server error (${response.statusCode})';
      }
      if (data['detail'] is String) return data['detail'];
      if (data['message'] is String) return data['message'];
      if (data['error'] is String) return data['error'];
    }

    switch (response.statusCode) {
      case 400: return 'Invalid request. Please check your input.';
      case 401: return 'Session expired. Please log in again.';
      case 403: return 'You don\'t have permission to perform this action.';
      case 404: return 'The requested resource was not found.';
      case 409: return 'This action conflicts with existing data.';
      case 422: return 'Invalid data provided. Please check and try again.';
      case 429: return 'Too many requests. Please wait a moment and try again.';
      case 500: return 'Server error. Our team has been notified.';
      case 502: return 'Server is temporarily unavailable. Please try again.';
      case 503: return 'Service is under maintenance. Please try later.';
      default: return 'Error (${response.statusCode}). Please try again.';
    }
  }

  /// Returns true if this error is a network/connectivity issue (retryable)
  static bool isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        (e.type == DioExceptionType.unknown && e.error is SocketException);
  }

  /// Returns true if this is a server-side error (5xx)
  static bool isServerError(DioException e) {
    final code = e.response?.statusCode ?? 0;
    return code >= 500 && code < 600;
  }
}

class ApiService {
  late Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Pre-flight connectivity check — fail fast with clear message
        final connectivity = ConnectivityService();
        if (!connectivity.isOnline) {
          // Double-check with a fresh lookup before failing
          final isReallyOnline = await connectivity.checkConnectivity();
          if (!isReallyOnline) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const SocketException('No internet connection'),
                message: 'No internet connection. Please check your WiFi or mobile data.',
              ),
            );
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        // Attach tenant_id header for all authenticated requests
        final tenantId = prefs.getString('tenant_id');
        if (tenantId != null) {
          options.headers['X-Tenant-Id'] = tenantId;
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        final authPaths = [
          ApiConstants.login,
          ApiConstants.requestOtp,
          ApiConstants.verifyOtp,
          ApiConstants.selectTenant,
          ApiConstants.forgotPassword,
          ApiConstants.forgotPasswordVerify,
          ApiConstants.setPassword,
        ];

        final requestPath = e.requestOptions.path;
        final isAuthEndpoint = authPaths.any((p) => requestPath.contains(p));

        if (isAuthEndpoint) {
          return handler.next(e);
        }

        if (e.response?.statusCode == 401 && e.requestOptions.extra['_retry'] != true) {
          e.requestOptions.extra['_retry'] = true;

          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');
          final tenantId = prefs.getString('tenant_id');

          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ));
              
              final dataPayload = <String, String>{'refresh_token': refreshToken};
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

                  final options = e.requestOptions;
                  options.headers['Authorization'] = 'Bearer $newAccessToken';
                  
                  final retryResponse = await _dio.fetch(options);
                  return handler.resolve(retryResponse);
                }
              }
              throw Exception('Invalid token refresh response format');
            } catch (refreshError) {
              await prefs.remove('access_token');
              await prefs.remove('refresh_token');
              
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
              return handler.reject(refreshError is DioException ? refreshError : e);
            }
          } else {
            await prefs.remove('access_token');
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
            return handler.reject(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}
