import 'package:employee_flutter/providers/announcement_provider.dart';
import 'package:employee_flutter/providers/auth_provider.dart';
import 'package:employee_flutter/providers/booking_provider.dart';
import 'package:employee_flutter/providers/time_format_provider.dart';
import 'package:employee_flutter/screens/schedules_screen.dart';
import 'package:employee_flutter/widgets/fx_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _EmptyAuthProvider extends AuthProvider {
  @override
  Future<List<Map<String, dynamic>>> getSwitchableTenants() async => const [];
}

Widget _app({Object? arguments}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => _EmptyAuthProvider()),
      ChangeNotifierProvider<BookingProvider>(create: (_) => BookingProvider()),
      ChangeNotifierProvider<AnnouncementProvider>(
        create: (_) => AnnouncementProvider(),
      ),
      ChangeNotifierProvider<TimeFormatProvider>(
        create: (_) => TimeFormatProvider(),
      ),
    ],
    child: MaterialApp(
      key: ValueKey(arguments?.toString() ?? 'none'),
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        settings: RouteSettings(name: '/schedules', arguments: arguments),
        builder: (_) => const SchedulesScreen(),
      ),
    ),
  );
}

void main() {
  const message = '2 round-trip booking(s) created successfully';

  testWidgets('SchedulesScreen reads route arguments after dependencies resolve',
      (tester) async {
    await tester.pumpWidget(_app(arguments: message));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SchedulesScreen), findsOneWidget);
    expect(find.byType(FxSuccessBanner), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Upcoming Rides')).dy,
      lessThan(tester.getTopLeft(find.text(message)).dy),
    );

    await tester.pump();
    expect(find.byType(FxSuccessBanner), findsOneWidget);

    await tester.pump(const Duration(seconds: 4, milliseconds: 1));
    expect(find.byType(FxSuccessBanner), findsNothing);
  });

  testWidgets('SchedulesScreen opens without route arguments', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SchedulesScreen), findsOneWidget);
    expect(find.text('Upcoming Rides'), findsOneWidget);
    expect(find.byType(FxSuccessBanner), findsNothing);
  });

  testWidgets('SchedulesScreen accepts login-only logout-only and combined messages',
      (tester) async {
    const messages = [
      'Login booking created successfully',
      'Logout booking created successfully',
      'Login and logout bookings created successfully',
    ];

    for (final text in messages) {
      await tester.pumpWidget(_app(arguments: text));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(text), findsOneWidget);
    }
  });
}
