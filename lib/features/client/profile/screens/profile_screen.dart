import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../models/client_profile_model.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/location_picker_sheet.dart';
import '../../../../providers/notification_provider.dart';
import '../../../../core/widgets/app_drawer.dart';

import 'my_profile_screen.dart';
import 'personal_information_screen.dart';
import 'recent_activity_screen.dart';
import 'support_help_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final unreadCount = ref.watch(notificationsProvider).unreadCount;

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
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
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white),
                onPressed: () => context.push(RouteNames.notifications),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(width: 8),
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
          // 1. Premium Minimal Profile Summary (Tapping navigates to My Profile)
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const MyProfileScreen()),
            ),
            child: _buildMinimalProfileHeader(profile),
          ),
          const SizedBox(height: 24),

          // Header for Account Management
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "ACCOUNT & PERSONAL DETAILS",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // 2. Account Details Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
            ),
            child: Column(
              children: [
                _buildMenuRow(
                  icon: Icons.person_outline,
                  title: "My Profile",
                  subtitle: "Photo, name, contact info",
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const MyProfileScreen()),
                  ),
                ),
                const Divider(color: Color(0xFF2B2B2B), height: 1),
                _buildMenuRow(
                  icon: Icons.contact_mail_outlined,
                  title: "Personal Information",
                  subtitle: "DOB, gender, address, languages",
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const PersonalInformationScreen()),
                  ),
                ),
                const Divider(color: Color(0xFF2B2B2B), height: 1),
                _buildMenuRow(
                  icon: Icons.show_chart_outlined,
                  title: "Recent Activity",
                  subtitle: "Your timeline of activity logs",
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const RecentActivityScreen()),
                  ),
                ),
                const Divider(color: Color(0xFF2B2B2B), height: 1),
                _buildMenuRow(
                  icon: Icons.headset_mic_outlined,
                  title: "Support & Help",
                  subtitle: "Help center, privacy, terms, support",
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SupportHelpScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Header for Operational Workspace
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "LEGAL DESK & SERVICES",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // 3. Operational Menu Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
            ),
            child: Column(
              children: [
                _buildMenuRow(
                  icon: Icons.description_outlined,
                  title: "Documents",
                  subtitle: "Your legal documents",
                  onTap: () => context.push(RouteNames.myDocuments),
                ),
                const Divider(color: Color(0xFF2B2B2B), height: 1),
                _buildMenuRow(
                  icon: Icons.settings_outlined,
                  title: "Settings",
                  subtitle: "Account & app settings",
                  onTap: () => context.push(RouteNames.settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
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
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMinimalProfileHeader(ClientProfileModel profile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2B2B2B),
            backgroundImage: profile.profileImage.isNotEmpty
                ? NetworkImage(Environment.getAttachmentUrl(profile.profileImage))
                : null,
            child: profile.profileImage.isEmpty
                ? Text(
                    profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.isVerified) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.verified, color: Color(0xFFD4AF37), size: 14),
                      SizedBox(width: 6),
                      Text(
                        "Verified Client",
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 20),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
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
    );
  }
}

class EditProfileBottomSheet extends ConsumerStatefulWidget {
  final ClientProfileModel profile;
  const EditProfileBottomSheet({super.key, required this.profile});

  @override
  ConsumerState<EditProfileBottomSheet> createState() => _EditProfileBottomSheetState();
}

class _EditProfileBottomSheetState extends ConsumerState<EditProfileBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _languagesController;
  late TextEditingController _locationController;

  bool _isSaving = false;

  DateTime? _parseDOB(String value) {
    if (value.trim().isEmpty) return null;
    try {
      return DateFormat("dd/MM/yyyy").parseStrict(value.trim());
    } catch (_) {}
    try {
      return DateFormat("dd MMM yyyy").parse(value.trim());
    } catch (_) {}
    try {
      return DateTime.parse(value.trim());
    } catch (_) {}
    return null;
  }

  Future<void> _selectDate() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      final parsed = _parseDOB(_dobController.text);
      if (parsed != null) {
        initial = parsed;
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryGold,
              onPrimary: Colors.black,
              surface: Color(0xFF1B1B1B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat("dd/MM/yyyy").format(picked);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.mobile);
    
    final parsed = _parseDOB(widget.profile.dob);
    _dobController = TextEditingController(
      text: parsed != null ? DateFormat("dd/MM/yyyy").format(parsed) : "",
    );
    
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
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _selectDate,
                style: const TextStyle(color: Colors.white),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Date of Birth is required";
                  }
                  final parsed = _parseDOB(val);
                  if (parsed == null) {
                    return "Please select a valid date";
                  }
                  if (parsed.isAfter(DateTime.now())) {
                    return "Date of Birth cannot be in the future";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Date of Birth",
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintText: "dd/mm/yyyy",
                  hintStyle: const TextStyle(color: Colors.grey),
                  suffixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.primaryGold),
                  filled: true,
                  fillColor: const Color(0xFF2B2B2B),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B3B3B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryGold),
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
              ),
              const SizedBox(height: 12),

              // Gender
              DropdownButtonFormField<String>(
                value: ['Male', 'Female', 'Other', 'Prefer Not To Say'].contains(_genderController.text)
                    ? _genderController.text
                    : null,
                dropdownColor: const Color(0xFF1B1B1B),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                hint: const Text(
                  "Select Gender",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                decoration: InputDecoration(
                  labelText: "Gender",
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF2B2B2B),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF3B3B3B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primaryGold),
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
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                  DropdownMenuItem(value: "Prefer Not To Say", child: Text("Prefer Not To Say")),
                ],
                validator: (val) => val == null || val.isEmpty ? "Gender is required" : null,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _genderController.text = val;
                    });
                  }
                },
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
