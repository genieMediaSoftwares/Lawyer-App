import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lawyer_provider.dart';
import '../../providers/profile_provider.dart';
import '../../routes/route_names.dart';
import '../../core/config/app_config.dart';
import 'app_circle_avatar.dart';
import '../../core/theme/app_colors.dart';

@visibleForTesting
bool isDrawerDestinationActive(String currentLocation, String target) {
  final current = Uri.parse(currentLocation);
  final destination = Uri.parse(target);

  if (current.path != destination.path) return false;

  final destinationTab = destination.queryParameters['tab'];
  if (destinationTab == null) return true;

  return (current.queryParameters['tab'] ?? '0') == destinationTab;
}

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static String _currentLocation(BuildContext context) =>
      GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString();

  void _navigate(BuildContext context, String target, {required bool isRoot}) {
    final router = GoRouter.of(context);

    Scaffold.maybeOf(context)?.closeDrawer();

    if (isDrawerDestinationActive(_currentLocation(context), target)) return;

    try {
      if (isRoot) {
        router.go(target);
      } else if (router.canPop()) {
        router.pushReplacement(target);
      } else {
        router.push(target);
      }
    } catch (e) {
      debugPrint("Sidebar navigation error for $target: $e");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isLawyer = auth.role == UserRole.lawyer;
    final theme = Theme.of(context);
    final location = _currentLocation(context);
    final loc = AppLocalizations.of(context)!;

    // For both roles, authProvider already holds the latest photo and name
    // (updated immediately after any profile-image or name change). For clients,
    // profileProvider holds the canonical fresh data — prefer it when loaded.
    String? photoUrl = auth.userPhotoUrl;
    String displayName = auth.userName ?? loc.guest_user;

    if (!isLawyer) {
      // Client: profileProvider is a non-family provider keyed to the logged-in user
      final profileState = ref.watch(profileProvider);
      final profile = profileState.profile;
      if (profile != null) {
        if (profile.profileImage.isNotEmpty) {
          photoUrl = profile.profileImage;
        }
        if (profile.fullName.isNotEmpty) {
          displayName = profile.fullName;
        }
      }
    }

    final resolvedPhotoUrl = (photoUrl != null && photoUrl.isNotEmpty)
        ? AppConfig.getAttachmentUrl(photoUrl)
        : null;

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
                  AppCircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    imageUrl: resolvedPhotoUrl,
                    fallback: Icon(Icons.person, color: theme.colorScheme.onSurface, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: isLawyer
                  ? _buildLawyerTiles(context, location, loc)
                  : _buildClientTiles(context, location, loc),
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _DrawerTile(
              icon: Icons.logout,
              label: loc.sign_out,
              onTap: () async {
                final router = GoRouter.of(context);
                Scaffold.maybeOf(context)?.closeDrawer();
                await ref.read(authProvider.notifier).logout();
                router.go(RouteNames.login);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _destination(
    BuildContext context, {
    required String location,
    required IconData icon,
    required String label,
    required String target,
    required bool isRoot,
    Widget? trailing,
  }) {
    return _DrawerTile(
      icon: icon,
      label: label,
      trailing: trailing,
      selected: isDrawerDestinationActive(location, target),
      onTap: () => _navigate(context, target, isRoot: isRoot),
    );
  }

  Widget _unreadMessagesBadge() {
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final countAsync = ref.watch(unreadMessagesCountProvider);
        return countAsync.when(
          data: (count) => count > 0
              ? Badge(
                  label: Text('$count'),
                  backgroundColor: theme.colorScheme.primary,
                  textColor: AppColors.onGold,
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        );
      },
    );
  }

  List<Widget> _buildClientTiles(BuildContext context, String location, AppLocalizations loc) {
    return [
      _destination(
        context,
        location: location,
        icon: Icons.home_outlined,
        label: loc.nav_dashboard,
        target: RouteNames.clientDashboard,
        isRoot: true,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.folder_open_outlined,
        label: loc.my_cases,
        target: RouteNames.myCases,
        isRoot: true,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.chat_bubble_outline,
        label: loc.advocates,
        target: RouteNames.advocates,
        isRoot: true,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.message_outlined,
        label: loc.messages,
        target: RouteNames.messages,
        isRoot: false,
        trailing: _unreadMessagesBadge(),
      ),
      _destination(
        context,
        location: location,
        icon: Icons.cloud_done_outlined,
        label: loc.my_documents,
        target: RouteNames.myDocuments,
        isRoot: false,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.favorite_border,
        label: loc.favorite_lawyers,
        target: RouteNames.favorites,
        isRoot: false,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.person_outline,
        label: loc.my_profile,
        target: RouteNames.profile,
        isRoot: true,
      ),
    ];
  }

  List<Widget> _buildLawyerTiles(BuildContext context, String location, AppLocalizations loc) {
    Widget tab(int index, IconData icon, String label) => _destination(
      context,
      location: location,
      icon: icon,
      label: label,
      target: '${RouteNames.lawyerDashboard}?tab=$index',
      isRoot: true,
    );

    return [
      tab(0, Icons.space_dashboard_outlined, loc.nav_workspace),
      tab(1, Icons.bar_chart_outlined, loc.nav_dashboard),
      tab(2, Icons.gavel_outlined, loc.nav_leads),
      tab(3, Icons.people_alt_outlined, loc.nav_clients),
      tab(4, Icons.calendar_month_outlined, loc.nav_calendar),
      _destination(
        context,
        location: location,
        icon: Icons.message_outlined,
        label: loc.messages,
        target: RouteNames.lawyerMessages,
        isRoot: false,
        trailing: _unreadMessagesBadge(),
      ),
      _destination(
        context,
        location: location,
        icon: Icons.card_membership_outlined,
        label: loc.subscription_plans,
        target: RouteNames.subscriptionPlans,
        isRoot: false,
      ),
      tab(5, Icons.person_outline, loc.my_profile),
    ];
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool selected;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return ListTile(
      selected: selected,
      selectedTileColor: accent.withValues(alpha: 0.10),
      leading: Icon(
        icon,
        color: selected ? accent : accent.withValues(alpha: 0.75),
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
          color: selected ? accent : theme.textTheme.bodyMedium?.color,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}