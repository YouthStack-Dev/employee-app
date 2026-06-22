class ChatSession {
  final int? id;
  final int? bookingId;
  final int? employeeId;
  final int? driverId;
  final String employeeLanguage;
  final String driverLanguage;
  final bool isActive;
  final DateTime? activatedAt;
  final DateTime? createdAt;
  final String? warningMessage;
  final String? firebasePath;
  final bool created;

  ChatSession({
    this.id,
    this.bookingId,
    this.employeeId,
    this.driverId,
    this.employeeLanguage = 'en',
    this.driverLanguage = 'en',
    this.isActive = true,
    this.activatedAt,
    this.createdAt,
    this.warningMessage,
    this.firebasePath,
    this.created = false,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return ChatSession(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      bookingId: json['booking_id'] is int ? json['booking_id'] : int.tryParse(json['booking_id']?.toString() ?? ''),
      employeeId: json['employee_id'] is int ? json['employee_id'] : int.tryParse(json['employee_id']?.toString() ?? ''),
      driverId: json['driver_id'] is int ? json['driver_id'] : int.tryParse(json['driver_id']?.toString() ?? ''),
      employeeLanguage: (json['employee_language'] ?? 'en').toString(),
      driverLanguage: (json['driver_language'] ?? 'en').toString(),
      isActive: json['is_active'] != false,
      activatedAt: parseDate(json['activated_at']),
      createdAt: parseDate(json['created_at']),
      warningMessage: json['warning_message']?.toString(),
      firebasePath: json['firebase_path']?.toString(),
      created: json['created'] == true,
    );
  }

  ChatSession copyWith({
    String? employeeLanguage,
    String? driverLanguage,
    bool? isActive,
  }) {
    return ChatSession(
      id: id,
      bookingId: bookingId,
      employeeId: employeeId,
      driverId: driverId,
      employeeLanguage: employeeLanguage ?? this.employeeLanguage,
      driverLanguage: driverLanguage ?? this.driverLanguage,
      isActive: isActive ?? this.isActive,
      activatedAt: activatedAt,
      createdAt: createdAt,
      warningMessage: warningMessage,
      firebasePath: firebasePath,
      created: created,
    );
  }
}
