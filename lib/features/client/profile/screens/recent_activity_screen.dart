import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../models/activity_model.dart';

class RecentActivityScreen extends ConsumerWidget {
  const RecentActivityScreen({super.key});

  String _formatActivityTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return "$months ${months == 1 ? 'month' : 'months'} ago";
    } else if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return "$weeks ${weeks == 1 ? 'week' : 'weeks'} ago";
    } else if (diff.inDays >= 1) {
      return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
    } else if (diff.inHours >= 1) {
      return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
    } else {
      return "Just now";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider);
    final list = state.activities;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Recent Activity",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "No recent activities found.",
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final act = list[index];
                final isLast = index == list.length - 1;
                return _buildTimelineItem(act, isLast);
              },
            ),
    );
  }

  Widget _buildTimelineItem(ActivityModel act, bool isLast) {
    final timeStr = _formatActivityTime(act.date);

    // Map title keywords to custom timeline icons
    IconData icon = Icons.circle;
    Color iconColor = const Color(0xFFD4AF37);
    final titleLower = act.title.toLowerCase();

    if (titleLower.contains("case") || titleLower.contains("post")) {
      icon = Icons.gavel_outlined;
    } else if (titleLower.contains("consult") || titleLower.contains("appointment")) {
      icon = Icons.calendar_today_outlined;
    } else if (titleLower.contains("doc") || titleLower.contains("file")) {
      icon = Icons.description_outlined;
    } else if (titleLower.contains("profile") || titleLower.contains("update")) {
      icon = Icons.person_outline;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1B1B1B),
                  border: Border.all(color: iconColor, width: 1),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFF2B2B2B),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
