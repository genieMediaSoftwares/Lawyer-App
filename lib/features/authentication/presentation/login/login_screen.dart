import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


import '../../../../routes/route_names.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final _formKey =
  GlobalKey<FormState>();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(
      String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return "Please enter email";
    }

    final regex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
    );

    if (!regex.hasMatch(
        value.trim())) {
      return "Invalid email";
    }

    return null;
  }

  String? _validatePassword(
      String? value) {
    if (value == null ||
        value.isEmpty) {
      return "Please enter password";
    }

    if (value.length < 6) {
      return "Password too short";
    }

    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    /// TODO:
    /// Call backend API

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
        Text("Login Success"),
      ),
    );

    /// Example
    context.go(
      RouteNames.clientDashboard,
    );
  }

  @override
  Widget build(
      BuildContext context) {
    final theme =
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title:
        const Text("Login"),
      ),
      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(
              20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(
                  height: 30,
                ),

                Icon(
                  Icons
                      .gavel_rounded,
                  size: 90,
                  color: theme
                      .colorScheme
                      .primary,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  "Welcome Back",
                  style: theme
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight
                        .bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Text(
                  "Login to continue",
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
                    "Email",
                    prefixIcon:
                    Icon(Icons
                        .email),
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextFormField(
                  controller:
                  _passwordController,
                  validator:
                  _validatePassword,
                  obscureText:
                  _obscurePassword,
                  decoration:
                  InputDecoration(
                    labelText:
                    "Password",
                    prefixIcon:
                    const Icon(
                        Icons
                            .lock),
                    border:
                    const OutlineInputBorder(),
                    suffixIcon:
                    IconButton(
                      onPressed:
                          () {
                        setState(
                                () {
                              _obscurePassword =
                              !_obscurePassword;
                            });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                            .visibility
                            : Icons
                            .visibility_off,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Align(
                  alignment:
                  Alignment
                      .centerRight,
                  child: TextButton(
                    onPressed:
                        () {
                      context.push(
                        RouteNames
                            .forgotPassword,
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
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
                        : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                      "Login",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 25,
                ),

                Row(
                  children: const [
                    Expanded(
                      child:
                      Divider(),
                    ),
                    Padding(
                      padding:
                      EdgeInsets.symmetric(
                          horizontal:
                          10),
                      child:
                      Text("OR"),
                    ),
                    Expanded(
                      child:
                      Divider(),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 25,
                ),

                SizedBox(
                  width:
                  double.infinity,
                  height: 55,
                  child:
                  OutlinedButton.icon(
                    onPressed:
                        () {
                      ScaffoldMessenger.of(
                          context)
                          .showSnackBar(
                        const SnackBar(
                          content:
                          Text(
                            "Google Sign In Coming Soon",
                          ),
                        ),
                      );
                    },
                    icon:
                    const Icon(
                      Icons
                          .g_mobiledata,
                      size: 30,
                    ),
                    label:
                    const Text(
                      "Continue with Google",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    const Text(
                      "Don't have an account?",
                    ),
                    TextButton(
                      onPressed:
                          () {
                        context.push(
                          RouteNames
                              .signup,
                        );
                      },
                      child:
                      const Text(
                        "Sign Up",
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}