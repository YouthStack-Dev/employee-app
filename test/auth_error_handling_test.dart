import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:employee_flutter/constants/error_messages.dart';
import 'package:employee_flutter/services/api_service.dart';

/// Verifies the login-endpoint error handling against the API docs:
///   wrong password/tenant → 401 (no error_code)
///   inactive employee     → 403 ACCOUNT_INACTIVE
///   app access disabled   → 403 APP_ACCESS_DISABLED
///   rate limit            → 429
DioException _serverError(int status, dynamic body) {
  final options = RequestOptions(path: '/api/v1/app/auth/employee/login');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

Map<String, dynamic> _envelope(String code, {Map<String, dynamic>? details}) => {
      'detail': {
        'success': false,
        'message': 'backend message',
        'error_code': code,
        'details': details ?? {},
      }
    };

void main() {
  group('Login error handling (per API docs)', () {
    test('wrong password → 401 without error_code shows invalid-credentials fallback', () {
      // Docs: 401 for bad tenant/username/password has NO machine-readable code.
      final e = _serverError(401, {'detail': 'Invalid credentials'});
      final msg = ApiError.resolve(e, feature: 'auth', fallback: AppErrorMessages.loginFailed);
      expect(msg, AppErrorMessages.loginFailed);
    });

    test('wrong tenant → 401 without error_code shows invalid-credentials fallback', () {
      final e = _serverError(401, {'detail': 'Unauthorized'});
      final msg = ApiError.resolve(e, feature: 'auth', fallback: AppErrorMessages.loginFailed);
      expect(msg, AppErrorMessages.loginFailed);
    });

    test('auth 401 must NOT say "session expired" (that copy is for authed calls)', () {
      final e = _serverError(401, {'detail': 'Invalid credentials'});
      final msg = ApiError.resolve(e, feature: 'auth', fallback: AppErrorMessages.loginFailed);
      expect(msg, isNot(contains('session has expired')));
    });

    test('inactive employee → 403 ACCOUNT_INACTIVE maps to friendly message', () {
      final e = _serverError(403, _envelope('ACCOUNT_INACTIVE'));
      final msg = ApiError.resolve(e, feature: 'auth', fallback: AppErrorMessages.loginFailed);
      expect(msg, AppErrorMessages.auth['ACCOUNT_INACTIVE']);
    });

    test('is_app_active=false → 403 APP_ACCESS_DISABLED maps to friendly message', () {
      final e = _serverError(403, _envelope('APP_ACCESS_DISABLED'));
      final msg = ApiError.resolve(e, feature: 'auth', fallback: AppErrorMessages.loginFailed);
      expect(msg, AppErrorMessages.auth['APP_ACCESS_DISABLED']);
    });

    test('rate limit → 429 shows too-many-requests message', () {
      final e = _serverError(429, null);
      final msg = ApiError.resolve(e, feature: 'auth', fallback: AppErrorMessages.loginFailed);
      expect(msg, contains('too many requests'));
    });
  });

  group('OTP verify error handling (per API docs)', () {
    test('INVALID_OTP surfaces details.remaining_attempts', () {
      final e = _serverError(401, _envelope('INVALID_OTP', details: {'remaining_attempts': 2}));
      final msg = ApiError.resolve(e, feature: 'auth', fallback: 'OTP verification failed.');
      expect(msg, contains('2 attempts remaining'));
    });

    test('INVALID_OTP singular grammar for 1 attempt', () {
      final e = _serverError(401, _envelope('INVALID_OTP', details: {'remaining_attempts': 1}));
      final msg = ApiError.resolve(e, feature: 'auth', fallback: 'OTP verification failed.');
      expect(msg, contains('1 attempt remaining'));
    });

    test('OTP_EXPIRED → 400 maps to request-new-OTP message', () {
      final e = _serverError(400, _envelope('OTP_EXPIRED'));
      final msg = ApiError.resolve(e, feature: 'auth', fallback: 'OTP verification failed.');
      expect(msg, AppErrorMessages.auth['OTP_EXPIRED']);
    });

    test('MAX_OTP_ATTEMPTS → 429 maps to friendly message', () {
      final e = _serverError(429, _envelope('MAX_OTP_ATTEMPTS'));
      final msg = ApiError.resolve(e, feature: 'auth', fallback: 'OTP verification failed.');
      expect(msg, AppErrorMessages.auth['MAX_OTP_ATTEMPTS']);
    });
  });

  group('Regression: non-auth features keep old behaviour', () {
    test('401 on authed endpoints still means expired session', () {
      final e = _serverError(401, {'detail': 'Token expired'});
      final msg = ApiError.resolve(e, feature: 'booking', fallback: 'load failed');
      expect(msg, contains('session has expired'));
    });
  });
}
