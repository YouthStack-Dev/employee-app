import 'package:flutter_test/flutter_test.dart';
import 'package:employee_flutter/models/nodal_models.dart';
import 'package:employee_flutter/providers/nodal_provider.dart';
import 'package:employee_flutter/services/nodal_service.dart';

/// Fake service that returns canned maps without any network/Dio call.
class _FakeNodalService extends NodalService {
  Map<String, dynamic> assignmentResult;
  Map<String, dynamic> scanResult;
  int scanCalls = 0;
  String? lastScanned;

  _FakeNodalService({
    this.assignmentResult = const {'success': false, 'error': 'none'},
    this.scanResult = const {'success': false, 'error': 'none'},
  });

  @override
  Future<Map<String, dynamic>> getAssignment() async => assignmentResult;

  @override
  Future<Map<String, dynamic>> scan(String vehicleNumber) async {
    scanCalls++;
    lastScanned = vehicleNumber;
    return scanResult;
  }
}

void main() {
  test('scan rejects an invalid vehicle number WITHOUT hitting the service', () async {
    final fake = _FakeNodalService();
    final provider = NodalProvider(service: fake);

    final result = await provider.scan('123');

    expect(result, isNull);
    expect(fake.scanCalls, 0, reason: 'invalid input must not call the API');
    expect(provider.scanError, isNotNull);
    expect(provider.isScanning, isFalse);
  });

  test('scan normalizes input and forwards the cleaned value on success', () async {
    final fake = _FakeNodalService(
      scanResult: {
        'success': true,
        'data': NodalScanResult.fromJson({
          'booking_id': 101,
          'status': 'Ongoing',
          'route_id': 5,
          'message': 'ok',
        }),
      },
    );
    final provider = NodalProvider(service: fake);

    final result = await provider.scan('  ka 01 ab 1234 ');

    expect(result, isNotNull);
    expect(fake.scanCalls, 1);
    expect(fake.lastScanned, 'KA01AB1234', reason: 'value must be normalized before send');
    expect(provider.lastResult?.bookingId, 101);
    expect(provider.scanError, isNull);
    expect(provider.isScanning, isFalse);
  });

  test('scan surfaces the service error on failure', () async {
    final fake = _FakeNodalService(
      scanResult: {'success': false, 'error': 'No active trip is running for this vehicle right now.'},
    );
    final provider = NodalProvider(service: fake);

    final result = await provider.scan('KA01AB1234');

    expect(result, isNull);
    expect(fake.scanCalls, 1);
    expect(provider.scanError, contains('No active trip'));
  });

  test('fetchAssignment populates assignment on success', () async {
    final fake = _FakeNodalService(
      assignmentResult: {
        'success': true,
        'data': NodalPoint.fromJson({
          'nodal_point_id': 3,
          'name': 'HSR Layout Hub',
          'latitude': 12.9116,
          'longitude': 77.6389,
          'is_overridden': true,
        }),
      },
    );
    final provider = NodalProvider(service: fake);

    await provider.fetchAssignment();

    expect(provider.assignment, isNotNull);
    expect(provider.assignment!.name, 'HSR Layout Hub');
    expect(provider.assignment!.isOverridden, isTrue);
    expect(provider.assignmentError, isNull);
  });

  test('fetchAssignment records a friendly error when none is assigned', () async {
    final fake = _FakeNodalService(
      assignmentResult: {'success': false, 'error': 'No nodal point has been assigned to you yet.'},
    );
    final provider = NodalProvider(service: fake);

    await provider.fetchAssignment();

    expect(provider.assignment, isNull);
    expect(provider.assignmentError, contains('No nodal point'));
  });

  test('clearScanError resets the error', () async {
    final fake = _FakeNodalService();
    final provider = NodalProvider(service: fake);
    await provider.scan('123'); // sets an error
    expect(provider.scanError, isNotNull);

    provider.clearScanError();
    expect(provider.scanError, isNull);
  });
}
