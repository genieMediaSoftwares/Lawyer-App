import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../routes/route_names.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
  TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String _selectedRole = "client";

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Signup Successful"),
      ),
    );

    context.go(RouteNames.login);
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Please enter your name";
    }

    if (value.length < 3) {
      return "Name too short";
    }

    return null;
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

  String? _validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return "Enter mobile number";
    }

    if (!RegExp(r'^[0-9]{10}$')
        .hasMatch(value)) {
      return "Invalid mobile";
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Enter password";
    }

    if (value.length < 6) {
      return "Minimum 6 characters";
    }

    return null;
  }

  String? _validateConfirmPassword(
      String? value) {
    if (value != _passwordController.text) {
      return "Passwords do not match";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(
                  height: size.height * 0.02,
                ),

                Icon(
                  Icons.gavel_rounded,
                  size: 90,
                  color: theme
                      .colorScheme.primary,
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  "Join LawConnect",
                  style: theme
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  "Create your account",
                  style: theme
                      .textTheme
                      .bodyMedium,
                ),

                const SizedBox(
                  height: 30,
                ),

                TextFormField(
                  controller:
                  _nameController,
                  validator:
                  _validateName,
                  decoration:
                  const InputDecoration(
                    labelText:
                    "Full Name",
                    prefixIcon:
                    Icon(Icons.person),
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 20,
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
                    Icon(Icons.email),
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextFormField(
                  controller:
                  _mobileController,
                  validator:
                  _validateMobile,
                  keyboardType:
                  TextInputType.phone,
                  decoration:
                  const InputDecoration(
                    labelText:
                    "Mobile Number",
                    prefixIcon:
                    Icon(Icons.phone),
                    border:
                    OutlineInputBorder(),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                DropdownButtonFormField<
                    String>(
                  value: _selectedRole,
                  decoration:
                  const InputDecoration(
                    labelText:
                    "Select Role",
                    border:
                    OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "client",
                      child:
                      Text("Client"),
                    ),
                    DropdownMenuItem(
                      value: "lawyer",
                      child:
                      Text("Lawyer"),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole =
                      value!;
                    });
                  },
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
                        Icons.lock),
                    border:
                    const OutlineInputBorder(),
                    suffixIcon:
                    IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                            .visibility
                            : Icons
                            .visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextFormField(
                  controller:
                  _confirmPasswordController,
                  validator:
                  _validateConfirmPassword,
                  obscureText:
                  _obscureConfirmPassword,
                  decoration:
                  InputDecoration(
                    labelText:
                    "Confirm Password",
                    prefixIcon:
                    const Icon(
                        Icons.lock),
                    border:
                    const OutlineInputBorder(),
                    suffixIcon:
                    IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons
                            .visibility
                            : Icons
                            .visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword =
                          !_obscureConfirmPassword;
                        });
                      },
                    ),
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
                        : _signup,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                      "Create Account",
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    const Text(
                      "Already have an account?",
                    ),
                    TextButton(
                      onPressed: () {
                        context.go(
                          RouteNames
                              .login,
                        );
                      },
                      child: const Text(
                        "Login",
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