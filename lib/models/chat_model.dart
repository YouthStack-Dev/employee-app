class ChatSession {
  final int id;
  final int bookingId;
  final int employeeId;
  final int? driverId;
  final String employeeLanguage;
  final String driverLanguage;
  final bool isActive;
  final String? activatedAt;
  final String? createdAt;
  final String? warningMessage;
  final String? firebasePath;
  final bool created;

  const ChatSession({
    required this.id,
    required this.bookingId,
    required this.employeeId,
    this.driverId,
    required this.employeeLanguage,
    required this.driverLanguage,
    required this.isActive,
    this.activatedAt,
    this.createdAt,
    this.warningMessage,
    this.firebasePath,
    this.created = false,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? 0,
      bookingId: json['booking_id'] ?? 0,
      employeeId: json['employee_id'] ?? 0,
      driverId: json['driver_id'],
      employeeLanguage: json['employee_language'] ?? 'en',
      driverLanguage: json['driver_language'] ?? 'en',
      isActive: json['is_active'] ?? true,
      activatedAt: json['activated_at'],
      createdAt: json['created_at'],
      warningMessage: json['warning_message'],
      firebasePath: json['firebase_path'],
      created: json['created'] ?? false,
    );
  }

  ChatSession copyWith({String? employeeLanguage, String? driverLanguage}) {
    return ChatSession(
      id: id,
      bookingId: bookingId,
      employeeId: employeeId,
      driverId: driverId,
      employeeLanguage: employeeLanguage ?? this.employeeLanguage,
      driverLanguage: driverLanguage ?? this.driverLanguage,
      isActive: isActive,
      activatedAt: activatedAt,
      createdAt: createdAt,
      warningMessage: warningMessage,
      firebasePath: firebasePath,
      created: created,
    );
  }
}

class ChatMessage {
  final int? id;
  final int? bookingId;
  final String senderType; // 'employee' | 'driver' | 'system'
  final int? senderId;
  final String originalText;
  final String originalLanguage;
  String translatedText; // mutable — patched by Firebase listener
  final String? firebaseMessageId; // RTDB push key
  final bool isSystemMessage;
  final DateTime? createdAt;
  final int? timestamp; // from Firebase (millis)

  ChatMessage({
    this.id,
    this.bookingId,
    required this.senderType,
    this.senderId,
    required this.originalText,
    this.originalLanguage = 'en',
    required this.translatedText,
    this.firebaseMessageId,
    this.isSystemMessage = false,
    this.createdAt,
    this.timestamp,
  });

  /// Parse from REST API response
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      bookingId: json['booking_id'],
      senderType: json['sender_type'] ?? 'system',
      senderId: json['sender_id'],
      originalText: json['original_text'] ?? '',
      originalLanguage: json['original_language'] ?? 'en',
      translatedText: json['translated_text'] ?? json['original_text'] ?? '',
      firebaseMessageId: json['firebase_message_id'],
      isSystemMessage: json['is_system_message'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  /// Parse from Firebase RTDB snapshot value
  factory ChatMessage.fromFirebase(String pushKey, Map<dynamic, dynamic> data) {
    final ts = data['timestamp'];
    DateTime? createdAt;
    if (ts != null) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
          int.tryParse(ts.toString()) ?? 0);
    }
    return ChatMessage(
      senderType: data['sender_type']?.toString() ?? 'system',
      senderId: data['sender_id'] != null
          ? int.tryParse(data['sender_id'].toString())
          : null,
      originalText: data['original_text']?.toString() ?? '',
      originalLanguage: data['original_language']?.toString() ?? 'en',
      translatedText: data['translated_text']?.toString() ??
          data['original_text']?.toString() ??
          '',
      firebaseMessageId: pushKey,
      isSystemMessage: data['is_system'] == true || data['is_system_message'] == true,
      createdAt: createdAt,
      timestamp: ts != null ? int.tryParse(ts.toString()) : null,
    );
  }

  /// Unique key for deduplication across REST + Firebase sources
  String get key => firebaseMessageId ?? 'rest_${id ?? originalText.hashCode}';

  DateTime get sortTime =>
      createdAt ?? (timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp!)
          : DateTime.now());
}

class SupportedLanguages {
  final Map<String, String> languages;

  const SupportedLanguages({required this.languages});

  factory SupportedLanguages.fromJson(Map<String, dynamic> json) {
    final raw = json['languages'] as Map<String, dynamic>? ?? {};
    return SupportedLanguages(
      languages: raw.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}
