import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../models/message_model.dart';
import '../../../../providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String lawyerName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.lawyerName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatNotifier = ref.read(chatMessagesProvider(widget.chatId).notifier);
    final success = await chatNotifier.sendMessage(text);

    if (success) {
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesProvider(widget.chatId));
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userId ?? "";

    // Trigger scroll to bottom on data load
    ref.listen(chatMessagesProvider(widget.chatId), (prev, next) {
      next.whenData((_) {
        Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lawyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.green),
                SizedBox(width: 4),
                Text("Online", style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            )
          ],
        ),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messagesState.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text("Start a conversation."));
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("Error: $err")),
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final formattedTime = DateFormat('hh:mm a').format(message.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? AppColors.navyBlue : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
              ),
              border: isMe ? null : Border.all(color: AppColors.grey200),
            ),
            child: Text(
              message.content,
              style: TextStyle(color: isMe ? Colors.white : AppColors.navyBlue, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: const TextStyle(color: AppColors.grey400, fontSize: 10),
          )
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.navyBlue),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.mic_none, color: AppColors.navyBlue),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                fillColor: AppColors.grey100,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.navyBlue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
