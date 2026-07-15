import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../core/config/env.dart';
import 'auth_provider.dart';
import 'notification_provider.dart';

final activeChatIdProvider = StateProvider<String?>((ref) => null);

final userOnlineStatusProvider =
    StateProvider.family<bool, String>((ref, userId) => false);

// ────────────────────────────────────────────────────────────────────────────
// chatsProvider — rebuilds ONLY when isLoggedIn changes (not on every
// auth state update like name/photo edits).
// ────────────────────────────────────────────────────────────────────────────
final chatsProvider =
    StateNotifierProvider<ChatsNotifier, AsyncValue<List<ChatModel>>>((ref) {
  final isLoggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
  return ChatsNotifier(ref, shouldFetch: isLoggedIn);
});

class ChatsNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  final Ref _ref;
  IO.Socket? _socket;

  IO.Socket? get socket => _socket;

  ChatsNotifier(this._ref, {bool shouldFetch = true})
      : super(
          shouldFetch
              ? const AsyncValue.loading()
              : const AsyncValue.data([]),
        ) {
    if (shouldFetch) {
      fetchChats().then((_) => _initSocket());
    }
  }

  void _initSocket() {
    // Guard against creating duplicate sockets
    if (_socket != null && _socket!.connected) return;

    final base = Environment.baseUrl.replaceAll('/api', '');
    _socket = IO.io(
      '$base/chat',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnectError((data) {
      print('🔌 [ChatsSocket] Connect Error: $data');
    });

    _socket!.onError((data) {
      print('🔌 [ChatsSocket] Error: $data');
    });

    _socket!.onDisconnect((data) {
      print('🔌 [ChatsSocket] Disconnected: $data');
    });

    _socket!.onConnect((_) {
      print('🔌 [ChatsSocket] Connected');
      final userId = _ref.read(authProvider).userId;
      if (userId != null) {
        // Register personal user room to receive chat_updated events
        _socket!.emit('register', {'userId': userId});
      }

      // Join every existing chat room
      state.whenData((chats) {
        for (final chat in chats) {
          _socket!.emit('join', {'chatId': chat.id});

          if (userId != null && chat.participants.isNotEmpty) {
            final other = chat.participants.firstWhere(
              (p) => p.id != userId,
              orElse: () => chat.participants.first,
            );
            // Request current online status for the other participant
            _socket!.emitWithAck(
              'check_status',
              {'userId': other.id},
              ack: (response) {
                if (response != null && response['status'] == 'online') {
                  _ref
                      .read(userOnlineStatusProvider(other.id).notifier)
                      .state = true;
                }
              },
            );
          }
        }
      });
    });

    // ── Online/offline status updates ──
    _socket!.on('user_status', (data) {
      if (data == null) return;
      final userId = (data['userId'] ?? '').toString();
      final status = (data['status'] ?? 'offline').toString();
      if (userId.isNotEmpty) {
        _ref.read(userOnlineStatusProvider(userId).notifier).state =
            (status == 'online');
      }
    });

    // ── chat_updated: lightweight event emitted to user rooms on new message ──
    // Updates last-message preview and unread badge WITHOUT adding a bubble
    // (that is handled by ChatMessagesNotifier which listens to "message").
    _socket!.on('chat_updated', (data) {
      if (data == null) return;
      final chatId = (data['chatId'] ?? data['chat'] ?? '').toString();
      final content = (data['lastMessage'] ?? '').toString();
      final lastMsgAtStr = (data['lastMessageAt'] ?? '').toString();
      final senderId = (data['senderId'] ?? '').toString();
      final currentUserId = _ref.read(authProvider).userId ?? '';
      final isMsgFromMe = senderId == currentUserId;
      final activeChatId = _ref.read(activeChatIdProvider);
      final isChatOpen = activeChatId == chatId;

      state.whenData((currentChats) {
        final hasChat = currentChats.any((c) => c.id == chatId);
        if (!hasChat) {
          // Completely new conversation — refresh list from backend
          fetchChats(silent: true);
          return;
        }
        final updatedChats = currentChats.map((c) {
          if (c.id == chatId) {
            return c.copyWith(
              lastMessage: content,
              lastMessageAt: lastMsgAtStr.isNotEmpty
                  ? (DateTime.tryParse(lastMsgAtStr)?.toLocal() ??
                      DateTime.now())
                  : DateTime.now(),
              lastMessageSender: senderId,
              // Only increment unread if the message is from someone else and chat is not open
              unreadCount: isChatOpen
                  ? 0
                  : (isMsgFromMe ? c.unreadCount : (c.unreadCount + 1)),
            );
          }
          return c;
        }).toList();
        updatedChats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        state = AsyncValue.data(updatedChats);
      });
    });

    _socket!.on('read', (data) {
      if (data == null) return;
      final readChatId = (data['chatId'] ?? '').toString();
      state.whenData((currentChats) {
        final updatedChats = currentChats.map((c) {
          if (c.id == readChatId) {
            return c.copyWith(isLastMessageRead: true);
          }
          return c;
        }).toList();
        state = AsyncValue.data(updatedChats);
      });
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> fetchChats({bool silent = false}) async {
    try {
      if (!silent) {
        state = const AsyncValue.loading();
      }
      final response = await DioClient.dio.get("/chats");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final chats =
            list.map((item) => ChatModel.fromJson(item as Map<String, dynamic>)).toList();
        state = AsyncValue.data(chats);

        // Ensure new chat rooms are joined on the socket after a fetch
        if (_socket != null && _socket!.connected) {
          for (final chat in chats) {
            _socket!.emit('join', {'chatId': chat.id});
          }
        }
      } else {
        if (!silent) {
          state = AsyncValue.error("Failed to load chats", StackTrace.current);
        }
      }
    } catch (e, stack) {
      if (!silent) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  /// Set unread count to 0 for a specific chat (called when the user opens it).
  void markChatAsRead(String chatId) {
    state.whenData((chats) {
      final updated = chats.map((c) {
        if (c.id == chatId) return c.copyWith(unreadCount: 0);
        return c;
      }).toList();
      state = AsyncValue.data(updated);
    });
  }

  /// Update last message preview after the current user sends a message.
  void updateLastMessage(
      String chatId, String lastMessage, DateTime lastMessageAt) {
    state.whenData((chats) {
      final updated = chats.map((c) {
        if (c.id == chatId) {
          return c.copyWith(
              lastMessage: lastMessage, lastMessageAt: lastMessageAt);
        }
        return c;
      }).toList();
      updated.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      state = AsyncValue.data(updated);
    });
  }

  Future<ChatModel?> getOrCreateChat(String otherUserId) async {
    try {
      final response = await DioClient.dio.post("/chats", data: {
        "otherUserId": otherUserId,
      });

      if (response.data != null && response.data['success'] == true) {
        final chat = ChatModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
        await fetchChats();
        _socket?.emit('join', {'chatId': chat.id});
        return chat;
      }
    } catch (e) {
      print('🔌 [ChatsNotifier] getOrCreateChat error: $e');
    }
    return null;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// chatTypingProvider — per-chat typing indicator
// ────────────────────────────────────────────────────────────────────────────
final chatTypingProvider =
    StateProvider.family<String?, String>((ref, chatId) => null);

// ────────────────────────────────────────────────────────────────────────────
// chatMessagesProvider — manages messages + socket for ONE specific chat
// ────────────────────────────────────────────────────────────────────────────
final chatMessagesProvider = StateNotifierProvider.family<
    ChatMessagesNotifier,
    AsyncValue<List<MessageModel>>,
    String>((ref, chatId) {
  return ChatMessagesNotifier(chatId, ref);
});

class ChatMessagesNotifier
    extends StateNotifier<AsyncValue<List<MessageModel>>> {
  final String chatId;
  final Ref _ref;
  IO.Socket? _socket;

  ChatMessagesNotifier(this.chatId, this._ref)
      : super(const AsyncValue.loading()) {
    fetchMessages();
    _initSocket();
  }

  void _initSocket() {
    final parentNotifier = _ref.read(chatsProvider.notifier);
    _socket = parentNotifier.socket;
    if (_socket == null) return;

    _socket!.emit('join', {'chatId': chatId});

    _socket!.on('message', _onMessageReceived);
    _socket!.on('read', _onReadReceiptReceived);
    _socket!.on('typing', _onTypingReceived);
  }

  void _onMessageReceived(dynamic data) {
    if (data == null) return;
    try {
      final rawData = Map<String, dynamic>.from(data as Map);
      final msgChatId = (rawData['chat'] ?? '').toString();
      if (msgChatId != chatId) return;

      final message = MessageModel.fromJson(rawData);
      state.whenData((currentMessages) {
        if (!currentMessages.any((m) => m.id == message.id)) {
          state = AsyncValue.data([...currentMessages, message]);
          markAsRead();
        }
      });
    } catch (e) {
      print('🔌 [ChatMsgSocket:$chatId] message parse error: $e');
    }
  }

  void _onReadReceiptReceived(dynamic data) {
    if (data == null) return;
    final readChatId = (data['chatId'] ?? '').toString();
    if (readChatId != chatId) return;

    state.whenData((currentMessages) {
      final currentUserId = _ref.read(authProvider).userId;
      final updatedMessages = currentMessages.map((m) {
        if (m.senderId == currentUserId) {
          return m.copyWith(isRead: true);
        }
        return m;
      }).toList();
      state = AsyncValue.data(updatedMessages);
    });
  }

  void _onTypingReceived(dynamic data) {
    if (data == null) return;
    final userName = (data['userName'] ?? '').toString();
    final isTyping = data['isTyping'] as bool? ?? false;
    _ref.read(chatTypingProvider(chatId).notifier).state =
        isTyping ? userName : null;
  }

  void emitTyping(String userName, bool isTyping) {
    _socket?.emit('typing', {
      'chatId': chatId,
      'userName': userName,
      'isTyping': isTyping,
    });
  }

  @override
  void dispose() {
    _socket?.off('message', _onMessageReceived);
    _socket?.off('read', _onReadReceiptReceived);
    _socket?.off('typing', _onTypingReceived);
    super.dispose();
  }

  /// Mark all messages in this chat as read on the backend and update local state.
  Future<void> markAsRead() async {
    try {
      await DioClient.dio.put("/chats/$chatId/read");
      _ref.read(chatsProvider.notifier).markChatAsRead(chatId);
      
      // Clear associated notifications
      final notificationsNotifier = _ref.read(notificationsProvider.notifier);
      final targetNotifications = _ref.read(notificationsProvider).notifications.where(
        (n) => n.referenceId == chatId && n.type == 'chat_message' && !n.isRead
      ).toList();
      for (final n in targetNotifications) {
        notificationsNotifier.markAsRead(n.id);
      }
    } catch (e) {
      // Ignore — non-critical
    }
  }

  Future<void> fetchMessages() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/chats/$chatId/messages");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final messages = list
            .map((item) =>
                MessageModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(messages);
        // Mark as read after loading (fire-and-forget, no await)
        markAsRead();
      } else {
        state = AsyncValue.error(
            "Failed to load messages", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<MessageAttachmentModel?> uploadAttachment({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    try {
      MultipartFile file;
      if (fileBytes != null) {
        file = MultipartFile.fromBytes(fileBytes, filename: fileName);
      } else if (filePath != null) {
        file = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        return null;
      }

      final formData = FormData.fromMap({"file": file});

      final response = await DioClient.dio.post(
        "/chats/$chatId/attachments",
        data: formData,
      );

      if (response.data != null && response.data['success'] == true) {
        return MessageAttachmentModel.fromJson(
            response.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      print('🔌 [ChatMsgNotifier] uploadAttachment error: $e');
    }
    return null;
  }

  Future<bool> sendMessage(String content,
      {List<MessageAttachmentModel> attachments = const []}) async {
    try {
      final response = await DioClient.dio.post(
        "/chats/$chatId/messages",
        data: {
          "content": content,
          "attachments": attachments
              .map((a) => {
                    "name": a.name,
                    "url": a.url,
                    "mimeType": a.mimeType,
                    "size": a.size,
                  })
              .toList(),
        },
      );

      if (response.data != null && response.data['success'] == true) {
        final newMessage = MessageModel.fromJson(
            response.data['data'] as Map<String, dynamic>);

        // Add to local message list (dedup check)
        state.whenData((currentMessages) {
          if (!currentMessages.any((m) => m.id == newMessage.id)) {
            state = AsyncValue.data([...currentMessages, newMessage]);
          }
        });

        // Update the chat list preview locally (no fetchChats — socket
        // chat_updated will handle the other participant's list update)
        final lastMsgText = content.isNotEmpty
            ? content
            : (attachments.isNotEmpty ? "Sent an attachment" : "");
        _ref.read(chatsProvider.notifier).updateLastMessage(
              chatId,
              lastMsgText,
              newMessage.createdAt,
            );

        return true;
      }
    } catch (e) {
      print('🔌 [ChatMsgNotifier] sendMessage error: $e');
    }
    return false;
  }
}
