class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.content,
    required this.createdAt,
    required this.isRead,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final senderData = json['sender'] is Map<String, dynamic> ? json['sender'] : {};
    final sId = json['sender'] is String ? json['sender'] : (senderData['_id'] ?? '');

    return MessageModel(
      id: json['_id'] ?? '',
      chatId: json['chat'] ?? '',
      senderId: sId,
      senderName: senderData['fullName'] ?? '',
      senderImage: senderData['profileImage'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderImage,
    String? content,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImage: senderImage ?? this.senderImage,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
