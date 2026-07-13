import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = Colors.grey;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            context.push('/post-case');
          },
          backgroundColor: theme.colorScheme.primary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        surfaceTintColor: Colors.black,
        elevation: 16,
        notchMargin: 8,
        clipBehavior: Clip.antiAlias,
        shape: const CircularNotchedRectangle(),
        padding: EdgeInsets.zero,
        height: 68,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_filled,
                label: "Home",
                isActive: navigationShell.currentIndex == 0,
                onTap: () => _onTap(0),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _NavItem(
                icon: Icons.assignment_outlined,
                label: "My Cases",
                isActive: navigationShell.currentIndex == 1,
                onTap: () => _onTap(1),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              const SizedBox(width: 48), // FAB notch space
              _NavItem(
                icon: Icons.message_outlined,
                label: "Messages",
                isActive: navigationShell.currentIndex == 2,
                onTap: () => _onTap(2),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: "Profile",
                isActive: navigationShell.currentIndex == 3,
                onTap: () => _onTap(3),
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}