import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/appointment_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/case_model.dart';
import '../../../../models/lawyer_model.dart';

class LawyerDashboardScreen extends ConsumerStatefulWidget {
  const LawyerDashboardScreen({super.key});

  @override
  ConsumerState<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends ConsumerState<LawyerDashboardScreen> {
  int _currentIndex = 0;
  final Set<String> _dismissedLeads = {};

  // Form State for Editing Profile
  bool _isEditingProfile = false;
  bool _isSavingProfile = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _specController;
  late TextEditingController _expController;
  late TextEditingController _feeController;
  late TextEditingController _bioController;
  late TextEditingController _barController;
  late TextEditingController _eduController;

  // Selected sub-tabs
  int _selectedLeadsTab = 0; // 0: New Leads, 1: In Progress, 2: Interested
  int _selectedClientsTab = 0; // 0: Active, 1: Consultations, 2: Completed

  // Selected date in calendar tab
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _specController = TextEditingController();
    _expController = TextEditingController();
    _feeController = TextEditingController();
    _bioController = TextEditingController();
    _barController = TextEditingController();
    _eduController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _specController.dispose();
    _expController.dispose();
    _feeController.dispose();
    _bioController.dispose();
    _barController.dispose();
    _eduController.dispose();
    super.dispose();
  }

  Future<void> _saveLawyerChanges(String userId) async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final spec = _specController.text.trim();
    final exp = int.tryParse(_expController.text.trim()) ?? 0;
    final fee = int.tryParse(_feeController.text.trim()) ?? 0;
    final bio = _bioController.text.trim();
    final bar = _barController.text.trim();
    final edu = _eduController.text.trim();

