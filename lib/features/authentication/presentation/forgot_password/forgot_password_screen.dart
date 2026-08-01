import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/dio_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
  TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "Please enter email";
    }

    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return "Invalid email";
    }

    return null;
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Calls the real endpoint. This screen used to wait on a two-second
    // `Future.delayed` and then tell the user a reset link had been sent —
    // nothing was ever requested, so no email was ever sent and anyone locked
    // out stayed locked out.
    try {
      final email = _emailController.text.trim();
      final response = await DioClient.dio.post(
        "/auth/forgot-password",
        data: {"email": email},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final body = response.data;
      final succeeded = body is Map && body['success'] == true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            succeeded
                // Deliberately does not confirm whether the address is
                // registered — that would let anyone enumerate accounts.
                ? "If $email is registered, a password reset link is on its way."
                : (body is Map && body['message'] != null
                    ? body['message'].toString()
                    : "Could not send the reset link. Please try again."),
          ),
        ),
      );

      if (succeeded) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is DioException && e.response?.data is Map
                ? (e.response!.data['message']?.toString() ??
                    "Could not send the reset link. Please try again.")
                : "Could not reach the server. Please check your connection.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Forgot Password",
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(
                  height: 40,
                ),

                Icon(
                  Icons.lock_reset,
                  size: 100,
                  color:
                  theme.colorScheme.primary,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  "Reset Password",
                  style: theme
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Text(
                  "Enter your registered email address.",
                  textAlign:
                  TextAlign.center,
                  style: theme
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(
                  height: 40,
                ),

                TextFormField(
                  controller:
                  _emailController,
                  validator:
                  _validateEmail,
                  keyboardType:
                  TextInputType
                      .emailAddress,
                  decoration:
                  const InputDecoration(
                    labelText:
                    "Email Address",
                    prefixIcon:
                    Icon(Icons.email),
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  height: 55,
                  child:
                  ElevatedButton(
                    onPressed:
                    _isLoading
                        ? null
                        : _sendResetLink,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                      "Send Reset Link",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextButton.icon(
                  onPressed: () {
                    context.pop();
                  },
                  icon: const Icon(
                    Icons.arrow_back,
                  ),
                  label: const Text(
                    "Back to Login",
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