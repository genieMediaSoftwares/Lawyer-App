import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/widgets/app_drawer.dart';

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

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      
      if (mounted) {
        setState(() => _isSaving = true);
      }

      final success = await ref.read(authProvider.notifier).updateProfileImage(bytes, image.name);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? "Profile image updated successfully!" : "Failed to upload profile image."),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error selecting image: $e")),
        );
      }
    }
  }

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
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
            _buildProfileHeaderCard(email, authState.userPhotoUrl),
            const SizedBox(height: 24),

            // Settings options (hidden in edit mode to focus on form)
            if (!_isEditing) ...[
              _buildOptionTile(
                icon: Icons.folder_open_outlined,
                title: "My Documents",
                onTap: () => context.push('/my-documents'),
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.favorite_border,
                title: "Favorite Lawyers",
                onTap: () => context.push('/favorites'),
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.article_outlined,
                title: "Legal Articles",
                onTap: () => context.push('/articles'),
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.question_answer_outlined,
                title: "FAQ Accordion",
                onTap: () => context.push('/faq'),
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.settings_outlined,
                title: "App Settings",
                onTap: () => context.push('/settings'),
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

   Widget _buildProfileHeaderCard(String email, String? photoUrl) {
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
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.navyBlue,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? const Icon(Icons.person, size: 44, color: Colors.white)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.gold,
                      child: Icon(Icons.camera_alt, size: 14, color: AppColors.navyBlue),
                    ),
                  ),
                ),
            ],
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
