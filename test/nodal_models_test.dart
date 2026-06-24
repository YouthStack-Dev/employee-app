import 'package:flutter_test/flutter_test.dart';
import 'package:employee_flutter/models/nodal_models.dart';

void main() {
  group('VehicleNumber.normalize', () {
    test('trims, uppercases and strips internal spaces', () {
      expect(VehicleNumber.normalize('  ka 01 ab 1234 '), 'KA01AB1234');
      expect(VehicleNumber.normalize('ka01ab1234'), 'KA01AB1234');
      expect(VehicleNumber.normalize('KA01AB1234'), 'KA01AB1234');
    });
  });

  group('VehicleNumber.isValid', () {
    test('accepts valid Indian RC plates', () {
      expect(VehicleNumber.isValid('KA01AB1234'), isTrue);
      expect(VehicleNumber.isValid('ka01ab1234'), isTrue); // normalized first
      expect(VehicleNumber.isValid('MH12DE1432'), isTrue);
      expect(VehicleNumber.isValid('KA 01 AB 1234'), isTrue); // spaces stripped
      expect(VehicleNumber.isValid('KA1A1'), isTrue); // minimal valid form
    });

    test('rejects malformed values', () {
      expect(VehicleNumber.isValid(''), isFalse);
      expect(VehicleNumber.isValid('123'), isFalse);
      expect(VehicleNumber.isValid('ABCDEF'), isFalse);
      expect(VehicleNumber.isValid('KA01AB12345'), isFalse); // 5 trailing digits > \d{1,4}
      expect(VehicleNumber.isValid('1A01AB1234'), isFalse); // must start with 2 letters
    });
  });

  group('NodalPoint.fromJson', () {
    test('parses the assignment payload including is_overridden', () {
      final p = NodalPoint.fromJson({
        'nodal_point_id': 3,
        'name': 'HSR Layout Hub',
        'address': 'HSR Layout, Bangalore',
        'latitude': 12.9116,
        'longitude': 77.6389,
        'is_overridden': false,
      });
      expect(p.nodalPointId, 3);
      expect(p.name, 'HSR Layout Hub');
      expect(p.address, 'HSR Layout, Bangalore');
      expect(p.latitude, closeTo(12.9116, 1e-9));
      expect(p.longitude, closeTo(77.6389, 1e-9));
      expect(p.isOverridden, isFalse);
      expect(p.hasCoordinates, isTrue);
    });

    test('coerces numeric strings and tolerates missing optional fields', () {
      final p = NodalPoint.fromJson({
        'nodal_point_id': '7',
        'name': 'Hub 7',
        'latitude': '12.5',
        'longitude': '77.1',
      });
      expect(p.nodalPointId, 7);
      expect(p.latitude, closeTo(12.5, 1e-9));
      expect(p.isOverridden, isNull);
      expect(p.address, isNull);
    });
  });

  group('NodalScanResult.fromJson', () {
    test('parses scan response with nested nodal_point', () {
      final r = NodalScanResult.fromJson({
        'booking_id': 101,
        'status': 'Ongoing',
        'route_id': 5,
        'nodal_point': {
          'nodal_point_id': 3,
          'name': 'HSR Layout Hub',
          'address': 'HSR Layout, Bangalore',
          'latitude': 12.9116,
          'longitude': 77.6389,
        },
        'message': 'You have been marked as onboarded at the nodal point.',
      });
      expect(r.bookingId, 101);
      expect(r.status, 'Ongoing');
      expect(r.routeId, 5);
      expect(r.nodalPoint, isNotNull);
      expect(r.nodalPoint!.name, 'HSR Layout Hub');
      expect(r.message, contains('onboarded'));
    });

    test('handles missing nodal_point gracefully', () {
      final r = NodalScanResult.fromJson({
        'booking_id': 9,
        'status': 'Ongoing',
        'route_id': 2,
      });
      expect(r.nodalPoint, isNull);
      expect(r.bookingId, 9);
      expect(r.message, isNotEmpty);
    });
  });
}
