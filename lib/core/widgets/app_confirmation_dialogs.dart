import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../network/dio_client.dart';
import '../theme/app_colors.dart';

/// Confirmation dialogs shared by the client and lawyer modules.
///
/// The delete-account flow in particular existed twice: the client screen ran a
/// real password-confirmed `POST /auth/delete-account`, while the lawyer screen
/// showed a dialog and then a "deletion simulated successfully" snackbar
/// without calling anything. Consolidating on the real implementation removes
/// the duplicate and the fake alike.

/// Generic yes/no confirmation. Returns true only when confirmed.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.icon,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final bool isDestructive;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    IconData? icon,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? AppColors.error : AppColors.primaryGold;

    return AlertDialog(
      backgroundColor: AppColors.aiCardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.5)),
      ),
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: accent, size: 24),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: TextStyle(
          color: AppColors.primaryText.withValues(alpha: 0.7),
          fontSize: 12.5,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelLabel,
            style: TextStyle(
              color: AppColors.primaryText.withValues(alpha: 0.7),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor:
                isDestructive ? AppColors.primaryText : AppColors.onGold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Asks the user to confirm signing out. Returns true when confirmed.
abstract final class LogoutDialog {
  LogoutDialog._();

  static Future<bool> show(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return ConfirmationDialog.show(
      context,
      icon: Icons.logout,
      title: loc.logout,
      message: loc.confirm_logout,
      confirmLabel: loc.logout,
      cancelLabel: loc.cancel,
      isDestructive: true,
    );
  }
}

/// Password-confirmed account deletion.
///
/// Returns true only after the server has actually accepted the deletion, so
/// callers may sign the user out unconditionally on true. Errors stay inside
/// the dialog — a wrong password should not close it and lose the typing.
abstract final class DeleteAccountDialog {
  DeleteAccountDialog._();

  static Future<bool> show(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final passwordController = TextEditingController();
    var obscurePassword = true;
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
                  const Icon(Icons.delete_forever,
                      color: AppColors.error, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.delete_account_dialog_title,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.delete_account_dialog_msg,
                      style: TextStyle(
                        color: AppColors.primaryText.withValues(alpha: 0.7),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.enter_password_to_confirm,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        prefixIcon: const Icon(Icons.lock_outline,
                            size: 18, color: AppColors.mutedText),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                            color: AppColors.mutedText,
                          ),
                          onPressed: () => setDialogState(
                              () => obscurePassword = !obscurePassword),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: AppColors.primaryGold),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    loc.cancel,
                    style: TextStyle(
                      color: AppColors.primaryText.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (passwordController.text.trim().isEmpty) {
                      setDialogState(
                          () => dialogError = loc.password_required_to_confirm);
                      return;
                    }

                    try {
                      final response = await DioClient.dio.post(
                        '/auth/delete-account',
                        data: {'password': passwordController.text.trim()},
                      );

                      if (response.statusCode == 200 &&
                          response.data?['success'] == true) {
                        if (context.mounted) Navigator.pop(context, true);
                      } else {
                        setDialogState(() => dialogError =
                            response.data?['message'] ?? loc.incorrect_password);
                      }
                    } catch (e) {
                      setDialogState(() => dialogError =
                          e.toString().replaceAll('Exception: ', ''));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(loc.delete_account),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
    return confirmed ?? false;
  }
}
