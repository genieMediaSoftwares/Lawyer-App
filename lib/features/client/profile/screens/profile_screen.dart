import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _nameController = TextEditingController(text: authState.userName ?? "");
    _phoneController = TextEditingController(text: authState.userMobile ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and phone number cannot be empty.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await ref.read(authProvider.notifier).updateUserProfile(
          name: name,
          mobile: phone,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Profile updated successfully!" : "Failed to update profile. Please try again."),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final name = authState.userName ?? "Client User";
    final email = authState.userEmail ?? "client@genielaw.com";
    final phone = authState.userMobile ?? "9876543210";

    // Synchronize form fields if not editing
    if (!_isEditing) {
      _nameController.text = name;
      _phoneController.text = phone;
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Cancel and reset
                  _nameController.text = name;
                  _phoneController.text = phone;
                }
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card Header
            _buildProfileHeaderCard(email),
            const SizedBox(height: 24),

            // Settings options (hidden in edit mode to focus on form)
            if (!_isEditing) ...[
              _buildOptionTile(
                icon: Icons.notifications_outlined,
                title: "Notifications Settings",
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.payment_outlined,
                title: "Payment Methods",
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.security_outlined,
                title: "Change Password",
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.info_outline,
                title: "Terms & Privacy Policy",
                onTap: () {},
              ),
              const SizedBox(height: 24),

              // Log Out Button
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              // Action Form Buttons in edit mode
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.navyBlue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.navyBlue, strokeWidth: 2))
                    : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
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
      ),
    );
  }

  Widget _buildProfileHeaderCard(String email) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.navyBlue,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 20),
          if (!_isEditing) ...[
            Text(
              _nameController.text,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_outlined, size: 14, color: AppColors.grey500),
                const SizedBox(width: 6),
                Text(email, style: const TextStyle(color: AppColors.grey500, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppColors.grey500),
                const SizedBox(width: 6),
                Text("+91 ${_phoneController.text}", style: const TextStyle(color: AppColors.grey500, fontSize: 13)),
              ],
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.navyBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
      ),
    );
  }
}
