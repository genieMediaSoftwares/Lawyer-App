import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState
    extends ConsumerState<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _languagesController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;

  bool _isSaving = false;

  /// Location is no longer a FormField, so its required-check lives
  /// here and is surfaced through the field's own errorText.
  String? _locationError;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = ref.read(profileProvider).profile;
      if (profile != null) {
        _dobController = TextEditingController(text: profile.dob);
        _genderController = TextEditingController(text: profile.gender);
        _languagesController = TextEditingController(
          text: profile.languages.join(", "),
        );
        _phoneController = TextEditingController(text: profile.mobile);
        _locationController = TextEditingController(text: profile.location);
        _initialized = true;
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _dobController.dispose();
      _genderController.dispose();
      _languagesController.dispose();
      _phoneController.dispose();
      _locationController.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_dobController.text.isNotEmpty) {
      try {
        initial = DateFormat("dd MMM yyyy").parse(_dobController.text);
      } catch (_) {}
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
              onPrimary: AppColors.onGold,
              surface: AppColors.surface,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat("dd MMM yyyy").format(picked);
      });
    }
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    final locationMissing = _locationController.text.trim().isEmpty;
    setState(() {
      _locationError = locationMissing ? loc.location_is_required : null;
    });
    if (!_formKey.currentState!.validate() || locationMissing) return;

    setState(() => _isSaving = true);

    final languagesList = _languagesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final profile = ref.read(profileProvider).profile!;

    final success = await ref
        .read(profileProvider.notifier)
        .updateProfile(
          fullName: profile.fullName,
          mobile: _phoneController.text.trim(),
          location: _locationController.text.trim(),
          dob: _dobController.text.trim(),
          gender: _genderController.text.trim(),
          languages: languagesList,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? loc.personal_info_updated_success
                : loc.personal_details_saved_failure,
          ),
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
    final state = ref.watch(profileProvider);
    final profile = state.profile;
    final loc = AppLocalizations.of(context)!;

    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.primaryBackground,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          loc.personal_info,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.personal_info_subtitle,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Date of Birth
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _dobController,
                    labelText: loc.date_of_birth,
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.primaryGold,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gender
              _buildGenderDropdown(),
              const SizedBox(height: 16),

              // Preferred Languages
              _buildTextField(
                controller: _languagesController,
                labelText: loc.languages_example_hint,
                validator: (val) => val == null || val.trim().isEmpty
                    ? loc.languages_required
                    : null,
              ),
              const SizedBox(height: 16),

              // Phone Number
              _buildTextField(
                controller: _phoneController,
                labelText: loc.phone_number,
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty
                    ? loc.phone_is_required
                    : null,
              ),
              const SizedBox(height: 16),

              LocationAutocompleteField(
                fieldKey: 'client_personal_info',
                initialText: _locationController.text,
                label: loc.address_location,
                onSelected: (place) => setState(
                  () => _locationController.text = place.description,
                ),
                onCleared: () => setState(_locationController.clear),
                errorText: _locationError,
              ),
              const SizedBox(height: 36),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.onGold,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.onGold,
                            ),
                          ),
                        )
                      : Text(
                          loc.save_changes,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
      style: const TextStyle(color: AppColors.primaryText),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryGold),
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

  Widget _buildGenderDropdown() {
    final loc = AppLocalizations.of(context)!;
    return DropdownButtonFormField<String>(
      initialValue: _genderController.text.isNotEmpty ? _genderController.text : null,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.primaryText),
      decoration: InputDecoration(
        labelText: loc.gender,
        labelStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryGold),
        ),
      ),
      items: [
        DropdownMenuItem(value: "Male", child: Text(loc.gender_male)),
        DropdownMenuItem(value: "Female", child: Text(loc.gender_female)),
        DropdownMenuItem(value: "Other", child: Text(loc.gender_other)),
      ],
      onChanged: (val) {
        if (val != null) {
          _genderController.text = val;
        }
      },
    );
  }
}
