import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/network/dio_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

final chatsProvider = StateNotifierProvider<ChatsNotifier, AsyncValue<List<ChatModel>>>((ref) {
  return ChatsNotifier();
});

class ChatsNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  late IO.Socket _socket;

  ChatsNotifier() : super(const AsyncValue.loading()) {
    fetchChats().then((_) => _initSocket());
  }

  void _initSocket() {
    _socket = IO.io('http://localhost:5000/chat', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    _socket.connect();

    _socket.onConnect((_) {
      state.whenData((chats) {
        for (final chat in chats) {
          _socket.emit('join', {'chatId': chat.id});
        }
      });
    });

    _socket.on('message', (data) {
      if (data != null) {
        final chatId = data['chat'] as String;
        final content = data['content'] as String;
        final createdAtStr = data['createdAt'] as String;

        state.whenData((currentChats) {
          final updatedChats = currentChats.map((c) {
            if (c.id == chatId) {
              return c.copyWith(
                lastMessage: content,
                lastMessageAt: DateTime.parse(createdAtStr),
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
    _socket = IO.io('http://localhost:5000/chat', IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    _socket.connect();

    _socket.onConnect((_) {
      _socket.emit('join', {'chatId': chatId});
    });

    _socket.on('message', (data) {
      if (data != null) {
        final message = MessageModel.fromJson(data);
        state.whenData((currentMessages) {
          if (!currentMessages.any((m) => m.id == message.id)) {
            state = AsyncValue.data([...currentMessages, message]);
          }
        });
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

  Future<void> fetchMessages() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/chats/$chatId/messages");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final messages = list.map((item) => MessageModel.fromJson(item)).toList();
        state = AsyncValue.data(messages);
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
        
        // Emit to socket room for real-time delivery
        _socket.emit('message', {
          'chat': chatId,
          'sender': newMessage.senderId,
          'content': content,
          'createdAt': newMessage.createdAt.toIso8601String(),
        });

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
