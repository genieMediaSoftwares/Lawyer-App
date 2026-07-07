import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/location_picker_sheet.dart';

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
  late TextEditingController _locationController;

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
            backgroundColor: success ? AppColors.success : AppColors.error,
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
    _locationController = TextEditingController(text: authState.userLocation ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty || phone.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, phone, and location cannot be empty.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await ref.read(authProvider.notifier).updateUserProfile(
          name: name,
          mobile: phone,
          location: location,
        );

    if (mounted) {
      setState(() {
        _isSaving = false;
        if (success) _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Profile updated successfully!" : "Failed to update profile. Please try again."),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final name = authState.userName ?? "Client User";
    final email = authState.userEmail ?? "client@genielaw.com";
    final phone = authState.userMobile ?? "9876543210";

    // Synchronize form fields if not editing
    if (!_isEditing) {
      _nameController.text = name;
      _phoneController.text = phone;
      _locationController.text = authState.userLocation ?? "";
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 24),
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
                icon: const Icon(Icons.logout),
                label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              // Action Form Buttons in edit mode
              ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text("Cancel"),
              ),
            ],
          ],
        ),
      ),
    );
  }

   Widget _buildProfileHeaderCard(String email, String? photoUrl) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: theme.colorScheme.surface,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Icon(Icons.person, size: 44, color: theme.textTheme.bodySmall?.color)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!_isEditing) ...[
            Text(
              _nameController.text,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleLarge?.color),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(email, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text("+91 ${_phoneController.text}", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(_locationController.text.isNotEmpty ? _locationController.text : "Hyderabad, Telangana", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13)),
              ],
            ),
          ] else ...[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: "Full Name",
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: "Phone Number",
                prefixIcon: const Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
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
                  decoration: InputDecoration(
                    hintText: "Location",
                    prefixIcon: const Icon(Icons.location_on),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
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
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
        trailing: Icon(Icons.chevron_right, color: theme.textTheme.bodySmall?.color),
      ),
    );
  }
}
