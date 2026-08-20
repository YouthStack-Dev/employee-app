import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/error_messages.dart';
import '../main.dart';
import 'connectivity_service.dart';

/// Persists tenant/app config returned by auth responses (login, select-tenant,
/// switch-tenant, refresh-token) as raw JSON. Missing keys are skipped, so
/// non-tenant-scoped responses (e.g. admin refresh) are handled gracefully.
Future<void> persistAppConfig(Map container) async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in const [
    'active_modules',
    'tenant_config',
    'booking_policy',
    'available_tenants',
  ]) {
    final value = container[key];
    if (value != null) {
      await prefs.setString(key, jsonEncode(value));
    }
  }
}

/// User-friendly error messages based on DioException type.
class ApiError {
  static String getUserMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppErrorMessages.timeout;
      case DioExceptionType.connectionError:
        return AppErrorMessages.noInternet;
      case DioExceptionType.badResponse:
        return _parseServerError(e.response);
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return AppErrorMessages.noInternet;
        }
        return 'Something went wrong. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  /// Full error resolver: extracts error_code from response and maps to
  /// user-friendly message using AppErrorMessages.
  static String resolve(DioException e, {required String feature, String? fallback}) {
    if (isNetworkError(e)) {
      return getUserMessage(e);
    }

    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String? errorCode;
    String? serverMessage;
    int? remainingAttempts;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        errorCode = detail['error_code']?.toString() ?? detail['code']?.toString();
        serverMessage = detail['message']?.toString();
        remainingAttempts = _extractRemainingAttempts(detail['details'] ?? detail);
      } else if (detail is String) {
        serverMessage = detail;
      }
      errorCode ??= data['error_code']?.toString() ?? data['code']?.toString();
      serverMessage ??= data['message']?.toString();
      remainingAttempts ??= _extractRemainingAttempts(data['details']);
    }

    return AppErrorMessages.resolve(
      feature: feature,
      statusCode: statusCode,
      errorCode: errorCode,
      serverMessage: serverMessage,
      remainingAttempts: remainingAttempts,
      fallback: fallback,
    );
  }

  /// Pulls `remaining_attempts` out of an error `details` payload
  /// (e.g. INVALID_OTP responses include it per the auth API docs).
  static int? _extractRemainingAttempts(dynamic details) {
    if (details is! Map) return null;
    final value = details['remaining_attempts'];
    if (value is int) return value;
    if (value != null) return int.tryParse(value.toString());
    return null;
  }

  static String _parseServerError(Response? response) {
    if (response == null) return 'Something went wrong. Please try again.';
    return AppErrorMessages.fromStatusCode(response.statusCode);
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

        // Pre-auth endpoints (login, OTP, tenant selection, forgot-password)
        // require no Authorization per the API docs. Never attach stale
        // session headers here — a leftover X-Tenant-Id could contradict the
        // tenant_id sent in the request body. (set-password is excluded: it
        // IS an authenticated call.)
        const preAuthPaths = [
          ApiConstants.login,
          ApiConstants.requestOtp,
          ApiConstants.verifyOtp,
          ApiConstants.selectTenant,
          ApiConstants.forgotPassword,
          ApiConstants.forgotPasswordVerify,
        ];
        final isPreAuthEndpoint = preAuthPaths.any((p) => options.path.contains(p));

        if (!isPreAuthEndpoint) {
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

          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ));

              // Per API docs the body is only {refresh_token} — sending extra
              // fields risks a 422 on strict schemas.
              final response = await refreshDio.post(
                '${ApiConstants.baseUrl}${ApiConstants.refreshToken}',
                data: {'refresh_token': refreshToken},
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

                  // Pick up mid-session config changes — refresh returns
                  // active_modules / tenant_config / booking_policy at the
                  // data level for tenant-scoped users.
                  if (data is Map) {
                    await persistAppConfig(data);
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
