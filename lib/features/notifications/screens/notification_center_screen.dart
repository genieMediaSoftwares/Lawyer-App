import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/notification_model.dart';
import '../../../providers/notification_provider.dart';
import '../domain/notification_presentation.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_filter_tabs.dart';

/// Resolves a tapped notification to a destination.
///
/// Return true if navigation happened. The client pushes routes; the lawyer
/// switches dashboard tabs — the screen itself stays out of that decision.
typedef NotificationOpener =
    bool Function(NotificationModel notification, NotificationTarget target);

/// The notification centre, shared by the client and lawyer apps.
///
/// Both used to carry their own copy of this screen with separately written
/// grouping, time formatting, icon mapping and filtering, which had drifted
/// apart — different icons for the same event, pagination in one and not the
/// other, and no navigation in either. Everything role-specific now arrives
/// through the constructor.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  /// Label for the third tab: "Clients" in the lawyer app, "Lawyers" in the
  /// client app.
  final String peopleLabel;

  final VoidCallback onBack;

  /// Opens the settings screen. The gear is hidden when null.
  final VoidCallback? onOpenSettings;

  final NotificationOpener onOpen;

  const NotificationCenterScreen({
    super.key,
    required this.peopleLabel,
    required this.onBack,
    required this.onOpen,
    this.onOpenSettings,
  });

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final _scrollController = ScrollController();
  NotificationFilter _filter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      // Guarded inside the notifier against overlapping pages, so firing this
      // on every scroll tick near the end is safe.
      ref.read(notificationsProvider.notifier).fetchNotifications();
    }
  }

  Future<void> _handleTap(NotificationModel notification) async {
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }
    final target = NotificationPresentation.forType(notification.type).target;
    widget.onOpen(notification, target);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final counts = ref.watch(notificationCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (state.isOffline) const _OfflineBanner(),
            _buildFilterRow(counts),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryGold,
                backgroundColor: AppColors.cardBackground,
                onRefresh: () => ref
                    .read(notificationsProvider.notifier)
                    .fetchNotifications(refresh: true, silent: true),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildBody(state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filter tabs plus the mark-all-read action.
  ///
  /// The tabs always scroll horizontally, so three of them never truncate. The
  /// action beside them cannot shrink, though, and on a narrow screen it left
  /// the tabs a sliver to scroll inside — the "cut off" symptom. Below the
  /// breakpoint it collapses to its icon, and below a narrower one still it
  /// moves onto its own line where it has room for the label again.
  Widget _buildFilterRow(NotificationCounts counts) {
    final markAllRead = () =>
        ref.read(notificationsProvider.notifier).markAllAsRead();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabs = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 4),
            child: NotificationFilterTabs(
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
              allCount: counts.all,
              unreadCount: counts.unread,
              peopleCount: counts.fromPeople,
              peopleLabel: widget.peopleLabel,
            ),
          );

          // Measured against the widest the tabs get, so the action only
          // gives up its label once it is genuinely crowding them out.
          if (constraints.maxWidth < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tabs,
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _MarkAllReadButton(
                    enabled: counts.unread > 0,
                    onPressed: markAllRead,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: tabs),
              const SizedBox(width: 10),
              _MarkAllReadButton(
                enabled: counts.unread > 0,
                onPressed: markAllRead,
                iconOnly: constraints.maxWidth < 420,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
            onPressed: widget.onBack,
            tooltip: 'Back',
          ),
          // Expanded, not Spacer-and-fixed-Text. The title is the only part
          // that can give, so it has to be the flexible one: between two
          // Spacers it could not shrink and blew the row apart on a 411pt
          // phone, let alone at an accessibility text scale.
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.notifications,
                  color: AppColors.primaryGold,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    "Notifications",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Balances the back button so the title stays optically centred
          // whether or not the settings action is present.
          if (widget.onOpenSettings != null)
            IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.secondaryText,
              ),
              onPressed: widget.onOpenSettings,
              tooltip: 'Notification settings',
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(color: AppColors.primaryGold),
      );
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return _ErrorState(
        key: const ValueKey('error'),
        message: state.errorMessage!,
        onRetry: () => ref
            .read(notificationsProvider.notifier)
            .fetchNotifications(refresh: true),
      );
    }

    final visible = _applyFilter(state.notifications);
    if (visible.isEmpty) {
      return _EmptyState(
        key: const ValueKey('empty'),
        filter: _filter,
        peopleLabel: widget.peopleLabel,
      );
    }

    final sections = _groupByDay(visible);

    return ListView.builder(
      key: const ValueKey('list'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: sections.length + 1,
      itemBuilder: (context, index) {
        if (index == sections.length) {
          if (!state.isLoadMore) return const SizedBox(height: 8);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGold,
                ),
              ),
            ),
          );
        }

        final section = sections[index];
        return _Section(
          title: section.title,
          items: section.items,
          onTap: _handleTap,
          onLongPress: _showActions,
        );
      },
    );
  }

  List<NotificationModel> _applyFilter(List<NotificationModel> all) {
    switch (_filter) {
      case NotificationFilter.unread:
        return all.where((n) => !n.isRead).toList();
      case NotificationFilter.people:
        // Raised by the other party rather than by the system.
        return all.where((n) => (n.senderId ?? '').isNotEmpty).toList();
      case NotificationFilter.all:
        return all;
    }
  }

  /// Buckets into Today / Yesterday / Earlier, preserving the server's
  /// newest-first order and dropping empty buckets.
  List<_DaySection> _groupByDay(List<NotificationModel> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final buckets = <String, List<NotificationModel>>{
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final item in items) {
      final day = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );
      if (day == today) {
        buckets['Today']!.add(item);
      } else if (day == yesterday) {
        buckets['Yesterday']!.add(item);
      } else {
        buckets['Earlier']!.add(item);
      }
    }

    return [
      for (final entry in buckets.entries)
        if (entry.value.isNotEmpty)
          _DaySection(title: entry.key, items: entry.value),
    ];
  }

  void _showActions(NotificationModel notification) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!notification.isRead)
              ListTile(
                leading: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primaryText,
                ),
                title: const Text(
                  "Mark as read",
                  style: TextStyle(color: AppColors.primaryText),
                ),
                onTap: () {
                  ref
                      .read(notificationsProvider.notifier)
                      .markAsRead(notification.id);
                  Navigator.pop(sheetContext);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
              ),
              title: const Text(
                "Remove",
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                ref
                    .read(notificationsProvider.notifier)
                    .deleteNotification(notification.id);
                Navigator.pop(sheetContext);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DaySection {
  final String title;
  final List<NotificationModel> items;
  const _DaySection({required this.title, required this.items});
}

class _Section extends StatelessWidget {
  final String title;
  final List<NotificationModel> items;
  final ValueChanged<NotificationModel> onTap;
  final ValueChanged<NotificationModel> onLongPress;

  const _Section({
    required this.title,
    required this.items,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final item in items)
            NotificationCard(
              key: ValueKey(item.id),
              notification: item,
              onTap: () => onTap(item),
              onLongPress: () => onLongPress(item),
            ),
        ],
      ),
    );
  }
}

