import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirmation_dialogs.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/language_provider.dart';
import '../../../../routes/route_names.dart';

/// Client Settings.
///
/// Structurally identical to the lawyer Settings screen: same
/// [SettingsSection] / [SettingsCard] / [SettingsTile] widgets, same section
/// order, same dialogs. The differences are role-specific and deliberate —
/// clients get Notifications and Change Password, and Google Calendar sync is
/// shown in a disabled state because the endpoints behind it
/// (`/api/lawyers/google-calendar/*`) exist only for advocates.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _languageNames = {
    'en': 'English',
    'te': 'తెలుగు (Telugu)',
    'hi': 'हिंदी (Hindi)',
  };

  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final currentLangCode = ref.watch(languageProvider).languageCode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          loc.settings,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // No Notifications row: notifications are reached from the bell in
            // the Profile app bar, so listing them here was a second door onto
            // the same screen — matching the lawyer Settings screen, which has
            // never had one.
            SettingsSection(loc.preferences_header),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.language,
                  title: loc.language,
                  subtitle: _languageNames[currentLangCode] ?? 'English',
                  onTap: () => context.push(RouteNames.languageSelection),
                ),
                // Disabled rather than hidden: the capability exists in the
                // product, just not for this role yet, and silently omitting it
                // makes the two Settings screens look inconsistent for no
                // visible reason. A null onTap dims the row.
                SettingsTile(
                  icon: Icons.calendar_month,
                  title: loc.google_calendar_title,
                  subtitle: loc.google_calendar_lawyer_only,
                  onTap: null,
                ),
              ],
            ),
            const SizedBox(height: 20),

            SettingsSection(loc.support_legal_header),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.headset_mic_outlined,
                  title: loc.contact_support,
                  subtitle: loc.contact_support_subtitle,
                  onTap: () => context.push(RouteNames.contactSupport),
                ),
                SettingsTile(
                  icon: Icons.info_outline,
                  title: loc.about_us,
                  subtitle: loc.about_us_subtitle,
                  onTap: () => context.push(RouteNames.aboutUs),
                ),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: loc.privacy_policy,
                  subtitle: loc.privacy_policy_subtitle,
                  onTap: () => context.push(RouteNames.privacyPolicy),
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: loc.terms_conditions,
                  subtitle: loc.terms_conditions_subtitle,
                  onTap: () => context.push(RouteNames.termsConditions),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SettingsSection(loc.account_header),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.lock_outline,
                  title: loc.change_password,
                  subtitle: loc.change_password_subtitle,
                  onTap: () => context.push(RouteNames.changePassword),
                ),
                // No Logout row here — the Profile screen already ends with a
                // logout button, and offering it in two places invited the
                // accidental sign-out that the confirmation dialog exists to
                // prevent.
                SettingsTile(
                  icon: Icons.delete_forever,
                  title: loc.delete_account,
                  subtitle: loc.delete_account_subtitle,
                  isDestructive: true,
                  onTap: _isDeleting ? null : _confirmDeleteAccount,
                  trailing: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final loc = AppLocalizations.of(context)!;

    // Only returns true once the server has accepted the deletion, so the
    // sign-out below is never reached on a wrong password.
    final deleted = await DeleteAccountDialog.show(context);
    if (!deleted || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.account_deleted_success),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(RouteNames.login);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
