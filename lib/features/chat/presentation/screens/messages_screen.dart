import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: theme.appBarTheme.iconTheme?.color),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: theme.appBarTheme.iconTheme?.color, size: 24),
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
                  side: BorderSide(color: theme.colorScheme.outline),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.titleMedium?.color),
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
                        color: typingUser != null ? AppColors.success : theme.textTheme.bodySmall?.color,
                        fontStyle: typingUser != null ? FontStyle.italic : FontStyle.normal,
                        fontWeight: typingUser != null ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
                      ),
                      if (chat.unreadCount > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              "${chat.unreadCount}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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
