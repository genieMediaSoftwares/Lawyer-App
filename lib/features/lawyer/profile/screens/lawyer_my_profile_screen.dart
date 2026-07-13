import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../core/widgets/location_picker_sheet.dart';

class LawyerMyProfileScreen extends ConsumerStatefulWidget {
  const LawyerMyProfileScreen({super.key});

  @override
  ConsumerState<LawyerMyProfileScreen> createState() => _LawyerMyProfileScreenState();
}

class _LawyerMyProfileScreenState extends ConsumerState<LawyerMyProfileScreen> {
  bool _isSavingImage = false;

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;

      final bytes = await image.readAsBytes();

      setState(() => _isSavingImage = true);

      final success = await ref.read(authProvider.notifier).updateProfileImage(bytes, image.name);
      
      // Invalidate lawyer details to sync photo across all providers
      final auth = ref.read(authProvider);
      if (auth.userId != null) {
        ref.invalidate(lawyerDetailsProvider(auth.userId!));
      }

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

  void _showEditProfileSheet(AuthState auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LawyerEditPersonalBottomSheet(auth: auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "My Profile",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Avatar Section
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: theme.colorScheme.outline,
                      backgroundImage: auth.userPhotoUrl != null && auth.userPhotoUrl!.isNotEmpty
                          ? NetworkImage(auth.userPhotoUrl!.startsWith('http')
                              ? auth.userPhotoUrl!
                              : 'http://localhost:5000/${auth.userPhotoUrl}')
                          : null,
                      child: (auth.userPhotoUrl == null || auth.userPhotoUrl!.isEmpty)
                          ? Text(
                              auth.userName != null && auth.userName!.isNotEmpty
                                  ? auth.userName![0].toUpperCase()
                                  : 'A',
                              style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  if (_isSavingImage)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isSavingImage ? null : _pickAndUploadImage,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Details Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline, width: 1),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(context, Icons.person_outline, "Full Name", auth.userName ?? ""),
                  Divider(color: theme.colorScheme.outline, height: 28),
                  _buildDetailRow(context, Icons.email_outlined, "Email Address", auth.userEmail ?? ""),
                  Divider(color: theme.colorScheme.outline, height: 28),
                  _buildDetailRow(context, Icons.phone_outlined, "Phone Number", auth.userMobile ?? ""),
                  Divider(color: theme.colorScheme.outline, height: 28),
                  _buildDetailRow(
                    context,
                    Icons.location_on_outlined,
                    "Location",
                    auth.userLocation != null && auth.userLocation!.isNotEmpty
                        ? auth.userLocation!
                        : "Location not set",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Edit Profile Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showEditProfileSheet(auth),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Edit Profile Details",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LawyerEditPersonalBottomSheet extends ConsumerStatefulWidget {
  final AuthState auth;
  const LawyerEditPersonalBottomSheet({super.key, required this.auth});

  @override
  ConsumerState<LawyerEditPersonalBottomSheet> createState() => _LawyerEditPersonalBottomSheetState();
}

class _LawyerEditPersonalBottomSheetState extends ConsumerState<LawyerEditPersonalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.auth.userName);
    _phoneController = TextEditingController(text: widget.auth.userMobile);
    _locationController = TextEditingController(text: widget.auth.userLocation);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await ref.read(authProvider.notifier).updateUserProfile(
          name: _nameController.text.trim(),
          mobile: _phoneController.text.trim(),
          location: _locationController.text.trim(),
        );

    // Also invalidate lawyer details to sync profile name/location in active dashboard
    if (widget.auth.userId != null) {
      ref.invalidate(lawyerDetailsProvider(widget.auth.userId!));
    }

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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
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
                  Text(
                    "Edit Personal Information",
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color ?? Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
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
                    labelText: "Location",
                    suffixIcon: Icon(Icons.my_location, color: theme.colorScheme.primary),
                    validator: (val) => val == null || val.trim().isEmpty ? "Location is required" : null,
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
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
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
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.colorScheme.primary),
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
