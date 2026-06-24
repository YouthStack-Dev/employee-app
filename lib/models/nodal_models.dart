/// Models for the Employee Nodal (QR onboarding) feature.
/// Backed by:
///   GET  /api/v1/employee/nodal/assignment  -> NodalPoint (with is_overridden)
///   POST /api/v1/employee/nodal/scan         -> NodalScanResult (embeds NodalPoint)

class NodalPoint {
  final int? nodalPointId;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// Only present on the assignment endpoint; true when an admin manually
  /// picked this hub rather than the system assigning the nearest one.
  final bool? isOverridden;

  const NodalPoint({
    this.nodalPointId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.isOverridden,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory NodalPoint.fromJson(Map<String, dynamic> json) {
    return NodalPoint(
      nodalPointId: json['nodal_point_id'] is int
          ? json['nodal_point_id']
          : int.tryParse(json['nodal_point_id']?.toString() ?? ''),
      name: (json['name'] ?? 'Nodal point').toString(),
      address: json['address']?.toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isOverridden: json['is_overridden'] is bool
          ? json['is_overridden'] as bool
          : (json['is_overridden'] == null ? null : json['is_overridden'].toString() == 'true'),
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;
}

class NodalScanResult {
  final int? bookingId;
  final String? status;
  final int? routeId;
  final NodalPoint? nodalPoint;
  final String message;

  const NodalScanResult({
    this.bookingId,
    this.status,
    this.routeId,
    this.nodalPoint,
    this.message = 'You have been marked as onboarded at the nodal point.',
  });

  factory NodalScanResult.fromJson(Map<String, dynamic> json) {
    NodalPoint? np;
    final raw = json['nodal_point'];
    if (raw is Map<String, dynamic>) {
      np = NodalPoint.fromJson(raw);
    } else if (raw is Map) {
      np = NodalPoint.fromJson(Map<String, dynamic>.from(raw));
    }
    return NodalScanResult(
      bookingId: json['booking_id'] is int
          ? json['booking_id']
          : int.tryParse(json['booking_id']?.toString() ?? ''),
      status: json['status']?.toString(),
      routeId: json['route_id'] is int
          ? json['route_id']
          : int.tryParse(json['route_id']?.toString() ?? ''),
      nodalPoint: np,
      message: (json['message'] ?? 'You have been marked as onboarded at the nodal point.').toString(),
    );
  }
}

/// Client-side helpers mirroring the backend `NodalQRScanRequest` validation:
/// normalize to trimmed uppercase (spaces removed) and match the Indian RC
/// plate pattern `^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,4}$` (4–15 chars).
class VehicleNumber {
  static final RegExp _pattern = RegExp(r'^[A-Z]{2}\d{1,2}[A-Z]{1,2}\d{1,4}$');

  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static bool isValid(String raw) {
    final v = normalize(raw);
    return v.length >= 4 && v.length <= 15 && _pattern.hasMatch(v);
  }
}
