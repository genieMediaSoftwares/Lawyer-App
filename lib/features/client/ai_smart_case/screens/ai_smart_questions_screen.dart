import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/ai_smart_case_provider.dart';
import 'ai_case_review_screen.dart';

class AISmartQuestionsScreen extends ConsumerStatefulWidget {
  const AISmartQuestionsScreen({super.key});

  @override
  ConsumerState<AISmartQuestionsScreen> createState() => _AISmartQuestionsScreenState();
}

class _AISmartQuestionsScreenState extends ConsumerState<AISmartQuestionsScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submitAnswers() async {
    final notifier = ref.read(aiSmartCaseProvider.notifier);
    for (var entry in _controllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        notifier.updateAnswer(entry.key, entry.value.text.trim());
      }
    }

    final success = await notifier.submitFollowUpAnswers();
    if (mounted && success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AICaseReviewScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSmartCaseProvider);
    final analysis = state.sessionResponse?.aiAnalysis;
    final readinessScore = analysis?.readinessScore ?? 85;
    final questions = analysis?.followUpQuestions ?? [];
    final fraudFlags = analysis?.fraudFlags ?? [];
    final missingInfo = analysis?.missingInformation ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF060713),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080914),
        title: const Text(
          "AI Smart Questions & Readiness",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Case Readiness Score Header Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1035), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryGold.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    // Score Circle
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F1424),
                        border: Border.all(
                          color: readinessScore >= 80 ? Colors.green : AppColors.primaryGold,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          "$readinessScore%",
                          style: TextStyle(
                            color: readinessScore >= 80 ? Colors.green : AppColors.primaryGold,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Case Readiness Score",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            readinessScore >= 90
                                ? "Excellent! Your case documents contain complete details."
                                : "Good progress. Answering a few quick questions will improve lawyer matching.",
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Checklist Section
              const Text(
                "Readiness Checklist",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1424),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _ChecklistItem(text: "Documents Uploaded & Processed", isSuccess: true),
                    _ChecklistItem(text: "Legal Category Detected (${analysis?.category ?? 'General'})", isSuccess: true),
                    _ChecklistItem(text: "Timeline Extracted (${analysis?.detectedTimeline.length ?? 0} events)", isSuccess: (analysis?.detectedTimeline.length ?? 0) > 0),
                    _ChecklistItem(text: "Priority Detected (${analysis?.priority ?? 'Medium'})", isSuccess: true),
                    for (var missing in missingInfo)
                      _ChecklistItem(text: "$missing Missing", isSuccess: false),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Fraud & Quality Detection Warnings (if any)
              if (fraudFlags.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Document Warning / Quality Alert",
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (var flag in fraudFlags)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text("• $flag", style: const TextStyle(color: Color(0xFFFED7AA), fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Intelligent AI Follow-up Questions Section
              if (questions.isNotEmpty) ...[
                const Text(
                  "AI Intelligent Follow-up Questions",
                  style: TextStyle(color: AppColors.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Help us complete your case profile by providing quick answers:",
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 12),

                for (var i = 0; i < questions.length; i++) ...[
                  Builder(builder: (context) {
                    final q = questions[i];
                    if (!_controllers.containsKey(q)) {
                      _controllers[q] = TextEditingController();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1424),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${i + 1}. $q",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _controllers[q],
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "Type your answer here...",
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF1E2436),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 20),
              ],

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isAnalyzing ? null : _submitAnswers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: state.isAnalyzing
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Save Answers & Review Case ➔",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
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

class _ChecklistItem extends StatelessWidget {
  final String text;
  final bool isSuccess;

  const _ChecklistItem({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isSuccess ? Colors.green : Colors.orange,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSuccess ? Colors.white : Colors.white70,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
