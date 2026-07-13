import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/network/dio_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../core/config/env.dart';
import 'auth_provider.dart';

final userOnlineStatusProvider = StateProvider.family<bool, String>((ref, userId) => false);

final chatsProvider = StateNotifierProvider<ChatsNotifier, AsyncValue<List<ChatModel>>>((ref) {
  return ChatsNotifier(ref);
});

class ChatsNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  final Ref _ref;
  late IO.Socket _socket;

  ChatsNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetchChats().then((_) => _initSocket());
  }

  void _initSocket() {
    final base = Environment.baseUrl.replaceAll('/api', '');
    _socket = IO.io('$base/chat', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    _socket.connect();

    _socket.onConnect((_) {
      final userId = _ref.read(authProvider).userId;
      if (userId != null) {
        _socket.emit('register', {'userId': userId});
      }
      state.whenData((chats) {
        for (final chat in chats) {
          _socket.emit('join', {'chatId': chat.id});
          
          if (userId != null) {
            final other = chat.participants.firstWhere(
              (p) => p.id != userId,
              orElse: () => chat.participants.first,
            );
            _socket.emitWithAck('check_status', {'userId': other.id}, ack: (response) {
              if (response != null && response['status'] == 'online') {
                _ref.read(userOnlineStatusProvider(other.id).notifier).state = true;
              }
            });
          }
        }
      });
    });

    _socket.on('user_status', (data) {
      if (data != null) {
        final userId = data['userId'] as String;
        final status = data['status'] as String;
        _ref.read(userOnlineStatusProvider(userId).notifier).state = (status == 'online');
      }
    });

    _socket.on('message', (data) {
      if (data != null) {
        final chatId = data['chat'] as String;
        final content = data['content'] as String;
        final createdAtStr = data['createdAt'] as String;

        state.whenData((currentChats) {
          final hasChat = currentChats.any((c) => c.id == chatId);
          if (!hasChat) {
            // New chat conversation, refresh list from backend
            fetchChats();
            return;
          }
          final updatedChats = currentChats.map((c) {
            if (c.id == chatId) {
              return c.copyWith(
                lastMessage: content,
                lastMessageAt: DateTime.parse(createdAtStr),
                // Increment unread count if we are not currently viewing it
                unreadCount: c.unreadCount + 1,
              );
            }
            return c;
          }).toList();
          
          updatedChats.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
          state = AsyncValue.data(updatedChats);
        });
      }
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  Future<void> fetchChats() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/chats");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final chats = list.map((item) => ChatModel.fromJson(item)).toList();
        state = AsyncValue.data(chats);
      } else {
        state = AsyncValue.error("Failed to load chats", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ChatModel?> getOrCreateChat(String otherUserId) async {
    try {
      final response = await DioClient.dio.post("/chats", data: {
        "otherUserId": otherUserId,
      });

      if (response.data != null && response.data['success'] == true) {
        final chat = ChatModel.fromJson(response.data['data']);
        await fetchChats();
        _socket.emit('join', {'chatId': chat.id});
        return chat;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }
}

final chatTypingProvider = StateProvider.family<String?, String>((ref, chatId) => null);

// Family provider to manage messages for a specific chat
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<MessageModel>>, String>((ref, chatId) {
  return ChatMessagesNotifier(chatId, ref);
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<MessageModel>>> {
  final String chatId;
  final Ref _ref;
  late IO.Socket _socket;

  ChatMessagesNotifier(this.chatId, this._ref) : super(const AsyncValue.loading()) {
    fetchMessages();
    _initSocket();
  }

  void _initSocket() {
    final base = Environment.baseUrl.replaceAll('/api', '');
    _socket = IO.io('$base/chat', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    _socket.connect();

    _socket.onConnect((_) {
      final userId = _ref.read(authProvider).userId;
      if (userId != null) {
        _socket.emit('register', {'userId': userId});
      }
      _socket.emit('join', {'chatId': chatId});
    });

    _socket.on('user_status', (data) {
      if (data != null) {
        final userId = data['userId'] as String;
        final status = data['status'] as String;
        _ref.read(userOnlineStatusProvider(userId).notifier).state = (status == 'online');
      }
    });

    _socket.on('message', (data) {
      if (data != null) {
        final message = MessageModel.fromJson(data);
        state.whenData((currentMessages) {
          if (!currentMessages.any((m) => m.id == message.id)) {
            state = AsyncValue.data([...currentMessages, message]);
            // Mark as read and refresh chats list
            markAsRead();
          }
        });
      }
    });

    _socket.on('read', (data) {
      if (data != null) {
        final readChatId = data['chatId'] as String;
        if (readChatId == chatId) {
          state.whenData((currentMessages) {
            final currentUserId = _ref.read(authProvider).userId;
            final updatedMessages = currentMessages.map((m) {
              if (m.senderId != currentUserId) {
                return m;
              }
              return m.copyWith(isRead: true);
            }).toList();
            state = AsyncValue.data(updatedMessages);
          });
        }
      }
    });

    _socket.on('typing', (data) {
      if (data != null) {
        final userName = data['userName'] as String;
        final isTyping = data['isTyping'] as bool;
        _ref.read(chatTypingProvider(chatId).notifier).state = isTyping ? userName : null;
      }
    });
  }

  void emitTyping(String userName, bool isTyping) {
    _socket.emit('typing', {
      'chatId': chatId,
      'userName': userName,
      'isTyping': isTyping,
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    super.dispose();
  }

  Future<void> markAsRead() async {
    try {
      await DioClient.dio.put("/chats/$chatId/read");
      // Refresh chats list to clear unread counts on parent screen
      _ref.read(chatsProvider.notifier).fetchChats();
    } catch (e) {
      // ignore
    }
  }

  Future<void> fetchMessages() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/chats/$chatId/messages");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final messages = list.map((item) => MessageModel.fromJson(item)).toList();
        state = AsyncValue.data(messages);
        await markAsRead();
      } else {
        state = AsyncValue.error("Failed to load messages", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> sendMessage(String content) async {
    try {
      final response = await DioClient.dio.post("/chats/$chatId/messages", data: {
        "content": content,
      });

      if (response.data != null && response.data['success'] == true) {
        final newMessage = MessageModel.fromJson(response.data['data']);
        
        state.whenData((currentMessages) {
          if (!currentMessages.any((m) => m.id == newMessage.id)) {
            state = AsyncValue.data([...currentMessages, newMessage]);
          }
        });
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
