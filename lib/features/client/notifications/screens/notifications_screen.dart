import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _expandedNotificationId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).fetchNotifications();
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'appointment_requested':
      case 'appointment_confirmed':
      case 'appointment_cancelled':
        return Icons.calendar_today_outlined;
      case 'payment_success':
      case 'payment_failure':
        return Icons.payment_outlined;
      case 'chat_message':
        return Icons.chat_bubble_outline_outlined;
      case 'document_uploaded':
        return Icons.insert_drive_file_outlined;
      case 'proposal_received':
      case 'proposal_accepted':
      case 'proposal_rejected':
        return Icons.gavel_outlined;
      case 'review_received':
        return Icons.star_outline_rounded;
      case 'profile_verification':
        return Icons.verified_user_outlined;
      case 'admin_announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodyMedium?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Text("Notifications"),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${state.unreadCount}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ]
          ],
        ),
        actions: [
          if (state.notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all_outlined),
              tooltip: "Mark all as read",
              onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: "Clear all",
              onPressed: () => ref.read(notificationsProvider.notifier).clearAll(),
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          // Offline State Banner
          if (state.isOffline)
            Container(
              width: double.infinity,
              color: AppColors.warning.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_outlined, size: 16, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    "Connection lost. Trying to reconnect...",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Main notification list / states
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(refresh: true),
              child: _buildBody(state, theme, primaryTextColor, secondaryTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    NotificationState state,
    ThemeData theme,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(notificationsProvider.notifier).fetchNotifications(refresh: true),
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined, size: 64, color: AppColors.mutedText),
            SizedBox(height: 16),
            Text(
              "No notifications yet",
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "We'll notify you when something important happens",
              style: TextStyle(
                color: AppColors.disabledText,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.notifications.length + (state.isLoadMore ? 1 : 0),
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == state.notifications.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final item = state.notifications[index];
        final isExpanded = _expandedNotificationId == item.id;

        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) {
            ref.read(notificationsProvider.notifier).deleteNotification(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Notification deleted"), duration: Duration(seconds: 2)),
            );
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: item.isRead ? theme.cardColor : theme.cardColor.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: item.isRead
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary.withOpacity(0.5),
                  width: item.isRead ? 1.0 : 1.5,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (!item.isRead) {
                    ref.read(notificationsProvider.notifier).markAsRead(item.id);
                  }
                  setState(() {
                    _expandedNotificationId = isExpanded ? null : item.id;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (item.isRead ? AppColors.primaryGold : theme.colorScheme.primary)
                              .withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(item.type),
                          color: item.isRead ? AppColors.primaryGold : theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & Message details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                                      fontSize: 14.5,
                                      color: primaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getRelativeTime(item.createdAt),
                                  style: TextStyle(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.message,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: isExpanded ? null : 2,
                              overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Unread indicator dot
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
