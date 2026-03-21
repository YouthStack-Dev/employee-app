class ReviewTagsResponse {
  final List<String> driverTags;
  final List<String> vehicleTags;

  ReviewTagsResponse({
    required this.driverTags,
    required this.vehicleTags,
  });

  factory ReviewTagsResponse.fromJson(Map<String, dynamic> json) {
    return ReviewTagsResponse(
      driverTags: List<String>.from(json['driver_tags'] ?? []),
      vehicleTags: List<String>.from(json['vehicle_tags'] ?? []),
    );
  }
}

class ReviewSubmission {
  final int? overallRating;
  final int? driverRating;
  final List<String>? driverTags;
  final String? driverComment;
  final int? vehicleRating;
  final List<String>? vehicleTags;
  final String? vehicleComment;

  ReviewSubmission({
    this.overallRating,
    this.driverRating,
    this.driverTags,
    this.driverComment,
    this.vehicleRating,
    this.vehicleTags,
    this.vehicleComment,
  });

  Map<String, dynamic> toJson() {
    return {
      if (overallRating != null) 'overall_rating': overallRating,
      if (driverRating != null) 'driver_rating': driverRating,
      if (driverTags != null && driverTags!.isNotEmpty) 'driver_tags': driverTags,
      if (driverComment != null && driverComment!.isNotEmpty) 'driver_comment': driverComment,
      if (vehicleRating != null) 'vehicle_rating': vehicleRating,
      if (vehicleTags != null && vehicleTags!.isNotEmpty) 'vehicle_tags': vehicleTags,
      if (vehicleComment != null && vehicleComment!.isNotEmpty) 'vehicle_comment': vehicleComment,
    };
  }
}

class RideReview {
  final int reviewId;
  final int bookingId;
  final int employeeId;
  final String tenantId;
  final int? driverId;
  final int? vehicleId;
  final int? routeId;
  
  final int? overallRating;
  
  final int? driverRating;
  final List<String>? driverTags;
  final String? driverComment;
  
  final int? vehicleRating;
  final List<String>? vehicleTags;
  final String? vehicleComment;

  RideReview({
    required this.reviewId,
    required this.bookingId,
    required this.employeeId,
    required this.tenantId,
    this.driverId,
    this.vehicleId,
    this.routeId,
    this.overallRating,
    this.driverRating,
    this.driverTags,
    this.driverComment,
    this.vehicleRating,
    this.vehicleTags,
    this.vehicleComment,
  });

  factory RideReview.fromJson(Map<String, dynamic> json) {
    return RideReview(
      reviewId: json['review_id'],
      bookingId: json['booking_id'],
      employeeId: json['employee_id'],
      tenantId: json['tenant_id'],
      driverId: json['driver_id'],
      vehicleId: json['vehicle_id'],
      routeId: json['route_id'],
      overallRating: json['overall_rating'],
      driverRating: json['driver_rating'],
      driverTags: json['driver_tags'] != null ? List<String>.from(json['driver_tags']) : null,
      driverComment: json['driver_comment'],
      vehicleRating: json['vehicle_rating'],
      vehicleTags: json['vehicle_tags'] != null ? List<String>.from(json['vehicle_tags']) : null,
      vehicleComment: json['vehicle_comment'],
    );
  }
}
