import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPassController.addListener(_onFieldChanged);
    _newPassController.addListener(_onFieldChanged);
    _confirmPassController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  // Password Validation Rules
  bool get _hasMinLength => _newPassController.text.length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newPassController.text);
  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(_newPassController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPassController.text);
  bool get _hasSpecialChar => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_newPassController.text);

  bool get _isNewPassDifferent =>
      _newPassController.text.isNotEmpty &&
      _currentPassController.text.isNotEmpty &&
      _newPassController.text != _currentPassController.text;

  bool get _isConfirmMatching =>
      _confirmPassController.text.isNotEmpty &&
      _confirmPassController.text == _newPassController.text;

  bool get _isFormValid =>
      _currentPassController.text.isNotEmpty &&
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar &&
      _isNewPassDifferent &&
      _isConfirmMatching;

  double get _passwordStrengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasNumber) score++;
    if (_hasSpecialChar) score++;
    return score / 5.0;
  }

  Color get _strengthColor {
    final score = _passwordStrengthScore;
    if (score <= 0.4) return AppColors.error;
    if (score <= 0.8) return AppColors.warning;
    return AppColors.success;
  }

  Future<void> _submitChangePassword() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final loc = AppLocalizations.of(context);

    try {
      final response = await DioClient.dio.post(
        '/auth/change-password',
        data: {
          'oldPassword': _currentPassController.text.trim(),
          'newPassword': _newPassController.text.trim(),
        },
      );

      if (response.statusCode == 200 && response.data?['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('password_changed_success')),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } else {
        setState(() {
          _errorMessage = response.data?['message'] ?? 'Failed to change password.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          loc.translate('change_password'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field 1: Current Password
                Text(
                  loc.translate('current_password'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textTheme.titleMedium?.color),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _currentPassController,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 18),

                // Field 2: New Password
                Text(
                  loc.translate('new_password'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textTheme.titleMedium?.color),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _newPassController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_reset, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                // Password Strength Bar
                if (_newPassController.text.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _passwordStrengthScore,
                      color: _strengthColor,
                      backgroundColor: AppColors.primaryText.withValues(alpha: 0.12),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Password Rules Checklist Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('password_requirements'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      _RuleCheckItem(label: loc.translate('rule_min_chars'), isMet: _hasMinLength),
                      _RuleCheckItem(label: loc.translate('rule_uppercase'), isMet: _hasUppercase),
                      _RuleCheckItem(label: loc.translate('rule_lowercase'), isMet: _hasLowercase),
                      _RuleCheckItem(label: loc.translate('rule_number'), isMet: _hasNumber),
                      _RuleCheckItem(label: loc.translate('rule_special'), isMet: _hasSpecialChar),
                      _RuleCheckItem(label: "New password cannot match old password", isMet: _isNewPassDifferent),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Field 3: Confirm New Password
                Text(
                  loc.translate('confirm_new_password'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textTheme.titleMedium?.color),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPassController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_confirmPassController.text.isNotEmpty && !_isConfirmMatching) ...[
                  const SizedBox(height: 4),
                  Text(
                    loc.translate('password_match_error'),
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),

                // Error Message Display
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                    ),
                  ),
                ],

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isFormValid && !_isLoading) ? _submitChangePassword : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: AppColors.onGold,
                      disabledBackgroundColor: AppColors.disabledText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onGold),
                          )
                        : Text(
                            loc.translate('save_password'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleCheckItem extends StatelessWidget {
  final String label;
  final bool isMet;

  const _RuleCheckItem({required this.label, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? AppColors.success : AppColors.mutedText,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: isMet ? AppColors.primaryText : AppColors.mutedText,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
