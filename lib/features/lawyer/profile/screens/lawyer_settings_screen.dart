import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirmation_dialogs.dart';
import '../../../../core/widgets/settings_widgets.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/google_calendar_provider.dart';
import '../../../../providers/language_provider.dart';
import '../../../../routes/route_names.dart';

/// Lawyer Settings.
///
/// Shares [SettingsSection] / [SettingsCard] / [SettingsTile] and the account
/// dialogs with the client Settings screen, so the two stay visually identical
/// without either being kept in sync by hand.
class LawyerSettingsScreen extends ConsumerStatefulWidget {
  const LawyerSettingsScreen({super.key});

  @override
  ConsumerState<LawyerSettingsScreen> createState() =>
      _LawyerSettingsScreenState();
}

class _LawyerSettingsScreenState extends ConsumerState<LawyerSettingsScreen> {
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
            // No Notifications row here: lawyers reach notifications from the
            // dashboard shell, and `/notifications` is a client-guarded route
            // that would redirect them straight back to the dashboard.
            SettingsSection(loc.preferences_header),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.language,
                  title: loc.language,
                  subtitle: _languageNames[currentLangCode] ?? 'English',
                  onTap: () => context.push(RouteNames.languageSelection),
                ),
                _buildGoogleCalendarTile(),
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

            // No Change Password row: `/change-password` is likewise a
            // client-guarded route, and there is no lawyer-side equivalent yet.
            SettingsSection(loc.account_header),
            SettingsCard(
              children: [
                // No Logout row here — the lawyer Profile screen already ends
                // with a logout button.
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

  /// Calendar row. Same [SettingsTile] shell as every other row; only the
  /// trailing control differs, because this one acts in place rather than
  /// navigating.
  Widget _buildGoogleCalendarTile() {
    final loc = AppLocalizations.of(context)!;
    final state = ref.watch(googleCalendarProvider);

    final Widget trailing;
    if (state.isLoading) {
      trailing = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (state.isConnected) {
      trailing = TextButton(
        onPressed: _disconnectGoogleCalendar,
        child: Text(
          loc.disconnect_button,
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    } else {
      trailing = ElevatedButton(
        onPressed: _showConnectGoogleDialog,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          loc.connect_button,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      );
    }

    return SettingsTile(
      icon: Icons.calendar_month,
      title: loc.google_calendar_title,
      subtitle: state.isConnected
          ? loc.google_calendar_connected(state.email)
          : loc.google_calendar_subtitle,
      onTap: null,
      trailing: trailing,
    );
  }

  /// Real deletion, shared with the client screen. This previously showed a
  /// confirmation and then an "Account deletion simulated successfully"
  /// snackbar without calling the server at all.
  Future<void> _confirmDeleteAccount() async {
    final loc = AppLocalizations.of(context)!;

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

  Future<void> _disconnectGoogleCalendar() async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final success =
        await ref.read(googleCalendarProvider.notifier).disconnect();
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(loc.google_calendar_disconnected)),
      );
    }
  }

  void _showConnectGoogleDialog() {
    final loc = AppLocalizations.of(context)!;
    final emailController = TextEditingController(
      text: ref.read(authProvider).userEmail ?? "",
    );

    // Disposed when the dialog closes. Without this a controller leaked on
    // every open, since it is created per invocation and the State's dispose
    // never sees it.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.calendar_month, color: AppColors.primaryGold),
            const SizedBox(width: 10),
            Expanded(child: Text(loc.google_calendar_title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.google_calendar_subtitle,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: loc.email_address,
                hintText: "example@gmail.com",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              if (email.isEmpty || !email.contains("@")) {
                messenger.showSnackBar(
                  SnackBar(content: Text(loc.enter_valid_email)),
                );
                return;
              }

              Navigator.pop(context);

              final success = await ref
                  .read(googleCalendarProvider.notifier)
                  .connect(email);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? loc.google_calendar_connected(email)
                        : loc.google_calendar_connect_failed,
                  ),
                ),
              );
            },
            child: Text(loc.connect_button),
          ),
        ],
      ),
    ).whenComplete(emailController.dispose);
  }
}
