import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../models/message_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/widgets/app_drawer.dart';

import 'dart:async';

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
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (!_isCurrentlyTyping && text.isNotEmpty) {
      _isCurrentlyTyping = true;
      final userName = ref.read(authProvider).userName ?? "Client";
      ref.read(chatMessagesProvider(widget.chatId).notifier).emitTyping(userName, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        final userName = ref.read(authProvider).userName ?? "Client";
        ref.read(chatMessagesProvider(widget.chatId).notifier).emitTyping(userName, false);
      }
    });
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

    // Stop typing state immediately when sending
    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      final userName = ref.read(authProvider).userName ?? "Client";
      ref.read(chatMessagesProvider(widget.chatId).notifier).emitTyping(userName, false);
    }

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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Consumer(
          builder: (context, ref, child) {
            final typingUser = ref.watch(chatTypingProvider(widget.chatId));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.lawyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (typingUser != null)
                  Text(
                    "typing...",
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color, fontStyle: FontStyle.italic),
                  )
                else
                  Row(
                    children: [
                      const CircleAvatar(radius: 4, backgroundColor: AppColors.success),
                      const SizedBox(width: 4),
                      Text("Online", style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                    ],
                  )
              ],
            );
          }
        ),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? theme.colorScheme.primary : theme.colorScheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
              ),
              border: isMe ? null : Border.all(color: theme.colorScheme.outline),
            ),
            child: Text(
              message.content,
              style: TextStyle(color: isMe ? Colors.black : theme.colorScheme.onSurface, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 10),
          )
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add, color: theme.colorScheme.primary),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.mic_none, color: theme.colorScheme.primary),
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: "Type a message...",
                fillColor: theme.inputDecorationTheme.fillColor,
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
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
