/// Delivery state of a message on this device.
///
/// Only [MessageStatus.sent] means the server has the message. The other two
/// exist so an optimistically drawn bubble can show progress and offer a retry
/// instead of vanishing when the network is down.
enum MessageStatus { sending, sent, failed }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String content;
  final DateTime createdAt;
  final List<MessageAttachmentModel> attachments;

  /// Sender-generated id, round-tripped through the server.
  ///
  /// The sender sees its own message twice — once as the POST response, once
  /// as the socket broadcast to the conversation room — and may already have
  /// drawn it optimistically. Matching on this collapses all three into one
  /// bubble whichever order they arrive in. Empty for messages sent before
  /// this existed, which fall back to matching on [id].
  final String clientId;

  final MessageStatus status;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.content,
    required this.createdAt,
    this.attachments = const [],
    this.clientId = '',
    this.status = MessageStatus.sent,
  });

  /// A message drawn before the server has acknowledged it.
  factory MessageModel.pending({
    required String clientId,
    required String chatId,
    required String senderId,
    required String content,
    List<MessageAttachmentModel> attachments = const [],
  }) {
    return MessageModel(
      id: clientId,
      chatId: chatId,
      senderId: senderId,
      senderName: '',
      senderImage: '',
      content: content,
      createdAt: DateTime.now(),
      attachments: attachments,
      clientId: clientId,
      status: MessageStatus.sending,
    );
  }

  bool get isPending => status != MessageStatus.sent;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final senderData = json['sender'] is Map<String, dynamic>
        ? json['sender'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final sId = json['sender'] is String
        ? json['sender'] as String
        : (senderData['_id'] ?? '').toString();

    return MessageModel(
      id: (json['_id'] ?? '').toString(),
      chatId: (json['chat'] ?? '').toString(),
      senderId: sId,
      senderName: (senderData['fullName'] ?? '').toString(),
      senderImage: (senderData['profileImage'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ??
                DateTime.now())
          : DateTime.now(),
      attachments:
          (json['attachments'] as List?)
              ?.map(
                (a) => MessageAttachmentModel.fromJson(
                  Map<String, dynamic>.from(a as Map),
                ),
              )
              .toList() ??
          const [],
      clientId: (json['clientId'] ?? '').toString(),
      status: MessageStatus.sent,
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
    List<MessageAttachmentModel>? attachments,
    String? clientId,
    MessageStatus? status,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderImage: senderImage ?? this.senderImage,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
    );
  }
}

class MessageAttachmentModel {
  final String name;
  final String url;
  final String mimeType;
  final int size;

  MessageAttachmentModel({
    required this.name,
    required this.url,
    required this.mimeType,
    required this.size,
  });

  factory MessageAttachmentModel.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'];
    return MessageAttachmentModel(
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      size: rawSize is num ? rawSize.toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'mimeType': mimeType,
    'size': size,
  };
}
