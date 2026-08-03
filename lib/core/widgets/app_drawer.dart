import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lawyer_provider.dart';
import '../../routes/route_names.dart';
import '../../core/config/env.dart';
import 'app_circle_avatar.dart';
import '../../core/theme/app_colors.dart';


/// Whether [target] is the destination currently on screen.
///
/// Path comparison alone is not enough for the lawyer: every one of its drawer
/// destinations is `/lawyer-dashboard` and they differ only by the `tab` query
/// parameter. An absent `tab` means the first tab, which is how the dashboard
/// itself defaults.
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

  /// Navigates to a drawer destination without ever stacking one on another.
  ///
  /// A drawer entry is a top-level destination, not a step in a journey, so
  /// picking one should never deepen the stack. It used to `push`
  /// unconditionally, so Messages → Documents → Messages left three pages
  /// stacked — two of them duplicates — and back had to be pressed once per
  /// visit. Replacing the current page when one is already on top keeps the
  /// stack at most one deep above the shell, so back always returns there.
  void _navigate(BuildContext context, String target, {required bool isRoot}) {
    final router = GoRouter.of(context);

    // Close the drawer explicitly. Popping the navigator to dismiss it works
    // only because the drawer registers a local history entry; if it is
    // already closing, that same pop removes the page underneath instead.
    Scaffold.maybeOf(context)?.closeDrawer();

    if (isDrawerDestinationActive(_currentLocation(context), target)) return;

    try {
      if (isRoot) {
        // Shell branches: swap the whole stack for the destination.
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
                  Builder(
                    builder: (context) {
                      final resolvedPhotoUrl = (auth.userPhotoUrl != null && auth.userPhotoUrl!.isNotEmpty)
                          ? Environment.getAttachmentUrl(auth.userPhotoUrl)
                          : null;
                      return AppCircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        imageUrl: resolvedPhotoUrl,
                        fallback: Icon(Icons.person, color: theme.colorScheme.onSurface, size: 28),
                      );
                    },
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
                  ? _buildLawyerTiles(context, location)
                  : _buildClientTiles(context, location),
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _DrawerTile(
              icon: Icons.logout,
              label: "Sign Out",
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

  /// One drawer destination, with its selected state derived from the route
  /// rather than tracked separately — so it cannot drift out of sync with
  /// where the user actually is.
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

  List<Widget> _buildClientTiles(BuildContext context, String location) {
    return [
      _destination(
        context,
        location: location,
        icon: Icons.home_outlined,
        label: "Dashboard",
        target: RouteNames.clientDashboard,
        isRoot: true,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.folder_open_outlined,
        label: "My Cases",
        target: RouteNames.myCases,
        isRoot: true,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.chat_bubble_outline,
        label: "Advocates",
        target: RouteNames.advocates,
        isRoot: true,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.message_outlined,
        label: "Messages",
        target: RouteNames.messages,
        isRoot: false,
        trailing: _unreadMessagesBadge(),
      ),
      _destination(
        context,
        location: location,
        icon: Icons.cloud_done_outlined,
        label: "My Documents",
        target: RouteNames.myDocuments,
        isRoot: false,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.favorite_border,
        label: "Favorite Lawyers",
        target: RouteNames.favorites,
        isRoot: false,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.article_outlined,
        label: "Legal Articles",
        target: RouteNames.articles,
        isRoot: false,
      ),
      _destination(
        context,
        location: location,
        icon: Icons.person_outline,
        label: "My Profile",
        target: RouteNames.profile,
        isRoot: true,
      ),
    ];
  }

  List<Widget> _buildLawyerTiles(BuildContext context, String location) {
    // Every entry below is the same route; the tab query parameter selects
    // which dashboard pane it lands on.
    Widget tab(int index, IconData icon, String label) => _destination(
      context,
      location: location,
      icon: icon,
      label: label,
      target: '${RouteNames.lawyerDashboard}?tab=$index',
      isRoot: true,
    );

    return [
      tab(0, Icons.space_dashboard_outlined, "Workspace"),
      tab(1, Icons.bar_chart_outlined, "Dashboard"),
      tab(2, Icons.gavel_outlined, "Leads"),
      tab(3, Icons.people_alt_outlined, "Clients"),
      tab(4, Icons.calendar_month_outlined, "Calendar"),
      _destination(
        context,
        location: location,
        icon: Icons.message_outlined,
        label: "Messages",
        target: RouteNames.lawyerMessages,
        isRoot: false,
        trailing: _unreadMessagesBadge(),
      ),
      _destination(
        context,
        location: location,
        icon: Icons.card_membership_outlined,
        label: "Subscription Plans",
        target: RouteNames.subscriptionPlans,
        isRoot: false,
      ),
      tab(5, Icons.person_outline, "My Profile"),
    ];
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  /// Marks the destination the user is currently on.
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