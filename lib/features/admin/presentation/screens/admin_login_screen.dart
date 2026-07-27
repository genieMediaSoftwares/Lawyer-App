import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart' as global_auth;
import '../../../../routes/route_names.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final loginUseCase = ref.read(loginUseCaseProvider);
      final response = await loginUseCase(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final userRoleStr = response.user.role;

      if (userRoleStr != 'admin') {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Access Denied: This portal is restricted to System Administrators only."),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      await ref.read(global_auth.authProvider.notifier).login(
            response.token,
            global_auth.UserRole.admin,
            id: response.user.id,
            name: response.user.fullName,
            email: response.user.email,
            mobile: response.user.mobile,
          );

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Admin Authentication Successful Welcome!"),
          backgroundColor: AppColors.success,
        ),
      );

      context.go(RouteNames.adminDashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.go(RouteNames.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shield Badge & Header
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGold, width: 2),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppColors.primaryGold,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "ADMINISTRATOR PORTAL",
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Secure System Sign In",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Authorized access for system control & management",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Form Box
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Administrator Email",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Please enter admin email";
                            if (!val.contains("@")) return "Invalid email address";
                            return null;
                          },
                          decoration: const InputDecoration(
                            hintText: "admin@lawyer.com",
                            prefixIcon: Icon(Icons.admin_panel_settings_outlined, color: AppColors.primaryGold),
                          ),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Master Password",
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Please enter password";
                            if (val.length < 6) return "Password must be at least 6 characters";
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "••••••••",
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryGold),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAdminLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    "Sign In to Admin Console",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Return to Regular Sign In
                  TextButton.icon(
                    onPressed: () => context.go(RouteNames.login),
                    icon: const Icon(Icons.swap_horiz, color: AppColors.primaryGold, size: 18),
                    label: const Text(
                      "Client / Lawyer Sign In",
                      style: TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
