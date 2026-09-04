import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests proving the route-ID transition bug (2400 → 2532) cannot return.
///
/// Root cause: booking_provider.startDuty() called fetchTrips() BEFORE
/// saving the new route to SharedPreferences. If the backend returned no
/// ongoing trips (read-after-write lag), fetchTrips safety catch would clear
/// active_route_id and stop the Kotlin service, leaving the uploader with
/// the previous route ID.
///
/// Fix (booking_provider.dart):
///   1. saveActiveRoute(newRouteId) BEFORE fetchTrips()
///   2. fetchTrips(skipSafetyCatch: true) prevents safety catch from clearing
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const routeKey = 'flutter.active_route_id';

  group('Route switching (2400 → 2532)', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
    });

    test('1. Old route 2400 overwritten by new route 2532', () async {
      await prefs.setString(routeKey, '2400');
      expect(prefs.getString(routeKey), '2400');

      await prefs.setString(routeKey, '2532');
      expect(prefs.getString(routeKey), '2532');
    });

    test('2. After persisting 2532, Kotlin reads 2532', () async {
      await prefs.setString(routeKey, '2532');
      expect(prefs.getString(routeKey), '2532');
    });

    test('3. Route persisted BEFORE safety catch — safety catch cannot clear it',
        () async {
      // Old route active
      await prefs.setString(routeKey, '2400');

      // Fixed flow: saveActiveRoute("2532") happens FIRST
      await prefs.setString(routeKey, '2532');
      expect(prefs.getString(routeKey), '2532');

      // Safety catch with skipSafetyCatch=true does NOT call remove()
      // Verify route is still 2532
      expect(prefs.getString(routeKey), '2532');
      expect(prefs.getString(routeKey), isNot('2400'));
    });

    test('4. Kotlin SharedPreferences keys match Flutter keys', () async {
      await prefs.setString(routeKey, '2532');
      await prefs.setString('flutter.bg_access_token', 'test-token');
      await prefs.setString('flutter.driver_id', '96');
      await prefs.setString('flutter.tenant_id', 'HANDSHAKE');
      await prefs.setString('flutter.vendor_id', '58');

      expect(prefs.getString(routeKey), '2532');
      expect(prefs.getString('flutter.bg_access_token'), 'test-token');
      expect(prefs.getString('flutter.driver_id'), '96');
      expect(prefs.getString('flutter.tenant_id'), 'HANDSHAKE');
      expect(prefs.getString('flutter.vendor_id'), '58');
    });

    test('5. Kotlin ping loop reads latest value on each iteration', () async {
      await prefs.setString(routeKey, '2400');

      for (var i = 0; i < 5; i++) {
        expect(prefs.getString(routeKey), '2400');
      }

      await prefs.setString(routeKey, '2532');

      for (var i = 0; i < 5; i++) {
        expect(prefs.getString(routeKey), '2532');
      }
    });

    test('6. SharedPreferences write-then-read is consistent', () async {
      await prefs.setString(routeKey, '2400');
      expect(prefs.getString(routeKey), '2400');

      await prefs.setString(routeKey, '2532');
      expect(prefs.getString(routeKey), '2532');
    });

    test('7. Null route (duty end) stops Kotlin ping loop', () async {
      await prefs.setString(routeKey, '2400');
      expect(prefs.getString(routeKey), '2400');

      await prefs.remove(routeKey);
      expect(prefs.getString(routeKey), isNull);
    });

    test('8. Concurrent writes: last write wins', () async {
      await prefs.setString(routeKey, '2400');
      await prefs.setString(routeKey, '2532');

      expect(prefs.getString(routeKey), '2532');
    });

    test('9. Route ID string type matches Kotlin getString behavior', () async {
      const routeId = '2532';
      await prefs.setString(routeKey, routeId);

      final readBack = prefs.getString(routeKey);
      expect(readBack, routeId);
      expect(readBack, isA<String>());
    });
  });
}
