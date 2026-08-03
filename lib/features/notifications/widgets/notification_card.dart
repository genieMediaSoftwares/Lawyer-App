import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/notification_model.dart';
import '../domain/notification_presentation.dart';

/// One notification row.
///
/// Shared by both apps: the client and lawyer notification centres render the
/// identical card, and only the destination a tap resolves to differs.
class NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final style = NotificationPresentation.forType(notification.type);
    final isUnread = !notification.isRead;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? style.accent.withValues(alpha: 0.28)
                : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            splashColor: style.accent.withValues(alpha: 0.06),
            // Stack, not IntrinsicHeight+Row. The rail has to match the card's
            // height, but IntrinsicHeight costs an extra layout pass on every
            // card in a long scrolling list, and it cannot measure the
            // LayoutBuilder the content needs. A stretched Positioned does the
            // same job with neither problem.
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: SizedBox(
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Below this the timestamp and content are fighting
                        // over the same handful of pixels, so the timestamp
                        // drops the clock and keeps the date.
                        final compact = constraints.maxWidth < 300;

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 8 : 10,
                            14,
                            compact ? 8 : 12,
                            14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _UnreadDot(
                                isUnread: isUnread,
                                color: style.accent,
                              ),
                              SizedBox(width: compact ? 6 : 8),
                              Container(
                                width: compact ? 34 : 40,
                                height: compact ? 34 : 40,
                                decoration: BoxDecoration(
                                  color: style.accent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  style.icon,
                                  color: style.accent,
                                  size: compact ? 17 : 20,
                                ),
                              ),
                              SizedBox(width: compact ? 8 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.title,
                                      style: TextStyle(
                                        color: AppColors.primaryText,
                                        fontSize: 15,
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    _HighlightedMessage(
                                      text: notification.message,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: compact ? 6 : 10),
                              // Capped so a long timestamp can never starve
                              // the title and message beside it.
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth * 0.30,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatNotificationTimestamp(
                                        notification.createdAt,
                                        compact: compact,
                                      ),
                                      textAlign: TextAlign.end,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.mutedText,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.disabledText,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Accent rail — the type's colour, only while unread.
                if (isUnread)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: style.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  final bool isUnread;
  final Color color;

  const _UnreadDot({required this.isUnread, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AnimatedOpacity(
        opacity: isUnread ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        // Keeps its footprint when read, so marking one read does not shuffle
        // every other card sideways.
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Renders the message with any `"quoted"` span picked out in gold.
///
/// The server embeds the case or client name in quotes — `… case request
/// "Ajay Kumar vs. Ravi Kumar"` — so highlighting is driven by the message
/// itself rather than by a separate field the backend does not send.
class _HighlightedMessage extends StatelessWidget {
  final String text;

  const _HighlightedMessage({required this.text});

  static final _quoted = RegExp(r'[""“”]([^""“”]+)[""“”]');

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: AppColors.secondaryText,
      fontSize: 13,
      height: 1.4,
    );
    const highlight = TextStyle(
      color: AppColors.primaryGold,
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w600,
    );

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _quoted.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: '"${match.group(1)}"', style: highlight));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Time on the right of a card: clock for today and yesterday — the section
/// header already says which day — date and clock for anything older.
///
/// [compact] drops the clock from the older form on narrow screens, where the
/// full string leaves too little room for the title beside it.
String formatNotificationTimestamp(DateTime dateTime, {bool compact = false}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dateTime.year, dateTime.month, dateTime.day);

  if (day == today || day == today.subtract(const Duration(days: 1))) {
    return DateFormat('h:mm a').format(dateTime);
  }
  return DateFormat(compact ? 'MMM dd' : 'MMM dd, h:mm a').format(dateTime);
}
