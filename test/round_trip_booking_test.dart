import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:employee_flutter/constants/api_constants.dart';
import 'package:employee_flutter/constants/error_messages.dart';
import 'package:employee_flutter/models/shift_model.dart';
import 'package:employee_flutter/screens/create_booking_screen.dart';
import 'package:employee_flutter/services/api_service.dart';
import 'package:employee_flutter/services/booking_service.dart';
import 'package:flutter_test/flutter_test.dart';

Shift _shift(int id, String logType) => Shift(
      shiftId: id,
      logType: logType,
      shiftCode: 'S$id',
      isActive: true,
    );

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({required this.responseBody, this.statusCode = 201});

  final Map<String, dynamic> responseBody;
  final int statusCode;
  String? capturedPath;
  Map<String, dynamic>? capturedBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedPath = options.path;
    final data = options.data;
    if (data is Map) {
      capturedBody = Map<String, dynamic>.from(data);
    } else if (data is String) {
      capturedBody = jsonDecode(data) as Map<String, dynamic>;
    }
    return ResponseBody.fromString(
      jsonEncode(responseBody),
      statusCode,
      headers: {'content-type': ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeApiService extends ApiService {
  FakeApiService(this._fakeDio);

  final Dio _fakeDio;

  @override
  Dio get dio => _fakeDio;
}

BookingService _serviceWith(RecordingAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return BookingService(apiService: FakeApiService(dio));
}

Map<String, dynamic> _okResponse({
  required List<Map<String, dynamic>> created,
  List<dynamic> skipped = const [],
  int? loginBookingId,
  int? logoutBookingId,
}) {
  final first = created.isEmpty ? null : created.first;
  final bookingId = first?['booking_id'];
  return {
    'success': true,
    'data': {
      'booking_id': bookingId,
      'login_booking_id': loginBookingId,
      'logout_booking_id': logoutBookingId,
      'created': created,
      'skipped': skipped,
    },
    'message': '${created.length} round-trip booking(s) created successfully',
  };
}

DioException _serverError(int status, String code) {
  final options = RequestOptions(path: ApiConstants.createRoundTripBooking);
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: {
        'detail': {
          'success': false,
          'message': 'raw backend detail',
          'error_code': code,
        }
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('Round-trip request payload', () {
    test('base URL uses the POST-capable production API host', () {
      expect(ApiConstants.baseUrl, 'https://api.mltcorporate.com');
    });

    test('login-only sends both legs and reuses login shift id for disabled logout', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 111, 'date': '2026-11-25', 'type': 'login'}
          ],
          loginBookingId: 111,
        ),
      );
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
        loginShift: _shift(101, 'IN'),
      );

      expect(result['success'], true);
      expect(adapter.capturedPath, ApiConstants.createRoundTripBooking);
      final body = adapter.capturedBody!;
      expect(body['employee_id'], 123);
      expect(body['booking_dates'], ['2026-11-25']);
      expect(body['booking_type'], 'regular');
      expect(body['login']['enabled'], true);
      expect(body['login']['shift_id'], 101);
      expect(body['logout']['enabled'], false);
      expect(body['logout']['shift_id'], 101);
      expect(body['logout'].containsKey('next_day'), false);
    });

    test('logout-only sends both legs and preserves next_day', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 222, 'date': '2026-11-26', 'type': 'logout'}
          ],
          logoutBookingId: 222,
        ),
      );
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
        logoutShift: _shift(202, 'OUT'),
        logoutNextDay: true,
      );

      expect(result['success'], true);
      final body = adapter.capturedBody!;
      expect(body['login']['enabled'], false);
      expect(body['login']['shift_id'], 202);
      expect(body['logout']['enabled'], true);
      expect(body['logout']['shift_id'], 202);
      expect(body['logout']['next_day'], true);
      expect(body['booking_dates'], ['2026-11-25']);
    });

    test('combined booking sends both real shift ids', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 111, 'date': '2026-11-25', 'type': 'login'},
            {'booking_id': 222, 'date': '2026-11-25', 'type': 'logout'}
          ],
          loginBookingId: 111,
          logoutBookingId: 222,
        ),
      );
      final service = _serviceWith(adapter);

      await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
        loginShift: _shift(101, 'IN'),
        logoutShift: _shift(202, 'OUT'),
      );

      final body = adapter.capturedBody!;
      expect(body['login']['enabled'], true);
      expect(body['login']['shift_id'], 101);
      expect(body['logout']['enabled'], true);
      expect(body['logout']['shift_id'], 202);
      expect(body['logout']['next_day'], false);
    });

    test('both legs disabled is rejected without an API call', () async {
      final adapter = RecordingAdapter(responseBody: _okResponse(created: []));
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
      );

      expect(result['success'], false);
      expect(
        result['error'],
        'Please select at least one journey (Login or Logout).',
      );
      expect(adapter.capturedPath, isNull);
    });
  });

  group('Journey selection validation', () {
    test('both disabled is rejected', () {
      expect(
        hasEnabledJourney(loginEnabled: false, logoutEnabled: false),
        isFalse,
      );
    });

    test('login-only is accepted', () {
      expect(
        hasEnabledJourney(loginEnabled: true, logoutEnabled: false),
        isTrue,
      );
    });

    test('logout-only is accepted', () {
      expect(
        hasEnabledJourney(loginEnabled: false, logoutEnabled: true),
        isTrue,
      );
    });

    test('combined selection is accepted', () {
      expect(
        hasEnabledJourney(loginEnabled: true, logoutEnabled: true),
        isTrue,
      );
    });
  });

  group('Round-trip response parsing', () {
    test('login-only uses login id and leaves logout id null', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 111, 'date': '2026-11-25', 'type': 'login'}
          ],
          loginBookingId: 111,
        ),
      );
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
        loginShift: _shift(101, 'IN'),
      );

      expect(result['bookingId'], 111);
      expect(result['loginBookingId'], 111);
      expect(result['logoutBookingId'], isNull);
      expect(result['createdCount'], 1);
      expect(result['requestedCount'], 1);
      expect(result['created'][0]['date'], '2026-11-25');
      expect(result['created'][0]['type'], 'login');
      expect(result['message'], contains('2026-11-25'));
    });

    test('logout-only never uses a login booking id', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 222, 'date': '2026-11-26', 'type': 'logout'}
          ],
          loginBookingId: null,
          logoutBookingId: 222,
        ),
      );
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
        logoutShift: _shift(202, 'OUT'),
        logoutNextDay: true,
      );

      expect(result['bookingId'], 222);
      expect(result['loginBookingId'], isNull);
      expect(result['logoutBookingId'], 222);
      expect(result['created'][0]['date'], '2026-11-26');
      expect(result['message'], contains('Logout booking created successfully'));
    });

    test('multiple dates and next-day logout use actual backend dates', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 111, 'date': '2026-11-25', 'type': 'login'},
            {'booking_id': 222, 'date': '2026-11-26', 'type': 'logout'},
            {'booking_id': 333, 'date': '2026-11-26', 'type': 'login'},
            {'booking_id': 444, 'date': '2026-11-27', 'type': 'logout'},
          ],
          loginBookingId: 333,
          logoutBookingId: 444,
        ),
      );
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25', '2026-11-26'],
        loginShift: _shift(101, 'IN'),
        logoutShift: _shift(202, 'OUT'),
        logoutNextDay: true,
      );

      expect(result['createdCount'], 4);
      expect(result['requestedCount'], 4);
      expect(result['loginBookingId'], 333);
      expect(result['logoutBookingId'], 444);
      expect(
        result['created'].map((row) => row['date']).toList(),
        ['2026-11-25', '2026-11-26', '2026-11-26', '2026-11-27'],
      );
      expect(result['message'], contains('4 bookings created successfully'));
      expect(result['skipped'], isEmpty);
    });

    test('non-empty skipped rows are parsed and reported', () async {
      final adapter = RecordingAdapter(
        responseBody: _okResponse(
          created: [
            {'booking_id': 111, 'date': '2026-11-25', 'type': 'login'}
          ],
          skipped: [
            {
              'booking_id': 999,
              'date': '2026-11-25',
              'type': 'logout',
              'reason': 'ALREADY_BOOKED'
            }
          ],
          loginBookingId: 111,
        ),
      );
      final service = _serviceWith(adapter);

      final result = await service.createRoundTripBooking(
        tenantId: 'HS001',
        employeeId: 123,
        bookingDates: const ['2026-11-25'],
        loginShift: _shift(101, 'IN'),
        logoutShift: _shift(202, 'OUT'),
      );

      expect(result['skipped'].length, 1);
      expect(result['skipped'][0]['type'], 'logout');
      expect(result['message'], contains('1 booking(s) were skipped.'));
    });
  });

  group('Round-trip error mapping', () {
    final codes = <String>[
      'ALREADY_BOOKED',
      'BOOKING_CUTOFF',
      'BOOKING_FROZEN',
      'BOOKING_TOO_FAR_AHEAD',
      'MAX_ACTIVE_BOOKINGS_REACHED',
      'WEEKOFF_DAY',
      'NEXT_DAY_WEEKOFF',
      'SHIFT_INACTIVE',
      'SHIFT_NOT_FOUND',
      'WRONG_SHIFT_LOG_TYPE',
      'SHIFT_GENDER_MISMATCH',
      'NO_NODAL_ASSIGNMENT',
      'NODAL_POINT_INACTIVE',
      'HOLIDAY_BLOCKED',
      'EMPLOYEE_APP_INACTIVE',
      'INVALID_DATE',
      'PAST_SHIFT_TIME',
      'NOTHING_TO_BOOK',
      'TENANT_ID_REQUIRED',
      'BOOKING_OWNERSHIP_FORBIDDEN',
      'TENANT_FORBIDDEN',
    ];

    for (final code in codes) {
      test('$code maps to an employee-friendly message', () {
        final message = ApiError.resolve(
          _serverError(422, code),
          feature: 'booking',
          fallback: AppErrorMessages.bookingCreateFailed,
        );
        expect(AppErrorMessages.booking[code], isNotNull, reason: code);
        expect(message, AppErrorMessages.booking[code], reason: code);
        expect(message, isNot(contains('raw backend detail')));
        expect(message, isNot(contains('Exception')));
      });
    }
  });
}
