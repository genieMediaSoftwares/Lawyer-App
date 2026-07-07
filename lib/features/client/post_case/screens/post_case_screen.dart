import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../models/document_model.dart';
import '../../../../providers/issue_provider.dart';
import '../../../../providers/document_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/location_picker_sheet.dart';
import '../../../../providers/auth_provider.dart';

class PostCaseScreen extends ConsumerStatefulWidget {
  const PostCaseScreen({super.key});

  @override
  ConsumerState<PostCaseScreen> createState() => _PostCaseScreenState();
}

class _PostCaseScreenState extends ConsumerState<PostCaseScreen> {
  int _currentStep = 0;

  // Form State
  String? _selectedCategory;
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController(text: "Hyderabad, Telangana");
  final _courtController = TextEditingController();
  String? _selectedBudget;
  String? _selectedUrgency;
  bool _agreedToTerms = false;

  final List<DocumentModel> _uploadedDocs = [];

  final List<String> _categories = [
    "Criminal Law",
    "Divorce & Family",
    "Property Disputes",
    "Civil Cases",
    "Cyber Crime",
    "GST & Taxation",
    "Labour Law",
    "Consumer Complaints",
    "More Categories"
  ];

  final List<Map<String, String>> _predefinedFiles = [
    {"name": "FIR Copy.pdf", "size": "2.4 MB"},
    {"name": "Notice.pdf", "size": "1.8 MB"},
    {"name": "Property Papers.jpg", "size": "1.2 MB"},
  ];

  @override
  void initState() {
    super.initState();
    final userLocation = ref.read(authProvider).userLocation;
    if (userLocation != null && userLocation.isNotEmpty) {
      _cityController.text = userLocation;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _cityController.dispose();
    _courtController.dispose();
    super.dispose();
  }

  Future<void> _simulateUpload() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;
      
      final doc = await ref.read(documentsProvider.notifier).uploadDocument(filePath, fileName);
      if (doc != null) {
        setState(() {
          _uploadedDocs.add(DocumentModel(
            name: doc.originalName,
            url: "http://localhost:5000/${doc.filePath}",
            size: "${(doc.fileSize / 1024).toStringAsFixed(1)} KB",
          ));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document uploaded and attached successfully!")),
        );
      }
    }
  }

  Future<void> _submitCase() async {
    if (_selectedCategory == null ||
        _descriptionController.text.isEmpty ||
        _cityController.text.isEmpty ||
        !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields and agree to the terms.")),
      );
      return;
    }

    final newIssue = await ref.read(issuesProvider.notifier).createIssue(
          title: _selectedCategory!, 
          description: _descriptionController.text,
          category: _selectedCategory!,
          urgency: _selectedUrgency ?? "Flexible",
          preferredLanguage: "English",
          location: _cityController.text,
          preferredMode: "Video",
          documents: _uploadedDocs,
        );

