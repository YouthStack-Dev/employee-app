class Shift {
  final int? shiftId;
  final String? tenantId;
  final String? shiftCode;
  final String? name;
  final String? shiftTime;
  final String? startTime;
  final String? endTime;
  final String? logType; // 'IN' or 'OUT'
  final String? pickupType;
  final String? gender;
  final bool? isActive;

  Shift({
    this.shiftId,
    this.tenantId,
    this.shiftCode,
    this.name,
    this.shiftTime,
    this.startTime,
    this.endTime,
    this.logType,
    this.pickupType,
    this.gender,
    this.isActive,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      shiftId: json['shift_id'],
      tenantId: json['tenant_id'],
      shiftCode: json['shift_code'],
      name: json['name'],
      shiftTime: json['shift_time'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      logType: json['log_type'],
      pickupType: json['pickup_type'],
      gender: json['gender'],
      isActive: json['is_active'],
    );
  }

  /// A shift whose `gender` is explicitly "Female" (case-insensitive) — a
  /// female-only shift. Male / Other / null are treated as general.
  bool get isFemaleOnly => (gender ?? '').trim().toLowerCase() == 'female';

  /// Gender-based visibility ("strict split"):
  ///  - a female viewer sees ONLY female-only shifts
  ///  - everyone else (male / other / unknown) sees everything EXCEPT
  ///    female-only shifts
  static List<Shift> visibleFor(List<Shift> shifts, {required bool viewerIsFemale}) {
    if (viewerIsFemale) {
      return shifts.where((s) => s.isFemaleOnly).toList();
    }
    return shifts.where((s) => !s.isFemaleOnly).toList();
  }

  /// Whether a profile gender string denotes female (case-insensitive).
  static bool genderIsFemale(String? gender) =>
      (gender ?? '').trim().toLowerCase() == 'female';
}
