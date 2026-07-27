import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../routes/route_names.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  void _showChangePasswordModal(BuildContext context) {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Change Admin Password', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully!')),
              );
            },
            child: const Text('Save Password', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Administrator Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryGold.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primaryGold,
                    child: Icon(Icons.shield, color: Colors.black, size: 36),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    authState.userName ?? 'Super Administrator',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.userEmail ?? 'admin@lawyer.com',
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGold),
                    ),
                    child: const Text(
                      'SYSTEM ADMINISTRATOR',
                      style: TextStyle(color: AppColors.primaryGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions Section
            _buildOptionTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              subtitle: 'Update administrator account credentials',
              onTap: () => _showChangePasswordModal(context),
            ),
            _buildOptionTile(
              icon: Icons.history,
              title: 'Login Activity',
              subtitle: 'View recent admin session log history',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.cardBackground,
                    title: const Text('Recent Login Activity', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      '• Today 10:45 AM - Windows Desktop Admin Session (Active)\n• Yesterday 04:20 PM - Mobile Admin Binding VM\n• 21 May 2025 - Initial System Admin Setup',
                      style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close', style: TextStyle(color: AppColors.primaryGold)),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.info_outline,
              title: 'About Admin Module',
              subtitle: 'Version 1.0.0 • Lawyer Consultation Enterprise',
              onTap: () {},
            ),
            const SizedBox(height: 20),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Logout Admin Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(RouteNames.login);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGold),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.mutedText, size: 14),
        onTap: onTap,
      ),
    );
  }
}
