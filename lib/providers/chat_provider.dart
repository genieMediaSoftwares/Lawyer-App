import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

final chatsProvider = StateNotifierProvider<ChatsNotifier, AsyncValue<List<ChatModel>>>((ref) {
  return ChatsNotifier();
});

class ChatsNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  ChatsNotifier() : super(const AsyncValue.loading()) {
    fetchChats();
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
        return chat;
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }
}

// Family provider to manage messages for a specific chat
final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<MessageModel>>, String>((ref, chatId) {
  return ChatMessagesNotifier(chatId);
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<MessageModel>>> {
  final String chatId;

  ChatMessagesNotifier(this.chatId) : super(const AsyncValue.loading()) {
    fetchMessages();
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
        state.whenData((currentMessages) {
          state = AsyncValue.data([...currentMessages, newMessage]);
        });
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
