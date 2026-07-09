import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../models/client_profile_model.dart';
import '../../../../models/activity_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/location_picker_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isSavingImage = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      
      setState(() => _isSavingImage = true);

      final success = await ref.read(profileProvider.notifier).updateProfileImage(bytes, image.name);

      setState(() => _isSavingImage = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Profile image updated successfully!" : "Failed to upload profile image."),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error selecting image: $e")),
        );
      }
    }
  }

  void _showEditProfileSheet(ClientProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileBottomSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () => context.push(RouteNames.notifications),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(profileProvider.notifier).fetchProfileData(),
        color: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF1B1B1B),
        child: state.isLoading && state.profile == null
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                ),
              )
            : state.errorMessage != null && state.profile == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            "Failed to load profile details.",
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.read(profileProvider.notifier).fetchProfileData(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text("Retry"),
                          )
                        ],
                      ),
                    ),
                  )
                : _buildProfileContent(state.profile!),
      ),
    );
  }

  Widget _buildProfileContent(ClientProfileModel profile) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Profile Header Card
          _buildProfileHeaderCard(profile),
          const SizedBox(height: 24),

          // 2. Menu Navigation Items List
          _buildMenuSection(),
          const SizedBox(height: 32),

          // 3. Personal Information
          _buildPersonalInformationSection(profile),
          const SizedBox(height: 32),

          // 4. Recent Activity Timeline
          _buildRecentActivitySection(),
          const SizedBox(height: 32),

          // 5. Support & Help
          _buildSupportSection(),
          const SizedBox(height: 32),

          // 6. Need Legal Help CTA Bottom Banner
          _buildCtaBanner(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard(ClientProfileModel profile) {
    final cleanUrl = profile.profileImage.isNotEmpty
        ? (profile.profileImage.startsWith('http') ? profile.profileImage : 'http://localhost:5000/${profile.profileImage}')
        : null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: const Color(0xFF2B2B2B),
                  backgroundImage: cleanUrl != null ? NetworkImage(cleanUrl) : null,
                  child: cleanUrl == null
                      ? Text(
                          profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              if (_isSavingImage)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isSavingImage ? null : _pickAndUploadImage,
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFD4AF37),
                    child: Icon(Icons.camera_alt, size: 16, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.fullName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          if (profile.isVerified) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.verified, color: Color(0xFFD4AF37), size: 16),
                SizedBox(width: 6),
                Text(
                  "Verified Client",
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _buildHeaderRow(Icons.email_outlined, profile.email),
          const SizedBox(height: 10),
          _buildHeaderRow(Icons.phone_outlined, profile.mobile),
          const SizedBox(height: 10),
          _buildHeaderRow(Icons.location_on_outlined, profile.location.isNotEmpty ? profile.location : "Location not set"),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuCard(
          icon: Icons.business_center_outlined,
          title: "My Cases",
          subtitle: "Track your legal cases",
          onTap: () => context.go(RouteNames.myCases),
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          icon: Icons.event_note_outlined,
          title: "Consultations",
          subtitle: "Your consultation history",
          onTap: () => context.push(RouteNames.consult),
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          icon: Icons.description_outlined,
          title: "Documents",
          subtitle: "Your legal documents",
          onTap: () => context.push(RouteNames.myDocuments),
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          icon: Icons.favorite_border,
          title: "Favorite Advocates",
          subtitle: "Advocates you follow",
          onTap: () => context.push(RouteNames.favorites),
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          icon: Icons.payment_outlined,
          title: "Payments",
          subtitle: "Payment history & invoices",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Payments history screen coming soon!")),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          icon: Icons.notifications_none_outlined,
          title: "Notifications",
          subtitle: "Alerts and messages",
          onTap: () => context.push(RouteNames.notifications),
        ),
        const SizedBox(height: 12),
        _buildMenuCard(
          icon: Icons.settings_outlined,
          title: "Settings",
          subtitle: "Account & app settings",
          onTap: () => context.push(RouteNames.settings),
        ),
        const SizedBox(height: 20),
        
        // Red Logout Button Card
        InkWell(
          onTap: () => ref.read(authProvider.notifier).logout(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF3B30), width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout, color: Color(0xFFFF3B30), size: 20),
                SizedBox(width: 10),
                Text(
                  "Logout",
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: const Color(0xFFD4AF37), size: 24),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 20),
      ),
    );
  }

  Widget _buildPersonalInformationSection(ClientProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.person_outline, color: Color(0xFFD4AF37), size: 20),
                SizedBox(width: 8),
                Text(
                  "Personal Information",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => _showEditProfileSheet(profile),
              child: const Text(
                "Edit",
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildInfoRow(
                Icons.calendar_today_outlined,
                "Date of Birth",
                profile.dob.isNotEmpty ? profile.dob : "Not set",
              ),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildInfoRow(
                Icons.male,
                "Gender",
                profile.gender.isNotEmpty ? profile.gender : "Not set",
              ),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildInfoRow(
                Icons.language_outlined,
                "Language",
                profile.languages.isNotEmpty ? profile.languages.join(", ") : "Not set",
              ),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildInfoRow(
                Icons.phone_outlined,
                "Phone Number",
                profile.mobile,
              ),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              GestureDetector(
                onTap: () => _showEditProfileSheet(profile),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      "Address",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      profile.location.isNotEmpty ? profile.location : "Not set",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    final state = ref.watch(profileProvider);
    final list = state.activities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.show_chart_outlined, color: Color(0xFFD4AF37), size: 20),
                SizedBox(width: 8),
                Text(
                  "Recent Activity",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Activity logs screen coming soon!")),
                );
              },
              child: const Text(
                "View All",
                style: TextStyle(
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      "No recent activities found.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final act = list[index];
                    final isLast = index == list.length - 1;
                    return _buildTimelineItem(act, isLast);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(ActivityModel act, bool isLast) {
    // Format timestamp nicely, e.g. "2 days ago", "1 week ago", "2 hours ago"
    final timeStr = _formatActivityTime(act.date);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const Icon(Icons.circle, size: 10, color: Color(0xFFD4AF37)),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    act.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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

  String _formatActivityTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return "$months ${months == 1 ? 'month' : 'months'} ago";
    } else if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return "$weeks ${weeks == 1 ? 'week' : 'weeks'} ago";
    } else if (diff.inDays >= 1) {
      return "${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago";
    } else if (diff.inHours >= 1) {
      return "${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago";
    } else {
      return "Just now";
    }
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.headset_mic_outlined, color: Color(0xFFD4AF37), size: 20),
            SizedBox(width: 8),
            Text(
              "Support & Help",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildSupportRow(Icons.help_outline, "Help Center"),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildSupportRow(Icons.support_agent, "Contact Support"),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildSupportRow(Icons.info_outline, "About Us"),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildSupportRow(Icons.privacy_tip_outlined, "Privacy Policy"),
              const Divider(color: Color(0xFF2B2B2B), height: 24),
              _buildSupportRow(Icons.gavel_outlined, "Terms & Conditions"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportRow(IconData icon, String title) {
    return InkWell(
      onTap: () {
        // Safe navigation or notification toast
        if (title == "Help Center" || title == "About Us") {
          context.push(RouteNames.faq);
        } else if (title == "Privacy Policy" || title == "Terms & Conditions") {
          context.push(RouteNames.articles);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$title is coming soon!")),
          );
        }
      },
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 16),
        ],
      ),
    );
  }

  Widget _buildCtaBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B1B1B), Color(0xFF0F0F0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Need Legal Help?",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Book a consultation with our expert advocates.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go(RouteNames.advocates),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Premium Scales of justice styled Vector display
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD4AF37).withOpacity(0.1),
                ),
              ),
              const Icon(
                Icons.balance,
                color: Color(0xFFD4AF37),
                size: 44,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProfileBottomSheet extends ConsumerStatefulWidget {
  final ClientProfileModel profile;
  const _EditProfileBottomSheet({required this.profile});

  @override
  ConsumerState<_EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends ConsumerState<_EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _languagesController;
  late TextEditingController _locationController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.mobile);
    _dobController = TextEditingController(text: widget.profile.dob);
    _genderController = TextEditingController(text: widget.profile.gender);
    _languagesController = TextEditingController(text: widget.profile.languages.join(", "));
    _locationController = TextEditingController(text: widget.profile.location);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _languagesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Split languages by comma
    final languagesList = _languagesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final success = await ref.read(profileProvider.notifier).updateProfile(
          fullName: _nameController.text.trim(),
          mobile: _phoneController.text.trim(),
          location: _locationController.text.trim(),
          dob: _dobController.text.trim(),
          gender: _genderController.text.trim(),
          languages: languagesList,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Personal details saved successfully!" : "Failed to update profile details."),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Edit Personal Information",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Full Name
              _buildTextField(
                controller: _nameController,
                labelText: "Full Name",
                validator: (val) => val == null || val.trim().isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 12),

              // Date of Birth
              _buildTextField(
                controller: _dobController,
                labelText: "Date of Birth (e.g. 05 Aug 2003)",
                validator: (val) => null,
              ),
              const SizedBox(height: 12),

              // Gender
              _buildTextField(
                controller: _genderController,
                labelText: "Gender (e.g. Male, Female)",
                validator: (val) => null,
              ),
              const SizedBox(height: 12),

              // Preferred Languages
              _buildTextField(
                controller: _languagesController,
                labelText: "Languages (comma separated)",
                validator: (val) => null,
              ),
              const SizedBox(height: 12),

              // Phone Number
              _buildTextField(
                controller: _phoneController,
                labelText: "Phone Number",
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
              ),
              const SizedBox(height: 12),

              // Address / Location
              GestureDetector(
                onTap: () async {
                  final loc = await LocationPickerSheet.show(context, initialLocation: _locationController.text);
                  if (loc != null) {
                    setState(() {
                      _locationController.text = loc;
                    });
                  }
                },
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _locationController,
                    labelText: "Address / Location",
                    suffixIcon: const Icon(Icons.my_location, color: Color(0xFFD4AF37)),
                    validator: (val) => null,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          "Save Changes",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.grey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF2B2B2B),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B3B3B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
