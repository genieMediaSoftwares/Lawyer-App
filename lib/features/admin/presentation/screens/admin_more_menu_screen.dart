import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/route_names.dart';

class AdminMoreMenuScreen extends StatelessWidget {
  const AdminMoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Admin Operations & Tools'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MANAGEMENT MODULES',
              style: TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _buildMenuCard(
                  context,
                  title: 'Lawyer Verification',
                  subtitle: 'Pending Approvals',
                  icon: Icons.verified_user_outlined,
                  route: RouteNames.adminLawyerVerification,
                ),
                _buildMenuCard(
                  context,
                  title: 'Appointments',
                  subtitle: 'Schedule & Calendar',
                  icon: Icons.calendar_month_outlined,
                  route: RouteNames.adminAppointments,
                ),
                _buildMenuCard(
                  context,
                  title: 'AI Analytics',
                  subtitle: 'Prompts & Tokens',
                  icon: Icons.psychology_outlined,
                  route: RouteNames.adminAiAnalytics,
                ),
                _buildMenuCard(
                  context,
                  title: 'Documents Vault',
                  subtitle: 'Case Attachments',
                  icon: Icons.folder_shared_outlined,
                  route: RouteNames.adminDocuments,
                ),
                _buildMenuCard(
                  context,
                  title: 'Support Tickets',
                  subtitle: 'Client Inquiries',
                  icon: Icons.support_agent_outlined,
                  route: RouteNames.adminSupportTickets,
                ),
                _buildMenuCard(
                  context,
                  title: 'Broadcast Alerts',
                  subtitle: 'Push Notifications',
                  icon: Icons.campaign_outlined,
                  route: RouteNames.adminNotifications,
                ),
                _buildMenuCard(
                  context,
                  title: 'Data Reports',
                  subtitle: 'PDF, Excel & CSV',
                  icon: Icons.assessment_outlined,
                  route: RouteNames.adminReports,
                ),
                _buildMenuCard(
                  context,
                  title: 'System Analytics',
                  subtitle: 'Growth Charts',
                  icon: Icons.analytics_outlined,
                  route: RouteNames.adminAnalytics,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'ADMINISTRATOR SETTINGS',
              style: TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondaryBackground,
                  child: Icon(Icons.person_outline, color: AppColors.primaryGold),
                ),
                title: const Text('Admin Profile & Security', style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold)),
                subtitle: const Text('Edit profile, change password, logout', style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.mutedText, size: 14),
                onTap: () => context.push(RouteNames.adminProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primaryGold, size: 20),
                ),
                const Icon(Icons.arrow_forward_ios, color: AppColors.mutedText, size: 12),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
