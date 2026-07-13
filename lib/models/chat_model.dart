class ChatModel {
  final String id;
  final List<ChatParticipantModel> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final ChatCaseInfoModel? caseInfo;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.caseInfo,
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
          ? DateTime.parse(json['lastMessageAt']).toLocal()
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
      caseInfo: json['caseInfo'] != null
          ? ChatCaseInfoModel.fromJson(json['caseInfo'])
          : null,
    );
  }

  ChatModel copyWith({
    String? id,
    List<ChatParticipantModel>? participants,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    ChatCaseInfoModel? caseInfo,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      caseInfo: caseInfo ?? this.caseInfo,
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

class ChatCaseInfoModel {
  final String id;
  final String title;

  ChatCaseInfoModel({
    required this.id,
    required this.title,
  });

  factory ChatCaseInfoModel.fromJson(Map<String, dynamic> json) {
    return ChatCaseInfoModel(
      id: json['id'] ?? json['_id'] ?? '',
      title: json['title'] ?? '',
    );
  }
}
