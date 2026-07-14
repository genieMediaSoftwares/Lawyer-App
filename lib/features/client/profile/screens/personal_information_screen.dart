import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../core/widgets/location_picker_sheet.dart';

class PersonalInformationScreen extends ConsumerStatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  ConsumerState<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends ConsumerState<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dobController;
  late TextEditingController _genderController;
  late TextEditingController _languagesController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;

  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = ref.read(profileProvider).profile;
      if (profile != null) {
        _dobController = TextEditingController(text: profile.dob);
        _genderController = TextEditingController(text: profile.gender);
        _languagesController = TextEditingController(text: profile.languages.join(", "));
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
              primary: Color(0xFFD4AF37),
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
        _dobController.text = DateFormat("dd MMM yyyy").format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final languagesList = _languagesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final profile = ref.read(profileProvider).profile!;

    final success = await ref.read(profileProvider.notifier).updateProfile(
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
          content: Text(success ? "Personal information updated successfully!" : "Failed to update details."),
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

    if (profile == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Personal Information",
          style: TextStyle(
            color: Colors.white,
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
              const Text(
                "Verify and update your personal details below to keep your legal records up to date.",
                style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Date of Birth
              GestureDetector(
                onTap: _selectDate,
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _dobController,
                    labelText: "Date of Birth",
                    suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFFD4AF37), size: 20),
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
                labelText: "Languages (e.g. English, Hindi, Spanish)",
                validator: (val) => val == null || val.trim().isEmpty ? "Languages are required" : null,
              ),
              const SizedBox(height: 16),

              // Phone Number
              _buildTextField(
                controller: _phoneController,
                labelText: "Phone Number",
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty ? "Phone number is required" : null,
              ),
              const SizedBox(height: 16),

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
                    suffixIcon: const Icon(Icons.my_location, color: Color(0xFFD4AF37), size: 20),
                    validator: (val) => val == null || val.trim().isEmpty ? "Location is required" : null,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Save Changes Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
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
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF1B1B1B),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2B2B2B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
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

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _genderController.text.isNotEmpty ? _genderController.text : null,
      dropdownColor: const Color(0xFF1B1B1B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: "Gender",
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1B1B1B),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2B2B2B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      items: const [
        DropdownMenuItem(value: "Male", child: Text("Male")),
        DropdownMenuItem(value: "Female", child: Text("Female")),
        DropdownMenuItem(value: "Other", child: Text("Other")),
      ],
      onChanged: (val) {
        if (val != null) {
          _genderController.text = val;
        }
      },
    );
  }
}
