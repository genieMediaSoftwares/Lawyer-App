import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared building blocks for the Settings and Profile screens.
///
/// Both the client and lawyer modules render the same list-of-cards layout.
/// These were private `_buildSectionHeader` / `_buildCard` / `_buildNavRow`
/// helpers duplicated inside each screen, which is how the two drifted apart
/// visually. Extracted verbatim from the lawyer implementation so the two
/// modules are identical by construction rather than by inspection.

/// Gold, upper-cased group label that sits above a [SettingsCard].
class SettingsSection extends StatelessWidget {
  const SettingsSection(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 0.8,
          color: AppColors.primaryGold,
        ),
      ),
    );
  }
}

/// Bordered container that groups related [SettingsTile]s.
///
/// Dividers are inserted between children automatically, so callers list only
/// the rows they want and cannot forget a separator or leave a trailing one.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        separated.add(const Divider(color: AppColors.border, height: 1));
      }
      separated.add(children[i]);
    }

    return Card(
      elevation: 0,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: separated),
    );
  }
}

/// A single settings row: circular gold icon, title, subtitle, chevron.
///
/// Set [isDestructive] for actions such as deleting an account — the icon,
/// text and chevron switch to the error colour, matching the treatment the
/// lawyer Settings screen already used for its delete row.
///
/// A null [onTap] renders the row dimmed and non-interactive; use it with
/// [subtitle] to explain why, rather than hiding an option outright.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Null disables the row.
  final VoidCallback? onTap;
  final bool isDestructive;

  /// Replaces the chevron — used by rows that own a control, such as the
  /// Google Calendar connect/disconnect button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || trailing != null;
    final accent = isDestructive ? AppColors.error : AppColors.primaryGold;
    final titleColor = isDestructive ? AppColors.error : AppColors.primaryText;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(Icons.arrow_forward_ios, size: 14, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width outlined logout button, as used at the bottom of both Profile
/// screens.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