    if (newIssue != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Issue posted successfully!")),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to post issue. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Post Your Case"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Stepper Indicator
            _buildStepperHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepView(),
              ),
            ),
            // Bottom Action Navigation Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDarkMode ? AppColors.darkSurface : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepIndicator(1, "Category", _currentStep >= 0),
          _buildStepDivider(_currentStep >= 1),
          _buildStepIndicator(2, "Details", _currentStep >= 1),
          _buildStepDivider(_currentStep >= 2),
          _buildStepIndicator(3, "Documents", _currentStep >= 2),
          _buildStepDivider(_currentStep >= 3),
          _buildStepIndicator(4, "Review", _currentStep >= 3),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepNum, String title, bool isActive) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (isDarkMode ? AppColors.gold : AppColors.navyBlue)
                : (isDarkMode ? AppColors.navyBlueLight : AppColors.grey200),
          ),
          alignment: Alignment.center,
          child: Text(
            "$stepNum",
            style: TextStyle(
              color: isActive
                  ? (isDarkMode ? AppColors.navyBlue : Colors.white)
                  : (isDarkMode ? Colors.white30 : AppColors.grey500),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            color: isActive
                ? (isDarkMode ? Colors.white : AppColors.navyBlue)
                : (isDarkMode ? Colors.white38 : AppColors.grey400),
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        )
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 2,
        color: isActive
            ? (isDarkMode ? AppColors.gold : AppColors.navyBlue)
            : (isDarkMode ? AppColors.navyBlueLight : AppColors.grey200),
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Category();
      case 1:
        return _buildStep2Details();
      case 2:
        return _buildStep3Documents();
      case 3:
        return _buildStep4Review();
      default:
        return Container();
    }
  }

  Widget _buildStep1Category() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Category",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory == cat;
            return Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDarkMode ? AppColors.gold.withOpacity(0.15) : AppColors.navyBlue.withOpacity(0.05))
                    : (isDarkMode ? AppColors.darkCard : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (isDarkMode ? AppColors.gold : AppColors.navyBlue)
                      : (isDarkMode ? AppColors.borderDark : AppColors.grey200),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                onTap: () {
                  setState(() => _selectedCategory = cat);
                },
                title: Text(
                  cat,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (isDarkMode ? AppColors.gold : AppColors.navyBlue)
                        : primaryTextColor,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2Details() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;
    final secondaryTextColor = isDarkMode ? AppColors.grey300 : AppColors.grey500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Case Details",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 16),
        // Description
        Text("Brief Description of Your Case", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          style: TextStyle(color: primaryTextColor),
          decoration: InputDecoration(
            hintText: "Explain your legal issue briefly...",
            hintStyle: TextStyle(color: secondaryTextColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        // City
        Text("City / Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final selectedLoc = await LocationPickerSheet.show(context, initialLocation: _cityController.text);
            if (selectedLoc != null) {
              setState(() {
                _cityController.text = selectedLoc;
              });
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: _cityController,
              style: TextStyle(color: primaryTextColor),
              decoration: InputDecoration(
                hintText: "Select location",
                hintStyle: TextStyle(color: secondaryTextColor),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Preferred Court
        Text("Preferred Court Location (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
        const SizedBox(height: 8),
        TextField(
          controller: _courtController,
          style: TextStyle(color: primaryTextColor),
          decoration: InputDecoration(
            hintText: "Select court location",
            hintStyle: TextStyle(color: secondaryTextColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        // Budget Range
        Text("Budget Range (Optional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedBudget,
          style: TextStyle(color: primaryTextColor),
          dropdownColor: isDarkMode ? AppColors.darkCard : Colors.white,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: ["₹5,000 - ₹10,000", "₹10,000 - ₹20,000", "₹20,000 - ₹50,000", "Above ₹50,000"]
              .map((val) => DropdownMenuItem(value: val, child: Text(val, style: TextStyle(color: primaryTextColor))))
              .toList(),
          onChanged: (val) => setState(() => _selectedBudget = val),
          hint: Text("Select budget range", style: TextStyle(color: secondaryTextColor)),
        ),
        const SizedBox(height: 16),

        // Urgency
        Text("When do you need help?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedUrgency,
          style: TextStyle(color: primaryTextColor),
          dropdownColor: isDarkMode ? AppColors.darkCard : Colors.white,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: ["Urgent", "Within a Week", "Within a Month", "Flexible"]
              .map((val) => DropdownMenuItem(value: val, child: Text(val, style: TextStyle(color: primaryTextColor))))
              .toList(),
          onChanged: (val) => setState(() => _selectedUrgency = val),
          hint: Text("Select urgency", style: TextStyle(color: secondaryTextColor)),
        ),
        const SizedBox(height: 24),

        // Checkbox Agreement
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreedToTerms,
              onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  "I agree to the Terms & Conditions and Privacy Policy",
                  style: TextStyle(fontSize: 12, color: primaryTextColor),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Documents() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;
    final secondaryTextColor = isDarkMode ? AppColors.grey300 : AppColors.grey500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Upload Documents (Optional)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 4),
        Text(
          "Upload any documents related to your case.",
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
        const SizedBox(height: 20),
        // File Drag & Drop Simulation Box
        InkWell(
          onTap: _simulateUpload,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDarkMode ? AppColors.borderDark : AppColors.grey300, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isDarkMode ? AppColors.gold.withOpacity(0.15) : AppColors.navyBlue.withOpacity(0.05), shape: BoxShape.circle),
                  child: Icon(Icons.cloud_upload_outlined, size: 36, color: isDarkMode ? AppColors.gold : AppColors.navyBlue),
                ),
                const SizedBox(height: 16),
                Text("Upload Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor)),
                const SizedBox(height: 6),
                const Text("PDF, JPG, PNG (Max 10MB each)", style: TextStyle(color: AppColors.grey400, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_uploadedDocs.isNotEmpty) ...[
          Text("Uploaded Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _uploadedDocs.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = _uploadedDocs[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? AppColors.borderDark : AppColors.grey200),
                ),
                child: Row(
                  children: [
                    Icon(
                      doc.name.endsWith(".jpg") ? Icons.image : Icons.picture_as_pdf,
                      color: doc.name.endsWith(".jpg") ? Colors.blue : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
                          const SizedBox(height: 2),
                          Text(doc.size, style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.grey500, size: 18),
                      onPressed: () {
                        setState(() => _uploadedDocs.removeAt(index));
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStep4Review() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Review Your Case",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDarkMode ? AppColors.borderDark : AppColors.grey200),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow("Category", _selectedCategory ?? "Not Selected"),
              const Divider(height: 24),
              _buildReviewRow("Description", _descriptionController.text, isMultiline: true),
              const Divider(height: 24),
              _buildReviewRow("Location", _cityController.text),
              const Divider(height: 24),
              _buildReviewRow("Budget Range", _selectedBudget ?? "Not Specified"),
              const Divider(height: 24),
              _buildReviewRow("Urgency", _selectedUrgency ?? "Flexible"),
              const Divider(height: 24),
              _buildReviewRow("Documents", "${_uploadedDocs.length} Documents Uploaded"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isMultiline = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;
    final secondaryTextColor = isDarkMode ? AppColors.grey300 : AppColors.grey500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: primaryTextColor, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    final bool isLast = _currentStep == 3;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: isDarkMode ? AppColors.darkSurface : Colors.white,
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: BorderSide(color: isDarkMode ? AppColors.gold : AppColors.navyBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Back", style: TextStyle(color: isDarkMode ? AppColors.gold : AppColors.navyBlue, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (isLast) {
                  _submitCase();
                } else {
                  if (_currentStep == 0 && _selectedCategory == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please select a category first.")),
                    );
                    return;
                  }
                  if (_currentStep == 1 && (_descriptionController.text.isEmpty || !_agreedToTerms)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill the description and agree to terms.")),
                    );
                    return;
                  }
                  setState(() => _currentStep++);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? AppColors.gold : AppColors.navyBlue,
                foregroundColor: isDarkMode ? AppColors.navyBlue : Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isLast ? "Submit Case" : "Next",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
