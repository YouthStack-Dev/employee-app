import 'package:flutter_test/flutter_test.dart';
import 'package:employee_flutter/models/shift_model.dart';

Shift _shift(int id, String? gender, {String logType = 'IN'}) =>
    Shift(shiftId: id, gender: gender, logType: logType, shiftCode: 'S$id');

void main() {
  group('Shift.genderIsFemale', () {
    test('female (any case) is true', () {
      expect(Shift.genderIsFemale('Female'), isTrue);
      expect(Shift.genderIsFemale('female'), isTrue);
      expect(Shift.genderIsFemale('FEMALE'), isTrue);
      expect(Shift.genderIsFemale('  Female  '), isTrue);
    });
    test('non-female / unknown is false', () {
      expect(Shift.genderIsFemale('Male'), isFalse);
      expect(Shift.genderIsFemale('Other'), isFalse);
      expect(Shift.genderIsFemale(null), isFalse);
      expect(Shift.genderIsFemale(''), isFalse);
    });
  });

  group('Shift.isFemaleOnly', () {
    test('only true when gender == female', () {
      expect(_shift(1, 'Female').isFemaleOnly, isTrue);
      expect(_shift(2, 'Male').isFemaleOnly, isFalse);
      expect(_shift(3, 'Other').isFemaleOnly, isFalse);
      expect(_shift(4, null).isFemaleOnly, isFalse);
    });
  });

  group('Shift.visibleFor — strict split', () {
    final shifts = [
      _shift(1, 'Female'),
      _shift(2, 'Male'),
      _shift(3, 'Other'),
      _shift(4, null),
      _shift(5, 'Female'),
    ];

    test('female viewer sees ONLY female-only shifts', () {
      final visible = Shift.visibleFor(shifts, viewerIsFemale: true);
      expect(visible.map((s) => s.shiftId), [1, 5]);
    });

    test('non-female viewer sees everything EXCEPT female-only shifts', () {
      final visible = Shift.visibleFor(shifts, viewerIsFemale: false);
      expect(visible.map((s) => s.shiftId), [2, 3, 4]);
    });

    test('empty input yields empty output for both viewers', () {
      expect(Shift.visibleFor(<Shift>[], viewerIsFemale: true), isEmpty);
      expect(Shift.visibleFor(<Shift>[], viewerIsFemale: false), isEmpty);
    });
  });
}
