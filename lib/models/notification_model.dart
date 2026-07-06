class NotificationModel {
  final String id;
  final String recipient;
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.recipient,
    required this.type,
    required this.title,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'] ?? '',
      recipient: json['recipient'] ?? '',
      type: json['type'] ?? 'Appointment',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      read: json['read'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
