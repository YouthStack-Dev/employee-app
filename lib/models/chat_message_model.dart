/// Max characters per chat message. Mirrors the backend's
/// `CHAT_MAX_MESSAGE_LENGTH` (app/config.py) — keep these in sync.
const int kChatMaxMessageLength = 500;

DateTime? _parseUtcDateTime(Object? raw) {
  if (raw is DateTime) return raw.toUtc();
  if (raw is! String || raw.trim().isEmpty) return null;
  var value = raw.trim();
  if (!value.endsWith('Z') && !RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value)) {
    value = '${value}Z';
  }
  return DateTime.tryParse(value)?.toUtc();
}

int? _parseTimestamp(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

class ChatMessage {
  final int? id;
  final int? bookingId;
  final String senderType;
  final int? senderId;
  final String originalText;
  final String? originalLanguage;
  final String? translatedText;
  final Map<String, String>? translatedTexts;
  final String? firebaseMessageId;
  final bool isSystemMessage;
  final DateTime? createdAt;
  final int? timestamp;

  ChatMessage({
    this.id,
    this.bookingId,
    required this.senderType,
    this.senderId,
    required this.originalText,
    this.originalLanguage,
    this.translatedText,
    this.translatedTexts,
    this.firebaseMessageId,
    this.isSystemMessage = false,
    this.createdAt,
    this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    Map<String, String>? translated;
    final raw = json['translated_texts'];
    if (raw is Map) {
      translated = raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }

    DateTime? created = _parseUtcDateTime(json['created_at']);
    final timestamp = _parseTimestamp(json['timestamp']);
    created ??= timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);

    return ChatMessage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      bookingId: json['booking_id'] is int ? json['booking_id'] : int.tryParse(json['booking_id']?.toString() ?? ''),
      senderType: (json['sender_type'] ?? 'system').toString(),
      senderId: json['sender_id'] is int ? json['sender_id'] : int.tryParse(json['sender_id']?.toString() ?? ''),
      originalText: (json['original_text'] ?? '').toString(),
      originalLanguage: json['original_language']?.toString(),
      translatedText: json['translated_text']?.toString(),
      translatedTexts: translated,
      firebaseMessageId: json['firebase_message_id']?.toString(),
      isSystemMessage: json['is_system_message'] == true || json['is_system'] == true,
      createdAt: created,
      timestamp: timestamp,
    );
  }

  factory ChatMessage.fromFirebase(String key, Map<dynamic, dynamic> data) {
    Map<String, String>? translated;
    final raw = data['translated_texts'];
    if (raw is Map) {
      translated = raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }

    final timestamp = _parseTimestamp(data['timestamp']);
    return ChatMessage(
      firebaseMessageId: key,
      senderType: (data['sender_type'] ?? 'system').toString(),
      senderId: data['sender_id'] is int ? data['sender_id'] : int.tryParse(data['sender_id']?.toString() ?? ''),
      originalText: (data['original_text'] ?? '').toString(),
      originalLanguage: data['original_language']?.toString(),
      translatedText: data['translated_text']?.toString(),
      translatedTexts: translated,
      isSystemMessage: data['is_system'] == true || data['is_system_message'] == true,
      createdAt: timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
      timestamp: timestamp,
    );
  }

  String displayText(String viewerLanguage) {
    // Per API spec: the employee endpoint already auto-selects translated_text
    // for the viewer's language. translated_texts is admin-only and should
    // only be consulted if the canonical translated_text is missing.
    if (translatedText != null && translatedText!.isNotEmpty) {
      return translatedText!;
    }
    if (translatedTexts != null && translatedTexts![viewerLanguage] != null && translatedTexts![viewerLanguage]!.isNotEmpty) {
      return translatedTexts![viewerLanguage]!;
    }
    return originalText;
  }

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? get displayTime {
    if (createdAt != null) return createdAt!.toUtc();
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp!, isUtc: true);
    }
    return null;
  }

  DateTime get sortTime => displayTime ?? _epoch;

  ChatMessage copyWith({
    int? id,
    String? translatedText,
    Map<String, String>? translatedTexts,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      bookingId: bookingId,
      senderType: senderType,
      senderId: senderId,
      originalText: originalText,
      originalLanguage: originalLanguage,
      translatedText: translatedText ?? this.translatedText,
      translatedTexts: translatedTexts ?? this.translatedTexts,
      firebaseMessageId: firebaseMessageId,
      isSystemMessage: isSystemMessage,
      createdAt: createdAt,
      timestamp: timestamp,
    );
  }
}
