import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/voice_recorder_button.dart';
import '../providers/ai_smart_case_provider.dart';
import 'ai_smart_case_processing_screen.dart';

class AISmartCaseIntakeScreen extends ConsumerStatefulWidget {
  const AISmartCaseIntakeScreen({super.key});

  @override
  ConsumerState<AISmartCaseIntakeScreen> createState() => _AISmartCaseIntakeScreenState();
}

class _AISmartCaseIntakeScreenState extends ConsumerState<AISmartCaseIntakeScreen> {
  final TextEditingController _descController = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  /// Mirrors the server limits: multer caps each file at 10 MB and the
  /// analyze route accepts at most 10 documents. Without these checks an
  /// oversized or eleventh file failed the entire upload server-side with an
  /// unhandled MulterError and no usable message.
  static const _maxFileBytes = 10 * 1024 * 1024;
  static const _maxFileCount = 10;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc'],
      );

      if (result == null || result.files.isEmpty) return;

      final notifier = ref.read(aiSmartCaseProvider.notifier);
      final alreadySelected = ref.read(aiSmartCaseProvider).selectedFiles.length;

      final accepted = <File>[];
      final oversized = <String>[];
      var overflowed = false;

      for (final picked in result.files) {
        if (picked.path == null) continue;

        final file = File(picked.path!);
        if (await file.length() > _maxFileBytes) {
          oversized.add(picked.name);
          continue;
        }

        if (alreadySelected + accepted.length >= _maxFileCount) {
          overflowed = true;
          break;
        }

        accepted.add(file);
      }

      if (accepted.isNotEmpty) notifier.addFiles(accepted);

      if (!mounted) return;

      final problems = <String>[
        if (oversized.isNotEmpty)
          'Skipped (over 10 MB): ${oversized.join(', ')}',
        if (overflowed) 'You can attach up to $_maxFileCount documents.',
      ];

      if (problems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(problems.join('\n'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }


  void _onProceed() async {
    final notifier = ref.read(aiSmartCaseProvider.notifier);
    if (_descController.text.trim().isNotEmpty) {
      notifier.setVoiceTranscript(_descController.text.trim());
    }

    final state = ref.read(aiSmartCaseProvider);
    if (state.selectedFiles.isEmpty && state.voiceFile == null && _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one document or record a voice note to proceed.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AISmartCaseProcessingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiSmartCaseProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060713),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080914),
        title: const Text(
          "AI Smart Case Assistant",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1035), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primaryGold, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "Smart Document & Voice Intake",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Upload FIRs, Agreements, Notices, Court Orders or record your voice.",
                            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Supported Documents Section
              const Text(
                "Upload Supporting Documents",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Supported formats: PDF, PNG, JPG, JPEG, DOCX (Multiple allowed)",
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Upload Dropzone
              GestureDetector(
                onTap: _pickFiles,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1424),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.cloud_upload_outlined, color: AppColors.primaryGold, size: 40),
                      SizedBox(height: 10),
                      Text(
                        "Tap to browse & select documents",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Select FIR, Agreements, Property Docs, Notices",
                        style: TextStyle(color: AppColors.mutedText, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Selected Files List
              if (state.selectedFiles.isNotEmpty) ...[
                Text(
                  "Selected Documents (${state.selectedFiles.length})",
                  style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = state.selectedFiles[index];
                    final fileName = file.path.split('/').last.split('\\').last;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2436),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: AppColors.primaryGold, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                            onPressed: () {
                              ref.read(aiSmartCaseProvider.notifier).removeFile(file);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Voice Recording Section
              const Text(
                "Or Describe Issue Using Voice",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Tap microphone to record voice explanation of your legal problem.",
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1424),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    // Same shared recorder as the post-case screen: small round
                    // mic, live waveform while recording, no parent rebuilds.
                    VoiceRecorderButton(
                      filePrefix: 'voice_case',
                      onRecordingStateChanged: (recording) =>
                          setState(() => _isRecording = recording),
                      onRecordingComplete: (file) {
                        ref.read(aiSmartCaseProvider.notifier).setVoiceFile(file);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Voice note recorded.')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRecording
                                ? "Recording voice..."
                                : (state.voiceFile != null ? "Voice Recorded ✓" : "Tap mic to start recording"),
                            style: TextStyle(
                              color: _isRecording ? Colors.redAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRecording
                                ? "Speak clearly into your phone"
                                : (state.voiceFile != null ? "Ready to transcribe" : "Supports English, Hindi, Telugu"),
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Additional Optional Description
              const Text(
                "Additional Written Notes (Optional)",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Add any extra details or dates if not mentioned in documents...",
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
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
              const SizedBox(height: 28),

              // Error Message Banner
              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                  ),
                ),
              ],

              // Next Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _onProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "Analyse & Generate Case with AI ➔",
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
