import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/ai_smart_case_provider.dart';
import 'ai_smart_questions_screen.dart';
import 'ai_case_review_screen.dart';

class AISmartCaseProcessingScreen extends ConsumerStatefulWidget {
  const AISmartCaseProcessingScreen({super.key});

  @override
  ConsumerState<AISmartCaseProcessingScreen> createState() => _AISmartCaseProcessingScreenState();
}

class _AISmartCaseProcessingScreenState extends ConsumerState<AISmartCaseProcessingScreen> {
  final List<String> _steps = [
    "Uploading Documents",
    "OCR Processing (Google Cloud Vision)",
    "AI Understanding & Context",
    "Document Classification (FIR / Notice / Contract)",
    "Generating Case Profile & Timeline",
    "Checking Duplicate Cases in MongoDB",
    "Finding Top Verified Lawyers",
    "Analysis Ready!"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProcess();
    });
  }

  Future<void> _startProcess() async {
    final notifier = ref.read(aiSmartCaseProvider.notifier);
    final success = await notifier.startIntakeAnalysis();

    if (!mounted) return;

    if (success) {
      final state = ref.read(aiSmartCaseProvider);
      final analysis = state.sessionResponse?.aiAnalysis;

      // Logic:
      // Confidence >= 90% -> Go straight to Review Screen
      // Confidence 70-89% or missing info/questions -> Go to Follow-up Questions Screen
      // Confidence < 70% -> Questions / Clarification Screen
      if (analysis != null &&
          analysis.aiConfidenceScore < 90 &&
          analysis.followUpQuestions.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AISmartQuestionsScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AICaseReviewScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSmartCaseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060713),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing AI Sphere Animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 32),

              const Text(
                "Analyzing Your Documents",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.processingStepMessage.isNotEmpty
                    ? state.processingStepMessage
                    : "Extracting legal facts and structuring your case...",
                style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // Animated Timeline Steps List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final isDone = index < state.processingStepIndex;
                  final isCurrent = index == state.processingStepIndex;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? Colors.green
                                : (isCurrent ? AppColors.primaryGold : Colors.white12),
                          ),
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.black, size: 14)
                              : (isCurrent
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : null),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _steps[index],
                            style: TextStyle(
                              color: isDone
                                  ? Colors.white
                                  : (isCurrent ? AppColors.primaryGold : Colors.white38),
                              fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Error Display & Retry Button
              if (state.errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _startProcess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Retry Analysis"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
