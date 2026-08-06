import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../post_case/screens/post_case_screen.dart';
import '../models/ai_smart_case_models.dart';
import '../providers/ai_smart_case_provider.dart';

/// One row of the pipeline timeline.
///
/// The ids match the backend's PIPELINE_STAGES exactly — this list only decides
/// how a stage is *labelled* before the server has said anything about it. Once
/// a stage is running, the line shown is the one the backend sent, so the
/// screen can say "Read document 3 of 7 — fir_copy.pdf" rather than a guess.
class _Stage {
  final String id;
  final String label;
  const _Stage(this.id, this.label);
}

const _stages = <_Stage>[
  _Stage('uploading', 'Uploading documents'),
  _Stage('queued', 'Preparing your documents'),
  _Stage('ocr', 'Reading documents'),
  _Stage('transcribing', 'Transcribing voice note'),
  _Stage('extracting', 'Extracting case details'),
  _Stage('classifying', 'Classifying the legal issue'),
  _Stage('completed', 'Analysis complete'),
];

class AISmartCaseProcessingScreen extends ConsumerStatefulWidget {
  const AISmartCaseProcessingScreen({super.key});

  @override
  ConsumerState<AISmartCaseProcessingScreen> createState() =>
      _AISmartCaseProcessingScreenState();
}

class _AISmartCaseProcessingScreenState
    extends ConsumerState<AISmartCaseProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProcess());
  }

  Future<void> _startProcess() async {
    final success = await ref.read(aiSmartCaseProvider.notifier).startExtraction();

    if (!mounted || !success) return;

    final result = ref.read(aiSmartCaseProvider).result;
    if (result == null) return;

    // Straight into the ordinary Post Case form, pre-filled. There is no
    // separate review or confirmation screen: the client edits the values in
    // the form they would have used anyway, and submits from there.
    //
    // pushReplacement so Back from the form returns to the intake screen
    // rather than to a spinner that would immediately re-run the analysis.
    unawaited(Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PostCaseScreen(prefill: result)),
    ));
  }

  /// How far the backend has got, as an index into [_stages].
  ///
  /// Unknown stage ids resolve to the current position rather than resetting
  /// the timeline, so an added backend stage degrades gracefully.
  int _reachedIndex(AnalysisProgress progress) {
    final index = _stages.indexWhere((s) => s.id == progress.stage);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSmartCaseProvider);
    final progress = state.progress;
    final activeIndex = _reachedIndex(progress);
    final hasFailed = state.errorMessage != null;

    return Scaffold(
      backgroundColor: AppColors.aiSurfaceBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.aiAccentViolet, AppColors.aiAccentAmber],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.aiAccentViolet.withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primaryText,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      "Analysing Your Documents",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // The backend's own words for what it is doing right now.
                    Text(
                      progress.message.isNotEmpty
                          ? progress.message
                          : "Starting analysis…",
                      style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Determinate: the percentage is computed server-side from
                    // real stage weights, so the bar cannot run ahead of the work.
                    if (!hasFailed) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress.percent / 100,
                          minHeight: 8,
                          backgroundColor:
                              AppColors.primaryText.withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${progress.percent}%",
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _stages.length,
                      itemBuilder: (context, index) {
                        final stage = _stages[index];
                        final isDone = !hasFailed && index < activeIndex;
                        final isCurrent = !hasFailed && index == activeIndex;

                        // Prefer the backend's live line for the running stage.
                        final label = isCurrent && progress.message.isNotEmpty
                            ? progress.message
                            : stage.label;

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
                                      ? AppColors.success
                                      : (isCurrent
                                          ? AppColors.primaryGold
                                          : AppColors.primaryText
                                              .withValues(alpha: 0.12)),
                                ),
                                child: isDone
                                    ? const Icon(Icons.check,
                                        color: AppColors.onGold, size: 14)
                                    : (isCurrent && stage.id != 'completed'
                                        ? const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.onGold,
                                            ),
                                          )
                                        : (isCurrent
                                            ? const Icon(Icons.check,
                                                color: AppColors.onGold, size: 14)
                                            : null)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isDone
                                        ? AppColors.primaryText
                                        : (isCurrent
                                            ? AppColors.primaryGold
                                            : AppColors.primaryText
                                                .withValues(alpha: 0.38)),
                                    fontWeight: isCurrent || isDone
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    if (hasFailed) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Back"),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _startProcess,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGold,
                              foregroundColor: AppColors.onGold,
                            ),
                            child: const Text("Retry Analysis"),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