    if (name.isEmpty || phone.isEmpty || spec.isEmpty || bar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, phone, specialization, and Bar ID cannot be empty.")),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    final successAuth = await ref.read(authProvider.notifier).updateUserProfile(name: name, mobile: phone);
    final successLawyer = await ref.read(lawyerProfileUpdaterProvider).updateProfile(
          specialization: spec,
          experience: exp,
          education: edu,
          barCouncilNumber: bar,
          consultationFee: fee,
          bio: bio,
        );

    if (mounted) {
      setState(() {
        _isSavingProfile = false;
        if (successAuth && successLawyer) {
          _isEditingProfile = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((successAuth && successLawyer) ? "Profile updated successfully!" : "Failed to update profile details."),
          backgroundColor: (successAuth && successLawyer) ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final lawyerName = authState.userName ?? "Rahul Sharma";

    // Set page title dynamically
    String screenTitle = "Workspace Hub";
    if (_currentIndex == 1) screenTitle = "Dashboard";
    if (_currentIndex == 2) screenTitle = "My Leads";
    if (_currentIndex == 3) screenTitle = "My Clients";
    if (_currentIndex == 4) screenTitle = "Calendar";
    if (_currentIndex == 5) screenTitle = "My Profile";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(screenTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navyBlue,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.navyBlue),
          onPressed: () {},
        ),
        actions: [
          if (_currentIndex == 5)
            IconButton(
              icon: Icon(_isEditingProfile ? Icons.close : Icons.edit, color: AppColors.navyBlue),
              onPressed: () {
                setState(() {
                  _isEditingProfile = !_isEditingProfile;
                });
              },
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none_outlined, color: AppColors.navyBlue),
                  onPressed: () {},
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                )
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(lawyerName, authState.userId ?? ""),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            _currentIndex = index;
            _isEditingProfile = false; // Reset edit profile on tab switch
          }),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.navyBlue,
          unselectedItemColor: AppColors.grey400,
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

  Widget _buildBody(String lawyerName, String userId) {
    switch (_currentIndex) {
      case 0:
        return _buildWorkspaceTab(lawyerName, userId);
      case 1:
        return _buildHomeTab(lawyerName, userId);
      case 2:
        return _buildLeadsTab();
      case 3:
        return _buildClientsTab();
      case 4:
        return _buildCalendarTab(userId);
      case 5:
        return _buildProfileTab(lawyerName, userId);
      default:
        return _buildWorkspaceTab(lawyerName, userId);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 0. LANDED WORKSPACE HERO SCREEN (NEW)
  // ═══════════════════════════════════════════════════════════
  Widget _buildWorkspaceTab(String lawyerName, String userId) {
    final casesState = ref.watch(casesProvider);
    final appointmentsState = ref.watch(appointmentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Header Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyBlue, Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.navyBlue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.balance, color: AppColors.gold, size: 36),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: AppColors.gold, size: 12),
                          SizedBox(width: 4),
                          Text("PRO HUB", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome, Adv. $lawyerName",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Manage client files, review case leads, and track consultation schedules from your centralized workspace.",
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Workspace Tools Title
          const Text(
            "Workspace Tools",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
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
              _buildWorkspaceToolCard(
                icon: Icons.gavel,
                title: "Client Leads",
                subtitle: "View and Bid on Cases",
                badgeCount: casesState.when(
                  data: (cases) => "${cases.where((c) => c.status == 'active').length}",
                  loading: () => "...",
                  error: (e, s) => "0",
                ),
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _buildWorkspaceToolCard(
                icon: Icons.people_alt,
                title: "Clients Folder",
                subtitle: "Manage Active Clients",
                onTap: () => setState(() => _currentIndex = 3),
              ),
              _buildWorkspaceToolCard(
                icon: Icons.calendar_month,
                title: "Practice Calendar",
                subtitle: "Track Consultations",
                badgeCount: appointmentsState.when(
                  data: (appts) => "${appts.where((a) => a.lawyerId == userId).length}",
                  loading: () => "...",
                  error: (e, s) => "0",
                ),
                onTap: () => setState(() => _currentIndex = 4),
              ),
              _buildWorkspaceToolCard(
                icon: Icons.bar_chart,
                title: "Practice Stats",
                subtitle: "Review Revenue & Leads",
                onTap: () => setState(() => _currentIndex = 1),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Daily Growth / Conversion Tip Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.navyBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Practice Growth Tip",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Providing a clear estimate and reference of previous similar cases in your proposal bid increases conversion rate by 80%.",
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grey200),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))
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
                  backgroundColor: AppColors.navyBlue.withOpacity(0.06),
                  child: Icon(icon, color: AppColors.navyBlue, size: 18),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.grey500)),
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
  Widget _buildHomeTab(String lawyerName, String userId) {
    final casesState = ref.watch(casesProvider);
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile row with blue checkmark
          lawyerState.when(
            data: (lawyer) => Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.navyBlue,
                  child: Icon(Icons.person, color: Colors.white, size: 28),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(lawyer.specialization, style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text("${lawyer.rating} (${lawyer.totalReviews} Reviews)", style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
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
                const CircleAvatar(radius: 28, backgroundColor: AppColors.navyBlue, child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Adv. $lawyerName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                    const Text("Legal Practitioner", style: TextStyle(color: AppColors.grey500, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Premium Plan Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navyBlue, Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Premium Plan",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Valid till 25 May 2026",
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: () => context.push('/subscription-plans'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("View Plan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Capsules (Navy style)
          Row(
            children: [
              Expanded(child: _buildHomeStatCard("Leads", "128", AppColors.navyBlue)),
              const SizedBox(width: 8),
              Expanded(child: _buildHomeStatCard("Consults", "42", AppColors.navyBlue)),
              const SizedBox(width: 8),
              Expanded(child: _buildHomeStatCard("Earnings", "₹45,600", AppColors.navyBlue)),
            ],
          ),
          const SizedBox(height: 24),

          // Today's Overview
          const Text("Today's Overview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.grey200),
            ),
            child: casesState.when(
              data: (cases) {
                final activeLeadsCount = cases.where((c) => c.status == 'active' && !_dismissedLeads.contains(c.id)).length;
                return Column(
                  children: [
                    _buildOverviewItem(Icons.gavel_outlined, "New Leads", "$activeLeadsCount"),
                    const Divider(height: 1, indent: 50),
                    _buildOverviewItem(Icons.mail_outline_rounded, "Unread Messages", "5"),
                    const Divider(height: 1, indent: 50),
                    _buildOverviewItem(Icons.phone_in_talk_outlined, "Consultation Requests", "3"),
                    const Divider(height: 1, indent: 50),
                    _buildOverviewItem(Icons.calendar_today_outlined, "Upcoming Appointments", "2"),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, s) => const Center(child: Text("Failed to load overview data")),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions Grid
          const Text("Quick Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickActionItem(Icons.search_rounded, "Browse Leads", () => setState(() => _currentIndex = 2)),
              _buildQuickActionItem(Icons.people_outline, "My Clients", () => setState(() => _currentIndex = 3)),
              _buildQuickActionItem(Icons.calendar_month_outlined, "Calendar", () => setState(() => _currentIndex = 4)),
              _buildQuickActionItem(Icons.wallet_outlined, "Earnings", () => _showEarningsDialog()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(IconData icon, String title, String count) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.navyBlue.withOpacity(0.06),
        child: Icon(icon, color: AppColors.navyBlue, size: 16),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, color: AppColors.navyBlue)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(12)),
        child: Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navyBlue)),
      ),
    );
  }

  Widget _buildQuickActionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.navyBlue.withOpacity(0.08),
            child: Icon(icon, color: AppColors.navyBlue, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.navyBlue)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 2. LEADS TAB (Figma Screen 2)
  // ═══════════════════════════════════════════════════════════
  Widget _buildLeadsTab() {
    final casesState = ref.watch(casesProvider);

    return Column(
      children: [
        // Sub-tabs row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLeadsSubTab(0, "New Leads", "12"),
              _buildLeadsSubTab(1, "In Progress", "8"),
              _buildLeadsSubTab(2, "Interested", "5"),
            ],
          ),
        ),
        const Divider(height: 1),

        // List View
        Expanded(
          child: casesState.when(
            data: (cases) {
              final activeLeads = cases.where((c) => c.status == 'active' && !_dismissedLeads.contains(c.id)).toList();
              if (activeLeads.isEmpty) {
                return const Center(child: Text("No new case leads. Check back later!"));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: activeLeads.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final lead = activeLeads[index];
                  return _buildFigmaLeadCard(lead);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error: $err")),
          ),
        ),
      ],
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
                  color: isSelected ? AppColors.navyBlue : AppColors.grey500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.navyBlue.withOpacity(0.1) : AppColors.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.navyBlue : AppColors.grey500,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 70,
            color: isSelected ? AppColors.navyBlue : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildFigmaLeadCard(CaseModel lead) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.grey200),
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
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Text(lead.category, style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                // Match percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text("95% Match", style: TextStyle(color: AppColors.navyBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(lead.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navyBlue)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.grey400),
                const SizedBox(width: 4),
                Text(lead.location, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                const SizedBox(width: 16),
                const Icon(Icons.currency_rupee, size: 14, color: AppColors.grey400),
                const SizedBox(width: 2),
                Text(lead.budgetRange, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Posted on: ${DateFormat('dd MMM yyyy').format(lead.createdAt)}",
              style: const TextStyle(color: AppColors.grey400, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showLeadDetailsDialog(lead),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                      side: const BorderSide(color: AppColors.navyBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("View Details", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showProposalDialog(lead.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navyBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Send Proposal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
  Widget _buildClientsTab() {
    final appointmentsState = ref.watch(appointmentsProvider);
    final currentUserId = ref.watch(authProvider).userId ?? "";

    return Column(
      children: [
        // Sub-tabs row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildClientsSubTab(0, "Active", "18"),
              _buildClientsSubTab(1, "Consultations", "24"),
              _buildClientsSubTab(2, "Completed", "32"),
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: appointmentsState.when(
            data: (appointments) {
              final lawyerAppts = appointments.where((a) => a.lawyerId == currentUserId).toList();
              if (lawyerAppts.isEmpty) {
                return const Center(child: Text("No clients recorded dynamically yet. Book an appointment first!"));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lawyerAppts.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final appt = lawyerAppts[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.grey200),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.navyBlue,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(appt.clientName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 15)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(appt.caseTitle ?? appt.mode, style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            "Next Appointment: ${DateFormat('dd MMM yyyy, hh:mm a').format(appt.date)}",
                            style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                          ),
                        ],
                      ),
                      trailing: OutlinedButton(
                        onPressed: () {
                          // Navigate to Chat Screen
                          context.push('/chat/chat_${appt.id}/${appt.clientName}');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.navyBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(60, 36),
                        ),
                        child: const Text("Chat", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error loading clients: $err")),
          ),
        ),
      ],
    );
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
                  color: isSelected ? AppColors.navyBlue : AppColors.grey500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.navyBlue.withOpacity(0.1) : AppColors.grey100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.navyBlue : AppColors.grey500,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 70,
            color: isSelected ? AppColors.navyBlue : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 4. CALENDAR TAB (Figma Screen 8)
  // ═══════════════════════════════════════════════════════════
  Widget _buildCalendarTab(String userId) {
    final appointmentsState = ref.watch(appointmentsProvider);

    return Column(
      children: [
        // Small horizontal calendar strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = DateTime.now().add(Duration(days: index - 3));
              final isSelected = date.day == _selectedCalendarDate.day && date.month == _selectedCalendarDate.month;
              return GestureDetector(
                onTap: () => setState(() => _selectedCalendarDate = date),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.navyBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(date)[0],
                        style: TextStyle(color: isSelected ? Colors.white70 : AppColors.grey400, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${date.day}",
                        style: TextStyle(color: isSelected ? Colors.white : AppColors.navyBlue, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const Divider(height: 1),

        // List of appointments for selected date
        Expanded(
          child: appointmentsState.when(
            data: (appointments) {
              final lawyerAppts = appointments.where((a) => a.lawyerId == userId).toList();
              if (lawyerAppts.isEmpty) {
                return const Center(child: Text("No appointments scheduled."));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lawyerAppts.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final appt = lawyerAppts[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.grey200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              DateFormat('hh:mm\na').format(appt.date),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(appt.clientName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(appt.caseTitle ?? appt.mode, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error: $err")),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 5. PROFILE TAB (Figma Screen 6)
  // ═══════════════════════════════════════════════════════════
  Widget _buildProfileTab(String lawyerName, String userId) {
    final authState = ref.watch(authProvider);
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));

    return lawyerState.when(
      data: (lawyer) {
        if (!_isEditingProfile) {
          _nameController.text = lawyerName;
          _phoneController.text = authState.userMobile ?? "";
          _specController.text = lawyer.specialization;
          _expController.text = "${lawyer.experience}";
          _feeController.text = "${lawyer.consultationFee}";
          _bioController.text = lawyer.bio;
          _barController.text = lawyer.barCouncilNumber;
          _eduController.text = lawyer.education;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Name Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey200),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: AppColors.navyBlue,
                      child: Icon(Icons.person, color: Colors.white, size: 35),
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditingProfile) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Adv. $lawyerName",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("${lawyer.specialization} • ${lawyer.experience}+ Years Exp", style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                      const SizedBox(height: 4),
                      const Text("Hyderabad, Telangana", style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text("${lawyer.rating} (${lawyer.totalReviews} Reviews)", style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                        ],
                      ),
                    ] else ...[
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: "Full Name", prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _specController,
                        decoration: const InputDecoration(labelText: "Specialization", prefixIcon: Icon(Icons.gavel), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _expController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Experience (Years)", prefixIcon: Icon(Icons.work), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _feeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Consultation Fee (₹)", prefixIcon: Icon(Icons.payments), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _barController,
                        decoration: const InputDecoration(labelText: "Bar Council ID", prefixIcon: Icon(Icons.badge), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _eduController,
                        decoration: const InputDecoration(labelText: "Qualification (Education)", prefixIcon: Icon(Icons.school), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: "Bio / Profile Summary", border: OutlineInputBorder()),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (!_isEditingProfile) ...[
                // About Me Section
                const Text("About Me", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                const SizedBox(height: 8),
                Text(
                  lawyer.bio.isNotEmpty ? lawyer.bio : "Provide a summary bio in edit mode.",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Expertise Chips
                const Text("Expertise", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildExpertiseChip("Bail Matters"),
                    _buildExpertiseChip("Civil Defense"),
                    _buildExpertiseChip("Property disputes"),
                    _buildExpertiseChip("Family Law"),
                  ],
                ),
                const SizedBox(height: 20),

                // Education block
                const Text("Education", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                const SizedBox(height: 8),
                Text(
                  lawyer.education.isNotEmpty ? lawyer.education : "Provide qualifications in edit mode.",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 24),

                // Log Out Button
                ElevatedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                // Save Changes & Cancel Buttons
                ElevatedButton(
                  onPressed: _isSavingProfile ? null : () => _saveLawyerChanges(userId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.navyBlue,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSavingProfile
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.navyBlue, strokeWidth: 2))
                      : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _isEditingProfile = false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    side: const BorderSide(color: AppColors.navyBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Failed to load profile details dynamically: $err", textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(lawyerDetailsProvider(userId)),
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpertiseChip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.navyBlue)),
      backgroundColor: AppColors.navyBlue.withOpacity(0.06),
      side: BorderSide.none,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(lead.title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.grey500),
                    const SizedBox(width: 4),
                    Text(lead.location, style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 14, color: AppColors.grey500),
                    const SizedBox(width: 4),
                    Text(lead.budgetRange, style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Client Requirements:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                const SizedBox(height: 6),
                Text(lead.description, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showProposalDialog(lead.id);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, foregroundColor: Colors.white),
              child: const Text("Send Proposal"),
            )
          ],
        );
      },
    );
  }

  void _showProposalDialog(String caseId) {
    final feeController = TextEditingController(text: "1500");
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Send Proposal", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Consultation Fee Bid (₹)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Your Message/Introduction",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final fee = double.tryParse(feeController.text) ?? 1500;
                final message = messageController.text.trim();
                final currentUserId = ref.read(authProvider).userId ?? "";

                if (message.isNotEmpty) {
                  final success = await ref.read(casesProvider.notifier).submitProposal(
                        caseId: caseId,
                        lawyerId: currentUserId,
                        message: message,
                        fee: fee,
                      );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? "Proposal submitted successfully!" : "Failed to send proposal."),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, foregroundColor: Colors.white),
              child: const Text("Submit Quote"),
            ),
          ],
        );
      },
    );
  }

  void _showEarningsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Earnings Details", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Total Earnings", style: TextStyle(fontSize: 12, color: AppColors.grey500)),
              const SizedBox(height: 4),
              const Text("₹45,600", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navyBlue)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Consultations", style: TextStyle(fontSize: 13)),
                  Text("₹32,000", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("Other Earnings", style: TextStyle(fontSize: 13)),
                  Text("₹13,600", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ],
        );
      },
    );
  }
}
