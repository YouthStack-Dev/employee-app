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

  /// A shift whose `gender` is explicitly "Female" (case-insensitive).
  bool get isFemaleOnly => (gender ?? '').trim().toLowerCase() == 'female';

  /// A shift whose `gender` is explicitly "Male" (case-insensitive).
  bool get isMaleOnly => (gender ?? '').trim().toLowerCase() == 'male';

  /// Any gender value other than "male" / "female" is treated as "both".
  bool get isBothGender => !isFemaleOnly && !isMaleOnly;

  /// Gender-based visibility:
  ///  - female viewer sees female-only + both-gender shifts
  ///  - male viewer sees male-only + both-gender shifts
  ///  - other / unknown viewer sees all shifts
  static List<Shift> visibleFor(List<Shift> shifts, {required bool viewerIsFemale}) {
    return shifts.where((s) {
      if (s.isBothGender) return true;
      if (viewerIsFemale) return s.isFemaleOnly;
      return s.isMaleOnly;
    }).toList();
  }

  /// Whether a profile gender string denotes female (case-insensitive).
  static bool genderIsFemale(String? gender) =>
      (gender ?? '').trim().toLowerCase() == 'female';
}
