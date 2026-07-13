import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/lawyer_model.dart';

class LawyerProfessionalDetailsScreen extends ConsumerStatefulWidget {
  const LawyerProfessionalDetailsScreen({super.key});

  @override
  ConsumerState<LawyerProfessionalDetailsScreen> createState() => _LawyerProfessionalDetailsScreenState();
}

class _LawyerProfessionalDetailsScreenState extends ConsumerState<LawyerProfessionalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _specController;
  late TextEditingController _expController;
  late TextEditingController _eduController;
  late TextEditingController _barController;
  late TextEditingController _bioController;

  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final userId = ref.read(authProvider).userId ?? "";
      final lawyerState = ref.read(lawyerDetailsProvider(userId));
      lawyerState.whenData((lawyer) {
        _specController = TextEditingController(text: lawyer.specialization);
        _expController = TextEditingController(text: "${lawyer.experience}");
        _eduController = TextEditingController(text: lawyer.education);
        _barController = TextEditingController(text: lawyer.barCouncilNumber);
        _bioController = TextEditingController(text: lawyer.bio);
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _specController.dispose();
      _expController.dispose();
      _eduController.dispose();
      _barController.dispose();
      _bioController.dispose();
    }
    super.dispose();
  }

  Future<void> _save(LawyerModel currentLawyer) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await ref.read(lawyerProfileUpdaterProvider).updateProfile(
          specialization: _specController.text.trim(),
          experience: int.tryParse(_expController.text.trim()) ?? 0,
          education: _eduController.text.trim(),
          barCouncilNumber: _barController.text.trim(),
          consultationFee: currentLawyer.consultationFee,
          bio: _bioController.text.trim(),
          officeAddress: currentLawyer.officeAddress,
          upiId: currentLawyer.upiId,
          workingHours: currentLawyer.workingHours,
          bankDetails: currentLawyer.bankDetails,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Professional details updated successfully!" : "Failed to update details."),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = ref.watch(authProvider).userId ?? "";
    final lawyerState = ref.watch(lawyerDetailsProvider(userId));

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
          "Professional Details",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: lawyerState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Colors.red))),
        data: (lawyer) {
          if (!_initialized) {
            _specController = TextEditingController(text: lawyer.specialization);
            _expController = TextEditingController(text: "${lawyer.experience}");
            _eduController = TextEditingController(text: lawyer.education);
            _barController = TextEditingController(text: lawyer.barCouncilNumber);
            _bioController = TextEditingController(text: lawyer.bio);
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Update your professional details to attract more client consultation bookings.",
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Specialization
                  _buildTextField(
                    controller: _specController,
                    labelText: "Specialization (e.g. Family Law, Criminal Defense)",
                    validator: (val) => val == null || val.trim().isEmpty ? "Specialization is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // Years of Experience
                  _buildTextField(
                    controller: _expController,
                    labelText: "Years of Experience",
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return "Experience is required";
                      }
                      if (int.tryParse(val.trim()) == null) {
                        return "Please enter a valid number";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Education
                  _buildTextField(
                    controller: _eduController,
                    labelText: "Education / Qualifications (e.g. LL.B., Harvard Law)",
                    validator: (val) => val == null || val.trim().isEmpty ? "Education is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // Bar Council Registration
                  _buildTextField(
                    controller: _barController,
                    labelText: "Bar Council Registration Number",
                    validator: (val) => val == null || val.trim().isEmpty ? "Registration number is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // Bio / Professional Summary
                  _buildTextField(
                    controller: _bioController,
                    labelText: "About Me / Professional Bio",
                    maxLines: 4,
                    validator: (val) => val == null || val.trim().isEmpty ? "Bio summary is required" : null,
                  ),
                  const SizedBox(height: 36),

                  // Save Changes Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _save(lawyer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 14),
        filled: true,
        fillColor: theme.colorScheme.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
