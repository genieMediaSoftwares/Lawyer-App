import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../providers/ai_smart_case_provider.dart';

class AICaseReviewScreen extends ConsumerStatefulWidget {
  const AICaseReviewScreen({super.key});

  @override
  ConsumerState<AICaseReviewScreen> createState() => _AICaseReviewScreenState();
}

class _AICaseReviewScreenState extends ConsumerState<AICaseReviewScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  String _selectedCategory = 'General Legal';
  String _selectedPriority = 'Medium';

  final List<String> _categories = [
    'Property Law',
    'Criminal Law',
    'Family Law',
    'Labour & Employment',
    'Civil Law',
    'Consumer Protection',
    'Cyber Law',
    'Rental & Tenancy',
    'Motor Vehicle Accidents',
    'Cheque Bounce & Finance',
    'Documentation',
    'General Legal',
  ];

  final List<String> _priorities = ['High', 'Medium', 'Urgent', 'Flexible'];

  @override
  void initState() {
    super.initState();
    final analysis = ref.read(aiSmartCaseProvider).sessionResponse?.aiAnalysis;
    _titleController = TextEditingController(text: analysis?.caseTitle ?? '');
    _descController = TextEditingController(
      text: analysis?.caseDescription ?? '',
    );

    if (analysis != null && _categories.contains(analysis.category)) {
      _selectedCategory = analysis.category;
    }
    if (analysis != null && _priorities.contains(analysis.priority)) {
      _selectedPriority = analysis.priority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onConfirmAndSubmit() async {
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and Description cannot be empty.")),
      );
      return;
    }

    final notifier = ref.read(aiSmartCaseProvider.notifier);
    final success = await notifier.confirmAndCreateCase(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      priority: _selectedPriority,
    );

    if (!mounted) return;

    if (success) {
      // Only claim a lawyer was notified when one was actually selected —
      // without a lawyer the case is filed and nobody is contacted.
      final notified = ref.read(aiSmartCaseProvider).selectedLawyer != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notified
                ? "Case created. Your selected advocate has been notified."
                : "Case created. Advocates can now review and respond to it.",
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to My Cases
      context.go(RouteNames.myCases);
      return;
    }

    // Surface the reason instead of failing silently.
    final error = ref.read(aiSmartCaseProvider).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? "Could not create the case. Please try again."),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSmartCaseProvider);
    final session = state.sessionResponse;
    final analysis = session?.aiAnalysis;
    final duplicate = session?.duplicateCheck;
    final lawyers = session?.recommendedLawyers ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF060713),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080914),
        title: const Text(
          "Review & Confirm Legal Case",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duplicate Case Banner (if detected)
              if (duplicate != null && duplicate.isDuplicate) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning, color: Colors.amber, size: 22),
                          SizedBox(width: 8),
                          Text(
                            "Similar Existing Case Found in Database",
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "You already have a similar active case titled: \"${duplicate.existingCaseTitle}\" (${duplicate.similarityScore}% match).",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                if (duplicate.existingCaseId != null) {
                                  context.push(
                                    '${RouteNames.caseProgress}/${duplicate.existingCaseId}',
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amber,
                                side: const BorderSide(color: Colors.amber),
                              ),
                              child: const Text(
                                "Open Existing",
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // "Merge Docs" was removed: it only showed a snackbar
                          // claiming documents would be merged, while no merge
                          // was implemented anywhere. Continuing with the new
                          // case is the one action that actually works.
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Continuing with a new case. Review the details below before confirming.",
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text(
                                "Continue Anyway",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Header Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1035), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGold.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI Case Profile Generated (Confidence: ${analysis?.aiConfidenceScore ?? 0}%)",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Review and edit fields before sending to verified lawyers.",
                            style: TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Field 1: Title
              const Text(
                "Case Title",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F1424),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Field 2: Description
              const Text(
                "Detailed Legal Description",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0F1424),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryGold),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Field 3: Category Dropdown & Priority Dropdown
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Legal Category",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1424),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0F1424),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Priority",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1424),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPriority,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF0F1424),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              items: _priorities.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Text(p),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedPriority = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Timeline & Document Summary Section
              if ((analysis?.detectedTimeline ?? []).isNotEmpty) ...[
                const Text(
                  "Extracted Timeline",
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1424),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var item in analysis!.detectedTimeline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_filled,
                                color: AppColors.primaryGold,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // REAL LAWYER RECOMMENDATION SECTION (From MongoDB)
              const Text(
                "Recommended Verified Lawyers (From Live Database)",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Sorted dynamically by Rating, Experience & Success Rate",
                style: TextStyle(color: AppColors.mutedText, fontSize: 11.5),
              ),
              const SizedBox(height: 12),

              if (lawyers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1424),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "No specific lawyer match found. Your case will be posted to all open advocates.",
                    style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                  ),
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: lawyers.length,
                    itemBuilder: (context, index) {
                      final lawyer = lawyers[index];
                      final isSelected =
                          state.selectedLawyer?.userId == lawyer.userId;

                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(aiSmartCaseProvider.notifier)
                              .selectLawyer(lawyer);
                        },
                        child: Container(
                          width: 240,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E1035)
                                : const Color(0xFF0F1424),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGold
                                  : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.primaryGold
                                        .withOpacity(0.2),
                                    child: Text(
                                      lawyer.name.isNotEmpty
                                          ? lawyer.name[0]
                                          : "A",
                                      style: const TextStyle(
                                        color: AppColors.primaryGold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lawyer.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          lawyer.specialization,
                                          style: const TextStyle(
                                            color: AppColors.mutedText,
                                            fontSize: 10.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Metrics the database does not hold are omitted
                              // rather than filled with plausible numbers.
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        lawyer.rating != null
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: AppColors.primaryGold,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        lawyer.rating != null
                                            ? "${lawyer.rating!.toStringAsFixed(1)} (${lawyer.totalReviews})"
                                            : "Not yet rated",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lawyer.experience != null)
                                    Text(
                                      "${lawyer.experience} Yrs Exp",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (lawyer.winPercentage != null)
                                    Text(
                                      "Win Rate: ${lawyer.winPercentage!.toInt()}%",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else if (lawyer.isVerified)
                                    const Text(
                                      "Verified",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  Text(
                                    lawyer.consultationFee != null
                                        ? "₹${lawyer.consultationFee!.toInt()}"
                                        : "Fee on request",
                                    style: const TextStyle(
                                      color: AppColors.primaryGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 28),

              // Confirm and Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isCreatingCase ? null : _onConfirmAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: state.isCreatingCase
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Confirm & Create Legal Case ➔",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
