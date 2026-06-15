import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/custom_button.dart';
import '../../../../routes/route_names.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  State<OTPVerificationScreen> createState() =>
      _OTPVerificationScreenState();
}

class _OTPVerificationScreenState
    extends State<OTPVerificationScreen> {
  final List<TextEditingController> controllers =
      List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> focusNodes =
      List.generate(
    6,
    (_) => FocusNode(),
  );

  Timer? timer;
  int secondsRemaining = 30;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();

    setState(() {
      secondsRemaining = 30;
    });

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (secondsRemaining == 0) {
          timer.cancel();
        } else {
          setState(() {
            secondsRemaining--;
          });
        }
      },
    );
  }

  String get otp =>
      controllers.map((e) => e.text).join();

  Future<void> verifyOTP() async {
    if (otp.length != 6) {
      showError("Please enter valid OTP");
      return;
    }

    setState(() {
      isLoading = true;
    });

    await Future.delayed(
      const Duration(seconds: 2),
    );

    setState(() {
      isLoading = false;
    });

    if (!mounted) return;

    // TODO:
    // Call backend OTP verification API

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("OTP Verified Successfully"),
      ),
    );

    context.go(
      RouteNames.clientDashboard,
    );
  }

  void resendOTP() {
    startTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "OTP Resent Successfully",
        ),
      ),
    );

    // TODO:
    // Call resend OTP API
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  Widget otpField(int index) {
    return SizedBox(
      width: 50,
      height: 60,
      child: TextField(
        controller: controllers[index],
        focusNode: focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty &&
              index < 5) {
            focusNodes[index + 1]
                .requestFocus();
          }

          if (value.isEmpty &&
              index > 0) {
            focusNodes[index - 1]
                .requestFocus();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();

    for (final controller
        in controllers) {
      controller.dispose();
    }

    for (final focusNode
        in focusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size =
        MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "OTP Verification",
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              SizedBox(
                height: size.height * 0.05,
              ),

              Icon(
                Icons.lock_outline,
                size: 90,
                color:
                    theme.colorScheme.primary,
              ),

              const SizedBox(height: 24),

              Text(
                "Verify OTP",
                style: theme
                    .textTheme
                    .headlineMedium,
              ),

              const SizedBox(height: 12),

              Text(
                "Enter the 6 digit OTP sent to your mobile number",
                textAlign: TextAlign.center,
                style: theme
                    .textTheme
                    .bodyMedium,
              ),

              const SizedBox(height: 40),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly,
                children: List.generate(
                  6,
                  (index) =>
                      otpField(index),
                ),
              ),

              const SizedBox(height: 30),

              if (secondsRemaining > 0)
                Text(
                  "Resend OTP in ${secondsRemaining}s",
                  style: theme
                      .textTheme
                      .bodyMedium,
                )
              else
                TextButton(
                  onPressed: resendOTP,
                  child: const Text(
                    "Resend OTP",
                  ),
                ),

              const SizedBox(height: 40),

              CustomButton(
                text: "Verify OTP",
                isLoading: isLoading,
                onPressed: verifyOTP,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
