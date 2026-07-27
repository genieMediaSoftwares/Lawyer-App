import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/ai_smart_case_provider.dart';
import 'ai_smart_case_processing_screen.dart';

class AISmartCaseIntakeScreen extends ConsumerStatefulWidget {
  const AISmartCaseIntakeScreen({super.key});

  @override
  ConsumerState<AISmartCaseIntakeScreen> createState() => _AISmartCaseIntakeScreenState();
}

class _AISmartCaseIntakeScreenState extends ConsumerState<AISmartCaseIntakeScreen> {
  final TextEditingController _descController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void dispose() {
    _descController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'docx', 'doc'],
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        ref.read(aiSmartCaseProvider.notifier).addFiles(newFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (mounted) {
          setState(() {
            _isRecording = false;
          });
        }

        if (path != null) {
          ref.read(aiSmartCaseProvider.notifier).setVoiceFile(File(path));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice note recorded successfully!')),
            );
          }
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/voice_case_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: path,
          );

          if (mounted) {
            setState(() {
              _isRecording = true;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission required for voice recording.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
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
                    GestureDetector(
                      onTap: _toggleRecording,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red : AppColors.primaryGold,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.red : AppColors.primaryGold).withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: _isRecording ? Colors.white : Colors.black,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
