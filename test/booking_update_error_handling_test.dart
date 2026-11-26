import 'package:dio/dio.dart';
import 'package:employee_flutter/constants/error_messages.dart';
import 'package:employee_flutter/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _serverError(int? status, dynamic body) {
  final options = RequestOptions(path: '/api/v1/app/bookings/7');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status, data: body),
    type: DioExceptionType.badResponse,
  );
}

Map<String, dynamic> _envelope(
  String code, {
  Map<String, dynamic>? details,
}) =>
    {
      'detail': {
        'success': false,
        'message': 'raw backend detail',
        'error_code': code,
        'details': details ?? {},
      }
    };

String _resolve(DioException error) => ApiError.resolve(
      error,
      feature: 'bookingUpdate',
      fallback: AppErrorMessages.bookingUpdateFailed,
    );

void main() {
  final activeCodes = <String>[
    'INSUFFICIENT_PERMISSIONS',
    'BOOKING_NOT_FOUND',
    'HOLIDAY_OVERRIDE_MOBILE_FORBIDDEN',
    'HOLIDAY_OVERRIDE_FORBIDDEN',
    'HOLIDAY_OVERRIDE_REASON_REQUIRED',
    'INVALID_BOOKING_STATUS',
    'INVALID_REBOOK_STATUS',
    'SHIFT_NOT_FOUND',
    'SHIFT_INACTIVE',
    'EMPLOYEE_NOT_FOUND',
    'EMPLOYEE_APP_INACTIVE',
    'SHIFT_GENDER_MISMATCH',
    'INVALID_DATE',
    'HOLIDAY_BLOCKED',
    'WEEKOFF_DAY',
    'ADHOC_BOOKING_DISABLED',
    'MEDICAL_EMERGENCY_BOOKING_DISABLED',
    'SHIFT_TIME_MISSING',
    'BOOKING_CUTOFF',
    'PAST_SHIFT_TIME',
    'DUPLICATE_BOOKING',
    'NO_NODAL_ASSIGNMENT',
    'INVALID_BOOKING_STATUS_TRANSITION',
    'TRANSITION_SOURCE_NOT_ALLOWED',
    'INTERNAL_SERVER_ERROR',
  ];

  final defensiveCodes = <String>[
    'LOCATION_EDIT_DISABLED',
    'BOOKING_FROZEN',
    'BOOKING_ALREADY_ASSIGNED',
    'BOOKING_ALREADY_ACTIVE',
    'BOOKING_TOO_FAR_AHEAD',
    'MAX_ACTIVE_BOOKINGS_REACHED',
  ];

  group('Booking update error mapping', () {
    for (final code in activeCodes) {
      test('$code maps to a distinct update/rebook message', () {
        final message = _resolve(_serverError(400, _envelope(code)));
        expect(message, AppErrorMessages.bookingUpdate[code], reason: code);
        expect(message, isNot(AppErrorMessages.booking['INVALID_BOOKING_STATUS']));
        expect(message, isNot(contains('raw backend detail')));
        expect(message, isNot(contains('Exception')));
      });
    }

    test('active update messages are not reused for different codes', () {
      final messages = activeCodes
          .map((code) => AppErrorMessages.bookingUpdate[code])
          .toList();
      expect(messages.toSet().length, messages.length);
    });
  });

  group('INVALID_BOOKING_STATUS detail-specific messages', () {
    final cases = <String, String?>{
      'Scheduled': 'SCHEDULED',
      'Ongoing': 'ONGOING',
      'Completed': 'COMPLETED',
      'No-Show': 'NO_SHOW',
      'NO_SHOW': 'NO_SHOW',
      'no show': 'NO_SHOW',
      'Expired': 'EXPIRED',
      'Cancelled': 'CANCELLED',
      'Request': 'REQUEST',
      'unknown-status': null,
    };

    for (final entry in cases.entries) {
      test('${entry.key} resolves to a clear status message', () {
        final error = _serverError(
          400,
          _envelope('INVALID_BOOKING_STATUS', details: {
            'current_status': entry.key,
            'allowed_statuses': ['REQUEST', 'CANCELLED'],
          }),
        );
        final expected = entry.value == null
            ? AppErrorMessages.bookingUpdate['INVALID_BOOKING_STATUS']
            : AppErrorMessages.bookingUpdateStatus[entry.value];
        expect(_resolve(error), expected);
        expect(_resolve(error), isNot(contains('raw backend detail')));
      });
    }

    test('Scheduled uses the shortened trip-generated message', () {
      const expected =
          'Trip already generated. Please contact administrator to modify this booking.';
      final error = _serverError(
        400,
        _envelope('INVALID_BOOKING_STATUS', details: {
          'current_status': 'Scheduled',
          'allowed_statuses': ['REQUEST', 'CANCELLED'],
        }),
      );
      expect(AppErrorMessages.bookingUpdateStatus['SCHEDULED'], expected);
      expect(_resolve(error), expected);
    });
  });

  group('Defensive-only booking update messages', () {
    for (final code in defensiveCodes) {
      test('$code is mapped separately from active update codes', () {
        expect(AppErrorMessages.bookingUpdate[code], isNull, reason: code);
        expect(AppErrorMessages.bookingUpdateDefensive[code], isNotNull,
            reason: code);
        final message = _resolve(_serverError(409, _envelope(code)));
        expect(message, AppErrorMessages.bookingUpdateDefensive[code]);
        expect(message, isNot(contains('raw backend detail')));
      });
    }

    test('BOOKING_ALREADY_ASSIGNED uses the shortened trip-generated message', () {
      const expected =
          'Trip already generated. Please contact administrator to modify this booking.';
      expect(
          AppErrorMessages.bookingUpdateDefensive['BOOKING_ALREADY_ASSIGNED'],
          expected);
      expect(
          _resolve(_serverError(
              409, _envelope('BOOKING_ALREADY_ASSIGNED'))),
          expected);
    });
  });

  group('Booking update fallbacks', () {
    test('unknown code with 400 uses the update/rebook fallback', () {
      final message = _resolve(_serverError(400, _envelope('UNKNOWN_CODE')));
      expect(message, AppErrorMessages.bookingUpdateFailed);
    });

    test('unknown code without status uses the update/rebook fallback', () {
      final message = _resolve(_serverError(null, _envelope('UNKNOWN_CODE')));
      expect(message, AppErrorMessages.bookingUpdateFailed);
    });

    test('unknown 422 keeps the existing validation fallback', () {
      final message = _resolve(_serverError(422, _envelope('UNKNOWN_CODE')));
      expect(message, AppErrorMessages.fromStatusCode(422));
    });

    test('top-level error_code is still recognized', () {
      final message = _resolve(_serverError(400, {
        'success': false,
        'message': 'raw backend detail',
        'error_code': 'BOOKING_CUTOFF',
      }));
      expect(message, AppErrorMessages.bookingUpdate['BOOKING_CUTOFF']);
    });

    test('401 without a known code keeps the auth status message', () {
      final message = _resolve(_serverError(401, {'detail': 'Token expired'}));
      expect(message, AppErrorMessages.fromStatusCode(401));
    });
  });

  group('Cutoff message copy', () {
    test('BOOKING_CUTOFF uses the requested modification message', () {
      const expected =
          'Booking modification time has expired. Please contact your administrator.';
      expect(AppErrorMessages.bookingUpdate['BOOKING_CUTOFF'], expected);
      expect(_resolve(_serverError(400, _envelope('BOOKING_CUTOFF'))), expected);
    });

    test('CANCEL_CUTOFF uses the requested cancellation message', () {
      const expected =
          'Booking cancellation time has expired. Please contact your administrator.';
      expect(AppErrorMessages.booking['CANCEL_CUTOFF'], expected);
      final message = ApiError.resolve(
        _serverError(400, _envelope('CANCEL_CUTOFF')),
        feature: 'booking',
        fallback: 'Failed to cancel booking',
      );
      expect(message, expected);
    });
  });
}
