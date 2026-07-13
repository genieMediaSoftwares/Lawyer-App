import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/lawyer_model.dart';

class LawyerConsultationSettingsScreen extends ConsumerStatefulWidget {
  const LawyerConsultationSettingsScreen({super.key});

  @override
  ConsumerState<LawyerConsultationSettingsScreen> createState() => _LawyerConsultationSettingsScreenState();
}

class _LawyerConsultationSettingsScreenState extends ConsumerState<LawyerConsultationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _feeController;
  late TextEditingController _hoursController;
  late TextEditingController _officeController;
  late TextEditingController _upiController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNoController;
  late TextEditingController _ifscController;
  late TextEditingController _holderController;

  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final userId = ref.read(authProvider).userId ?? "";
      final lawyerState = ref.read(lawyerDetailsProvider(userId));
      lawyerState.whenData((lawyer) {
        _feeController = TextEditingController(text: "${lawyer.consultationFee}");
        _hoursController = TextEditingController(text: lawyer.workingHours);
        _officeController = TextEditingController(text: lawyer.officeAddress);
        _upiController = TextEditingController(text: lawyer.upiId);
        
        final bank = lawyer.bankDetails;
        _bankNameController = TextEditingController(text: bank['bankName'] ?? "");
        _accountNoController = TextEditingController(text: bank['accountNumber'] ?? "");
        _ifscController = TextEditingController(text: bank['ifscCode'] ?? "");
        _holderController = TextEditingController(text: bank['accountHolderName'] ?? "");
        
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _feeController.dispose();
      _hoursController.dispose();
      _officeController.dispose();
      _upiController.dispose();
      _bankNameController.dispose();
      _accountNoController.dispose();
      _ifscController.dispose();
      _holderController.dispose();
    }
    super.dispose();
  }

  Future<void> _save(LawyerModel currentLawyer) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final success = await ref.read(lawyerProfileUpdaterProvider).updateProfile(
          specialization: currentLawyer.specialization,
          experience: currentLawyer.experience,
          education: currentLawyer.education,
          barCouncilNumber: currentLawyer.barCouncilNumber,
          consultationFee: int.tryParse(_feeController.text.trim()) ?? 0,
          bio: currentLawyer.bio,
          officeAddress: _officeController.text.trim(),
          upiId: _upiController.text.trim(),
          workingHours: _hoursController.text.trim(),
          bankDetails: {
            "bankName": _bankNameController.text.trim(),
            "accountNumber": _accountNoController.text.trim(),
            "ifscCode": _ifscController.text.trim(),
            "accountHolderName": _holderController.text.trim(),
          },
        );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Consultation settings updated successfully!" : "Failed to update settings."),
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
          "Consultation Settings",
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
            _feeController = TextEditingController(text: "${lawyer.consultationFee}");
            _hoursController = TextEditingController(text: lawyer.workingHours);
            _officeController = TextEditingController(text: lawyer.officeAddress);
            _upiController = TextEditingController(text: lawyer.upiId);

            final bank = lawyer.bankDetails;
            _bankNameController = TextEditingController(text: bank['bankName'] ?? "");
            _accountNoController = TextEditingController(text: bank['accountNumber'] ?? "");
            _ifscController = TextEditingController(text: bank['ifscCode'] ?? "");
            _holderController = TextEditingController(text: bank['accountHolderName'] ?? "");
            
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
                    "Set up your consultation fees, working hours, and banking details to automate payouts and booking confirmations.",
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6) ?? Colors.grey,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Consultation Fee
                  _buildTextField(
                    controller: _feeController,
                    labelText: "Consultation Fee (₹ per slot)",
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Consultation fee is required";
                      if (int.tryParse(val.trim()) == null) return "Enter a valid number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Working Hours
                  _buildTextField(
                    controller: _hoursController,
                    labelText: "Working Hours (e.g. 9:00 AM - 6:00 PM)",
                    validator: (val) => val == null || val.trim().isEmpty ? "Working hours is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // Office Address
                  _buildTextField(
                    controller: _officeController,
                    labelText: "Office Address / Chamber Location",
                    validator: (val) => val == null || val.trim().isEmpty ? "Office address is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // UPI ID
                  _buildTextField(
                    controller: _upiController,
                    labelText: "UPI ID (for direct client payouts)",
                    validator: (val) => val == null || val.trim().isEmpty ? "UPI ID is required" : null,
                  ),
                  const SizedBox(height: 24),

                  // Bank details header
                  Text(
                    "BANK SETTLEMENT DETAILS",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bank Holder Name
                  _buildTextField(
                    controller: _holderController,
                    labelText: "Account Holder Name",
                    validator: (val) => val == null || val.trim().isEmpty ? "Account holder name is required" : null,
                  ),
                  const SizedBox(height: 12),

                  // Bank Name
                  _buildTextField(
                    controller: _bankNameController,
                    labelText: "Bank Name",
                    validator: (val) => val == null || val.trim().isEmpty ? "Bank name is required" : null,
                  ),
                  const SizedBox(height: 12),

                  // Account Number
                  _buildTextField(
                    controller: _accountNoController,
                    labelText: "Bank Account Number",
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.trim().isEmpty ? "Account number is required" : null,
                  ),
                  const SizedBox(height: 12),

                  // IFSC Code
                  _buildTextField(
                    controller: _ifscController,
                    labelText: "IFSC Code",
                    validator: (val) => val == null || val.trim().isEmpty ? "IFSC Code is required" : null,
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
