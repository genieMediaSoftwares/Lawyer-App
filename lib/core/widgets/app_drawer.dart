import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../routes/route_names.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _safeNavigate(BuildContext context, String routeName, {required bool isRoot}) {
    // 1. Close the drawer first
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    final router = GoRouter.of(context);
    final currentUri = router.routerDelegate.currentConfiguration.uri.toString();

    // 2. Prevent duplicate navigation if already on the same page
    if (currentUri == routeName) {
      return;
    }

    try {
      if (isRoot) {
        context.go(routeName);
      } else {
        context.push(routeName);
      }
    } catch (e) {
      debugPrint("Sidebar Navigation Error for $routeName: $e");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isLawyer = auth.role == UserRole.lawyer;
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner Container
          Container(
            width: double.infinity,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.onSurface.withOpacity(0.12),
                    backgroundImage: auth.userPhotoUrl != null && auth.userPhotoUrl!.isNotEmpty
                        ? NetworkImage(auth.userPhotoUrl!)
                        : null,
                    child: (auth.userPhotoUrl == null || auth.userPhotoUrl!.isEmpty)
                        ? Icon(Icons.person, color: theme.colorScheme.onSurface, size: 28)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        auth.userName ?? "Guest User",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isLawyer) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, color: theme.colorScheme.primary, size: 16),
                      ]
                    ],
                  ),
                  Text(
                    auth.userEmail ?? "",
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 12,
                    ),
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
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
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
        label: "Dashboard",
        onTap: () => _safeNavigate(context, RouteNames.clientDashboard, isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.folder_open_outlined,
        label: "My Cases",
        onTap: () => _safeNavigate(context, RouteNames.myCases, isRoot: true),
      ),

      _DrawerTile(
        icon: Icons.message_outlined,
        label: "Messages",
        onTap: () => _safeNavigate(context, RouteNames.messages, isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.cloud_done_outlined,
        label: "My Documents",
        onTap: () => _safeNavigate(context, RouteNames.myDocuments, isRoot: false),
      ),
      _DrawerTile(
        icon: Icons.favorite_border,
        label: "Favorite Lawyers",
        onTap: () => _safeNavigate(context, RouteNames.favorites, isRoot: false),
      ),
      _DrawerTile(
        icon: Icons.article_outlined,
        label: "Legal Articles",
        onTap: () => _safeNavigate(context, RouteNames.articles, isRoot: false),
      ),
      _DrawerTile(
        icon: Icons.person_outline,
        label: "My Profile",
        onTap: () => _safeNavigate(context, RouteNames.profile, isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.settings_outlined,
        label: "App Settings",
        onTap: () => _safeNavigate(context, RouteNames.settings, isRoot: false),
      ),
    ];
  }

  List<Widget> _buildLawyerTiles(BuildContext context) {
    return [
      _DrawerTile(
        icon: Icons.space_dashboard_outlined,
        label: "Workspace",
        onTap: () => _safeNavigate(context, '${RouteNames.lawyerDashboard}?tab=0', isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.bar_chart_outlined,
        label: "Dashboard",
        onTap: () => _safeNavigate(context, '${RouteNames.lawyerDashboard}?tab=1', isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.gavel_outlined,
        label: "Leads",
        onTap: () => _safeNavigate(context, '${RouteNames.lawyerDashboard}?tab=2', isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.people_alt_outlined,
        label: "Clients",
        onTap: () => _safeNavigate(context, '${RouteNames.lawyerDashboard}?tab=3', isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.calendar_month_outlined,
        label: "Calendar",
        onTap: () => _safeNavigate(context, '${RouteNames.lawyerDashboard}?tab=4', isRoot: true),
      ),
      _DrawerTile(
        icon: Icons.message_outlined,
        label: "Messages",
        onTap: () => _safeNavigate(context, RouteNames.lawyerMessages, isRoot: false),
      ),
      _DrawerTile(
        icon: Icons.card_membership_outlined,
        label: "Subscription Plans",
        onTap: () => _safeNavigate(context, RouteNames.subscriptionPlans, isRoot: false),
      ),
      _DrawerTile(
        icon: Icons.person_outline,
        label: "My Profile",
        onTap: () => _safeNavigate(context, '${RouteNames.lawyerDashboard}?tab=5', isRoot: true),
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
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}