import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> mockNotifications = [
      {
        "title": "New Proposal Received",
        "description": "Adv. Sandeep Kumar sent a proposal of ₹1,500 for your Property Dispute case.",
        "time": "5 mins ago"
      },
      {
        "title": "Appointment Confirmed",
        "description": "Your consultation session with Adv. Priya Reddy has been confirmed.",
        "time": "1 hour ago"
      },
      {
        "title": "Welcome to GenieLaw",
        "description": "Your account has been verified. You can now post cases and consult lawyers.",
        "time": "1 day ago"
      }
    ];

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;
    final secondaryTextColor = isDarkMode ? AppColors.grey300 : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: mockNotifications.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = mockNotifications[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDarkMode ? AppColors.borderDark : AppColors.grey200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item["title"]!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor)),
                      Text(item["time"]!, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item["description"]!, style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
