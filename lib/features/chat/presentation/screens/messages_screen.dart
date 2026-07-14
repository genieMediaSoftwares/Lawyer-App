import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/env.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/chat_model.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    // Always fetch fresh data when the Messages screen is shown
    // (covers the case where the user navigates back from a chat)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatsProvider.notifier).fetchChats();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ImageProvider? _resolveImage(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    final base = Environment.baseUrl.replaceAll('/api', '');
    final clean = url.startsWith('/') ? url : '/$url';
    return NetworkImage('$base$clean');
  }

  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(chatsProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.userId ?? "";
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Messages",
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: theme.appBarTheme.iconTheme?.color, size: 24),
          onPressed: () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search conversations...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.primaryGold),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.secondaryBackground,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide:
                      BorderSide(color: theme.colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                      color: theme.colorScheme.outline.withAlpha(128)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                      color: AppColors.primaryGold, width: 1),
                ),
              ),
            ),
          ),

          // ── Filter Chips ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Unread', 'Clients'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                    selectedColor: AppColors.primaryGold,
                    backgroundColor: AppColors.secondaryBackground,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : Colors.grey.shade400,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryGold
                            : theme.colorScheme.outline.withAlpha(77),
                        width: 0.8,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Conversation Cards ──
          Expanded(
            child: chatsState.when(
              data: (chats) {
                // Apply search query
                var filtered = chats;
                final query =
                    _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  filtered = filtered.where((chat) {
                    final other = _getOtherParticipant(chat.participants, currentUserId);
                    final nameMatches =
                        other.fullName.toLowerCase().contains(query);
                    final caseMatches = chat.caseInfo?.title
                            .toLowerCase()
                            .contains(query) ??
                        false;
                    return nameMatches || caseMatches;
                  }).toList();
                }

                // Apply filter chip
                if (_selectedFilter == 'Unread') {
                  filtered = filtered
                      .where((chat) => chat.unreadCount > 0)
                      .toList();
                } else if (_selectedFilter == 'Clients') {
                  filtered = filtered.where((chat) {
                    final other = _getOtherParticipant(chat.participants, currentUserId);
                    return other.role == 'client';
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(chatsProvider.notifier).fetchChats(),
                    color: AppColors.primaryGold,
                    backgroundColor: AppColors.cardBackground,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height:
                              MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 48,
                                    color: Colors.grey.shade600),
                                const SizedBox(height: 16),
                                Text(
                                  "No conversations found",
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Accept a client case to start messaging",
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(chatsProvider.notifier).fetchChats(),
                  color: AppColors.primaryGold,
                  backgroundColor: AppColors.cardBackground,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chat = filtered[index];
                      final otherParticipant =
                          _getOtherParticipant(chat.participants, currentUserId);

                      final isOnline = ref.watch(
                          userOnlineStatusProvider(otherParticipant.id));
                      final typingUser =
                          ref.watch(chatTypingProvider(chat.id));
                      final formattedTime =
                          _formatTime(chat.lastMessageAt);
                      final isUnread = chat.unreadCount > 0;

                      return Card(
                        elevation: 0,
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isUnread
                                ? AppColors.primaryGold.withAlpha(102)
                                : theme.colorScheme.outline
                                    .withAlpha(128),
                            width: isUnread ? 1.2 : 0.8,
                          ),
                        ),
                        child: ListTile(
                          onTap: () {
                            context.push(
                                '/chat/${chat.id}/${Uri.encodeComponent(otherParticipant.fullName)}');
                          },
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor:
                                    AppColors.secondaryBackground,
                                backgroundImage: _resolveImage(
                                    otherParticipant.profileImage),
                                child: otherParticipant
                                        .profileImage.isEmpty
                                    ? const Icon(Icons.person,
                                        color: AppColors.primaryGold)
                                    : null,
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color:
                                              AppColors.cardBackground,
                                          width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherParticipant.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  color: isUnread
                                      ? AppColors.primaryGold
                                      : Colors.grey.shade500,
                                  fontSize: 11,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Case title (if linked)
                                Row(
                                  children: [
                                    const Icon(Icons.folder_open,
                                        size: 12,
                                        color: AppColors.primaryGold),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        chat.caseInfo?.title ??
                                            "General Consultation",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.primaryGold,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Last message or typing indicator
                                Text(
                                  typingUser != null
                                      ? "typing..."
                                      : (chat.lastMessage.isNotEmpty
                                          ? chat.lastMessage
                                          : "No messages yet."),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: typingUser != null
                                        ? AppColors.success
                                        : (isUnread
                                            ? Colors.white
                                            : Colors.grey.shade400),
                                    fontStyle: typingUser != null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                    fontWeight: typingUser != null
                                        ? FontWeight.bold
                                        : (isUnread
                                            ? FontWeight.w600
                                            : FontWeight.normal),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: isUnread
                              ? Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGold,
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
                                )
                              : const SizedBox.shrink(),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => RefreshIndicator(
                // Wrap shimmer in RefreshIndicator so users can retry
                onRefresh: () =>
                    ref.read(chatsProvider.notifier).fetchChats(),
                color: AppColors.primaryGold,
                backgroundColor: AppColors.cardBackground,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: 5,
                  itemBuilder: (context, index) =>
                      const _MessageShimmerTile(),
                ),
              ),
              error: (err, stack) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(chatsProvider.notifier).fetchChats(),
                color: AppColors.primaryGold,
                backgroundColor: AppColors.cardBackground,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off,
                                size: 48, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            Text(
                              "Could not load conversations",
                              style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              err.toString().contains('401')
                                  ? "Session expired. Please log in again."
                                  : "Pull down to retry",
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => ref
                                  .read(chatsProvider.notifier)
                                  .fetchChats(),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text("Retry"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGold,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Smart timestamp: shows time for today's messages, or date for older ones.
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    if (msgDay == today) {
      return DateFormat('hh:mm a').format(dt);
    } else if (today.difference(msgDay).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(dt);
    }
  }

  ChatParticipantModel _getOtherParticipant(List<ChatParticipantModel> participants, String currentUserId) {
    if (participants.isEmpty) {
      return ChatParticipantModel(id: '', fullName: 'Unknown', profileImage: '', role: 'client');
    }
    for (final p in participants) {
      if (p.id.isNotEmpty && currentUserId.isNotEmpty && p.id.toLowerCase() != currentUserId.toLowerCase()) {
        return p;
      }
    }
    for (final p in participants) {
      if (p.role == 'client') {
        return p;
      }
    }
    return participants.first;
  }
}

// ── Shimmer Loading Tile ──────────────────────────────────────────────────────
class _MessageShimmerTile extends StatefulWidget {
  const _MessageShimmerTile();

  @override
  State<_MessageShimmerTile> createState() => _MessageShimmerTileState();
}

class _MessageShimmerTileState extends State<_MessageShimmerTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _opacity,
      child: Card(
        elevation: 0,
        color: AppColors.cardBackground,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: theme.colorScheme.outline.withAlpha(77)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 100,
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    theme.colorScheme.onSurface.withAlpha(20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withAlpha(13),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 10,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withAlpha(8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
