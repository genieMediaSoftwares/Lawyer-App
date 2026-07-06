import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/widgets/app_drawer.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsState = ref.watch(chatsProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userId ?? "";

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: chatsState.when(
        data: (chats) {
          if (chats.isEmpty) {
            return const Center(child: Text("No conversations yet."));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: chats.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final chat = chats[index];
              // Get the other participant
              final otherParticipant = chat.participants.firstWhere(
                (p) => p.id != currentUserId,
                orElse: () => chat.participants.first,
              );

              final typingUser = ref.watch(chatTypingProvider(chat.id));
              final formattedTime = DateFormat('hh:mm a').format(chat.lastMessageAt);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.grey200),
                ),
                child: ListTile(
                  onTap: () {
                    context.push('/chat/${chat.id}/${otherParticipant.fullName}');
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundImage: otherParticipant.profileImage.isNotEmpty
                        ? NetworkImage(otherParticipant.profileImage)
                        : null,
                    child: otherParticipant.profileImage.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(
                    otherParticipant.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      typingUser != null
                          ? "typing..."
                          : (chat.lastMessage.isNotEmpty ? chat.lastMessage : "No messages yet."),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: typingUser != null ? Colors.green : AppColors.grey500,
                        fontStyle: typingUser != null ? FontStyle.italic : FontStyle.normal,
                        fontWeight: typingUser != null ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  trailing: Text(
                    formattedTime,
                    style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
