import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/ai_smart_case_provider.dart';
import '../widgets/voice_note_recorder.dart';
import 'ai_smart_case_processing_screen.dart';

class AISmartCaseIntakeScreen extends ConsumerStatefulWidget {
  const AISmartCaseIntakeScreen({super.key});

  @override
  ConsumerState<AISmartCaseIntakeScreen> createState() => _AISmartCaseIntakeScreenState();
}

class _AISmartCaseIntakeScreenState extends ConsumerState<AISmartCaseIntakeScreen> {
  final TextEditingController _descController = TextEditingController();
  bool _isRecording = false;

  /// Bumped whenever this intake is finished with, to give the voice note
  /// recorder a fresh key — see where it is built.
  int _intakeGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Clear anything left from a previous run. The provider outlives this
    // screen, so without this the intake reopened still holding the last
    // analysis's files, voice note and result — and a second run re-uploaded
    // the previous documents alongside the new ones.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiSmartCaseProvider.notifier).reset();
    });
  }

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
        // Mirrors EXTENSION_BY_MIME in backend/src/middleware/upload.middleware.js.
        // `.doc` is deliberately absent: the pre-2007 binary Word format has no
        // text extractor here and Gemini cannot read it, so offering it only
        // produced an upload that could never be analysed.
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'docx', 'txt', 'csv'],
        // Web has no filesystem to stream from, so the bytes must come back
        // with the pick or the file is unreadable. On native we deliberately
        // skip this and stream from the path at upload time instead — loading
        // ten 10 MB documents into memory up front is wasteful.
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final notifier = ref.read(aiSmartCaseProvider.notifier);
      final alreadySelected = ref.read(aiSmartCaseProvider).selectedFiles.length;

      final accepted = <PlatformFile>[];
      final oversized = <String>[];
      final unreadable = <String>[];
      var overflowed = false;

      for (final picked in result.files) {
        // Size comes straight from PlatformFile, which every platform
        // populates. The previous version built a `dart:io` File just to call
        // `length()` — that threw `Unsupported operation: _Namespace` on web,
        // because file_picker's web backend puts a `blob:` URL in `path`
        // (so it is never null) and `File` does not exist in a browser.
        if (picked.size > _maxFileBytes) {
          oversized.add(picked.name);
          continue;
        }

        // No bytes and no usable native path means the upload step would have
        // nothing to send. Reported separately from oversized so the message
        // matches the actual reason.
        if (picked.bytes == null && (kIsWeb || picked.path == null)) {
          unreadable.add(picked.name);
          continue;
        }

        if (alreadySelected + accepted.length >= _maxFileCount) {
          overflowed = true;
          break;
        }

        accepted.add(picked);
      }

      if (accepted.isNotEmpty) notifier.addFiles(accepted);

      if (!mounted) return;

      final problems = <String>[
        if (oversized.isNotEmpty)
          'Skipped (over 10 MB): ${oversized.join(', ')}',
        if (unreadable.isNotEmpty)
          'Could not read: ${unreadable.join(', ')}',
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


  /// Recognition locales to try, best first: the client's chosen app language,
  /// then English, which every recogniser that ships in India carries.
  List<String> _preferredSpeechLocales() {
    final language = ref.read(localeProvider).languageCode;
    return <String>[
      '${language}_IN',
      language,
      'en_IN',
      'en_US',
    ];
  }

  void _onProceed() async {
    final notifier = ref.read(aiSmartCaseProvider.notifier);
    notifier.setWrittenNotes(_descController.text.trim());

    // Submitting mid-recording would send a half-finished transcript and leave
    // the microphone open behind the processing screen.
    if (_isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please stop the recording before continuing.')),
      );
      return;
    }

    final state = ref.read(aiSmartCaseProvider);
    // The document is the primary input the AI reasons from; the voice note
    // and written notes are optional supplements, not alternatives to it.
    if (state.selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one document to proceed. A voice note or notes can add extra detail.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AISmartCaseProcessingScreen()),
    );

    // Reached once this screen is on top again — either the analysis was
    // abandoned, or it succeeded and the processing screen replaced itself with
    // the pre-filled form the client has now backed out of.
    //
    // Either way this intake is finished. `initState` alone did not cover it:
    // this screen is still mounted underneath, so returning to it never re-ran
    // that reset and left the previous document selected and its extraction in
    // memory — the "uploaded a different document, got the old data" report.
    if (!mounted) return;
    ref.read(aiSmartCaseProvider.notifier).clearForNewIntake();
    _descController.clear();
    setState(() => _intakeGeneration++);
  }

  @override
  Widget build(BuildContext context) {
    // Watched field by field rather than as a whole. The transcript is written
    // to the provider on every keystroke while the client edits it, and a plain
    // `watch` rebuilt this entire screen — dropzone, file list, recorder and
    // all — once per character typed.
    final selectedFiles =
        ref.watch(aiSmartCaseProvider.select((s) => s.selectedFiles));
    final errorMessage =
        ref.watch(aiSmartCaseProvider.select((s) => s.errorMessage));

    return Scaffold(
      backgroundColor: AppColors.aiSurfaceBackground,
      appBar: AppBar(
        backgroundColor: AppColors.aiSurfaceBackgroundAlt,
        title: const Text(
          "AI Smart Case Assistant",
          style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
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
                    colors: [AppColors.aiCardBackgroundAlt, AppColors.aiCardBackground],
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
                            "Smart Document Intake",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Upload FIRs, Agreements, Notices or Court Orders — add a voice note to explain further, if you'd like.",
                            style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Supported Documents Section — the primary, required input.
              Row(
                children: const [
                  Text(
                    "Upload Supporting Documents",
                    style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    " *",
                    style: TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "Supported formats: PDF, PNG, JPG, WEBP, DOCX, TXT (Multiple allowed)",
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
                    color: AppColors.aiCardBackground,
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
                        style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 14),
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
              if (selectedFiles.isNotEmpty) ...[
                Text(
                  "Selected Documents (${selectedFiles.length})",
                  style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedFiles.length,
                  itemBuilder: (context, index) {
                    final file = selectedFiles[index];
                    // PlatformFile.name is the real filename on every
                    // platform. Deriving it from `path` broke on web, where
                    // the path is an opaque `blob:` URL with no filename in it.
                    final fileName = file.name;
                    final fileSize = file.size < 1024 * 1024
                        ? '${(file.size / 1024).toStringAsFixed(0)} KB'
                        : '${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.aiCardBackgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryText.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: AppColors.primaryGold, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: const TextStyle(color: AppColors.primaryText, fontSize: 12.5),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  fileSize,
                                  style: TextStyle(
                                    color: AppColors.primaryText.withValues(alpha: 0.5),
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppColors.primaryText.withValues(alpha: 0.6), size: 18),
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

              // Voice Note Section — an optional supplement to the documents
              // above, not an alternative to them. Speech is transcribed on the
              // device as the client talks, so the words are ready to edit the
              // moment they stop and the analysis never waits on transcription.
              const Text(
                "Add a Voice Note (Optional)",
                style: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Explain anything the documents don't cover — your words appear as you speak.",
                style: TextStyle(color: AppColors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 12),

              VoiceNoteRecorder(
                // Rebuilt from scratch for each intake. clearForNewIntake()
                // empties the provider when this screen is returned to, and
                // without a new key the recorder would still be showing the
                // previous run's transcript in its own controller.
                key: ValueKey('voice-note-$_intakeGeneration'),
                preferredLocales: _preferredSpeechLocales(),
                onTranscriptChanged: (text) =>
                    ref.read(aiSmartCaseProvider.notifier).setVoiceTranscript(text),
                onAudioChanged: (file) =>
                    ref.read(aiSmartCaseProvider.notifier).setVoiceFile(file),
                onListeningChanged: (listening) {
                  if (_isRecording != listening) {
                    setState(() => _isRecording = listening);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Additional Optional Description
              const Text(
                "Additional Written Notes (Optional)",
                style: TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 3,
                // Kept in the provider as it is typed so it reaches the
                // pipeline as its own input, separate from the voice note.
                onChanged: (text) =>
                    ref.read(aiSmartCaseProvider.notifier).setWrittenNotes(text.trim()),
                style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Add any extra details or dates if not mentioned in documents...",
                  hintStyle: TextStyle(color: AppColors.primaryText.withValues(alpha: 0.38), fontSize: 12),
                  filled: true,
                  fillColor: AppColors.aiCardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryText.withValues(alpha: 0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primaryGold),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Error Message Banner
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text(
                    errorMessage,
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
                    foregroundColor: AppColors.onGold,
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
