import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
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
    final theme = Theme.of(context);

    final logoSize = screen.width * 0.28;

    return Scaffold(
      // Was theme.scaffoldBackgroundColor — routed through the dedicated
      // AppColors.splashBackgroundColor token instead. Both resolve to the
      // same value today, but a screen-specific token means a future splash
      // redesign has exactly one place to change, rather than a literal that
      // can silently drift out of sync with the rest of the theme (which is
      // exactly what caused the original seam below).
      backgroundColor: AppColors.splashBackgroundColor,
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
                ///
                /// `logo.jpg` had a navy-black background baked into the
                /// JPEG (JPEGs can't be transparent), which never matched
                /// this screen's neutral near-black background — visible as
                /// a mismatched square, worse at the corners where the
                /// gold-filled Container behind it peeked through the
                /// rounded clip. `logo_transparent.png` is a soft-alpha
                /// chroma-keyed cutout of the same artwork (background
                /// verified as fully transparent, RGBA alpha=0 at every
                /// corner) with no wrapping Container or fill color needed —
                /// it simply sits on the scaffold background, so it matches
                /// by construction rather than by picking a close-enough
                /// color.
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
                  child: Image.asset(
                    "assets/images/logo_transparent.png",
                    width: logoSize * 1.6,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 30),

                /// App Name
                Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.textTheme.headlineMedium?.color,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                /// Tagline
                Text(
                  AppStrings.appTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyLarge?.color,
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
                      theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Loading...",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color,
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