class _MarkAllReadButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  /// Drops the label and keeps the tick. The tooltip carries the meaning.
  final bool iconOnly;

  const _MarkAllReadButton({
    required this.enabled,
    required this.onPressed,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primaryGold : AppColors.disabledText;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Tooltip(
        message: "Mark all read",
        child: iconOnly
            ? OutlinedButton(
                onPressed: enabled ? onPressed : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 40),
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: color.withValues(alpha: 0.7)),
                  shape: shape,
                ),
                child: Icon(Icons.done_all_rounded, size: 18, color: color),
              )
            : OutlinedButton.icon(
                onPressed: enabled ? onPressed : null,
                icon: Icon(Icons.check_rounded, size: 16, color: color),
                label: Text(
                  "Mark all read",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: BorderSide(color: color.withValues(alpha: 0.7)),
                  shape: shape,
                ),
              ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.warning),
          SizedBox(width: 8),
          Text(
            "Reconnecting…",
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final NotificationFilter filter;
  final String peopleLabel;

  const _EmptyState({
    super.key,
    required this.filter,
    required this.peopleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (filter) {
      NotificationFilter.unread => (
        "You're all caught up",
        "Every notification has been read.",
      ),
      NotificationFilter.people => (
        "Nothing from your ${peopleLabel.toLowerCase()} yet",
        "Messages and requests from them will show up here.",
      ),
      NotificationFilter.all => (
        "No Notifications Yet",
        "We'll notify you whenever something important happens.",
      ),
    };

    // Scrollable so pull-to-refresh still works with nothing on screen.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              filter == NotificationFilter.unread
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_rounded,
              size: 44,
              color: AppColors.primaryGold.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        const Icon(
          Icons.cloud_off_rounded,
          size: 52,
          color: AppColors.disabledText,
        ),
        const SizedBox(height: 16),
        const Text(
          "Couldn't load notifications",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primaryText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Retry"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGold,
              side: const BorderSide(color: AppColors.primaryGold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
