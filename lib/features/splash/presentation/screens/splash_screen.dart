import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../routes/route_names.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _loadingController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();

    Future.delayed(
      const Duration(seconds: 3),
      _handleNavigation,
    );
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeIn,
      ),
    );

    _logoController.forward();
    _loadingController.repeat();
  }

  void _handleNavigation() {
    if (!mounted) return;

    final authState = ref.read(authProvider);

    // Onboarding check
    if (!authState.onboardingCompleted) {
      context.go(RouteNames.onboarding);
      return;
    }

    // Login check
    if (!authState.isLoggedIn) {
      context.go(RouteNames.login);
      return;
    }

    // Role-based navigation
    switch (authState.role) {
      case UserRole.client:
        context.go(RouteNames.clientDashboard);
        break;

      case UserRole.lawyer:
        context.go(RouteNames.lawyerDashboard);
        break;

      default:
        context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    final logoSize = screen.width * 0.28;

    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
            ),
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: [
                /// Animated Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius:
                      BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.gavel_rounded,
                      size: logoSize * 0.5,
                      color: AppColors.navyBlue,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                /// App Name
                Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                /// Tagline
                Text(
                  AppStrings.appTagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 50),

                /// Loading Indicator
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                    AlwaysStoppedAnimation(
                      AppColors.gold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Loading...",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: Colors.white70,
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