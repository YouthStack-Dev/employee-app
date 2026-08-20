class Booking {
  final int? id;
  final String? status;
  final String? date;
  final String? pickupLocation;
  final String? dropLocation;
  final String? pickupTime;
  final String? dropTime;
  final String? logType;
  final int? shiftId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropLatitude;
  final double? dropLongitude;
  final Map<String, dynamic>? routeDetails;
  final int? tenantId;
  final String? boardingOtp;
  final String? deboardingOtp;
  final String? escortOtp;
  final String? shiftTime;

  Booking({
    this.id,
    this.status,
    this.date,
    this.pickupLocation,
    this.dropLocation,
    this.pickupTime,
    this.dropTime,
    this.logType,
    this.shiftId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.dropLatitude,
    this.dropLongitude,
    this.routeDetails,
    this.tenantId,
    this.boardingOtp,
    this.deboardingOtp,
    this.escortOtp,
    this.shiftTime,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['booking_id'] is int ? json['booking_id'] : int.tryParse(json['booking_id']?.toString() ?? ''),
      status: json['status'],
      date: json['booking_date'] ?? json['date'],
      pickupLocation: json['pickup_location'],
      dropLocation: json['drop_location'],
      pickupTime: json['pickup_time'],
      dropTime: json['drop_time'] ?? json['end_time']?.toString(),
      logType: json['log_type'],
      shiftId: json['shift_id'] is int ? json['shift_id'] : int.tryParse(json['shift_id']?.toString() ?? ''),
      pickupLatitude: double.tryParse(json['pickup_latitude']?.toString() ?? '0'),
      pickupLongitude: double.tryParse(json['pickup_longitude']?.toString() ?? '0'),
      dropLatitude: double.tryParse(json['drop_latitude']?.toString() ?? '0'),
      dropLongitude: double.tryParse(json['drop_longitude']?.toString() ?? '0'),
      routeDetails: json['route_details'] != null
          ? Map<String, dynamic>.from(json['route_details'])
          : (json['route'] is Map ? Map<String, dynamic>.from(json['route']) : null),
      tenantId: json['tenant_id'] is int ? json['tenant_id'] : int.tryParse(json['tenant_id']?.toString() ?? ''),
      boardingOtp: json['boarding_otp']?.toString(),
      deboardingOtp: json['deboarding_otp']?.toString(),
      escortOtp: json['escort_otp']?.toString(),
      shiftTime: json['shift_time']?.toString(),
    );
  }
  Booking copyWith({
    int? id,
    String? status,
    String? date,
    String? pickupLocation,
    String? dropLocation,
    String? pickupTime,
    String? dropTime,
    String? logType,
    int? shiftId,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropLatitude,
    double? dropLongitude,
    Map<String, dynamic>? routeDetails,
    int? tenantId,
    String? boardingOtp,
    String? deboardingOtp,
    String? escortOtp,
    String? shiftTime,
  }) {
    return Booking(
      id: id ?? this.id,
      status: status ?? this.status,
      date: date ?? this.date,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      pickupTime: pickupTime ?? this.pickupTime,
      dropTime: dropTime ?? this.dropTime,
      logType: logType ?? this.logType,
      shiftId: shiftId ?? this.shiftId,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropLatitude: dropLatitude ?? this.dropLatitude,
      dropLongitude: dropLongitude ?? this.dropLongitude,
      routeDetails: routeDetails ?? this.routeDetails,
      tenantId: tenantId ?? this.tenantId,
      boardingOtp: boardingOtp ?? this.boardingOtp,
      deboardingOtp: deboardingOtp ?? this.deboardingOtp,
      escortOtp: escortOtp ?? this.escortOtp,
      shiftTime: shiftTime ?? this.shiftTime,
    );
  }
}
