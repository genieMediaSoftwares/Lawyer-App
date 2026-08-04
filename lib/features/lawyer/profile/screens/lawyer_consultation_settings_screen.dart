import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
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
    final loc = AppLocalizations.of(context)!;
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
          content: Text(success ? loc.consultation_settings_updated_success : loc.consultation_settings_updated_failure),
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
    final loc = AppLocalizations.of(context)!;

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
          loc.consultation_settings,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: lawyerState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: AppColors.error))),
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
                    loc.consultation_settings_subtitle,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6) ?? AppColors.mutedText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Consultation Fee
                  _buildTextField(
                    controller: _feeController,
                    labelText: loc.consultation_fee_label,
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return loc.consultation_fee_required;
                      if (int.tryParse(val.trim()) == null) return loc.valid_number_required;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Working Hours
                  _buildTextField(
                    controller: _hoursController,
                    labelText: loc.working_hours_label,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.working_hours_required : null,
                  ),
                  const SizedBox(height: 16),

                  // Office Address
                  _buildTextField(
                    controller: _officeController,
                    labelText: loc.office_address_label,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.office_address_required : null,
                  ),
                  const SizedBox(height: 16),

                  // UPI ID
                  _buildTextField(
                    controller: _upiController,
                    labelText: loc.upi_id_label,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.upi_id_required : null,
                  ),
                  const SizedBox(height: 24),

                  // Bank details header
                  Text(
                    loc.bank_settlement_header,
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
                    labelText: loc.account_holder_label,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.account_holder_required : null,
                  ),
                  const SizedBox(height: 12),

                  // Bank Name
                  _buildTextField(
                    controller: _bankNameController,
                    labelText: loc.bank_name_label,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.bank_name_required : null,
                  ),
                  const SizedBox(height: 12),

                  // Account Number
                  _buildTextField(
                    controller: _accountNoController,
                    labelText: loc.account_number_label,
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.account_number_required : null,
                  ),
                  const SizedBox(height: 12),

                  // IFSC Code
                  _buildTextField(
                    controller: _ifscController,
                    labelText: loc.ifsc_code_label,
                    validator: (val) => val == null || val.trim().isEmpty ? loc.ifsc_code_required : null,
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
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.onGold),
                              ),
                            )
                          : Text(
                              loc.save_changes,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 14),
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
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
