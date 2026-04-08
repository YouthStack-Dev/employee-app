class Announcement {
  final int announcementId;
  final String title;
  final String? body;
  final String contentType;
  final String? mediaUrl;
  final String? mediaFilename;
  final DateTime? publishedAt;
  final String deliveryStatus;
  final DateTime? readAt;
  final int recipientId;

  Announcement({
    required this.announcementId,
    required this.title,
    this.body,
    required this.contentType,
    this.mediaUrl,
    this.mediaFilename,
    this.publishedAt,
    required this.deliveryStatus,
    this.readAt,
    required this.recipientId,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      announcementId: json['announcement_id'] != null 
          ? json['announcement_id'] as int 
          : throw const FormatException('Missing required field: announcement_id'),
      title: json['title'] != null 
          ? json['title'] as String 
          : throw const FormatException('Missing required field: title'),
      body: json['body'] as String?,
      contentType: json['content_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      mediaFilename: json['media_filename'] as String?,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
      deliveryStatus: json['delivery_status'] as String? ?? 'pending',
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      recipientId: json['recipient_id'] != null 
          ? json['recipient_id'] as int 
          : throw const FormatException('Missing required field: recipient_id'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'announcement_id': announcementId,
      'title': title,
      'body': body,
      'content_type': contentType,
      'media_url': mediaUrl,
      'media_filename': mediaFilename,
      'published_at': publishedAt?.toIso8601String(),
      'delivery_status': deliveryStatus,
      'read_at': readAt?.toIso8601String(),
      'recipient_id': recipientId,
    };
  }
}
