import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

class LawyerDashboardScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const LawyerDashboardScreen({super.key, this.initialTab = 0});

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
  late TextEditingController _locationController;
  late TextEditingController _officeAddressController;
  late TextEditingController _upiIdController;
  late TextEditingController _workingHoursController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountNoController;
  late TextEditingController _bankIFSCController;
  late TextEditingController _bankHolderController;

  // Selected sub-tabs
  int _selectedLeadsTab = 0; // 0: New Leads, 1: In Progress, 2: Interested
  int _selectedClientsTab = 0; // 0: Active, 1: Consultations, 2: Completed

  // Selected date in calendar tab
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _focusedCalendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late ScrollController _calendarScrollController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _calendarScrollController = ScrollController();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _specController = TextEditingController();
    _expController = TextEditingController();
    _feeController = TextEditingController();
    _bioController = TextEditingController();
    _barController = TextEditingController();
    _eduController = TextEditingController();
    _locationController = TextEditingController();
    _officeAddressController = TextEditingController();
    _upiIdController = TextEditingController();
    _workingHoursController = TextEditingController();
    _bankNameController = TextEditingController();
    _bankAccountNoController = TextEditingController();
    _bankIFSCController = TextEditingController();
    _bankHolderController = TextEditingController();
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

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      
      setState(() => _isSavingProfile = true);

      final success = await ref.read(authProvider.notifier).updateProfileImage(bytes, image.name);

      setState(() {
        _isSavingProfile = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Profile image updated successfully!" : "Failed to upload profile image."),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error selecting image: $e")),
      );
    }
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
    _locationController.dispose();
    _officeAddressController.dispose();
    _upiIdController.dispose();
    _workingHoursController.dispose();
    _bankNameController.dispose();
    _bankAccountNoController.dispose();
    _bankIFSCController.dispose();
    _bankHolderController.dispose();
    _calendarScrollController.dispose();
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
    final location = _locationController.text.trim();

    if (name.isEmpty || phone.isEmpty || spec.isEmpty || bar.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, phone, location, specialization, and Bar ID cannot be empty.")),
      );
      return;
    }

    setState(() => _isSavingProfile = true);

    final successAuth = await ref.read(authProvider.notifier).updateUserProfile(name: name, mobile: phone, location: location);
    final successLawyer = await ref.read(lawyerProfileUpdaterProvider).updateProfile(
          specialization: spec,
          experience: exp,
          education: edu,
          barCouncilNumber: bar,
          consultationFee: fee,
          bio: bio,
          officeAddress: _officeAddressController.text.trim(),
          upiId: _upiIdController.text.trim(),
          workingHours: _workingHoursController.text.trim(),
          bankDetails: {
            "bankName": _bankNameController.text.trim(),
            "accountNumber": _bankAccountNoController.text.trim(),
            "ifscCode": _bankIFSCController.text.trim(),
            "accountHolderName": _bankHolderController.text.trim(),
          },
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
    final lawyerName = authState.userName ?? "Rahul Sharma";
    final userId = authState.userId ?? "";

    // Watch all providers at the top level to avoid conditional watcher assertion violations
    final casesState = ref.watch(casesProvider);
    final appointmentsState = ref.watch(appointmentsProvider);
    final chatsState = ref.watch(chatsProvider);
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));

    // Set page title dynamically
    String screenTitle = "Workspace Hub";
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
          if (_currentIndex == 5)
            IconButton(
              icon: Icon(_isEditingProfile ? Icons.close : Icons.edit, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () {
                setState(() {
                  _isEditingProfile = !_isEditingProfile;
                });
              },
            )
          else if (_currentIndex == 4)
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
            _isEditingProfile = false; // Reset edit profile on tab switch
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
        return _buildWorkspaceTab(lawyerName, userId, casesState, appointmentsState);
      case 1:
        return _buildHomeTab(lawyerName, userId, casesState, appointmentsState, chatsState, lawyerState);
      case 2:
        return _buildLeadsTab(casesState, userId);
      case 3:
        return _buildClientsTab(casesState, appointmentsState, userId);
      case 4:
        return _buildCalendarTab(userId, appointmentsState);
      case 5:
        return _buildProfileTab(lawyerName, userId, lawyerState);
      default:
        return _buildWorkspaceTab(lawyerName, userId, casesState, appointmentsState);
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
  ) {

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
                colors: AppColors.darkGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
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
                        color: Colors.white12,
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
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.gold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Practice Growth Tip",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Providing a clear estimate and reference of previous similar cases in your proposal bid increases conversion rate by 80%.",
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondaryDark, height: 1.4),
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

          // Premium Plan Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.darkGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Premium Plan",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                    side: const BorderSide(color: AppColors.gold),
                    foregroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(100, 36),
                  ),
                  child: const Text("View Plan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Capsules (Gold style)
          casesState.maybeWhen(
            data: (cases) => appointmentsState.maybeWhen(
              data: (appointments) {
                final totalBids = cases.where((c) => 
                  c.proposals.any((p) => p.lawyerId == userId)
                ).length;

                final totalConsults = appointments.where((a) => 
                  a.lawyerId == userId
                ).length;

                final completedConsults = appointments.where((a) => 
                  a.lawyerId == userId && a.status == 'completed'
                ).length;

                final fee = lawyerState.maybeWhen(
                  data: (lawyer) => lawyer.consultationFee,
                  orElse: () => 1500,
                );
                final totalEarnings = completedConsults * fee;

                return Row(
                  children: [
                    Expanded(child: _buildHomeStatCard("Leads Bid", "$totalBids", Theme.of(context).cardColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHomeStatCard("Consults", "$totalConsults", Theme.of(context).cardColor)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHomeStatCard("Earnings", "₹$totalEarnings", Theme.of(context).cardColor)),
                  ],
                );
              },
              orElse: () => const SizedBox(),
            ),
            orElse: () => const SizedBox(),
          ),
          const SizedBox(height: 24),

          // Today's Overview
          Text(
            "Today's Overview",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onBackground),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: casesState.when(
              data: (cases) {
                return appointmentsState.when(
                  data: (appointments) {
                    final activeLeadsCount = cases.where((c) => 
                      c.status == 'active' && 
                      c.assignedLawyerId == null && 
                      !c.proposals.any((p) => p.lawyerId == userId) &&
                      !_dismissedLeads.contains(c.id)
                    ).length;

                    final pendingAppts = appointments.where((a) => 
                      a.lawyerId == userId && a.status == 'pending'
                    ).length;

                    final upcomingAppts = appointments.where((a) => 
                      a.lawyerId == userId && a.date.isAfter(DateTime.now().subtract(const Duration(hours: 2)))
                    ).length;

                    final chatCount = chatsState.maybeWhen(
                      data: (chats) => chats.length,
                      orElse: () => 0,
                    );

                    return Column(
                      children: [
                        _buildOverviewItem(Icons.gavel_outlined, "New Leads", "$activeLeadsCount"),
                        const Divider(height: 1, indent: 50),
                        _buildOverviewItem(Icons.mail_outline_rounded, "Unread Messages", "$chatCount"),
                        const Divider(height: 1, indent: 50),
                        _buildOverviewItem(Icons.phone_in_talk_outlined, "Consultation Requests", "$pendingAppts"),
                        const Divider(height: 1, indent: 50),
                        _buildOverviewItem(Icons.calendar_today_outlined, "Upcoming Appointments", "$upcomingAppts"),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, s) => const Center(child: Text("Failed to load appointments")),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, s) => const Center(child: Text("Failed to load overview data")),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions Grid
          Text(
            "Quick Actions",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onBackground),
          ),
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
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildOverviewItem(IconData icon, String title, String count) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.gold.withOpacity(0.1),
        child: Icon(icon, color: AppColors.gold, size: 16),
      ),
      title: Text(title, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
        child: Text(count, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gold)),
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
            backgroundColor: AppColors.gold.withOpacity(0.1),
            child: Icon(icon, color: AppColors.gold, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onBackground)),
        ],
      ),
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
        final newLeadsCount = cases.where((c) {
          final isGeneral = (c.status == 'active' || c.status == 'Submitted') &&
              c.assignedLawyerId == null &&
              !c.proposals.any((p) => p.lawyerId == currentUserId) &&
              !_dismissedLeads.contains(c.id);
          final isDirect = c.status == 'Awaiting Lawyer Acceptance' &&
              c.selectedLawyerId == currentUserId;
          return isGeneral || isDirect;
        }).length;
        
        final inProgressCount = cases.where((c) => 
          c.assignedLawyerId == null && 
          c.proposals.any((p) => p.lawyerId == currentUserId)
        ).length;
        
        final interestedCount = cases.where((c) => 
          c.assignedLawyerId == currentUserId
        ).length;

        List<CaseModel> filteredLeads = [];
        if (_selectedLeadsTab == 0) {
          filteredLeads = cases.where((c) {
            final isGeneral = (c.status == 'active' || c.status == 'Submitted') &&
                c.assignedLawyerId == null &&
                !c.proposals.any((p) => p.lawyerId == currentUserId) &&
                !_dismissedLeads.contains(c.id);
            final isDirect = c.status == 'Awaiting Lawyer Acceptance' &&
                c.selectedLawyerId == currentUserId;
            return isGeneral || isDirect;
          }).toList();
        } else if (_selectedLeadsTab == 1) {
          filteredLeads = cases.where((c) => 
            c.assignedLawyerId == null && 
            c.proposals.any((p) => p.lawyerId == currentUserId)
          ).toList();
        } else {
          filteredLeads = cases.where((c) => 
            c.assignedLawyerId == currentUserId
          ).toList();
        }

        return Column(
          children: [
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLeadsSubTab(0, "New Leads", "$newLeadsCount"),
                  _buildLeadsSubTab(1, "In Progress", "$inProgressCount"),
                  _buildLeadsSubTab(2, "Interested", "$interestedCount"),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filteredLeads.isEmpty
                  ? Center(
                      child: Text(
                        _selectedLeadsTab == 0
                            ? "No new case leads. Check back later!"
                            : _selectedLeadsTab == 1
                                ? "No proposals submitted yet."
                                : "No won or interested cases yet.",
                        style: const TextStyle(color: AppColors.textSecondaryDark),
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
                // Match percentage badge
                if (lead.status == 'Awaiting Lawyer Acceptance')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text("Direct Request", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else
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
            Text(lead.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onBackground)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryDark),
                const SizedBox(width: 4),
                Text(lead.location, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                const SizedBox(width: 16),
                const Icon(Icons.currency_rupee, size: 14, color: AppColors.textSecondaryDark),
                const SizedBox(width: 2),
                Text(lead.budgetRange.isNotEmpty ? lead.budgetRange : "N/A", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Posted on: ${DateFormat('dd MMM yyyy').format(lead.createdAt)}",
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (lead.status == 'Awaiting Lawyer Acceptance') ...[
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () => _showLeadDetailsDialog(lead),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        side: const BorderSide(color: AppColors.gold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("View Case", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Reject Request?"),
                            content: const Text("Are you sure you want to reject this direct case request?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Reject", style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final success = await ref.read(casesProvider.notifier).rejectCaseRequest(lead.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Case request rejected.")),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Accept Request?"),
                            content: const Text("Are you sure you want to accept this direct case request?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Accept")),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final success = await ref.read(casesProvider.notifier).acceptCaseRequest(lead.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Case request accepted! Case is now In Progress.")),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ] else ...[
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
                      child: const Text("View Details", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showProposalDialog(lead.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Send Proposal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
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
        return appointmentsState.when(
          data: (appointments) {
            final activeClientsCases = cases.where((c) => 
              c.assignedLawyerId == currentUserId && c.status != 'resolved'
            ).toList();

            final completedCases = cases.where((c) => 
              c.assignedLawyerId == currentUserId && c.status == 'resolved'
            ).toList();

            final consultations = appointments.where((a) => 
              a.lawyerId == currentUserId
            ).toList();

            final activeCount = activeClientsCases.length;
            final consultationsCount = consultations.length;
            final completedCount = completedCases.length;

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
                      _buildClientsSubTab(1, "Consultations", "$consultationsCount"),
                      _buildClientsSubTab(2, "Completed", "$completedCount"),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _buildClientsTabContent(
                    activeClientsCases,
                    consultations,
                    completedCases,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildClientsTabContent(
    List<CaseModel> activeCases,
    List<AppointmentModel> consultations,
    List<CaseModel> completedCases,
  ) {
    if (_selectedClientsTab == 0) {
      if (activeCases.isEmpty) {
        return const Center(child: Text("No active case clients yet. Accept proposals to get started.", style: TextStyle(color: AppColors.textSecondaryDark)));
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
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.navyBlueLight,
                backgroundImage: clientCase.clientImage.isNotEmpty
                    ? NetworkImage(clientCase.clientImage)
                    : null,
                child: clientCase.clientImage.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              title: Text(clientCase.clientName, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground, fontSize: 15)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("Case: ${clientCase.title}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    "Budget: ${clientCase.budgetRange} • Urgency: ${clientCase.urgency}",
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                  ),
                ],
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  context.push('/chat/chat_${clientCase.id}/${clientCase.clientName}');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(60, 36),
                ),
                child: const Text("Chat", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          );
        },
      );
    } else if (_selectedClientsTab == 1) {
      if (consultations.isEmpty) {
        return const Center(child: Text("No booked consultations yet.", style: TextStyle(color: AppColors.textSecondaryDark)));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: consultations.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final appt = consultations[index];
          return Card(
            elevation: 0,
            color: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.navyBlueLight,
                backgroundImage: appt.clientImage.isNotEmpty
                    ? NetworkImage(appt.clientImage)
                    : null,
                child: appt.clientImage.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
              ),
              title: Text(appt.clientName, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground, fontSize: 15)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(appt.caseTitle ?? appt.mode, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    "Scheduled: ${DateFormat('dd MMM yyyy, hh:mm a').format(appt.date)} (${appt.timeSlot})",
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                  ),
                ],
              ),
              trailing: OutlinedButton(
                onPressed: () {
                  context.push('/chat/chat_${appt.id}/${appt.clientName}');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.gold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size(60, 36),
                ),
                child: const Text("Chat", style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          );
        },
      );
    } else {
      if (completedCases.isEmpty) {
        return const Center(child: Text("No completed cases recorded.", style: TextStyle(color: AppColors.textSecondaryDark)));
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
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.navyBlueLight,
                backgroundImage: clientCase.clientImage.isNotEmpty
                    ? NetworkImage(clientCase.clientImage)
                    : null,
                child: clientCase.clientImage.isEmpty ? const Icon(Icons.person, color: Colors.white70) : null,
              ),
              title: Text(clientCase.clientName, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground, fontSize: 15)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("Case: ${clientCase.title}", style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  const SizedBox(height: 6),
                  const Text("Status: Completed/Resolved", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              trailing: const Icon(Icons.verified, color: AppColors.gold),
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

    String selectedClientId = clients.isNotEmpty ? clients.first['id']! : "64f15d2a900994f29a02256c";
    final TextEditingController nameTextController = TextEditingController();
    if (clients.isEmpty) {
      nameTextController.text = "Rahul Sharma"; // Default seeded client name
    }

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
                      return notificationsState.when(
                        data: (notifications) {
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
                              if (notif.type == "Appointment") icon = Icons.calendar_today_outlined;
                              if (notif.type == "Messages") icon = Icons.mail_outline_rounded;
                              if (notif.type == "Offers") icon = Icons.gavel_outlined;

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
                                      fontWeight: notif.read ? FontWeight.normal : FontWeight.bold,
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
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text("Error loading notifications: $err", style: const TextStyle(color: Colors.red))),
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
  // 5. PROFILE TAB (Figma Screen 6)
  // ═══════════════════════════════════════════════════════════
  Widget _buildProfileTab(
    String lawyerName,
    String userId,
    AsyncValue<LawyerModel> lawyerState,
  ) {
    final authState = ref.read(authProvider);

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
          _locationController.text = authState.userLocation ?? "";
          _officeAddressController.text = lawyer.officeAddress;
          _upiIdController.text = lawyer.upiId;
          _workingHoursController.text = lawyer.workingHours;
          _bankNameController.text = lawyer.bankDetails['bankName'] ?? "";
          _bankAccountNoController.text = lawyer.bankDetails['accountNumber'] ?? "";
          _bankIFSCController.text = lawyer.bankDetails['ifscCode'] ?? "";
          _bankHolderController.text = lawyer.bankDetails['accountHolderName'] ?? "";
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
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.navyBlue,
                          backgroundImage: authState.userPhotoUrl != null && authState.userPhotoUrl!.isNotEmpty
                              ? NetworkImage(authState.userPhotoUrl!)
                              : null,
                          child: (authState.userPhotoUrl == null || authState.userPhotoUrl!.isEmpty)
                              ? const Icon(Icons.person, color: Colors.white, size: 35)
                              : null,
                        ),
                        if (_isEditingProfile)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.gold,
                                child: Icon(Icons.camera_alt, size: 12, color: AppColors.navyBlue),
                              ),
                            ),
                          ),
                      ],
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
                      Text(authState.userLocation != null && authState.userLocation!.isNotEmpty ? authState.userLocation! : "Hyderabad, Telangana", style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Full Name",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.person, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Phone Number",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.phone, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _specController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Specialization",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.gavel, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _expController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Experience (Years)",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.work, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _feeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Consultation Fee (₹)",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.payments, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final selectedLoc = await LocationPickerSheet.show(context, initialLocation: _locationController.text);
                          if (selectedLoc != null) {
                            setState(() {
                              _locationController.text = selectedLoc;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: _locationController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: "Location",
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                              prefixIcon: const Icon(Icons.location_on, color: Colors.white70, size: 20),
                              suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                              filled: true,
                              fillColor: AppColors.navyBlue,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: AppColors.borderDark),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: AppColors.borderDark),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _barController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Bar Council ID",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.badge, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _eduController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Qualification (Education)",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.school, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bioController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Bio / Profile Summary",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _officeAddressController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Office Address",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.location_city, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _workingHoursController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Working Hours",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.timer, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _upiIdController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "UPI ID",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          prefixIcon: const Icon(Icons.payment, color: Colors.white70, size: 20),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text("Bank Account Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bankHolderController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Account Holder Name",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bankNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Bank Name",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bankAccountNoController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Account Number",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bankIFSCController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "IFSC Code",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          filled: true,
                          fillColor: AppColors.navyBlue,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.borderDark),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(color: AppColors.gold, width: 1.5),
                          ),
                        ),
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

                // Office Info Section
                const Text("Office Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                const SizedBox(height: 8),
                Text(
                  lawyer.officeAddress.isNotEmpty ? lawyer.officeAddress : "Not provided.",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Working Hours
                const Text("Working Hours", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                const SizedBox(height: 8),
                Text(
                  lawyer.workingHours.isNotEmpty ? lawyer.workingHours : "9:00 AM - 6:00 PM",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Payment Info
                const Text("UPI / Settlement Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                const SizedBox(height: 8),
                Text(
                  lawyer.upiId.isNotEmpty ? "UPI: ${lawyer.upiId}" : "UPI: Not set.",
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                ),
                if (lawyer.bankDetails['bankName'] != null && lawyer.bankDetails['bankName'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Bank: ${lawyer.bankDetails['bankName']} (A/c: ${lawyer.bankDetails['accountNumber']})",
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                ],
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
      label: Text(text, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9))),
      backgroundColor: AppColors.navyBlue,
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
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(lead.title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 4),
                    Text(lead.location, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.currency_rupee, size: 14, color: AppColors.textSecondaryDark),
                    const SizedBox(width: 4),
                    Text(lead.budgetRange, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 16),
                Text("Client Requirements:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onBackground)),
                const SizedBox(height: 6),
                Text(lead.description, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: AppColors.textSecondaryDark)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showProposalDialog(lead.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
              ),
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
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Send Proposal", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feeController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                decoration: const InputDecoration(
                  labelText: "Consultation Fee Bid (₹)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
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
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondaryDark)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.black,
              ),
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
        return Consumer(
          builder: (context, ref, child) {
            final appointmentsState = ref.watch(appointmentsProvider);
            final currentUserId = ref.watch(authProvider).userId ?? "";
            final lawyerState = ref.watch(lawyerDetailsProvider(currentUserId));

            return appointmentsState.when(
              data: (appointments) {
                final completedConsults = appointments.where((a) =>
                  a.lawyerId == currentUserId && a.status == 'completed'
                ).toList();

                final fee = lawyerState.maybeWhen(
                  data: (lawyer) => lawyer.consultationFee,
                  orElse: () => 1500,
                );

                final consultEarnings = completedConsults.length * fee;
                final totalEarnings = consultEarnings;

                return AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text("Earnings Details", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onBackground)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Total Earnings", style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                      const SizedBox(height: 4),
                      Text("₹$totalEarnings", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.gold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Consultations", style: TextStyle(fontSize: 13)),
                          Text("₹$consultEarnings", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Other Earnings", style: TextStyle(fontSize: 13)),
                          Text("₹0", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close", style: TextStyle(color: AppColors.textSecondaryDark)),
                    ),
                  ],
                );
              },
              loading: () => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                content: const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, stack) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                content: Text("Error: $err", style: const TextStyle(color: Colors.red)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
