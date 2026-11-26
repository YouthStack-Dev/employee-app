import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:employee_flutter/constants/api_constants.dart';
import 'package:employee_flutter/constants/error_messages.dart';
import 'package:employee_flutter/services/api_service.dart';
import 'package:employee_flutter/services/booking_service.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({required this.responseBody, this.statusCode = 200});

  final Map<String, dynamic> responseBody;
  final int statusCode;
  String? capturedMethod;
  String? capturedPath;
  Map<String, dynamic>? capturedBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedMethod = options.method;
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

Map<String, dynamic> _successBody() => {
      'success': true,
      'message': 'Booking updated successfully',
      'data': {
        'booking_id': 7,
        'status': 'Request',
        'booking_date': '2026-12-01',
        'shift_id': 11,
      },
    };

Map<String, dynamic> _errorBody(
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

void main() {
  group('BookingService.updateBooking', () {
    test('sends PUT to the employee booking endpoint with shift change payload',
        () async {
      final adapter = RecordingAdapter(responseBody: _successBody());
      final result = await _serviceWith(adapter).updateBooking(7, {
        'shift_id': 11,
      });

      expect(result['success'], true);
      expect(adapter.capturedMethod, 'PUT');
      expect(adapter.capturedPath, '${ApiConstants.bookingOperations}/7');
      expect(adapter.capturedBody, {'shift_id': 11});
    });

    test('sends rebook flag and date for cancelled bookings', () async {
      final adapter = RecordingAdapter(responseBody: _successBody());
      await _serviceWith(adapter).updateBooking(7, {
        'shift_id': 12,
        'rebook': true,
        'booking_date': '2026-12-01',
      });

      expect(adapter.capturedBody, {
        'shift_id': 12,
        'rebook': true,
        'booking_date': '2026-12-01',
      });
    });

    for (final code in AppErrorMessages.bookingUpdate.keys) {
      test('$code returns the update-specific message', () async {
        final adapter = RecordingAdapter(
          responseBody: _errorBody(code),
          statusCode: 400,
        );
        final result = await _serviceWith(adapter).updateBooking(7, {
          'shift_id': 12,
        });

        expect(result['success'], false);
        expect(result['error'], AppErrorMessages.bookingUpdate[code]);
        expect(result['error'], isNot(contains('raw backend detail')));
      });
    }

    test('INVALID_BOOKING_STATUS uses details.current_status', () async {
      final adapter = RecordingAdapter(
        responseBody: _errorBody('INVALID_BOOKING_STATUS', details: {
          'current_status': 'No-Show',
          'allowed_statuses': ['REQUEST', 'CANCELLED'],
        }),
        statusCode: 400,
      );
      final result = await _serviceWith(adapter).updateBooking(7, {
        'shift_id': 12,
      });

      expect(result['error'],
          AppErrorMessages.bookingUpdateStatus['NO_SHOW']);
    });

    test('unknown code uses the update/rebook fallback', () async {
      final adapter = RecordingAdapter(
        responseBody: _errorBody('UNKNOWN_CODE'),
        statusCode: 400,
      );
      final result = await _serviceWith(adapter).updateBooking(7, {
        'shift_id': 12,
      });

      expect(result['error'], AppErrorMessages.bookingUpdateFailed);
    });
  });
}
