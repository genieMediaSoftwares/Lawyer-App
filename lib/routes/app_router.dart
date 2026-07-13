import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import 'route_names.dart';
import '../core/widgets/app_shell.dart';

import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/client/dashboard/screens/client_dashboard_screen.dart';
import '../features/client/dashboard/screens/all_categories_screen.dart';
import '../features/client/case_tracking/screens/my_cases_screen.dart';

import '../features/chat/presentation/screens/messages_screen.dart';
import '../features/client/profile/screens/profile_screen.dart';
import 'package:law/features/client/lawyer_profile/screens/lawyer_profile_screen.dart';
import '../features/client/notifications/screens/notifications_screen.dart';
import '../features/client/ai_chat/screens/ai_chat_screen.dart';
import '../features/client/post_case/screens/post_case_screen.dart';
import '../features/client/case_tracking/screens/lawyers_responded_screen.dart';
import '../features/client/case_tracking/screens/case_progress_screen.dart';
import '../features/client/appointment_booking/screens/schedule_consultation_screen.dart';
import '../features/client/appointment_booking/screens/calendar_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/lawyer/dashboard/screens/lawyer_dashboard_screen.dart';
import '../features/lawyer/subscription/screens/subscription_plans_screen.dart';
import '../features/authentication/presentation/signup/signup_screen.dart';
import '../features/authentication/presentation/login/login_screen.dart';
import '../features/authentication/presentation/forgot_password/forgot_password_screen.dart';
import '../features/client/lawyer_search/screens/get_matched_screen.dart';
import '../features/client/consultation_history/screens/consult_screen.dart';
import '../features/client/case_tracking/screens/resolve_screen.dart';
import '../features/client/lawyer_search/screens/category_detail_screen.dart';
import '../features/client/documents/screens/my_documents_screen.dart';
import '../features/client/profile/screens/settings_screen.dart';
import '../features/client/profile/screens/favorite_lawyers_screen.dart';
import '../features/client/profile/screens/articles_screen.dart';
import '../features/client/profile/screens/help_center_screen.dart';
import '../features/client/profile/screens/contact_support_screen.dart';
import '../features/client/profile/screens/about_us_screen.dart';
import '../features/client/profile/screens/privacy_policy_screen.dart';
import '../features/client/profile/screens/terms_conditions_screen.dart';

final routerListenableProvider = Provider((ref) {
  final listenable = RouterListenable();
  ref.listen<AuthState>(authProvider, (previous, next) {
    Future.microtask(() => listenable.notify());
  });
  return listenable;
});

class RouterListenable extends ChangeNotifier {
  void notify() => notifyListeners();
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ref.read(routerListenableProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.matchedLocation;
      final isLoggedIn = auth.isLoggedIn;
      final role = auth.role;
      final onboardingDone = auth.onboardingCompleted;

      if (path == RouteNames.splash) return null;

      if (!onboardingDone && path != RouteNames.onboarding) {
        return RouteNames.onboarding;
      }

      final authRoutes = [
        RouteNames.login,
        RouteNames.signup,
        RouteNames.forgotPassword,
      ];

      if (!isLoggedIn && !authRoutes.contains(path) && path != RouteNames.onboarding) {
        return RouteNames.login;
      }

      if (isLoggedIn && authRoutes.contains(path)) {
        if (role == UserRole.client) return RouteNames.clientDashboard;
        if (role == UserRole.lawyer) return RouteNames.lawyerDashboard;
      }

      if (path == RouteNames.lawyerDashboard && role != UserRole.lawyer) {
        return RouteNames.clientDashboard;
      }

      final clientRoutes = [
        RouteNames.clientDashboard,
        RouteNames.myCases,
        RouteNames.profile,
        RouteNames.messages,
        RouteNames.lawyerProfile,
        RouteNames.postCase,
        RouteNames.lawyersResponded,
        RouteNames.caseProgress,
        RouteNames.scheduleConsultation,
        RouteNames.notifications,
        RouteNames.aiChat,
        RouteNames.chat,
        RouteNames.getMatched,
        RouteNames.consult,
        RouteNames.resolve,
        RouteNames.categoryDetail,
        RouteNames.myDocuments,
        RouteNames.settings,
        RouteNames.favorites,
        RouteNames.articles,
        RouteNames.faq,
        RouteNames.contactSupport,
        RouteNames.aboutUs,
        RouteNames.privacyPolicy,
        RouteNames.termsConditions,
      ];

      if (clientRoutes.contains(path) && role == UserRole.lawyer) {
        return RouteNames.lawyerDashboard;
      }

      return null;
    },
    routes: [
      GoRoute(path: RouteNames.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: RouteNames.onboarding, builder: (c, s) => const OnboardingScreen()),
      GoRoute(path: RouteNames.login, builder: (c, s) => const LoginScreen()),
      GoRoute(path: RouteNames.signup, builder: (c, s) => const SignupScreen()),
      GoRoute(path: RouteNames.forgotPassword, builder: (c, s) => const ForgotPasswordScreen()),

      // Bottom-nav tabs — IndexedStack keeps each tab's state alive when you switch
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.clientDashboard, builder: (c, s) => const ClientDashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.myCases, builder: (c, s) => const MyCasesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.messages, builder: (c, s) => const MessagesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RouteNames.profile, builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),

