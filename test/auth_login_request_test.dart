import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:employee_flutter/constants/api_constants.dart';
import 'package:employee_flutter/constants/error_messages.dart';
import 'package:employee_flutter/services/api_service.dart';
import 'package:employee_flutter/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.responseBody, required this.statusCode});

  final dynamic responseBody;
  final int statusCode;
  String? capturedUri;
  String? capturedMethod;
  Map<String, dynamic>? capturedBody;
  Map<String, dynamic>? capturedHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedUri = options.uri.toString();
    capturedMethod = options.method;
    capturedHeaders = Map<String, dynamic>.from(options.headers);
    final data = options.data;
    if (data is Map) {
      capturedBody = Map<String, dynamic>.from(data);
    } else if (data is String) {
      capturedBody = jsonDecode(data) as Map<String, dynamic>;
    }
    final isHtml = responseBody is String;
    return ResponseBody.fromString(
      isHtml ? responseBody as String : jsonEncode(responseBody),
      statusCode,
      headers: {
        'content-type': [isHtml ? 'text/html' : 'application/json']
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeApiService extends ApiService {
  _FakeApiService(this._fakeDio);

  final Dio _fakeDio;

  @override
  Dio get dio => _fakeDio;
}

AuthService _serviceWith(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    headers: {'Content-Type': 'application/json'},
  ))..httpClientAdapter = adapter;
  return AuthService(apiService: _FakeApiService(dio));
}

Map<String, dynamic> _successBody() => {
      'success': true,
      'data': {
        'access_token': 'dummy-access-token',
        'refresh_token': 'dummy-refresh-token',
        'token_type': 'bearer',
        'user': {
          'employee': {
            'employee_id': 42,
            'name': 'Test Employee',
            'email': 'employee@example.com',
            'gender': 'female',
            'contact_number': '0000000000',
            'address': 'Test Address',
            'latitude': '12.34',
            'longitude': '56.78',
          },
          'tenant': {
            'name': 'Test Tenant',
            'latitude': '12.34',
            'longitude': '56.78',
          },
          'roles': ['employee'],
          'active_modules': ['bookings'],
          'tenant_config': {'feature': true},
          'booking_policy': {'advance_days': 7},
          'available_tenants': [],
        },
      },
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('production base URL uses the POST-capable API host', () {
    expect(ApiConstants.baseUrl, 'https://api.mltcorporate.com');
    expect(Uri.parse(ApiConstants.baseUrl).host, 'api.mltcorporate.com');
    expect(ApiConstants.login, '/api/v1/app/auth/employee/login');
  });

  test('login posts the expected payload and headers to the production endpoint', () async {
    final adapter = _RecordingAdapter(responseBody: _successBody(), statusCode: 200);

    final result = await _serviceWith(adapter).login(
      'TENANT001',
      'employee@example.com',
      'DummyPass1!',
    );

    expect(result['success'], true);
    expect(adapter.capturedUri, 'https://api.mltcorporate.com/api/v1/app/auth/employee/login');
    expect(adapter.capturedMethod, 'POST');
    expect(adapter.capturedBody, containsPair('tenant_id', 'TENANT001'));
    expect(adapter.capturedBody, containsPair('username', 'employee@example.com'));
    expect(adapter.capturedBody, containsPair('password', 'DummyPass1!'));
    expect(adapter.capturedBody, containsPair('login_source', 'app'));
    expect(adapter.capturedHeaders, containsPair('Content-Type', 'application/json'));
    expect(adapter.capturedHeaders, isNot(containsPair('Authorization', anything)));
    expect(adapter.capturedHeaders, isNot(containsPair('X-Tenant-Id', anything)));
  });

  test('login success stores tokens using the API response values', () async {
    final adapter = _RecordingAdapter(responseBody: _successBody(), statusCode: 200);

    final result = await _serviceWith(adapter).login(
      'TENANT001',
      'employee@example.com',
      'DummyPass1!',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(result['success'], true);
    expect(prefs.getString('access_token'), 'dummy-access-token');
    expect(prefs.getString('refresh_token'), 'dummy-refresh-token');
    expect(prefs.getString('tenant_id'), 'TENANT001');
    expect(prefs.getString('employee_id'), '42');
    expect(prefs.getString('active_modules'), isNotNull);
  });

  test('backend 401 maps to the friendly login-failure message', () async {
    final adapter = _RecordingAdapter(
      statusCode: 401,
      responseBody: {
        'detail': {
          'success': false,
          'message': 'Incorrect tenant, email, or password',
          'error_code': 401,
          'details': null,
        }
      },
    );

    final result = await _serviceWith(adapter).login(
      'TENANT001',
      'employee@example.com',
      'DummyPass1!',
    );

    expect(result['success'], false);
    expect(result['error'], AppErrorMessages.loginFailed);
    expect(result['error'], isNot(contains('session has expired')));
  });

  test('nginx 405 does not surface raw HTML or a generic fallback', () async {
    final adapter = _RecordingAdapter(
      statusCode: 405,
      responseBody: '<html><body>405 Not Allowed</body></html>',
    );

    final result = await _serviceWith(adapter).login(
      'TENANT001',
      'employee@example.com',
      'DummyPass1!',
    );

    expect(result['success'], false);
    expect(result['error'], contains('temporarily unavailable'));
    expect(result['error'], isNot(contains('<html>')));
    expect(result['error'], isNot('Something went wrong. Please try again.'));
  });

  test('unexpected success-response shape uses the friendly login fallback', () async {
    final adapter = _RecordingAdapter(
      statusCode: 200,
      responseBody: {'data': 'unexpected'},
    );

    final result = await _serviceWith(adapter).login(
      'TENANT001',
      'employee@example.com',
      'DummyPass1!',
    );

    expect(result['success'], false);
    expect(result['error'], AppErrorMessages.loginFailed);
  });
}
