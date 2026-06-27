import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import 'route_names.dart';

// Screens
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/client/dashboard/screens/client_dashboard_screen.dart';
import '../features/client/lawyer_search/screens/lawyer_search_screen.dart';
import 'package:law/features/client/lawyer_profile/screens/lawyer_profile_screen.dart';
import '../features/lawyer/dashboard/screens/lawyer_dashboard_screen.dart';
import '../features/authentication/presentation/signup/signup_screen.dart';
import '../features/authentication/presentation/login/login_screen.dart';
import '../features/authentication/presentation/forgot_password/forgot_password_screen.dart';

final routerListenableProvider = Provider((ref) {
  final listenable = RouterListenable();
  ref.listen<AuthState>(authProvider, (previous, next) {
    Future.microtask(() {
      listenable.notify();
    });
  });
  return listenable;
});

class RouterListenable extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.read(routerListenableProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;
      final isLoggedIn = auth.isLoggedIn;
      final role = auth.role;
      final onboardingDone = auth.onboardingCompleted;

      // Splash
      if (path == RouteNames.splash) {
        return null;
      }

      // Onboarding Flow
      if (!onboardingDone && path != RouteNames.onboarding) {
        return RouteNames.onboarding;
      }

      // Authentication Guard
      final authRoutes = [
        RouteNames.login,
        RouteNames.signup,
        RouteNames.forgotPassword,
      ];

      if (!isLoggedIn && !authRoutes.contains(path) && path != RouteNames.onboarding) {
        return RouteNames.login;
      }

      // Prevent logged user from going back
      if (isLoggedIn && authRoutes.contains(path)) {
        if (role == UserRole.client) {
          return RouteNames.clientDashboard;
        }
        if (role == UserRole.lawyer) {
          return RouteNames.lawyerDashboard;
        }
      }

      // Lawyer Only Routes
      if (path == RouteNames.lawyerDashboard && role != UserRole.lawyer) {
        return RouteNames.clientDashboard;
      }

      // Client Only Routes
      final clientRoutes = [
        RouteNames.clientDashboard,
        RouteNames.lawyerSearch,
        RouteNames.lawyerProfile,
        RouteNames.appointmentBooking,
      ];

      if (clientRoutes.contains(path) && role == UserRole.lawyer) {
        return RouteNames.lawyerDashboard;
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Login
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Client Dashboard
      GoRoute(
        path: RouteNames.clientDashboard,
        builder: (context, state) => const ClientDashboardScreen(),
      ),

      // Lawyer Search
      GoRoute(
        path: RouteNames.lawyerSearch,
        builder: (context, state) => const LawyerSearchScreen(),
      ),

      // Lawyer Profile
      GoRoute(
        path: RouteNames.lawyerProfile,
        builder: (context, state) => const LawyerProfileScreen(),
      ),

      // Lawyer Dashboard
      GoRoute(
        path: RouteNames.lawyerDashboard,
        builder: (context, state) => const LawyerDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Text(
            'Route Not Found\n${state.uri}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    },
  );
});
