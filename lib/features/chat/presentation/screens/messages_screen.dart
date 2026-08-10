import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/chat_model.dart';
import '../../../../core/widgets/app_circle_avatar.dart';

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
    // Reconcile with the server whenever the screen is shown, silently: the
    // list is kept current by socket events, so this is a safety net and must
    // not blank what is already correct into a shimmer on every visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatsProvider.notifier).fetchChats(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        backgroundColor: AppColors.primaryBackground,
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.primaryText),
              decoration: InputDecoration(
                hintText: "Search conversations...",
                hintStyle: TextStyle(color: AppColors.mutedText),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.primaryGold),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon:
                            const Icon(Icons.clear, color: AppColors.mutedText),
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
          //
          // Scrollable: three chips plus their padding are wider than a 320dp
          // screen, and a plain Row overflowed instead of shrinking, painting
          // the yellow-and-black overflow stripe across the last chip.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Unread', authState.role == UserRole.lawyer ? 'Clients' : 'Lawyers'].map((filter) {
                final isSelected = _selectedFilter == filter || 
                    (_selectedFilter == 'Clients' && filter == 'Lawyers' && authState.role != UserRole.lawyer) ||
                    (_selectedFilter == 'Lawyers' && filter == 'Clients' && authState.role == UserRole.lawyer);
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
                          ? AppColors.onGold
                          : AppColors.secondaryText,
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
                    final msgMatches =
                        chat.lastMessage.toLowerCase().contains(query);
                    return nameMatches || caseMatches || msgMatches;
                  }).toList();
                }

                // Apply filter chip
                if (_selectedFilter == 'Unread') {
                  filtered = filtered
                      .where((chat) => chat.unreadCount > 0)
                      .toList();
                } else if (_selectedFilter == 'Clients' || _selectedFilter == 'Lawyers') {
                  filtered = filtered.where((chat) {
                    final other = _getOtherParticipant(chat.participants, currentUserId);
                    return other.role == (authState.role == UserRole.lawyer ? 'client' : 'lawyer');
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
                                    color: AppColors.disabledText),
                                const SizedBox(height: 16),
                                Text(
                                  "No conversations found",
                                  style: TextStyle(
                                      color: AppColors.mutedText,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Accept a client case to start messaging",
                                  style: TextStyle(
                                      color: AppColors.disabledText,
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
                        // Laid out by hand rather than with ListTile.
                        //
                        // ListTile sizes itself from a one- or two-line model
                        // and constrains `subtitle` to match. This row carries
                        // three stacked lines — an optional specialisation, the
                        // case, and the message preview — so the last of them
                        // was being clipped out of the card. That is the
                        // "messages are hidden" case: the text was rendered and
                        // then cut off. A plain Row grows to whatever its
                        // children need.
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            context.push(
                                '/chat/${chat.id}/${Uri.encodeComponent(otherParticipant.fullName)}');
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppCircleAvatar(
                                  radius: 26,
                                  backgroundColor:
                                      AppColors.secondaryBackground,
                                  imageUrl: otherParticipant
                                          .profileImage.isNotEmpty
                                      ? AppConfig.getAttachmentUrl(
                                          otherParticipant.profileImage)
                                      : null,
                                  fallback: const Icon(Icons.person,
                                      color: AppColors.primaryGold),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // ── Name + timestamp ──
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              otherParticipant.fullName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: isUnread
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 16,
                                                height: 1.2,
                                                color: AppColors.primaryText,
                                              ),
                                            ),
                                          ),
                                          if (otherParticipant.role ==
                                                  'lawyer' &&
                                              otherParticipant.isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.verified,
                                                color: AppColors.primaryGold,
                                                size: 16),
                                          ],
                                          const SizedBox(width: 8),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color: isUnread
                                                  ? AppColors.primaryGold
                                                  : AppColors.mutedText,
                                              fontSize: 11,
                                              fontWeight: isUnread
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (otherParticipant.role == 'lawyer' &&
                                          otherParticipant
                                              .specialization.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          otherParticipant.specialization,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],

                                      // ── Linked case ──
                                      const SizedBox(height: 4),
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

                                      // ── Preview + unread badge ──
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              typingUser != null
                                                  ? "typing..."
                                                  : (chat.lastMessage.isNotEmpty
                                                      ? chat.lastMessage
                                                      : "No messages yet."),
                                              // Two lines, so a normal message
                                              // is readable in full instead of
                                              // being cut off after a few words.
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: typingUser != null
                                                    ? AppColors.success
                                                    : (isUnread
                                                        ? AppColors.primaryText
                                                        : AppColors
                                                            .secondaryText),
                                                fontStyle: typingUser != null
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                                fontWeight: typingUser != null
                                                    ? FontWeight.bold
                                                    : (isUnread
                                                        ? FontWeight.w600
                                                        : FontWeight.normal),
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                          if (isUnread) ...[
                                            const SizedBox(width: 10),
                                            _UnreadBadge(
                                                count: chat.unreadCount),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                                size: 48, color: AppColors.disabledText),
                            const SizedBox(height: 16),
                            Text(
                              "Could not load conversations",
                              style: TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              err.toString().contains('401')
                                  ? "Session expired. Please log in again."
                                  : "Pull down to retry",
                              style: TextStyle(
                                  color: AppColors.disabledText,
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
                                foregroundColor: AppColors.onGold,
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
    final normalizedCurrentId = currentUserId.trim().toLowerCase();
    if (normalizedCurrentId.isNotEmpty) {
      for (final p in participants) {
        if (p.id.isNotEmpty && p.id.trim().toLowerCase() != normalizedCurrentId) {
          return p;
        }
      }
    }
    if (participants.length > 1) {
      return participants[1];
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

/// Red pill carrying the unread count for one conversation.
///
/// A pill rather than a fixed circle so a two- or three-digit count stays
/// inside it instead of overflowing; counts above 99 read as "99+", which is
/// all the precision this badge needs.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
