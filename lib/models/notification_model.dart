class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