      // Pushed full-screen routes — parentNavigatorKey makes them cover the bottom nav
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.lawyerMessages,
        builder: (c, s) => const MessagesScreen(),
      ),

      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.lawyerProfile,
        builder: (c, s) => LawyerProfileScreen(
          userId: s.pathParameters['userId']!,
          caseId: s.uri.queryParameters['caseId'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/all-categories',
        builder: (c, s) => const AllCategoriesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.postCase,
        builder: (c, s) => PostCaseScreen(
          preselectedCategory: s.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.lawyersResponded,
        builder: (c, s) => LawyersRespondedScreen(
          caseId: s.pathParameters['caseId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.caseProgress,
        builder: (c, s) => CaseProgressScreen(
          caseId: s.pathParameters['caseId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.scheduleConsultation,
        builder: (c, s) => ScheduleConsultationScreen(
          lawyerUserId: s.pathParameters['lawyerUserId']!,
          caseId: s.uri.queryParameters['caseId'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/calendar-view',
        builder: (c, s) => const CalendarScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.notifications,
        builder: (c, s) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.aiChat,
        builder: (c, s) => const AiChatScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.chat,
        builder: (c, s) => ChatScreen(
          chatId: s.pathParameters['chatId']!,
          lawyerName: s.pathParameters['lawyerName']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.getMatched,
        builder: (c, s) => const GetMatchedScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.consult,
        builder: (c, s) => const ConsultScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.resolve,
        builder: (c, s) => const ResolveScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.categoryDetail,
        builder: (c, s) => CategoryDetailScreen(
          categoryName: s.pathParameters['categoryName']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.myDocuments,
        builder: (c, s) => const MyDocumentsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.settings,
        builder: (c, s) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.favorites,
        builder: (c, s) => const FavoriteLawyersScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.articles,
        builder: (c, s) => const ArticlesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.faq,
        builder: (c, s) => const HelpCenterScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.contactSupport,
        builder: (c, s) => const ContactSupportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.aboutUs,
        builder: (c, s) => const AboutUsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.privacyPolicy,
        builder: (c, s) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.termsConditions,
        builder: (c, s) => const TermsConditionsScreen(),
      ),

      GoRoute(
        path: RouteNames.lawyerDashboard,
        builder: (c, s) {
          final tabIndexStr = s.uri.queryParameters['tab'];
          final initialTab = int.tryParse(tabIndexStr ?? '') ?? 0;
          return LawyerDashboardScreen(initialTab: initialTab);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: RouteNames.subscriptionPlans,
        builder: (c, s) => const SubscriptionPlansScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route Not Found\n${state.uri}', textAlign: TextAlign.center)),
    ),
  );
});