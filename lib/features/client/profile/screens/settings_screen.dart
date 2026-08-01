import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/language_provider.dart';
import '../../../../routes/route_names.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDeleting = false;

  void _onLanguageChanged(String? newCode) {
    if (newCode != null) {
      ref.read(languageProvider.notifier).setLanguage(newCode);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final loc = AppLocalizations.of(context);
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.aiCardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              title: Row(
                children: [
                  const Icon(Icons.delete_forever, color: AppColors.error, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    loc.translate('delete_account_dialog_title'),
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('delete_account_dialog_msg'),
                      style: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.7), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.translate('enter_password_to_confirm'),
                      style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.38)),
                        filled: true,
                        fillColor: AppColors.aiCardBackgroundAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.primaryText.withValues(alpha: 0.54),
                            size: 18,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    loc.translate('cancel'),
                    style: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (passwordController.text.trim().isEmpty) {
                      setDialogState(() {
                        dialogError = "Password is required to confirm.";
                      });
                      return;
                    }

                    try {
                      final response = await DioClient.dio.post(
                        '/auth/delete-account',
                        data: {'password': passwordController.text.trim()},
                      );

                      if (response.statusCode == 200 && response.data?['success'] == true) {
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } else {
                        setDialogState(() {
                          dialogError = response.data?['message'] ?? 'Incorrect password.';
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        dialogError = e.toString().replaceAll('Exception: ', '');
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.primaryText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(loc.translate('delete_account')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        // Logout & Clear Session locally
        await ref.read(authProvider.notifier).logout();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('account_deleted_success')),
              backgroundColor: AppColors.success,
            ),
          );
          context.go(RouteNames.login);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deletion completed: $e')),
          );
          context.go(RouteNames.login);
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);
    final currentLangCode = ref.watch(languageProvider).languageCode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          loc.translate('settings'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // 1. Language Card (Embedded Minimal Dropdown)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.language, color: AppColors.primaryGold, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.translate('language'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.translate('choose_language'),
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Minimal Dropdown Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.aiCardBackgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: currentLangCode,
                          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryGold, size: 18),
                          dropdownColor: AppColors.aiCardBackgroundAlt,
                          style: const TextStyle(color: AppColors.primaryText, fontSize: 12.5, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English')),
                            DropdownMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
                            DropdownMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
                          ],
                          onChanged: _onLanguageChanged,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Change Password Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, color: AppColors.primaryGold, size: 22),
                ),
                title: Text(
                  loc.translate('change_password'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                subtitle: Text(
                  loc.translate('change_password_subtitle'),
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11.5),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primaryGold),
                onTap: () => context.push('/change-password'),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Delete Account Card (Danger styling)
            Card(
              elevation: 0,
              color: AppColors.error.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever, color: AppColors.error, size: 22),
                ),
                title: Text(
                  loc.translate('delete_account'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.error),
                ),
                subtitle: Text(
                  loc.translate('delete_account_subtitle'),
                  style: TextStyle(color: AppColors.error.withValues(alpha: 0.8), fontSize: 11.5),
                ),
                trailing: _isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                      )
                    : const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.error),
                onTap: _isDeleting ? null : _confirmDeleteAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
