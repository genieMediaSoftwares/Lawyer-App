import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../models/notification_model.dart';

class LawyerNotificationsScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const LawyerNotificationsScreen({
    super.key,
    required this.onBack,
  });

  @override
  ConsumerState<LawyerNotificationsScreen> createState() => _LawyerNotificationsScreenState();
}

class _LawyerNotificationsScreenState extends ConsumerState<LawyerNotificationsScreen> {
  int _selectedTab = 0; // 0: All, 1: Unread, 2: Clients

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF131211), // Modern dark theme background
      appBar: AppBar(
        backgroundColor: const Color(0xFF131211),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.notifications, color: Color(0xFFDE9D32), size: 24),
            SizedBox(width: 8),
            Text(
              "Notifications",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildTabsAndActions(context, ref),
            const SizedBox(height: 16),
            Expanded(
              child: _buildNotificationsList(notificationsState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsAndActions(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              _buildTab(0, "All"),
              _buildTab(1, "Unread"),
              _buildTab(2, "Clients"),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {
            ref.read(notificationsProvider.notifier).markAllAsRead();
          },
          icon: const Icon(Icons.check_circle_outlined, color: Color(0xFFDE9D32), size: 16),
          label: const Text(
            "Mark all read",
            style: TextStyle(
              color: Color(0xFFDE9D32),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDE9D32) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList(NotificationState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDE9D32)));
    }

    if (state.errorMessage != null) {
      return Center(
        child: Text(
          "Error: ${state.errorMessage}",
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final notifications = state.notifications;
    if (notifications.isEmpty) {
      return const Center(
        child: Text(
          "No notifications yet.",
          style: TextStyle(color: Colors.white60, fontSize: 14),
        ),
      );
    }

    // Apply Filter
    final filteredList = notifications.where((notif) {
      if (_selectedTab == 1) {
        return !notif.isRead;
      } else if (_selectedTab == 2) {
        final isClientType = notif.type == 'case_posted' ||
            notif.type == 'proposal_received' ||
            notif.type == 'proposal_accepted' ||
            notif.type == 'appointment_requested' ||
            notif.type == 'chat_message';
        return notif.senderId != null || isClientType;
      }
      return true;
    }).toList();

    if (filteredList.isEmpty) {
      return const Center(
        child: Text(
          "No notifications in this filter.",
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
      );
    }

    // Grouping
    final grouped = _groupNotifications(filteredList);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (grouped['Today']!.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 8, left: 4),
            child: Text(
              "Today",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          ...grouped['Today']!.map((n) => _buildNotificationItem(context, ref, n)),
        ],
        if (grouped['Yesterday']!.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 12, left: 4),
            child: Text(
              "Yesterday",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          ...grouped['Yesterday']!.map((n) => _buildNotificationItem(context, ref, n)),
        ],
        if (grouped['Older']!.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 12, left: 4),
            child: Text(
              "Older",
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          ...grouped['Older']!.map((n) => _buildNotificationItem(context, ref, n)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Map<String, List<NotificationModel>> _groupNotifications(List<NotificationModel> list) {
    final Map<String, List<NotificationModel>> groups = {
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final notif in list) {
      final notifDate = DateTime(notif.createdAt.year, notif.createdAt.month, notif.createdAt.day);
      if (notifDate == today) {
        groups['Today']!.add(notif);
      } else if (notifDate == yesterday) {
        groups['Yesterday']!.add(notif);
      } else {
        groups['Older']!.add(notif);
      }
    }
    return groups;
  }

  Widget _buildNotificationItem(BuildContext context, WidgetRef ref, NotificationModel notif) {
    final style = _getNotificationStyle(notif);
    final timeStr = _formatNotificationTime(notif.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20), // Dark rounded card
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Colored circular icon and unread dot
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !notif.isRead ? const Color(0xFFDE9D32) : Colors.transparent,
                ),
              ),
              CircleAvatar(
                radius: 20,
                backgroundColor: style.color.withOpacity(0.12),
                child: Icon(style.icon, color: style.color, size: 20),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Center content: Title and Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notif.message,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right Side: Time and menu options
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showMoreOptions(context, ref, notif),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.more_vert, color: Colors.white60, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final notifDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeStr = DateFormat('h:mm a').format(dateTime);

    if (notifDate == today) {
      return timeStr;
    } else if (notifDate == yesterday) {
      return "Yesterday, $timeStr";
    } else {
      return "${DateFormat('MMM dd').format(dateTime)}, $timeStr";
    }
  }

  NotificationStyle _getNotificationStyle(NotificationModel notif) {
    final type = notif.type.toLowerCase();
    final title = notif.title.toLowerCase();

    if (type == 'case_posted' || type == 'proposal_received' || title.contains('client request') || title.contains('new client')) {
      return NotificationStyle(Icons.person, const Color(0xFFDE9D32)); // amber/orange
    } else if (type == 'proposal_accepted' || title.contains('accepted')) {
      return NotificationStyle(Icons.check_circle_outline, const Color(0xFF28C76F)); // green
    } else if (type.contains('case') || type.contains('document') || title.contains('case') || title.contains('document')) {
      return NotificationStyle(Icons.article_outlined, const Color(0xFF28C76F)); // green
    } else if (type == 'chat_message' || title.contains('message') || title.contains('chat')) {
      return NotificationStyle(Icons.chat_bubble_outline, const Color(0xFF9F7AEA)); // purple
    } else if (type.contains('appointment') || type.contains('schedule') || type.contains('reminder') || title.contains('schedule') || title.contains('appointment')) {
      return NotificationStyle(Icons.calendar_month_outlined, const Color(0xFFDE9D32)); // amber
    } else {
      // System update/general
      return NotificationStyle(Icons.notifications_outlined, const Color(0xFF3B82F6)); // blue
    }
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref, NotificationModel notif) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (!notif.isRead)
                  ListTile(
                    leading: const Icon(Icons.mail_outline, color: Colors.white),
                    title: const Text("Mark as read", style: TextStyle(color: Colors.white)),
                    onTap: () {
                      ref.read(notificationsProvider.notifier).markAsRead(notif.id);
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Clear", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    ref.read(notificationsProvider.notifier).deleteNotification(notif.id);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }


}

class NotificationStyle {
  final IconData icon;
  final Color color;
  NotificationStyle(this.icon, this.color);
}
