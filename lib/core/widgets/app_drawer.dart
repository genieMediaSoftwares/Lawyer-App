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

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: AppColors.navyBlue,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    backgroundImage: auth.userPhotoUrl != null ? NetworkImage(auth.userPhotoUrl!) : null,
                    child: auth.userPhotoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 28) : null,
                  ),
                  const SizedBox(height: 12),
                  Text(auth.userName ?? "Guest", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(auth.userEmail ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DrawerTile(icon: Icons.home_outlined, label: "Home", onTap: () { Navigator.pop(context); context.go(RouteNames.clientDashboard); }),
            _DrawerTile(icon: Icons.folder_open, label: "My Cases", onTap: () { Navigator.pop(context); context.go(RouteNames.myCases); }),
            _DrawerTile(icon: Icons.chat_bubble_outline, label: "Messages", onTap: () { Navigator.pop(context); context.go(RouteNames.messages); }),
            _DrawerTile(icon: Icons.person_outline, label: "Profile", onTap: () { Navigator.pop(context); context.go(RouteNames.profile); }),
            const Divider(),
            _DrawerTile(
              icon: Icons.logout,
              label: "Logout",
              onTap: () async {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                router.go(RouteNames.login);
              },
            ),
          ],
        ),
      ),
    );
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
      leading: Icon(icon, color: AppColors.navyBlue),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}