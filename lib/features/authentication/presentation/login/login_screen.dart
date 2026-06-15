import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../routes/route_names.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _mobileController =
  TextEditingController();

  bool _acceptTerms = false;
  bool _isLoading = false;

  String? _mobileValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Mobile number is required";
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(value.trim())) {
      return "Enter a valid 10-digit mobile number";
    }

    return null;
  }

  Future<void> _continueWithMobile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please accept Terms & Conditions",
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    context.push(
      RouteNames.otpVerification,
      extra: _mobileController.text.trim(),
    );
  }

  Future<void> _googleSignIn() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please accept Terms & Conditions",
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Google Sign-In Integration Pending",
        ),
      ),
    );

    // TODO:
    // Implement Firebase Google Sign-In
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.06,
            vertical: 20,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: size.height * 0.08,
                ),

                /// Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(24),
                    color: theme.colorScheme.primary,
                  ),
                  child: Icon(
                    Icons.gavel_rounded,
                    size: 50,
                    color:
                    theme.colorScheme.onPrimary,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  "Welcome Back",
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Login to connect with legal experts",
                  textAlign: TextAlign.center,
                  style:
                  theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 40),

                /// Mobile Number
                CustomTextField(
                  controller: _mobileController,
                  hintText:
                  "Enter Mobile Number",
                  labelText:
                  "Mobile Number",
                  keyboardType:
                  TextInputType.phone,
                  validator:
                  _mobileValidator,
                  prefixIcon: const Icon(
                    Icons.phone_android,
                  ),
                ),

                const SizedBox(height: 20),

                /// Terms Checkbox
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (value) {
                        setState(() {
                          _acceptTerms =
                              value ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding:
                        const EdgeInsets.only(
                          top: 12,
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: theme
                                .textTheme
                                .bodyMedium,
                            children: const [
                              TextSpan(
                                text:
                                "I agree to the ",
                              ),
                              TextSpan(
                                text:
                                "Terms & Conditions",
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                              TextSpan(
                                text: " and ",
                              ),
                              TextSpan(
                                text:
                                "Privacy Policy",
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// Continue Button
                CustomButton(
                  text: "Continue",
                  onPressed:
                  _continueWithMobile,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 30),

                Row(
                  children: [
                    const Expanded(
                      child: Divider(),
                    ),
                    Padding(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      child: Text(
                        "OR",
                        style: theme
                            .textTheme
                            .bodyMedium,
                      ),
                    ),
                    const Expanded(
                      child: Divider(),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                /// Google Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: _googleSignIn,
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 30,
                    ),
                    label: const Text(
                      "Continue with Google",
                    ),
                  ),
                ),

                SizedBox(
                  height: size.height * 0.12,
                ),

                Text(
                  "Secure • Fast • Trusted",
                  style:
                  theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}