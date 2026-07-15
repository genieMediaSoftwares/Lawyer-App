class ChatModel {
  final String id;
  final List<ChatParticipantModel> participants;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageSender;
  final bool isLastMessageRead;
  final int unreadCount;
  final ChatCaseInfoModel? caseInfo;

  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
    this.lastMessageSender = '',
    this.isLastMessageRead = false,
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
      lastMessageSender: json['lastMessageSender'] ?? '',
      isLastMessageRead: json['isLastMessageRead'] ?? false,
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
    String? lastMessageSender,
    bool? isLastMessageRead,
    int? unreadCount,
    ChatCaseInfoModel? caseInfo,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      isLastMessageRead: isLastMessageRead ?? this.isLastMessageRead,
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
  final bool isVerified;
  final String specialization;

  ChatParticipantModel({
    required this.id,
    required this.fullName,
    required this.profileImage,
    required this.role,
    this.isVerified = false,
    this.specialization = '',
  });

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) {
    return ChatParticipantModel(
      id: json['_id'] ?? json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      profileImage: json['profileImage'] ?? '',
      role: json['role'] ?? 'client',
      isVerified: json['isVerified'] ?? false,
      specialization: json['specialization'] ?? '',
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
