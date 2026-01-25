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
}
