class ChatModel {
  final String id;
  final List<ChatParticipantModel> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['_id'] ?? '',
      participants: (json['participants'] as List?)
              ?.map((p) => ChatParticipantModel.fromJson(p))
              .toList() ??
          [],
      lastMessage: json['lastMessage'] ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  ChatModel copyWith({
    String? id,
    List<ChatParticipantModel>? participants,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatParticipantModel {
  final String id;
  final String fullName;
  final String profileImage;
  final String role;

  ChatParticipantModel({
    required this.id,
    required this.fullName,
    required this.profileImage,
    required this.role,
  });

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) {
    return ChatParticipantModel(
      id: json['_id'] ?? '',
      fullName: json['fullName'] ?? '',
      profileImage: json['profileImage'] ?? '',
      role: json['role'] ?? 'client',
    );
  }
}
