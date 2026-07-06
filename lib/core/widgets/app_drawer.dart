import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../routes/route_names.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isLawyer = auth.role == UserRole.lawyer;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner Container
          Container(
            width: double.infinity,
            color: AppColors.navyBlue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    backgroundImage: auth.userPhotoUrl != null && auth.userPhotoUrl!.isNotEmpty
                        ? NetworkImage(auth.userPhotoUrl!)
                        : null,
                    child: (auth.userPhotoUrl == null || auth.userPhotoUrl!.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white, size: 28)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        auth.userName ?? "Guest User",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (isLawyer) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: AppColors.gold, size: 16),
                      ]
                    ],
                  ),
                  Text(
                    auth.userEmail ?? "",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          // Scrollable tiles list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: isLawyer
                  ? _buildLawyerTiles(context)
                  : _buildClientTiles(context),
            ),
          ),

          const Divider(height: 1),
          _DrawerTile(
            icon: Icons.logout,
            label: "Sign Out",
            onTap: () async {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              router.go(RouteNames.login);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  List<Widget> _buildClientTiles(BuildContext context) {
    return [
      _DrawerTile(
        icon: Icons.home_outlined,
        label: "Home Dashboard",
        onTap: () {
          Navigator.pop(context);
          context.go(RouteNames.clientDashboard);
        },
      ),
      _DrawerTile(
        icon: Icons.folder_open_outlined,
        label: "My Cases",
        onTap: () {
          Navigator.pop(context);
          context.go(RouteNames.myCases);
        },
      ),
      _DrawerTile(
        icon: Icons.chat_bubble_outline,
        label: "Messages",
        onTap: () {
          Navigator.pop(context);
          context.go(RouteNames.messages);
        },
      ),
      _DrawerTile(
        icon: Icons.cloud_done_outlined,
        label: "My Documents",
        onTap: () {
          Navigator.pop(context);
          context.go('/my-documents');
        },
      ),
      _DrawerTile(
        icon: Icons.favorite_border,
        label: "Favorite Lawyers",
        onTap: () {
          Navigator.pop(context);
          context.go('/favorites');
        },
      ),
      _DrawerTile(
        icon: Icons.article_outlined,
        label: "Legal Articles",
        onTap: () {
          Navigator.pop(context);
          context.go('/articles');
        },
      ),
      _DrawerTile(
        icon: Icons.question_answer_outlined,
        label: "FAQ Accordion",
        onTap: () {
          Navigator.pop(context);
          context.go('/faq');
        },
      ),
      _DrawerTile(
        icon: Icons.settings_outlined,
        label: "App Settings",
        onTap: () {
          Navigator.pop(context);
          context.go('/settings');
        },
      ),
    ];
  }

  List<Widget> _buildLawyerTiles(BuildContext context) {
    return [
      _DrawerTile(
        icon: Icons.space_dashboard_outlined,
        label: "Workspace Hub",
        onTap: () {
          Navigator.pop(context);
          context.go('/lawyer-dashboard?tab=0');
        },
      ),
      _DrawerTile(
        icon: Icons.bar_chart_outlined,
        label: "Practice Stats",
        onTap: () {
          Navigator.pop(context);
          context.go('/lawyer-dashboard?tab=1');
        },
      ),
      _DrawerTile(
        icon: Icons.gavel_outlined,
        label: "Client Leads",
        onTap: () {
          Navigator.pop(context);
          context.go('/lawyer-dashboard?tab=2');
        },
      ),
      _DrawerTile(
        icon: Icons.people_alt_outlined,
        label: "Active Clients",
        onTap: () {
          Navigator.pop(context);
          context.go('/lawyer-dashboard?tab=3');
        },
      ),
      _DrawerTile(
        icon: Icons.calendar_month_outlined,
        label: "Practice Calendar",
        onTap: () {
          Navigator.pop(context);
          context.go('/lawyer-dashboard?tab=4');
        },
      ),
      _DrawerTile(
        icon: Icons.chat_bubble_outline,
        label: "Messages Feed",
        onTap: () {
          Navigator.pop(context);
          context.go(RouteNames.messages);
        },
      ),
      _DrawerTile(
        icon: Icons.card_membership_outlined,
        label: "Membership Plans",
        onTap: () {
          Navigator.pop(context);
          context.go('/subscription-plans');
        },
      ),
      _DrawerTile(
        icon: Icons.person_outline,
        label: "My Profile Details",
        onTap: () {
          Navigator.pop(context);
          context.go('/lawyer-dashboard?tab=5');
        },
      ),
    ];
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.navyBlue, size: 22),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.navyBlue)),
      onTap: onTap,
      dense: true,
    );
  }
}