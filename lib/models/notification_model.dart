class NotificationModel {
  final int id;
  final String title;
  final String message;
  final bool read;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? json['body'] ?? '',
      read: json['read'] ?? json['is_read'] ?? false,
      createdAt: json['created_at'] ?? json['timestamp'] ?? '',
    );
  }
}
