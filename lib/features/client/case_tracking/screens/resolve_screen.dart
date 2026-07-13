import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/issue_provider.dart';
import '../../../../providers/case_provider.dart';
import '../../../../models/issue_model.dart';
import '../../../../core/network/dio_client.dart';

class ResolveScreen extends ConsumerStatefulWidget {
  const ResolveScreen({super.key});

  @override
  ConsumerState<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends ConsumerState<ResolveScreen> {
  final List<String> _timelineSteps = [
    "Issue Submitted",
    "Lawyer Assigned",
    "Consultation",
    "Legal Action",
    "Completed",
  ];

  final _feedbackController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmittingFeedback = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  int _getStepIndex(String status) {
    switch (status) {
      case 'Pending':
        return 1;
      case 'Assigned':
        return 2;
      case 'Resolved':
        return 4;
      case 'Closed':
        return 5;
      default:
        return 1;
    }
  }

  Future<void> _submitFeedback(String lawyerId) async {
    if (_feedbackController.text.trim().isEmpty) return;
    
    setState(() => _isSubmittingFeedback = true);
    try {
      final response = await DioClient.dio.post("/reviews", data: {
        "lawyerId": lawyerId,
        "rating": _rating.toInt(),
        "review": _feedbackController.text,
      });

      if (response.data != null && response.data['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback submitted successfully!")));
        _feedbackController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to submit feedback.")));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuesState = ref.watch(issuesProvider);
    final casesState = ref.watch(casesProvider);
    final theme = Theme.of(context);

    String? associatedLawyerId;
    casesState.whenData((cases) {
      if (cases.isNotEmpty) {
        final matchingCase = cases.firstWhere(
          (c) => c.status == 'In Progress' || c.status == 'Closed' || c.status == 'Completed',
          orElse: () => cases.first,
        );
        associatedLawyerId = matchingCase.assignedLawyerId ?? matchingCase.selectedLawyerId;
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text("Resolve / Tracking", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: issuesState.when(
        data: (issues) {
          if (issues.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.track_changes, size: 72, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text("No Issues for Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleMedium?.color)),
                    const SizedBox(height: 8),
                    Text("Post a new legal issue to track its resolution timeline in real-time.", textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => context.push('/post-case'),
                      child: const Text("Post Issue Now"),
                    )
                  ],
                ),
              ),
            );
          }

          // Render first active/pending issue for tracking, or list them in a dropdown/picker
          final activeIssue = issues.first;

          final currentStep = _getStepIndex(activeIssue.status);
          final progressPercent = currentStep / _timelineSteps.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Issue Header Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeIssue.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleMedium?.color)),
                            const SizedBox(height: 4),
                            Text("Category: ${activeIssue.category}", style: TextStyle(color: theme.textTheme.bodyMedium?.color, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text("Posted on ${DateFormat('dd MMM yyyy').format(activeIssue.createdAt)}", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activeIssue.status,
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Progress Bar
                Text("Resolution Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.titleMedium?.color)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 12,
                    backgroundColor: theme.colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 24),

                // Vertical Timeline
                Text("Resolution Milestone Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.titleMedium?.color)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    children: List.generate(_timelineSteps.length, (index) {
                      final stepTitle = _timelineSteps[index];
                      final isCompleted = index < currentStep;
                      final isLast = index == _timelineSteps.length - 1;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCompleted ? AppColors.success : theme.colorScheme.surface,
                                    border: Border.all(color: isCompleted ? AppColors.success : theme.colorScheme.outline, width: 2),
                                  ),
                                  child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                                ),
                                if (!isLast)
                                  Expanded(
                                    child: Container(
                                      width: 2,
                                      color: isCompleted ? AppColors.success : theme.colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Text(
                                stepTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted ? theme.colorScheme.onSurface : theme.textTheme.bodySmall?.color,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),

                // Feedback Form (Only show if issue status is closed/resolved, or show for general rating)
                Text("Submit Case Feedback", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.titleMedium?.color)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Rate your experience:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _rating ? Icons.star : Icons.star_border,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                            onPressed: () {
                              setState(() => _rating = index + 1.0);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _feedbackController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Write your feedback or notes regarding the issue resolution process...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: (_isSubmittingFeedback || associatedLawyerId == null)
                            ? null
                            : () => _submitFeedback(associatedLawyerId!),
                        child: _isSubmittingFeedback
                            ? const CircularProgressIndicator()
                            : const Text("Submit Review"),
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
