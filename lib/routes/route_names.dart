class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const signup = '/signup';

  static const String login = '/login';
  static const forgotPassword = '/forgot-password';

  /// Client — bottom nav tabs (live inside the shell)
  static const String clientDashboard = '/client-dashboard';
  static const String myCases = '/my-cases';
  static const String advocates = '/advocates';
  static const String profile = '/profile';
  static const String messages = '/messages';

  /// Client — pushed full-screen routes (sit above the shell)
  static const String lawyerProfile = '/lawyer-profile/:userId';
  static const String postCase = '/post-case';
  static const String allCategories = '/all-categories';
  static const String lawyersResponded = '/lawyers-responded/:caseId';
  static const String caseProgress = '/case-progress/:caseId';
  static const String scheduleConsultation =
      '/schedule-consultation/:lawyerUserId';
  static const String notifications = '/notifications';
  static const String aiChat = '/ai-chat';
  static const String aiSmartCase = '/ai-smart-case';

  static const String chat = '/chat/:chatId/:lawyerName';

  static const String getMatched = '/get-matched';
  static const String consult = '/consult';
  static const String resolve = '/resolve';
  static const String categoryDetail = '/category-detail/:categoryName';
  static const String myDocuments = '/my-documents';
  static const String settings = '/settings';
  static const String changePassword = '/change-password';

  static const String favorites = '/favorites';
  static const String articles = '/articles';
  static const String contactSupport = '/contact-support';
  static const String aboutUs = '/about-us';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsConditions = '/terms-conditions';

  static const String lawyerDashboard = '/lawyer-dashboard';
  static const String subscriptionPlans = '/subscription-plans';
  static const String lawyerMessages = '/lawyer-messages';

  /// Admin — bottom nav tabs & pushed routes
  static const String adminDashboard = '/admin-dashboard';
  static const String adminClients = '/admin-clients';
  static const String adminCases = '/admin-cases';
  static const String adminLawyers = '/admin-lawyers';
  static const String adminMore = '/admin-more';
  static const String adminLawyerVerification = '/admin-lawyer-verification';
  static const String adminAppointments = '/admin-appointments';
  static const String adminAiAnalytics = '/admin-ai-analytics';
  static const String adminDocuments = '/admin-documents';
  static const String adminSupportTickets = '/admin-support-tickets';
  static const String adminNotifications = '/admin-notifications';
  static const String adminReports = '/admin-reports';
  static const String adminProfile = '/admin-profile';
  static const String adminAnalytics = '/admin-analytics';
}
