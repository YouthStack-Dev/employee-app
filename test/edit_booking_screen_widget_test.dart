import 'package:employee_flutter/constants/error_messages.dart';
import 'package:employee_flutter/models/booking_model.dart';
import 'package:employee_flutter/models/shift_model.dart';
import 'package:employee_flutter/providers/time_format_provider.dart';
import 'package:employee_flutter/screens/edit_booking_screen.dart';
import 'package:employee_flutter/services/booking_service.dart';
import 'package:employee_flutter/services/shift_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBookingService extends BookingService {
  FakeBookingService({
    required this.status,
    this.errorMessage,
    this.omitError = false,
  });

  final String status;
  final String? errorMessage;
  final bool omitError;
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> getBookingDetails(int bookingId) async => {
        'success': true,
        'data': Booking(
          id: bookingId,
          status: status,
          date: '2026-12-01',
          shiftId: 11,
        ),
      };

  @override
  Future<Map<String, dynamic>> updateBooking(
    int bookingId,
    Map<String, dynamic> updateData,
  ) async {
    lastPayload = updateData;
    if (omitError) return {'success': false};
    if (errorMessage != null) {
      return {'success': false, 'error': errorMessage};
    }
    return {
      'success': true,
      'data': Booking(
        id: bookingId,
        status: status,
        date: '2026-12-01',
        shiftId: 12,
      ),
      'message': 'Booking updated successfully',
    };
  }
}

class FakeShiftService extends ShiftService {
  @override
  Future<Map<String, dynamic>> fetchShifts() async => {
        'success': true,
        'shifts': {
          'in': [
            Shift(
              shiftId: 11,
              shiftCode: 'IN11',
              shiftTime: '08:00',
              logType: 'IN',
              isActive: true,
            ),
            Shift(
              shiftId: 12,
              shiftCode: 'IN12',
              shiftTime: '17:00',
              logType: 'IN',
              isActive: true,
            ),
          ],
          'out': <Shift>[],
        },
      };
}

Widget _app(EditBookingScreen screen) => ChangeNotifierProvider(
      create: (_) => TimeFormatProvider(),
      child: MaterialApp(home: screen),
    );

Future<void> _submit(WidgetTester tester, String actionLabel) async {
  await tester.tap(find.text('17:00'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(actionLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text(actionLabel == 'Rebook booking' ? 'Rebook' : 'Update'));
  await tester.pumpAndSettle();
}

void main() {
  final codes = AppErrorMessages.bookingUpdate.keys.toList();

  setUp(() {
    SharedPreferences.setMockInitialValues({'gender': 'MALE'});
  });

  for (final code in codes) {
    testWidgets('$code displays its mapped message in an error snackbar',
        (tester) async {
      final message = AppErrorMessages.bookingUpdate[code]!;
      final service = FakeBookingService(status: 'Request', errorMessage: message);

      await tester.pumpWidget(_app(EditBookingScreen(
        bookingId: 7,
        bookingService: service,
        shiftService: FakeShiftService(),
      )));
      await tester.pumpAndSettle();

      await _submit(tester, 'Update booking');

      expect(find.text(message), findsOneWidget);
      expect(find.text('raw backend detail'), findsNothing);
    });
  }

  testWidgets('status-specific INVALID_BOOKING_STATUS message is displayed',
      (tester) async {
    final message = AppErrorMessages.bookingUpdateStatus['ONGOING']!;
    final service = FakeBookingService(status: 'Request', errorMessage: message);

    await tester.pumpWidget(_app(EditBookingScreen(
      bookingId: 7,
      bookingService: service,
      shiftService: FakeShiftService(),
    )));
    await tester.pumpAndSettle();

    await _submit(tester, 'Update booking');

    expect(find.text(message), findsOneWidget);
    expect(find.text(AppErrorMessages.booking['INVALID_BOOKING_STATUS']!),
        findsNothing);
  });

  testWidgets('failed update without a message uses the update fallback',
      (tester) async {
    final service = FakeBookingService(
      status: 'Request',
      omitError: true,
    );

    await tester.pumpWidget(_app(EditBookingScreen(
      bookingId: 7,
      bookingService: service,
      shiftService: FakeShiftService(),
    )));
    await tester.pumpAndSettle();

    await _submit(tester, 'Update booking');

    expect(find.text(AppErrorMessages.bookingUpdateFailed), findsOneWidget);
  });

  testWidgets('rebook flow keeps the rebook payload and shows mapped message',
      (tester) async {
    final message = AppErrorMessages.bookingUpdate['INVALID_REBOOK_STATUS']!;
    final service = FakeBookingService(status: 'Cancelled', errorMessage: message);

    await tester.pumpWidget(_app(EditBookingScreen(
      bookingId: 7,
      bookingService: service,
      shiftService: FakeShiftService(),
    )));
    await tester.pumpAndSettle();

    await _submit(tester, 'Rebook booking');

    expect(service.lastPayload, {
      'shift_id': 12,
      'rebook': true,
      'booking_date': '2026-12-01',
    });
    expect(find.text(message), findsOneWidget);
  });
}
