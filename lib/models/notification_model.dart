class NotificationModel {
  final String id;
  final String notificationId;
  final String? senderId;
  final String? senderName;
  final String receiverId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final Map<String, dynamic> metadata;
  final String? referenceId;
  final bool isRead;
  final bool softDelete;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.notificationId,
    this.senderId,
    this.senderName,
    required this.receiverId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.metadata,
    this.referenceId,
    required this.isRead,
    required this.softDelete,
    required this.createdAt,
    required this.updatedAt,
  });

  NotificationModel copyWith({
    String? id,
    String? notificationId,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? title,
    String? message,
    String? type,
    String? priority,
    Map<String, dynamic>? metadata,
    String? referenceId,
    bool? isRead,
    bool? softDelete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      notificationId: notificationId ?? this.notificationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      softDelete: softDelete ?? this.softDelete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    String? resolvedSenderId;
    String? resolvedSenderName;

    if (json['senderId'] is Map) {
      resolvedSenderId = json['senderId']['_id']?.toString();
      resolvedSenderName = json['senderId']['fullName']?.toString();
    } else {
      resolvedSenderId = json['senderId']?.toString();
    }

    return NotificationModel(
      id: json['_id'] ?? '',
      notificationId: json['notificationId'] ?? json['_id'] ?? '',
      senderId: resolvedSenderId,
      senderName: resolvedSenderName,
      receiverId: json['receiverId'] ?? json['recipient'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      priority: json['priority'] ?? 'low',
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : {},
      referenceId: json['referenceId']?.toString(),
      isRead: json['isRead'] ?? json['read'] ?? false,
      softDelete: json['softDelete'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'notificationId': notificationId,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'title': title,
      'message': message,
      'type': type,
      'priority': priority,
      'metadata': metadata,
      'referenceId': referenceId,
      'isRead': isRead,
      'softDelete': softDelete,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
