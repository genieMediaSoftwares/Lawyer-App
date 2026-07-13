import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/env.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../providers/chat_provider.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../models/appointment_model.dart';
import '../../../../models/chat_model.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/location_picker_sheet.dart';
import '../../../client/appointment_booking/providers/calendar_provider.dart';
import '../../profile/screens/lawyer_profile_screen.dart';

class LawyerDashboardScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const LawyerDashboardScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends ConsumerState<LawyerDashboardScreen> {
  int _currentIndex = 0;
  final Set<String> _dismissedLeads = {};

  // Selected sub-tabs
  int _selectedLeadsTab = 0; // 0: New Leads, 1: In Progress, 2: Interested
  int _selectedClientsTab = 0; // 0: Active, 1: Consultations, 2: Completed

  // Selected date in calendar tab
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _focusedCalendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late ScrollController _calendarScrollController;

  // Lawyer insights state
  late LawyerInsight _currentInsight;
  Timer? _insightTimer;

  @override
  void initState() {
    super.initState();
    _currentInsight = LawyerInsightsService.getRandomInsight();
    _insightTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      if (mounted) {
        setState(() {
          _currentInsight = LawyerInsightsService.getRandomInsight(
            currentTipTextToExclude: _currentInsight.tip,
          );
        });
      }
    });
    _currentIndex = widget.initialTab;
    _calendarScrollController = ScrollController();
    _scrollToSelectedDate();
  }



  @override
  void didUpdateWidget(covariant LawyerDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _currentIndex = widget.initialTab;
      });
    }
  }

  @override
  void dispose() {
    _insightTimer?.cancel();
    _calendarScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_calendarScrollController.hasClients) {
        final dayIndex = _selectedCalendarDate.day - 1;
        // Each item in the vertical date strip has height 68.0
        final targetOffset = (dayIndex * 68.0) - 150.0;
        _calendarScrollController.animateTo(
          targetOffset.clamp(0.0, _calendarScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = authState.userId ?? "";
    final unreadCount = ref.watch(notificationsProvider).unreadCount;

    // Watch all providers at the top level to avoid conditional watcher assertion violations
    final casesState = ref.watch(casesProvider);
    final appointmentsState = ref.watch(appointmentsProvider);
    final chatsState = ref.watch(chatsProvider);
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));

    final lawyerName = lawyerState.maybeWhen(
      data: (lawyer) => lawyer.fullName,
      orElse: () => authState.userName ?? "Advocate",
    );

    // Set page title dynamically
    String screenTitle = "";
    if (_currentIndex == 1) screenTitle = "Dashboard";
    if (_currentIndex == 2) screenTitle = "My Leads";
    if (_currentIndex == 3) screenTitle = "My Clients";
    if (_currentIndex == 4) screenTitle = "Calendar";
    if (_currentIndex == 5) screenTitle = "My Profile";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(screenTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.onSurface)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (_currentIndex == 4)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: () => _showAddAppointmentDialog(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 20),
                ),
              ),
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_none_outlined, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => _showNotificationsBottomSheet(context),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(
          lawyerName,
          userId,
          casesState,
          appointmentsState,
          chatsState,
          lawyerState,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            _currentIndex = index;
          }),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_outlined, size: 20), activeIcon: Icon(Icons.space_dashboard, size: 20), label: "Workspace"),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined, size: 20), activeIcon: Icon(Icons.bar_chart, size: 20), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(Icons.gavel_outlined, size: 20), activeIcon: Icon(Icons.gavel, size: 20), label: "Leads"),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined, size: 20), activeIcon: Icon(Icons.people_alt, size: 20), label: "Clients"),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined, size: 20), activeIcon: Icon(Icons.calendar_month, size: 20), label: "Calendar"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 20), activeIcon: Icon(Icons.person, size: 20), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    String lawyerName,
    String userId,
    AsyncValue<List<CaseModel>> casesState,
    AsyncValue<List<AppointmentModel>> appointmentsState,
    AsyncValue<List<ChatModel>> chatsState,
    AsyncValue<LawyerModel> lawyerState,
  ) {
    switch (_currentIndex) {
      case 0:
        return _buildWorkspaceTab(lawyerName, userId, casesState, appointmentsState, lawyerState);
      case 1:
        return _buildHomeTab(lawyerName, userId, casesState, appointmentsState, chatsState, lawyerState);
      case 2:
        return _buildLeadsTab(casesState, userId);
      case 3:
        return _buildClientsTab(casesState, appointmentsState, userId);
      case 4:
        return _buildCalendarTab(userId, appointmentsState);
      case 5:
        return const LawyerProfileScreen();
      default:
        return _buildWorkspaceTab(lawyerName, userId, casesState, appointmentsState, lawyerState);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 0. LANDED WORKSPACE HERO SCREEN (NEW)
  // ═══════════════════════════════════════════════════════════
  Widget _buildWorkspaceTab(
    String lawyerName,
    String userId,
    AsyncValue<List<CaseModel>> casesState,
    AsyncValue<List<AppointmentModel>> appointmentsState,
    AsyncValue<LawyerModel> lawyerState,
  ) {

    final welcomeSection = lawyerState.when(
      data: (lawyer) {
        final name = lawyer.fullName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, Advocate",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              "Manage client cases, review legal inquiries, respond to consultation requests, and organize your schedule—all from one secure workspace.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ],
        );
      },
      loading: () {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ShimmerPulse(width: 180, height: 20, borderRadius: 8),
            SizedBox(height: 6),
            _ShimmerPulse(width: 120, height: 16, borderRadius: 8),
            SizedBox(height: 16),
            _ShimmerPulse(width: double.infinity, height: 14, borderRadius: 8),
            SizedBox(height: 6),
            _ShimmerPulse(width: double.infinity, height: 14, borderRadius: 8),
            SizedBox(height: 6),
            _ShimmerPulse(width: 200, height: 14, borderRadius: 8),
          ],
        );
      },
      error: (err, stack) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, Advocate",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              "Lawyer",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              "Manage client cases, review legal inquiries, respond to consultation requests, and organize your schedule—all from one secure workspace.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ],
        );
      },
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: welcomeSection,
          ),
          const SizedBox(height: 28),

          // Workspace Tools Title
          Text(
            "Workspace Tools",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onBackground),
          ),
          const SizedBox(height: 12),

          // Grid of clean professional navigation options
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              ref.watch(lawyerWorkspaceLeadsProvider).when(
                data: (leads) => _buildWorkspaceToolCard(
                  icon: Icons.gavel,
                  title: "${leads.length} New Leads",
                  subtitle: "Waiting for your response",
                  badgeCount: leads.isEmpty ? null : "${leads.length}",
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                loading: () => _buildWorkspaceToolCard(
                  icon: Icons.gavel,
                  title: "Loading Leads...",
                  subtitle: "Waiting for your response",
                  badgeCount: "...",
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                error: (e, s) => _buildWorkspaceToolCard(
                  icon: Icons.gavel,
                  title: "0 New Leads",
                  subtitle: "Waiting for your response",
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ),
              ref.watch(lawyerWorkspaceClientsProvider).when(
                data: (clientsMap) {
                  final accepted = clientsMap['accepted'] as List? ?? [];
                  final inProgress = clientsMap['inProgress'] as List? ?? [];
                  final totalActive = accepted.length + inProgress.length;
                  return _buildWorkspaceToolCard(
                    icon: Icons.people_alt,
                    title: "$totalActive Active Clients",
                    subtitle: "Accepted, In Progress, Closed",
                    badgeCount: totalActive == 0 ? null : "$totalActive",
                    onTap: () => setState(() => _currentIndex = 3),
                  );
                },
                loading: () => _buildWorkspaceToolCard(
                  icon: Icons.people_alt,
                  title: "Loading Clients...",
                  subtitle: "Accepted, In Progress, Closed",
                  badgeCount: "...",
                  onTap: () => setState(() => _currentIndex = 3),
                ),
                error: (e, s) => _buildWorkspaceToolCard(
                  icon: Icons.people_alt,
                  title: "0 Active Clients",
                  subtitle: "Accepted, In Progress, Closed",
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ),
              ref.watch(lawyerWorkspaceScheduleProvider).when(
                data: (events) {
                  final count = events.length;
                  return _buildWorkspaceToolCard(
                    icon: Icons.calendar_month,
                    title: "Today's Schedule",
                    subtitle: count > 0 ? "$count Events Today" : "No Events Today",
                    badgeCount: count == 0 ? null : "$count",
                    onTap: () => setState(() => _currentIndex = 4),
                  );
                },
                loading: () => _buildWorkspaceToolCard(
                  icon: Icons.calendar_month,
                  title: "Today's Schedule",
                  subtitle: "Loading events...",
                  badgeCount: "...",
                  onTap: () => setState(() => _currentIndex = 4),
                ),
                error: (e, s) => _buildWorkspaceToolCard(
                  icon: Icons.calendar_month,
                  title: "Today's Schedule",
                  subtitle: "No Events Today",
                  onTap: () => setState(() => _currentIndex = 4),
                ),
              ),
              ref.watch(lawyerWorkspaceMessagesProvider).when(
                data: (msgData) {
                  final unreadCount = msgData['unreadCount'] as int? ?? 0;
                  return _buildWorkspaceToolCard(
                    icon: Icons.chat,
                    title: "Messages",
                    subtitle: unreadCount > 0 ? "$unreadCount Unread Chats" : "You're all caught up",
                    badgeCount: unreadCount == 0 ? null : "$unreadCount",
                    onTap: () => context.push('/messages'),
                  );
                },
                loading: () => _buildWorkspaceToolCard(
                  icon: Icons.chat,
                  title: "Messages",
                  subtitle: "Checking messages...",
                  badgeCount: "...",
                  onTap: () => context.push('/messages'),
                ),
                error: (e, s) => _buildWorkspaceToolCard(
                  icon: Icons.chat,
                  title: "Messages",
                  subtitle: "You're all caught up",
                  onTap: () => context.push('/messages'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Daily Growth / Conversion Tip Box
          GestureDetector(
            onTap: () {
              setState(() {
                _currentInsight = LawyerInsightsService.getRandomInsight(
                  currentTipTextToExclude: _currentInsight.tip,
                  specialization: ref.read(lawyerDetailsProvider(userId)).valueOrNull?.specialization,
                  experience: ref.read(lawyerDetailsProvider(userId)).valueOrNull?.experience,
                  rating: ref.read(lawyerDetailsProvider(userId)).valueOrNull?.rating,
                  activeCases: ref.read(casesProvider).valueOrNull?.where((c) => c.status == 'active').length,
                );
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Column(
                        key: ValueKey<String>(_currentInsight.tip),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentInsight.category,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentInsight.tip,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.gold.withOpacity(0.1),
                  child: Icon(icon, color: AppColors.gold, size: 18),
                ),
                if (badgeCount != null && badgeCount != "0")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      badgeCount,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 1. HOME / STATS TAB (Figma Screen 1)
  // ═══════════════════════════════════════════════════════════
  Widget _buildHomeTab(
    String lawyerName,
    String userId,
    AsyncValue<List<CaseModel>> casesState,
    AsyncValue<List<AppointmentModel>> appointmentsState,
    AsyncValue<List<ChatModel>> chatsState,
    AsyncValue<LawyerModel> lawyerState,
  ) {
    final authState = ref.read(authProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile row with blue checkmark
          lawyerState.when(
            data: (lawyer) => Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.navyBlueLight,
                    backgroundImage: authState.userPhotoUrl != null && authState.userPhotoUrl!.isNotEmpty
                        ? NetworkImage(authState.userPhotoUrl!)
                        : null,
                    child: (authState.userPhotoUrl == null || authState.userPhotoUrl!.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Adv. $lawyerName",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onBackground),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.gold, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(lawyer.specialization, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 14),
                          const SizedBox(width: 2),
                          Text("${lawyer.rating} (${lawyer.totalReviews} Reviews)", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.navyBlueLight,
                    backgroundImage: authState.userPhotoUrl != null && authState.userPhotoUrl!.isNotEmpty
                        ? NetworkImage(authState.userPhotoUrl!)
                        : null,
                    child: (authState.userPhotoUrl == null || authState.userPhotoUrl!.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white, size: 28)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Adv. $lawyerName", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onBackground)),
                    const Text("Legal Practitioner", style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Premium Plan Box (Redesigned - Clean & Elegant)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFD4AF37).withOpacity(0.15),
                  const Color(0xFFE5A63F).withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Premium Plan",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Unlock priority case matching, AI legal tools, premium visibility, and exclusive professional features.",
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => context.push('/subscription-plans'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    foregroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(90, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text("View Plan", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Today's Overview
          Text(
            "Today's Overview",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onBackground),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Column(
              children: [
                _buildOverviewRow(
                  icon: Icons.gavel_outlined,
                  title: "New Case Requests",
                  subtitle: "Awaiting response",
                  provider: newCaseRequestsCountProvider,
                ),
                const Divider(height: 1, indent: 50, endIndent: 16, color: Colors.white10),
                _buildOverviewRow(
                  icon: Icons.chat_bubble_outline,
                  title: "Unread Messages",
                  subtitle: "From active clients",
                  provider: unreadMessagesCountProvider,
                ),
                const Divider(height: 1, indent: 50, endIndent: 16, color: Colors.white10),
                _buildOverviewRow(
                  icon: Icons.calendar_today_outlined,
                  title: "Today's Consultations",
                  subtitle: "Scheduled for today",
                  provider: todayConsultationsCountProvider,
                ),
                const Divider(height: 1, indent: 50, endIndent: 16, color: Colors.white10),
                _buildOverviewRow(
                  icon: Icons.scale_outlined,
                  title: "Today's Hearings",
                  subtitle: "Court hearings schedule",
                  provider: todayHearingsCountProvider,
                ),
                const Divider(height: 1, indent: 50, endIndent: 16, color: Colors.white10),
                _buildOverviewRow(
                  icon: Icons.description_outlined,
                  title: "Pending Document Reviews",
                  subtitle: "Docs waiting for review",
                  provider: pendingDocumentReviewsCountProvider,
                ),
                const Divider(height: 1, indent: 50, endIndent: 16, color: Colors.white10),
                _buildOverviewRow(
                  icon: Icons.notifications_none_outlined,
                  title: "Pending Client Responses",
                  subtitle: "Waiting for lawyer action",
                  provider: pendingClientResponsesCountProvider,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required ProviderBase<AsyncValue<int>> provider,
  }) {
    return Consumer(
      builder: (context, ref, child) {
        final countState = ref.watch(provider);
        return countState.when(
          data: (count) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.gold.withOpacity(0.1),
                child: Icon(icon, color: AppColors.gold, size: 16),
              ),
              title: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onBackground),
              ),
              subtitle: Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
              ),
              trailing: Text(
                count.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.gold,
                ),
              ),
            );
          },
          loading: () => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.gold.withOpacity(0.05),
              child: const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
              ),
            ),
            title: const Text("Loading...", style: TextStyle(fontSize: 13, color: AppColors.textSecondaryDark)),
            subtitle: const Text("Fetching...", style: TextStyle(fontSize: 10, color: AppColors.textSecondaryDark)),
          ),
          error: (err, stack) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.red.withOpacity(0.1),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 16),
            ),
            title: Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
            subtitle: const Text("Error loading", style: TextStyle(fontSize: 10, color: Colors.red)),
            trailing: const Text(
              "00",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondaryDark),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. LEADS TAB (Figma Screen 2)
  // ═══════════════════════════════════════════════════════════
  Widget _buildLeadsTab(
    AsyncValue<List<CaseModel>> casesState,
    String currentUserId,
  ) {

    return casesState.when(
      data: (cases) {
        final filteredLeads = cases.where((c) {
          return c.selectedLawyerId == currentUserId &&
              (c.status == 'Pending Lawyer Response' || c.status == 'Awaiting Lawyer Acceptance');
        }).toList();

        return Column(
          children: [
            Expanded(
              child: filteredLeads.isEmpty
                  ? const Center(
                      child: Text(
                        "No new case leads. Check back later!",
                        style: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredLeads.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final lead = filteredLeads[index];
                        return _buildFigmaLeadCard(lead);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildLeadsSubTab(int index, String label, String count) {
    final isSelected = _selectedLeadsTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedLeadsTab = index),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.gold : AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold.withOpacity(0.15) : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.gold : AppColors.textSecondaryDark,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 70,
            color: isSelected ? AppColors.gold : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaLeadCard(CaseModel lead) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(lead.category, style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("95% Match", style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(lead.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onBackground)),
                ),
                if (lead.clientVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: Colors.blue, size: 16),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lead.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(lead.location, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.gavel_outlined, size: 14, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Text(lead.preferredCourt?.isNotEmpty == true ? lead.preferredCourt! : "Any Court", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_outlined, size: 14, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Text("Urgency: ${lead.urgency}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
                const SizedBox(width: 16),
                const Icon(Icons.file_present_outlined, size: 14, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Text("${lead.documents.length} docs uploaded", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Posted on: ${DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt)}",
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showLeadDetailsDialog(lead),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      side: const BorderSide(color: AppColors.gold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("View Case Details", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Theme.of(context).cardColor,
                          title: const Text("Accept Case Request?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: const Text("Are you sure you want to accept this case request?", style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Accept", style: TextStyle(color: AppColors.gold)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final success = await ref.read(casesProvider.notifier).acceptCaseRequest(lead.id);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Case request accepted! Case is now Accepted.")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Accept Case", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 3. CLIENTS TAB (Figma Screen 7)
  // ═══════════════════════════════════════════════════════════
  Widget _buildClientsTab(
    AsyncValue<List<CaseModel>> casesState,
    AsyncValue<List<AppointmentModel>> appointmentsState,
    String currentUserId,
  ) {

    return casesState.when(
      data: (cases) {
        final activeCasesList = cases.where((c) => 
          c.assignedLawyerId == currentUserId && c.status == 'Accepted'
        ).toList();

        final inProgressCasesList = cases.where((c) => 
          c.assignedLawyerId == currentUserId && c.status == 'In Progress'
        ).toList();

        final completedCasesList = cases.where((c) => 
          c.assignedLawyerId == currentUserId && (c.status == 'Completed' || c.status == 'resolved' || c.status == 'Closed')
        ).toList();

        final activeCount = activeCasesList.length;
        final inProgressCount = inProgressCasesList.length;
        final completedCount = completedCasesList.length;

        return Column(
          children: [
            // Sub-tabs row
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildClientsSubTab(0, "Active", "$activeCount"),
                  _buildClientsSubTab(1, "In Progress", "$inProgressCount"),
                  _buildClientsSubTab(2, "Completed", "$completedCount"),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _buildClientsTabContent(
                activeCasesList,
                inProgressCasesList,
                completedCasesList,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildClientsTabContent(
    List<CaseModel> activeCases,
    List<CaseModel> inProgressCases,
    List<CaseModel> completedCases,
  ) {
    if (_selectedClientsTab == 0) {
      if (activeCases.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: AppColors.textSecondaryDark),
                SizedBox(height: 12),
                Text(
                  "No accepted clients yet.",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  "Accept a case request from My Leads to start building your client list.",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: activeCases.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final clientCase = activeCases[index];
          return Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.navyBlueLight,
                        backgroundImage: clientCase.clientImage.isNotEmpty
                            ? NetworkImage(clientCase.clientImage)
                            : null,
                        child: clientCase.clientImage.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientCase.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text("ID: ${clientCase.id.length > 8 ? clientCase.id.substring(clientCase.id.length - 8) : clientCase.id}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text("Accepted", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Category: ${clientCase.category}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.title_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text("Title: ${clientCase.title}", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text("Location: ${clientCase.location}", style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.gavel_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Court: ${clientCase.preferredCourt?.isNotEmpty == true ? clientCase.preferredCourt! : 'Any Court'}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Accepted: ${clientCase.acceptedAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(clientCase.acceptedAt!) : DateFormat('dd MMM yyyy, hh:mm a').format(clientCase.createdAt)}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showLeadDetailsDialog(clientCase),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 36),
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("View Client", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await ref.read(casesProvider.notifier).startCase(clientCase.id);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Case work started!")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Start Case", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else if (_selectedClientsTab == 1) {
      if (inProgressCases.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_history_outlined, size: 48, color: AppColors.textSecondaryDark),
                SizedBox(height: 12),
                Text(
                  "No active cases in progress.",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  "Start working on an accepted client case to see it here.",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: inProgressCases.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final clientCase = inProgressCases[index];
          return Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.navyBlueLight,
                        backgroundImage: clientCase.clientImage.isNotEmpty
                            ? NetworkImage(clientCase.clientImage)
                            : null,
                        child: clientCase.clientImage.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientCase.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text("Case: ${clientCase.title}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text("In Progress", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Category: ${clientCase.category}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.update_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Last Updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(clientCase.createdAt)}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  if (clientCase.nextHearing != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.gavel_outlined, size: 14, color: AppColors.textSecondaryDark),
                        const SizedBox(width: 6),
                        Text("Next Hearing: ${DateFormat('dd MMM yyyy').format(clientCase.nextHearing!)}", style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.checklist_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      const Text("Tasks: 2 tasks remaining", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showLeadDetailsDialog(clientCase),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("View Case", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            context.push('/chat/chat_${clientCase.id}/${clientCase.clientName}');
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Chat", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Calling ${clientCase.clientName}... (Simulated)")),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Call", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Theme.of(context).cardColor,
                          title: const Text("Complete Case?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: const Text("Are you sure you want to mark this case as completed?", style: TextStyle(color: Colors.white70)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Complete", style: TextStyle(color: AppColors.gold))),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final success = await ref.read(casesProvider.notifier).markCaseCompleted(clientCase.id);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Case marked completed successfully!")),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Mark Case Completed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      if (completedCases.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_outlined, size: 48, color: AppColors.textSecondaryDark),
                SizedBox(height: 12),
                Text(
                  "No completed cases yet.",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  "Completed client cases will appear here for future reference.",
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: completedCases.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final clientCase = completedCases[index];
          return Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.navyBlueLight,
                        backgroundImage: clientCase.clientImage.isNotEmpty
                            ? NetworkImage(clientCase.clientImage)
                            : null,
                        child: clientCase.clientImage.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientCase.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text("Case: ${clientCase.title}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: const Text("Completed", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Category: ${clientCase.category}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.gavel_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Court: ${clientCase.preferredCourt?.isNotEmpty == true ? clientCase.preferredCourt! : 'Any Court'}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondaryDark),
                      const SizedBox(width: 6),
                      Text("Completed Date: ${clientCase.completedAt != null ? DateFormat('dd MMM yyyy').format(clientCase.completedAt!) : DateFormat('dd MMM yyyy').format(clientCase.createdAt)}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showLeadDetailsDialog(clientCase),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 36),
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("View Case Summary", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showLeadDetailsDialog(clientCase),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 36),
                            side: const BorderSide(color: AppColors.gold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("View Documents", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildClientsSubTab(int index, String label, String count) {
    final isSelected = _selectedClientsTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedClientsTab = index),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.gold : AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.gold.withOpacity(0.15) : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.gold : AppColors.textSecondaryDark,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 70,
            color: isSelected ? AppColors.gold : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 4. CALENDAR TAB (Figma Screen 8)
  // ═══════════════════════════════════════════════════════════
  Widget _buildCalendarTab(
    String userId,
    AsyncValue<List<AppointmentModel>> appointmentsState,
  ) {

    final year = _focusedCalendarMonth.year;
    final month = _focusedCalendarMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekdayOffset = DateTime(year, month, 1).weekday % 7;
    final totalSlots = firstWeekdayOffset + daysInMonth;
    final totalRows = (totalSlots / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build grid rows
    final List<TableRow> gridRows = [];

    // Weekdays header
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    gridRows.add(
      TableRow(
        children: weekdays.map((label) {
          return SizedBox(
            height: 32,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // Get appointment days for events dot
    final appointmentDays = <int>{};
    appointmentsState.whenData((appointments) {
      for (final appt in appointments) {
        if (appt.lawyerId == userId &&
            appt.date.month == month &&
            appt.date.year == year &&
            appt.status != 'cancelled') {
          appointmentDays.add(appt.date.day);
        }
      }
    });

    for (int row = 0; row < totalRows; row++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        final index = row * 7 + col;
        if (index < firstWeekdayOffset || index >= totalSlots) {
          cells.add(const SizedBox(height: 48));
        } else {
          final dayNum = index - firstWeekdayOffset + 1;
          final cellDate = DateTime(year, month, dayNum);

          final isSelected = _selectedCalendarDate.day == dayNum &&
              _selectedCalendarDate.month == month &&
              _selectedCalendarDate.year == year;

          final isToday = cellDate.isAtSameMomentAs(today);
          final hasEvents = appointmentDays.contains(dayNum);

          cells.add(
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCalendarDate = cellDate;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.gold : Colors.transparent,
                        border: isSelected
                            ? Border.all(color: AppColors.gold, width: 2.5)
                            : (isToday ? Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.5) : null),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.black
                              : Theme.of(context).colorScheme.onBackground,
                          height: 1.0,
                        ),
                      ),
                    ),
                    if (hasEvents) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
      }
      gridRows.add(TableRow(children: cells));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar Grid Card
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered month navigator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _focusedCalendarMonth = DateTime(
                            _focusedCalendarMonth.year,
                            _focusedCalendarMonth.month - 1,
                            1,
                          );
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onBackground, size: 24),
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_focusedCalendarMonth),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _focusedCalendarMonth = DateTime(
                            _focusedCalendarMonth.year,
                            _focusedCalendarMonth.month + 1,
                            1,
                          );
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onBackground, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Table(
                  defaultColumnWidth: const FlexColumnWidth(1),
                  children: gridRows,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Title Section: Appointments
          Text(
            'Appointments',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 12),

          // Dynamic list container matching design
          appointmentsState.when(
            data: (appointments) {
              final dailyAppts = appointments.where((appt) {
                if (appt.lawyerId != userId) return false;
                final apptDate = DateTime(appt.date.year, appt.date.month, appt.date.day);
                return (apptDate.isAtSameMomentAs(_selectedCalendarDate) || apptDate.isAfter(_selectedCalendarDate)) &&
                    appt.status != 'cancelled';
              }).toList();

              // Sort
              dailyAppts.sort((a, b) {
                final dateCompare = a.date.compareTo(b.date);
                if (dateCompare != 0) return dateCompare;
                return a.timeSlot.compareTo(b.timeSlot);
              });

              if (dailyAppts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: const Center(
                    child: Text(
                      'No upcoming appointments scheduled.',
                      style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dailyAppts.length,
                  separatorBuilder: (context, index) => Divider(color: Theme.of(context).dividerColor, height: 20),
                  itemBuilder: (context, index) {
                    final appt = dailyAppts[index];

                    String dateBadge = "";
                    final todayVal = DateTime(now.year, now.month, now.day);
                    final apptDayVal = DateTime(appt.date.year, appt.date.month, appt.date.day);

                    if (apptDayVal.isAtSameMomentAs(todayVal)) {
                      dateBadge = "Today";
                    } else {
                      dateBadge = DateFormat('d MMM').format(appt.date);
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time
                          SizedBox(
                            width: 80,
                            child: Text(
                              appt.timeSlot,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appt.clientName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onBackground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  appt.caseTitle ?? (appt.mode.toLowerCase().contains("video") ? "Video Consultation" : "Voice Consultation"),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Date Badge
                          Text(
                            dateBadge,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error: $err")),
          ),
        ],
      ),
    );
  }

  void _showAddAppointmentDialog() {
    final currentUserId = ref.read(authProvider).userId ?? "";
    final cases = ref.read(casesProvider).value ?? [];
    final activeCases = cases.where((c) => c.assignedLawyerId == currentUserId).toList();

    // Get unique active clients list
    final List<Map<String, String>> clients = [];
    final Set<String> seen = {};
    for (final c in activeCases) {
      if (c.clientId.isNotEmpty && !seen.contains(c.clientId)) {
        seen.add(c.clientId);
        clients.add({
          "id": c.clientId,
          "name": c.clientName,
        });
      }
    }

    String selectedClientId = clients.isNotEmpty ? clients.first['id']! : "";
    final TextEditingController nameTextController = TextEditingController();

    DateTime selectedDate = _selectedCalendarDate;
    String selectedTimeSlot = "11:00 AM";
    String selectedMode = "Video Call";
    bool isSaving = false;

    final List<String> timeSlots = [
      '09:00 AM',
      '11:00 AM',
      '01:00 PM',
      '03:00 PM',
      '05:00 PM',
      '07:00 PM',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Add Appointment",
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Client selection
                    if (clients.isNotEmpty) ...[
                      const Text("Select Client", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selectedClientId,
                        dropdownColor: Theme.of(context).cardColor,
                        iconEnabledColor: AppColors.gold,
                        selectedItemBuilder: (BuildContext context) {
                          return clients.map((c) {
                            return Text(
                              c['name']!,
                              style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 13),
                            );
                          }).toList();
                        },
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: clients.map((c) {
                          return DropdownMenuItem<String>(
                            value: c['id'],
                            child: Text(c['name']!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedClientId = val!);
                        },
                      ),
                    ] else ...[
                      const Text("Client Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryDark)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameTextController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Enter client name",
                          hintStyle: TextStyle(color: AppColors.textSecondaryDark.withOpacity(0.5), fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Date Selection
                    const Text("Appointment Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryDark)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(4),
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd MMM yyyy').format(selectedDate), style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.gold),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time Slot Selection
                    const Text("Select Time Slot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryDark)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedTimeSlot,
                      dropdownColor: Theme.of(context).cardColor,
                      iconEnabledColor: AppColors.gold,
                      selectedItemBuilder: (BuildContext context) {
                        return timeSlots.map((String slot) {
                          return Text(
                            slot,
                            style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 13),
                          );
                        }).toList();
                      },
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: timeSlots.map((slot) {
                        return DropdownMenuItem<String>(
                          value: slot,
                          child: Text(slot, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedTimeSlot = val!);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mode Selection
                    const Text("Consultation Mode", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryDark)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedMode,
                      dropdownColor: Theme.of(context).cardColor,
                      iconEnabledColor: AppColors.gold,
                      selectedItemBuilder: (BuildContext context) {
                        return ["Video Call", "Audio Call"].map((String mode) {
                          return Text(
                            mode,
                            style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 13),
                          );
                        }).toList();
                      },
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: "Video Call", child: Text("Video Call", style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground))),
                        DropdownMenuItem(value: "Audio Call", child: Text("Audio Call", style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground))),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedMode = val!);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final success = await ref.read(appointmentsProvider.notifier).bookAppointment(
                                lawyerId: currentUserId,
                                clientId: selectedClientId,
                                date: selectedDate,
                                timeSlot: selectedTimeSlot,
                                mode: selectedMode,
                              );
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (success) {
                              ref.invalidate(appointmentsProvider);
                              ref.invalidate(calendarAppointmentsProvider);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Appointment added successfully!")),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Failed to save appointment. Please try again.")),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Notifications",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onBackground),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) {
                      final notificationsState = ref.watch(notificationsProvider);
                      
                      if (notificationsState.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (notificationsState.errorMessage != null) {
                        return Center(child: Text("Error: ${notificationsState.errorMessage}", style: const TextStyle(color: Colors.red)));
                      }

                      final notifications = notificationsState.notifications;
                      if (notifications.isEmpty) {
                        return const Center(
                          child: Text(
                            "No notifications yet.",
                            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) => Divider(color: Theme.of(context).dividerColor),
                        itemBuilder: (context, index) {
                          final notif = notifications[index];
                          IconData icon = Icons.notifications_none_outlined;
                          if (notif.type == "appointment_requested" || notif.type == "appointment_confirmed" || notif.type == "appointment_cancelled") {
                            icon = Icons.calendar_today_outlined;
                          }
                          if (notif.type == "chat_message") icon = Icons.mail_outline_rounded;
                          if (notif.type == "proposal_received" || notif.type == "proposal_accepted" || notif.type == "proposal_rejected") {
                            icon = Icons.gavel_outlined;
                          }

                          final timeStr = DateFormat('dd MMM, hh:mm a').format(notif.createdAt);
                          return Dismissible(
                            key: Key(notif.id),
                            onDismissed: (_) {
                              ref.read(notificationsProvider.notifier).markAsRead(notif.id);
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.gold.withOpacity(0.1),
                                child: Icon(icon, color: AppColors.gold, size: 20),
                              ),
                              title: Text(
                                notif.title,
                                style: TextStyle(
                                  fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onBackground,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(notif.message, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                                  const SizedBox(height: 4),
                                  Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(IconData icon, String title, String subtitle, String time) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.navyBlue.withOpacity(0.08),
        child: Icon(icon, color: AppColors.navyBlue, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 10, color: AppColors.grey400)),
        ],
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════
  // 6. POPUPS & HELPER DIALOGS (Figma Dialogs)
  // ═══════════════════════════════════════════════════════════
  void _showLeadDetailsDialog(CaseModel lead) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Expanded(
                child: Text(lead.title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground)),
              ),
              if (lead.clientVerified) ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, color: Colors.blue, size: 20),
              ],
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 16, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(lead.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.tag, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text("Case ID: ${lead.id}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text(lead.location, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.gavel_outlined, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text("Preferred Court: ${lead.preferredCourt?.isNotEmpty == true ? lead.preferredCourt! : "Any Court"}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text("Budget: ${lead.budgetRange.isNotEmpty ? lead.budgetRange : "N/A"}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                    const SizedBox(width: 24),
                    const Icon(Icons.access_time_outlined, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text("Urgency: ${lead.urgency}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text("Selected Lawyer: ${lead.selectedLawyerName ?? "Direct Selection"}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 8),
                    Text("Submitted on: ${DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt)}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Case Description:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                const SizedBox(height: 6),
                Text(lead.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                Text("Acknowledgement Documents:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                const SizedBox(height: 8),
                if (lead.documents.isEmpty)
                  const Text("No documents uploaded.", style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark))
                else
                  Column(
                    children: lead.documents.map((doc) {
                      return Card(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Theme.of(context).colorScheme.outline),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.description, color: AppColors.gold, size: 20),
                          title: Text(doc.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          subtitle: Text(doc.size, style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryDark)),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new, color: AppColors.gold, size: 18),
                            onPressed: () async {
                              final String urlStr = doc.url.startsWith("http")
                                  ? doc.url
                                  : "${Environment.baseUrl}${doc.url}";
                              final Uri uri = Uri.parse(urlStr);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Could not open document: $urlStr")),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: AppColors.textSecondaryDark)),
            ),
            if (lead.status == 'Pending Lawyer Response' || lead.status == 'Awaiting Lawyer Acceptance')
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Theme.of(context).cardColor,
                      title: const Text("Accept Case Request?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: const Text("Are you sure you want to accept this case request?", style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Accept", style: TextStyle(color: AppColors.gold)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    final success = await ref.read(casesProvider.notifier).acceptCaseRequest(lead.id);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Case request accepted! Case is now Accepted.")),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text("Accept Case"),
              )
          ],
        );
      },
    );
  }




}

class _ShimmerPulse extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerPulse({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<_ShimmerPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B2C),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class LawyerInsight {
  final String category;
  final String tip;
  // Future personalization parameters
  final List<String>? specializations;
  final int? minExperience;
  final int? minActiveCases;
  final double? minRating;

  const LawyerInsight({
    required this.category,
    required this.tip,
    this.specializations,
    this.minExperience,
    this.minActiveCases,
    this.minRating,
  });
}

class LawyerInsightsService {
  // Static list of premium structured tips
  static const List<LawyerInsight> _tips = [
    // Today's Practice Tip
    LawyerInsight(
      category: "💡 Today's Practice Tip",
      tip: "Respond to new client requests within 10 minutes to significantly improve your chances of being selected.",
    ),
    LawyerInsight(
      category: "💡 Today's Practice Tip",
      tip: "Start your day by reviewing updates on active cases to stay ahead of client expectations.",
    ),
    // Business Growth Tip
    LawyerInsight(
      category: "📈 Business Growth Tip",
      tip: "A complete lawyer profile with experience, languages, and certifications receives more client inquiries.",
    ),
    LawyerInsight(
      category: "📈 Business Growth Tip",
      tip: "Requesting feedback from satisfied clients helps improve your professional rating and visibility.",
    ),
    // Legal Practice Tip
    LawyerInsight(
      category: "⚖️ Legal Practice Tip",
      tip: "Review uploaded documents before the first consultation to provide more accurate legal advice.",
    ),
    LawyerInsight(
      category: "⚖️ Legal Practice Tip",
      tip: "Ensure all regulatory changes are factored into your ongoing active case briefs.",
    ),
    // Client Success Tip
    LawyerInsight(
      category: "⭐ Client Success Tip",
      tip: "Keep clients informed about every milestone to build trust and increase repeat consultations.",
    ),
    LawyerInsight(
      category: "⭐ Client Success Tip",
      tip: "A clear, upfront fee breakdown prevents billing disputes and keeps client trust high.",
    ),
    // Productivity Tip
    LawyerInsight(
      category: "🚀 Productivity Tip",
      tip: "Schedule tomorrow's consultations before ending your workday to reduce missed appointments.",
    ),
    LawyerInsight(
      category: "🚀 Productivity Tip",
      tip: "Allocate a dedicated hour each morning for reviewing active proposals and client bids.",
    ),
    // Case Management Tip
    LawyerInsight(
      category: "📂 Case Management Tip",
      tip: "Update case progress immediately after every consultation for better organization.",
    ),
    LawyerInsight(
      category: "📂 Case Management Tip",
      tip: "Organize all case documents under client folders as soon as they are received.",
    ),
    // Client Communication Tip
    LawyerInsight(
      category: "🤝 Client Communication Tip",
      tip: "Simple explanations create stronger client confidence than complex legal terminology.",
    ),
    LawyerInsight(
      category: "🤝 Client Communication Tip",
      tip: "Confirm key discussion points in writing after every phone call or meeting.",
    ),
    // Compliance Reminder
    LawyerInsight(
      category: "🔒 Compliance Reminder",
      tip: "Ensure all client documents remain confidential and securely stored.",
    ),
    LawyerInsight(
      category: "🔒 Compliance Reminder",
      tip: "Double-check conflict of interest disclosures before accepting any new case bid.",
    ),
    // Court Preparation Tip
    LawyerInsight(
      category: "📅 Court Preparation Tip",
      tip: "Prepare hearing notes and supporting documents one day before court.",
    ),
    LawyerInsight(
      category: "📅 Court Preparation Tip",
      tip: "Perform a final case law search to ensure your arguments align with the latest precedents.",
    ),
    // Practice Management Tip
    LawyerInsight(
      category: "💼 Practice Management Tip",
      tip: "Regularly review pending consultations and proposals to maximize monthly revenue.",
    ),
    LawyerInsight(
      category: "💼 Practice Management Tip",
      tip: "Keep your working hours updated so clients can book convenient slots.",
    ),
  ];

  /// Get random insight with support for future personalization filtering.
  static LawyerInsight getRandomInsight({
    String? currentTipTextToExclude,
    String? specialization,
    int? experience,
    int? activeCases,
    double? rating,
  }) {
    // 1. Filter based on target attributes (architecture is ready for personalization)
    List<LawyerInsight> filtered = _tips.where((item) {
      if (specialization != null && item.specializations != null) {
        if (!item.specializations!.contains(specialization)) return false;
      }
      if (experience != null && item.minExperience != null) {
        if (experience < item.minExperience!) return false;
      }
      if (rating != null && item.minRating != null) {
        if (rating < item.minRating!) return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      filtered = List.from(_tips);
    }

    // 2. Exclude current tip if possible to avoid consecutive repeats
    if (filtered.length > 1 && currentTipTextToExclude != null) {
      filtered.removeWhere((item) => item.tip == currentTipTextToExclude);
    }

    // 3. Select random
    final rand = math.Random();
    return filtered[rand.nextInt(filtered.length)];
  }
}


