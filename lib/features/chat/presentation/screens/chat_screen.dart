import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/env.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../models/message_model.dart';
import '../../../../models/chat_model.dart';
import '../../../../providers/auth_provider.dart';

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
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeChatIdProvider.notifier).state = widget.chatId;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeChatIdProvider.notifier).state = null;
    });
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (!_isCurrentlyTyping && text.isNotEmpty) {
      _isCurrentlyTyping = true;
      final userName = ref.read(authProvider).userName ?? "User";
      ref.read(chatMessagesProvider(widget.chatId).notifier).emitTyping(userName, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isCurrentlyTyping) {
        _isCurrentlyTyping = false;
        final userName = ref.read(authProvider).userName ?? "User";
        ref.read(chatMessagesProvider(widget.chatId).notifier).emitTyping(userName, false);
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _typingTimer?.cancel();
    if (_isCurrentlyTyping) {
      _isCurrentlyTyping = false;
      final userName = ref.read(authProvider).userName ?? "User";
      ref.read(chatMessagesProvider(widget.chatId).notifier).emitTyping(userName, false);
    }

    final chatNotifier = ref.read(chatMessagesProvider(widget.chatId).notifier);
    final success = await chatNotifier.sendMessage(text);

    if (success) {
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        setState(() {
          _isUploading = true;
        });

        final chatNotifier = ref.read(chatMessagesProvider(widget.chatId).notifier);
        MessageAttachmentModel? attachment;

        if (kIsWeb) {
          if (file.bytes != null) {
            attachment = await chatNotifier.uploadAttachment(
              fileBytes: file.bytes,
              fileName: file.name,
            );
          }
        } else {
          attachment = await chatNotifier.uploadAttachment(
            filePath: file.path,
            fileName: file.name,
          );
        }

        setState(() {
          _isUploading = false;
        });

        if (attachment != null) {
          final success = await chatNotifier.sendMessage("", attachments: [attachment]);
          if (success) {
            Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload file attachment.")),
          );
        }
      }
    } catch (e) {
      print('🔌 Error picking attachment: $e');
      setState(() {
        _isUploading = false;
      });
    }
  }

  String _resolveImageUrl(String url) {
    return Environment.getAttachmentUrl(url);
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch URL";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open attachment link: $urlString")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessagesProvider(widget.chatId));
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userId ?? "";

    ref.listen(chatMessagesProvider(widget.chatId), (prev, next) {
      next.whenData((_) {
        Future.delayed(const Duration(milliseconds: 250), _scrollToBottom);
      });
    });

    final theme = Theme.of(context);

    // Get current chat metadata for caseInfo card
    final chatsState = ref.watch(chatsProvider);
    ChatModel? currentChat;
    chatsState.whenData((chats) {
      try {
        currentChat = chats.firstWhere((c) => c.id == widget.chatId);
      } catch (_) {
        // Fallback if not found in list yet
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Consumer(
          builder: (context, ref, child) {
            final typingUser = ref.watch(chatTypingProvider(widget.chatId));
            
            String? otherParticipantId;
            chatsState.whenData((chats) {
              final chat = chats.firstWhere((c) => c.id == widget.chatId, orElse: () => chats.first);
              final other = chat.participants.firstWhere(
                (p) => p.id != currentUserId,
                orElse: () => chat.participants.first,
              );
              otherParticipantId = other.id;
            });

            final isOnline = otherParticipantId != null
                ? ref.watch(userOnlineStatusProvider(otherParticipantId!))
                : false;

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
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: isOnline ? AppColors.success : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? "Online" : "Offline",
                        style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                      ),
                    ],
                  )
              ],
            );
          }
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Linked Case Information Card (Gold Accent Header)
            if (currentChat?.caseInfo != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGold.withOpacity(0.4), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_shared_outlined, color: AppColors.primaryGold, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CONNECTED CASE DETAILS",
                            style: TextStyle(
                              color: AppColors.primaryGold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentChat!.caseInfo!.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Case ID: ${currentChat!.caseInfo!.id}",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Chat Feed Area
            Expanded(
              child: messagesState.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(child: Text("No messages in this chat. Start typing below!"));
                  }

                  // Find the index of the last message sent by me
                  int lastMeMsgIndex = -1;
                  for (int i = messages.length - 1; i >= 0; i--) {
                    if (messages[i].senderId == currentUserId) {
                      lastMeMsgIndex = i;
                      break;
                    }
                  }

                  // Build chronological list with date separators
                  final List<Widget> chatWidgets = [];
                  DateTime? lastDate;

                  for (int i = 0; i < messages.length; i++) {
                    final message = messages[i];
                    final msgDate = DateTime(message.createdAt.year, message.createdAt.month, message.createdAt.day);

                    if (lastDate == null || msgDate != lastDate) {
                      lastDate = msgDate;
                      chatWidgets.add(_buildDateSeparator(message.createdAt));
                    }

                    final isMe = message.senderId == currentUserId;
                    chatWidgets.add(_buildMessageBubble(message, isMe, i == lastMeMsgIndex));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: chatWidgets.length,
                    itemBuilder: (context, index) => chatWidgets[index],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryGold)),
                error: (err, stack) => Center(child: Text("Error loading messages: $err", style: const TextStyle(color: Colors.red))),
              ),
            ),

            // 3. Input Text Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final compareDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (compareDate == today) {
      dateText = "Today";
    } else if (compareDate == yesterday) {
      dateText = "Yesterday";
    } else {
      dateText = DateFormat('MMMM dd, yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Text(
          dateText,
          style: const TextStyle(
            color: AppColors.primaryGold,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isLastSentByMe) {
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
              color: isMe ? AppColors.primaryGold : AppColors.cardBackground,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
              ),
              border: isMe ? null : Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text content
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.black : Colors.white,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: isMe ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),

                // File/Document attachment display
                if (message.attachments.isNotEmpty) ...[
                  if (message.content.isNotEmpty) const SizedBox(height: 8),
                  ...message.attachments.map((attachment) {
                    final isImage = attachment.mimeType.startsWith('image/') ||
                        attachment.name.endsWith('.png') ||
                        attachment.name.endsWith('.jpg') ||
                        attachment.name.endsWith('.jpeg');

                    if (isImage) {
                      return InkWell(
                        onTap: () => _launchUrl(_resolveImageUrl(attachment.url)),
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isMe ? Colors.black26 : Colors.white24),
                            image: DecorationImage(
                              image: NetworkImage(_resolveImageUrl(attachment.url)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    } else {
                      // Document (PDF or doc)
                      return Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.black.withOpacity(0.15) : AppColors.secondaryBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isMe ? Colors.black12 : Colors.white12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.insert_drive_file_outlined,
                              color: isMe ? Colors.black : AppColors.primaryGold,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    attachment.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isMe ? Colors.black : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    attachment.mimeType.isNotEmpty
                                        ? attachment.mimeType.split('/').last.toUpperCase()
                                        : "PDF DOCUMENT",
                                    style: TextStyle(
                                      color: isMe ? Colors.black54 : Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.open_in_new,
                                color: isMe ? Colors.black : AppColors.primaryGold,
                                size: 18,
                              ),
                              onPressed: () => _launchUrl(_resolveImageUrl(attachment.url)),
                            ),
                          ],
                        ),
                      );
                    }
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formattedTime,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
              if (isMe && isLastSentByMe && message.isRead) ...[
                const SizedBox(width: 6),
                const Text(
                  "Seen",
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Emoji Button
          IconButton(
            icon: const Icon(Icons.sentiment_satisfied_alt_outlined, color: AppColors.primaryGold),
            onPressed: () {
              // Static trigger/placeholder
            },
          ),
          
          // Attachment Button with local indicator
          _isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGold,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.primaryGold),
                  onPressed: _pickAttachment,
                ),
          
          const SizedBox(width: 4),

          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                fillColor: AppColors.primaryBackground,
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
              color: AppColors.primaryGold,
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
