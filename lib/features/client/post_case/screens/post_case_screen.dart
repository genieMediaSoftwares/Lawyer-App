import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/env.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/document_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/category_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../widgets/premium_audio_player.dart';
import '../../../../core/widgets/voice_recorder_button.dart';
import '../../../../core/widgets/location_autocomplete_field.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/category_item.dart';
import 'package:intl/intl.dart';
import '../../../../providers/court_provider.dart';
import '../../../../routes/route_names.dart';
import '../../ai_smart_case/models/ai_smart_case_models.dart';
import '../../ai_smart_case/providers/ai_smart_case_provider.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../chat/presentation/screens/advocates_screen.dart' show AdvocateCard;

class PostCaseScreen extends ConsumerStatefulWidget {
  final String? preselectedCategoryId;

  /// Field values extracted from uploaded documents by the AI intake flow.
  ///
  /// When present the form opens pre-filled and the client edits from there.
  /// Null for a normal, manually-started case. Nothing is submitted on the
  /// client's behalf either way — they always review and press submit.
  final ExtractionResult? prefill;

  const PostCaseScreen({
    super.key,
    this.preselectedCategoryId,
    this.prefill,
  });

  @override
  ConsumerState<PostCaseScreen> createState() => _PostCaseScreenState();
}

class _PostCaseScreenState extends ConsumerState<PostCaseScreen> {
  int _currentStep = 0;

  String _sortByFilter = "Best Match";

  // ── Structured case detail ───────────────────────────────────────────────
  // Always shown: an incident date and the other side are relevant to nearly
  // every category.
  DateTime? _incidentDate;
  final _opposingPartyController = TextEditingController();

  // Shown only for Criminal Law, Cyber Crime and Motor Accident Claims — the
  // 3 of 15 categories where these mean anything. See [_showCriminalFields].
  final _firNumberController = TextEditingController();
  final _policeStationController = TextEditingController();
  final _bailDetailsController = TextEditingController();

  /// Categories for which the FIR / police station / bail group is relevant.
  /// Mirrors CRIMINAL_LIKE_CATEGORY_IDS in backend/src/config/legalCategories.js.
  static const _criminalLikeCategories = {
    'Criminal Law',
    'Cyber Crime',
    'Motor Accident Claims',
  };

  bool get _showCriminalFields =>
      _selectedCategory != null &&
      _criminalLikeCategories.contains(_selectedCategory);

  // Form State State Getters linked to Riverpod Single Source of Truth
  String? get _selectedCategory {
    final activeState = ref.read(selectedCategoryProvider);
    if (activeState.categoryId == null) return null;
    try {
      return _categories
          .firstWhere((c) => c.id == activeState.categoryId)
          .title;
    } catch (_) {
      return null;
    }
  }

  String? get _selectedSubcategory {
    return ref.read(selectedCategoryProvider).subcategory;
  }

  String? _expandedCategory;
  final Map<String, GlobalKey> _categoryKeys = {};

  // Voice Recording & Transcription State.
  // The recorder itself (permission, encoder, timer, amplitude stream) lives
  // in VoiceRecorderButton; this screen only tracks the result.
  final GlobalKey _recorderKey = GlobalKey();
  bool _isRecording = false;
  String? _recordedFilePath;

  // Transcription states
  bool _isTranscribing = false;
  String? _transcribeError;

  // Replay source path
  String? _audioPlayerSource;

  /// The case title. Pre-filled from the AI extraction when one was produced;
  /// otherwise the client writes it. Falls back to the sub-type on submit so a
  /// manually-filed case behaves exactly as it did before this field existed.
  final _titleController = TextEditingController();

  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _courtController = TextEditingController();
  String? _selectedUrgency;
  bool _agreedToTerms = false;

  final List<DocumentModel> _uploadedDocs = [];

  // ── AI intake context ────────────────────────────────────────────────────
  // Populated only when the form was opened from the AI Smart Assistant. All
  // of it is read-only reporting: what the analysis understood, and what it
  // could not read. None of it is submitted as case data on its own.

  /// Fields the model filled but was not confident enough about. The server has
  /// already blanked their values; naming them here lets the form ask the
  /// client for them instead of pre-filling a guess.
  Set<String> _needsReview = const {};

  /// Documents the AI intake already uploaded and catalogued, kept so the
  /// document step can show them as attached rather than asking again.
  final List<DocumentRecord> _aiUploadedDocs = [];

  /// The lawyer the client picked on the final step, or null while unchosen.
  LawyerModel? _selectedLawyerModel;

  /// Amount in dispute, when the analysis found one stated in the documents.
  /// Null means no sum was identified — never zero, which would read as a
  /// claim for nothing.
  double? _claimAmount;

  /// Guards the submit button against a double tap creating two cases.
  bool _isSubmitting = false;

  // Location Autocomplete State
  String? _selectedCityName;
  String? _selectedDistrictName;
  String? _selectedStateName;
  String? _selectedCountryName;
  double? _selectedLatitude;
  double? _selectedLongitude;

  // Court Suggestions State
  String? _selectedCourtName;
  String _courtFilter = "";
  bool _showCourtSuggestions = false;

  bool _hasTouchedDescription = false;

  // Document Upload State
  DocumentRecord? _uploadedDocRecord;
  bool _isDocUploading = false;
  String? _docErrorText;

  /// Shared height for the upload panel's idle / uploading / uploaded states so
  /// the section does not resize as it moves between them.
  static const double _kDocPanelMinHeight = 190;

  final List<CategoryData> _categories = allCategories;

  @override
  void initState() {
    super.initState();

    // A prefill from the AI intake flow wins over any saved draft: the client
    // just uploaded documents for this specific matter, so a stale half-typed
    // draft from a previous session would be the wrong thing to show.
    if (widget.prefill != null) {
      _applyPrefill(widget.prefill!);
      return;
    }

    _loadDraft().then((_) {
      if (widget.preselectedCategoryId != null) {
        final preselectedId = widget.preselectedCategoryId!.trim();
        try {
          final matchedCategory = _categories.firstWhere(
            (c) => c.id == preselectedId,
          );
          ref
              .read(selectedCategoryProvider.notifier)
              .selectCategory(matchedCategory.id);
          setState(() {
            _expandedCategory = matchedCategory.title;
          });
          _scrollToCategory(matchedCategory.title);
          _saveDraft();
        } catch (_) {
          // fallback if category not found
        }
      } else {
        // If there was a loaded selected category from draft, expand it
        final activeState = ref.read(selectedCategoryProvider);
        if (activeState.categoryId != null) {
          try {
            final cat = _categories.firstWhere(
              (c) => c.id == activeState.categoryId,
            );
            setState(() {
              _expandedCategory = cat.title;
            });
            _scrollToCategory(cat.title);
          } catch (_) {}
        }
      }
    });

    final userLocation = ref.read(authProvider).userLocation;
    if (userLocation != null && userLocation.isNotEmpty) {
      _cityController.text = userLocation;
      final parts = userLocation.split(',');
      _selectedCityName = parts[0].trim();
      if (parts.length > 1) {
        _selectedStateName = parts[1].trim();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(courtsProvider.notifier)
            .fetchCourtsForLocation(
              city: _selectedCityName!,
              district: _selectedDistrictName,
              stateName: _selectedStateName ?? "",
            );
      });
    }
  }

  void _scrollToCategory(String categoryTitle) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _categoryKeys[categoryTitle]?.currentContext;
      if (keyContext != null && mounted) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _opposingPartyController.dispose();
    _firNumberController.dispose();
    _policeStationController.dispose();
    _bailDetailsController.dispose();
    _cityController.dispose();
    _courtController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeState = ref.read(selectedCategoryProvider);
      await prefs.setString(
        "draft_selectedCategoryId",
        activeState.categoryId ?? "",
      );
      await prefs.setString(
        "draft_selectedSubcategory",
        activeState.subcategory ?? "",
      );
      await prefs.setString("draft_expandedCategory", _expandedCategory ?? "");
      await prefs.setString("draft_description", _descriptionController.text);
      await prefs.setString("draft_recordedFilePath", _recordedFilePath ?? "");
      await prefs.setString("draft_cityName", _selectedCityName ?? "");
      await prefs.setString("draft_stateName", _selectedStateName ?? "");
      await prefs.setString("draft_cityText", _cityController.text);
      await prefs.setString("draft_courtName", _selectedCourtName ?? "");
      await prefs.setString("draft_urgency", _selectedUrgency ?? "");
      await prefs.setString(
          "draft_incidentDate", _incidentDate?.toIso8601String() ?? "");
      await prefs.setString(
          "draft_opposingParty", _opposingPartyController.text);
      await prefs.setString("draft_firNumber", _firNumberController.text);
      await prefs.setString(
          "draft_policeStation", _policeStationController.text);
      await prefs.setString("draft_bailDetails", _bailDetailsController.text);
    } catch (e) {
      debugPrint("Error saving draft: $e");
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catId = prefs.getString("draft_selectedCategoryId");
      final sub = prefs.getString("draft_selectedSubcategory");
      final exp = prefs.getString("draft_expandedCategory");
      final desc = prefs.getString("draft_description");
      final path = prefs.getString("draft_recordedFilePath");
      final city = prefs.getString("draft_cityName");
      final state = prefs.getString("draft_stateName");
      final cityText = prefs.getString("draft_cityText");
      final court = prefs.getString("draft_courtName");
      final urgency = prefs.getString("draft_urgency");
      final incidentDateRaw = prefs.getString("draft_incidentDate");
      final opposingParty = prefs.getString("draft_opposingParty");
      final firNumber = prefs.getString("draft_firNumber");
      final policeStation = prefs.getString("draft_policeStation");
      final bailDetails = prefs.getString("draft_bailDetails");

      if (mounted) {
        if (catId != null && catId.isNotEmpty) {
          ref
              .read(selectedCategoryProvider.notifier)
              .selectSubcategory(catId, sub);
        }
        setState(() {
          if (exp != null && exp.isNotEmpty) {
            _expandedCategory = exp;
          } else if (catId != null && catId.isNotEmpty) {
            try {
              final cat = _categories.firstWhere((c) => c.id == catId);
              _expandedCategory = cat.title;
            } catch (_) {}
          }
          if (desc != null && desc.isNotEmpty) {
            _descriptionController.text = desc;
          }
          if (path != null && path.isNotEmpty) {
            _recordedFilePath = path;
            _audioPlayerSource = path;
          }
          if (city != null && city.isNotEmpty) _selectedCityName = city;
          if (state != null && state.isNotEmpty) _selectedStateName = state;
          if (cityText != null && cityText.isNotEmpty) {
            _cityController.text = cityText;
          }
          if (court != null && court.isNotEmpty) _selectedCourtName = court;
          if (urgency != null && urgency.isNotEmpty) _selectedUrgency = urgency;

          if (incidentDateRaw != null && incidentDateRaw.isNotEmpty) {
            _incidentDate = DateTime.tryParse(incidentDateRaw);
          }
          if (opposingParty != null) {
            _opposingPartyController.text = opposingParty;
          }
          if (firNumber != null) _firNumberController.text = firNumber;
          if (policeStation != null) {
            _policeStationController.text = policeStation;
          }
          if (bailDetails != null) _bailDetailsController.text = bailDetails;
        });

        // Scroll to preselected or loaded category card
        if (_expandedCategory != null) {
          _scrollToCategory(_expandedCategory!);
        }
      }
    } catch (e) {
      debugPrint("Error loading draft: $e");
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("draft_selectedCategoryId");
      await prefs.remove("draft_selectedSubcategory");
      await prefs.remove("draft_expandedCategory");
      await prefs.remove("draft_description");
      await prefs.remove("draft_recordedFilePath");
      await prefs.remove("draft_cityName");
      await prefs.remove("draft_stateName");
      await prefs.remove("draft_cityText");
      await prefs.remove("draft_courtName");
      await prefs.remove("draft_urgency");
      await prefs.remove("draft_incidentDate");
      await prefs.remove("draft_opposingParty");
      await prefs.remove("draft_firNumber");
      await prefs.remove("draft_policeStation");
      await prefs.remove("draft_bailDetails");
      ref.read(selectedCategoryProvider.notifier).clearSelection();
    } catch (e) {
      debugPrint("Error clearing draft: $e");
    }
  }

  Future<void> _transcribeAudio(String path) async {
    setState(() {
      _isTranscribing = true;
      _transcribeError = null;
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception("Audio file not found.");
      }

      final formData = FormData.fromMap({
        "audio": await MultipartFile.fromFile(
          path,
          filename: "recording.m4a",
          contentType: MediaType("audio", "mp4"),
        ),
      });

      final response = await DioClient.dio.post(
        "/ai/transcribe",
        data: formData,
      );

      if (response.data != null && response.data['success'] == true) {
        final String transcript = response.data['data']['transcript'] ?? "";
        if (transcript.isNotEmpty) {
          _handleNewTranscript(transcript);
        }
      } else {
        throw Exception(response.data?['message'] ?? "Transcription failed");
      }
    } catch (e) {
      debugPrint("Error transcribing audio: $e");
      if (mounted) {
        setState(() {
          _transcribeError = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  void _handleNewTranscript(String newText) {
    final existingText = _descriptionController.text.trim();
    if (existingText.isEmpty) {
      _descriptionController.text = newText;
      setState(() {
        _hasTouchedDescription = true;
      });
      _saveDraft();
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text("New Transcript Available"),
            content: const Text(
              "You already have some description text. Would you like to append the new transcript to it, or replace it entirely?",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _descriptionController.text = "$existingText\n\n$newText";
                  setState(() {
                    _hasTouchedDescription = true;
                  });
                  _saveDraft();
                },
                child: const Text(
                  "APPEND",
                  style: TextStyle(color: AppColors.primaryGold),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _descriptionController.text = newText;
                  setState(() {
                    _hasTouchedDescription = true;
                  });
                  _saveDraft();
                },
                child: const Text(
                  "REPLACE",
                  style: TextStyle(color: AppColors.primaryGold),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildDescriptionSection(
    ThemeData theme,
    Color? primaryTextColor,
    Color? secondaryTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 6,
              style: TextStyle(color: primaryTextColor),
              onChanged: (val) {
                setState(() {
                  _hasTouchedDescription = true;
                });
                _saveDraft();
              },
              decoration: InputDecoration(
                hintText: "Briefly explain your legal issue...",
                hintStyle: TextStyle(color: secondaryTextColor),
                errorText: _hasTouchedDescription && _descriptionError != null
                    ? _descriptionError
                    : null,
                contentPadding: const EdgeInsets.only(
                  left: 16,
                  right: 48, // Leave space for microphone button
                  top: 16,
                  bottom:
                      40, // Space so text doesn't hide behind positioned mic button
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              // Small round mic button. Owns its own recording state, so the
              // amplitude stream no longer rebuilds this entire screen.
              child: VoiceRecorderButton(
                key: _recorderKey,
                filePrefix: 'case_desc',
                onRecordingStateChanged: (recording) {
                  setState(() => _isRecording = recording);
                  if (!recording) _saveDraft();
                },
                onRecordingComplete: (file) {
                  setState(() {
                    _recordedFilePath = file.path;
                    _audioPlayerSource = file.path;
                    _transcribeError = null;
                  });
                  _saveDraft();
                  _transcribeAudio(file.path);
                },
              ),
            ),
            if (_isTranscribing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.shadow.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(height: 8),
                      Text(
                        "Transcribing voice to English...",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        // The elapsed time, live waveform, discard and stop controls all live
        // inside VoiceRecorderButton now, so there is no separate bar here.
        if (_isRecording) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const _PulsingRecordDot(),
              const SizedBox(width: 8),
              Text(
                "Recording — tap stop when you're done",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
        if (_transcribeError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Transcription error: $_transcribeError",
                  style: const TextStyle(color: AppColors.error, fontSize: 11),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (_recordedFilePath != null) {
                    _transcribeAudio(_recordedFilePath!);
                  }
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text("Retry", style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
        if (_audioPlayerSource != null) ...[
          const SizedBox(height: 12),
          PremiumAudioPlayer(
            source: _audioPlayerSource!,
            onDelete: () {
              setState(() {
                _audioPlayerSource = null;
                _recordedFilePath = null;
              });
              _saveDraft();
            },
            // Clearing the clip reveals the mic button again; the user taps it
            // to record afresh. Driving the recorder from here would mean
            // reaching into another widget's state.
            onReRecord: () {
              setState(() {
                _audioPlayerSource = null;
                _recordedFilePath = null;
                _transcribeError = null;
              });
              _saveDraft();
            },
          ),
        ],
      ],
    );
  }

  /// Populates the form from AI-extracted document data.
  ///
  /// Only writes fields the extractor actually resolved — a blank stays blank
  /// rather than being filled with a guess, because a wrong value the client
  /// does not notice is worse than an empty one they do. Everything written
  /// here remains fully editable; nothing is submitted automatically.
  /// Copies the AI extraction into the form.
  ///
  /// The one rule here is that a value the analysis did not produce is left
  /// blank. Earlier this method filled every gap with an invented stand-in —
  /// a description reading "Legal case assistance request based on uploaded
  /// document details.", a city of "Online Location", an urgency of
  /// "Within 15 Days", and the first category in the list whenever
  /// classification failed. Those all passed the submit validation, so they
  /// were filed verbatim as the client's legal case. The backend goes to
  /// considerable trouble to return null rather than guess (see
  /// CONFIDENCE_FLOOR in aiSmartIntakeService.js); throwing that away at the
  /// last step defeated the entire pipeline.
  ///
  /// Nothing is auto-agreed and nothing is auto-submitted: the client still
  /// accepts the terms and presses submit themselves.
  void _applyPrefill(ExtractionResult result) {
    final data = result.extracted;

    _needsReview = data.needsReview.toSet();

    if (data.title.isNotEmpty) _titleController.text = data.title;

    if (data.description.isNotEmpty) {
      _descriptionController.text = data.description;
      _hasTouchedDescription = true;
    }

    // Category + sub-type. Resolved against the app's own taxonomy; when
    // nothing matched, the dropdown stays untouched so the client chooses.
    CategoryData? matched;
    if (data.category != null || data.categoryId != null) {
      for (final c in _categories) {
        if (c.id == data.categoryId || c.title == data.category) {
          matched = c;
          break;
        }
      }
    }
    if (matched != null) _expandedCategory = matched.title;

    // The selection lives in a provider, and this runs from initState while the
    // tree is still building — writing to it here throws. Resolve the match
    // above synchronously, commit it once the first frame is done.
    final resolved = matched;
    final extractedSubType = data.subType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || resolved == null) return;
      // Only select a sub-type the extraction actually identified. Defaulting
      // to `subcategories.first` used to put a wrong sub-type on the case —
      // and, because the title was derived from it, a wrong title too.
      if (extractedSubType != null &&
          resolved.subcategories.contains(extractedSubType)) {
        ref
            .read(selectedCategoryProvider.notifier)
            .selectSubcategory(resolved.id, extractedSubType);
      } else {
        ref.read(selectedCategoryProvider.notifier).selectCategory(resolved.id);
      }
    });

    if (data.city.isNotEmpty) {
      _selectedCityName = data.city;
      _selectedStateName = data.state.isNotEmpty ? data.state : null;
      _cityController.text =
          data.location.isNotEmpty ? data.location : data.city;
    }

    if (data.court.isNotEmpty) {
      _selectedCourtName = data.court;
      _courtController.text = data.court;
    }

    // Left null when the analysis had no view on urgency — the client picks.
    _selectedUrgency = data.urgency != null ? _mapUrgency(data.urgency!) : null;

    _incidentDate = data.incidentDate;
    _opposingPartyController.text = data.opposingParty;
    _firNumberController.text = data.firNumber;
    _policeStationController.text = data.policeStation;
    _bailDetailsController.text = data.bailDetails;
    _claimAmount = data.claimAmount;

    // The intake already uploaded these and registered each one in the same
    // Document collection the manual upload writes to, so they count as
    // attached. Previously they were added for display only, which left the
    // document step believing nothing had been uploaded: the review row read
    // "None Uploaded" and stepping back to it blocked the client behind a
    // required upload they had already completed.
    for (final doc in result.uploadedDocuments) {
      if (doc.originalName.isEmpty) continue;

      _uploadedDocs.add(DocumentModel(
        name: doc.originalName,
        url: Environment.getAttachmentUrl(doc.url),
        size: doc.size > 0
            ? "${(doc.size / (1024 * 1024)).toStringAsFixed(1)} MB"
            : '',
      ));

      if (doc.documentId.isNotEmpty) {
        _aiUploadedDocs.add(DocumentRecord(
          id: doc.documentId,
          clientId: '',
          originalName: doc.originalName,
          fileName: doc.originalName,
          filePath: doc.url,
          mimeType: doc.mimeType,
          fileSize: doc.size,
          uploadedAt: DateTime.now(),
        ));
      }
    }

    // The document step's validation is written against a single record; the
    // first AI upload satisfies it while `_uploadedDocs` carries them all
    // through to submission.
    if (_aiUploadedDocs.isNotEmpty) _uploadedDocRecord = _aiUploadedDocs.first;

    // Open on the lawyer step, which is what the client came here to do. Every
    // earlier step remains reachable with Back, and each is pre-filled with
    // whatever the analysis established — and blank where it did not.
    _currentStep = _lawyerStepIndex;
  }

  /// The extractor returns a coarse urgency; the form offers specific windows.
  String? _mapUrgency(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'urgent':
        return 'Immediately (Within 24 Hours)';
      case 'high':
        return 'This Week';
      case 'medium':
        return 'Within 15 Days';
      case 'flexible':
        return 'Within One Month';
      default:
        return null;
    }
  }

  Future<void> _pickIncidentDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      // An incident cannot be in the future, and cases older than ~30 years
      // are outside any realistic limitation period.
      firstDate: DateTime(now.year - 30),
      lastDate: now,
      helpText: 'When did the incident happen?',
    );

    if (picked == null || !mounted) return;
    setState(() => _incidentDate = picked);
    _saveDraft();
  }

  Future<void> _submitCase() async {
    if (_selectedCategory == null ||
        _selectedSubcategory == null ||
        _descriptionController.text.trim().length < 20 ||
        _selectedCityName == null ||
        !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please complete all required fields and agree to the terms.",
          ),
        ),
      );
      return;
    }

    if (_selectedLawyerModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose an advocate for your case.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? voiceUrl;
    if (_recordedFilePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Uploading voice description recording..."),
        ),
      );
      try {
        final docRecord = await ref
            .read(documentsProvider.notifier)
            .uploadDocument(
              _recordedFilePath!,
              "voice_description_${DateTime.now().millisecondsSinceEpoch}.m4a",
            );
        if (docRecord != null) {
          voiceUrl = Environment.getAttachmentUrl(docRecord.filePath);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload audio recording: $e")),
        );
        return;
      }
    }

    // The client's own title when they gave one, otherwise the sub-type —
    // which is what every case used before the title field existed.
    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _selectedSubcategory!;

    final newCase = await ref
        .read(casesProvider.notifier)
        .createCase(
          title: title,
          description: _descriptionController.text,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory!,
          location: _cityController.text,
          urgency: _selectedUrgency ?? "Flexible",
          preferredCourt: _selectedCourtName,
          documents: _uploadedDocs,
          // Chosen on the final step, so the case is filed with this advocate
          // attached and reaches them as a direct request.
          selectedLawyer: _selectedLawyerModel?.userId,
          voiceUrl: voiceUrl,
          voiceTranscript: _recordedFilePath != null
              ? _descriptionController.text
              : null,
          city: _selectedCityName,
          district: _selectedDistrictName,
          stateName: _selectedStateName,
          country: _selectedCountryName,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          incidentDate: _incidentDate,
          opposingParty: _opposingPartyController.text.trim(),
          firNumber: _showCriminalFields ? _firNumberController.text.trim() : null,
          policeStation:
              _showCriminalFields ? _policeStationController.text.trim() : null,
          bailDetails:
              _showCriminalFields ? _bailDetailsController.text.trim() : null,
          claimAmount: _claimAmount,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (newCase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to post case. Please try again.")),
      );
      return;
    }

    _clearDraft();

    // Close the audit trail from uploaded document through to filed case.
    // Best-effort — the case already exists either way.
    final sessionId = widget.prefill?.sessionId;
    if (sessionId != null && sessionId.isNotEmpty) {
      await ref.read(aiSmartCaseRepositoryProvider).linkSessionToCase(
            sessionId: sessionId,
            caseId: newCase.id,
          );
    }

    // Refresh everything derived from the case list so My Cases, the
    // dashboards, badge counts and notifications reflect the new case without
    // the client reopening or refreshing anything. `casesProvider` has already
    // inserted it locally; these are the views that read from their own
    // endpoints.
    await ref.read(casesProvider.notifier).caseChanged();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Case posted and sent to ${_selectedLawyerModel!.fullName}.",
        ),
      ),
    );
    context.go(RouteNames.myCases);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(selectedCategoryProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Post Your Case"),
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
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Five steps, ending on lawyer selection: the client chooses their
          // advocate before the case is created, so it is filed with that
          // lawyer attached rather than going out unassigned. The AI intake
          // opens the form directly on the final step — see [_applyPrefill].
          _buildStepIndicator(1, "Category", _currentStep >= 0),
          _buildStepDivider(_currentStep >= 1),
          _buildStepIndicator(2, "Details", _currentStep >= 1),
          _buildStepDivider(_currentStep >= 2),
          _buildStepIndicator(3, "Documents", _currentStep >= 2),
          _buildStepDivider(_currentStep >= 3),
          _buildStepIndicator(4, "Review", _currentStep >= 3),
          _buildStepDivider(_currentStep >= 4),
          _buildStepIndicator(5, "Lawyer", _currentStep >= 4),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepNum, String title, bool isActive) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          alignment: Alignment.center,
          child: Text(
            "$stepNum",
            style: TextStyle(
              color: isActive
                  ? AppColors.onGold
                  : theme.textTheme.bodySmall?.color,
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
                ? theme.textTheme.titleMedium?.color
                : theme.textTheme.bodySmall?.color,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  /// Index of the final step. Named because several places need it and a bare
  /// `4` scattered around is what let the stepper, the action bar and the AI
  /// prefill drift apart previously.
  static const int _lawyerStepIndex = 4;

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Category();
      case 1:
        return _buildStep2Details();
      case 2:
        return _buildStep3Documents();
      case 3:
        return _buildStep5Review();
      case _lawyerStepIndex:
        return _buildStep6Lawyer();
      default:
        return Container();
    }
  }

  Widget _buildStep1Category() {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Category",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            return _buildCategoryCard(_categories[index]);
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryData cat) {
    final theme = Theme.of(context);
    final selectedCategoryState = ref.watch(selectedCategoryProvider);
    final isExpanded = _expandedCategory == cat.title;
    final isHighlighted = selectedCategoryState.categoryId == cat.id;
    final cardKey = _categoryKeys.putIfAbsent(cat.title, () => GlobalKey());

    return Container(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: isHighlighted ? 1.8 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCategory = null;
                  if (selectedCategoryState.subcategory == null) {
                    ref
                        .read(selectedCategoryProvider.notifier)
                        .clearSelection();
                  }
                } else {
                  _expandedCategory = cat.title;
                  ref
                      .read(selectedCategoryProvider.notifier)
                      .selectCategory(cat.id);
                  _scrollToCategory(cat.title);
                }
              });
              _saveDraft();
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    cat.icon,
                    size: 24,
                    color: isHighlighted
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                              AppColors.primaryText.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      cat.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isHighlighted
                            ? theme.colorScheme.primary
                            : theme.textTheme.titleMedium?.color,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Subcategories section
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    child: Column(
                      children: [
                        Divider(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        ...cat.subcategories.map(
                          (sub) => _buildSubcategoryItem(cat.id, sub),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryItem(String categoryId, String subcategoryName) {
    final selectedCategoryState = ref.watch(selectedCategoryProvider);
    final isSelected =
        selectedCategoryState.categoryId == categoryId &&
        selectedCategoryState.subcategory == subcategoryName;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            ref
                .read(selectedCategoryProvider.notifier)
                .selectCategory(categoryId);
          } else {
            ref
                .read(selectedCategoryProvider.notifier)
                .selectSubcategory(categoryId, subcategoryName);
          }
        });
        _saveDraft();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                subcategoryName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  /// What the analysis understood, and — just as importantly — what it could
  /// not.
  ///
  /// The backend has always returned `extractionWarnings`, a per-document OCR
  /// verdict and a `voiceTranscriptionFailed` flag, and the client model has
  /// always parsed them. Nothing rendered any of it, so a run where OCR failed
  /// on three of four documents produced a confidently pre-filled form with no
  /// indication that most of the evidence had never been read.
  Widget _buildAiAnalysisPanel(ExtractionResult prefill) {
    final theme = Theme.of(context);
    final data = prefill.extracted;

    final unreadable =
        prefill.uploadedDocuments.where((d) => d.readFailed).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "From your documents",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Filled in from what we could read. Review and edit anything that needs a change.",
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),

          if (data.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              data.summary,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],

          if (data.parties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Parties identified",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final party in data.parties)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Text(
                      party.display,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Fields the model produced but was not confident enough about. The
          // server cleared the values; the client is told which ones to supply.
          if (_needsReview.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAiNotice(
              Icons.edit_note,
              AppColors.warning,
              "Please fill in yourself: "
              "${_needsReview.map(_fieldLabel).join(', ')}. "
              "We were not confident enough to fill these from your documents.",
            ),
          ],

          if (unreadable.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAiNotice(
              Icons.description_outlined,
              AppColors.error,
              "Could not read: ${unreadable.map((d) => d.originalName).join(', ')}. "
              "Nothing from these documents was used.",
            ),
          ],

          if (prefill.voiceTranscriptionFailed) ...[
            const SizedBox(height: 8),
            _buildAiNotice(
              Icons.mic_off_outlined,
              AppColors.error,
              "Your voice note could not be transcribed, so it was not used.",
            ),
          ],

          for (final warning in prefill.warnings) ...[
            const SizedBox(height: 8),
            _buildAiNotice(Icons.info_outline, AppColors.warning, warning),
          ],
        ],
      ),
    );
  }

  Widget _buildAiNotice(IconData icon, Color color, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 11.5, height: 1.35, color: color),
          ),
        ),
      ],
    );
  }

  /// Extraction field name → the label the client sees on the form.
  static String _fieldLabel(String field) {
    const labels = {
      'title': 'case title',
      'description': 'description',
      'category': 'category',
      'subType': 'sub-category',
      'city': 'city',
      'state': 'state',
      'location': 'location',
      'court': 'preferred court',
      'incidentDate': 'date of incident',
      'opposingParty': 'other party',
      'firNumber': 'FIR / case number',
      'policeStation': 'police station',
      'bailDetails': 'bail details',
      'claimAmount': 'amount claimed',
      'urgency': 'urgency',
    };
    return labels[field] ?? field;
  }

  String? get _descriptionError {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) {
      return "Please describe your legal issue.";
    }
    if (text.length < 20) {
      return "Description must be at least 20 characters.";
    }
    return null;
  }

  Widget _buildStep2Details() {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;
    final courtsState = ref.watch(courtsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Case Details",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 16),

        if (widget.prefill != null) ...[
          _buildAiAnalysisPanel(widget.prefill!),
          const SizedBox(height: 16),
        ],

        // 0. Case Title
        Text(
          "Case Title",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          maxLength: 120,
          onChanged: (_) => _saveDraft(),
          decoration: InputDecoration(
            hintText: _selectedSubcategory != null
                ? "Leave blank to use \"$_selectedSubcategory\""
                : "A short title for your case",
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        // 1. Brief Description of Your Case *
        Row(
          children: [
            Text(
              "Brief Description of Your Case",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: primaryTextColor,
              ),
            ),
            const Text(
              " *",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildDescriptionSection(theme, primaryTextColor, secondaryTextColor),
        const SizedBox(height: 16),

        // 2. City / Location *
        Row(
          children: [
            Text(
              "City / Location",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: primaryTextColor,
              ),
            ),
            const Text(
              " *",
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Live autocomplete — Post-a-Case only.
        //
        // Replaces ~130 lines of inline RawAutocomplete plus its own debounce
        // timer, cache map, loading flag and error/retry row. All of that now
        // lives in LocationAutocompleteField, which additionally cancels
        // superseded in-flight requests (the inline version did not, so a slow
        // earlier response could overwrite a newer one).
        //
        // The profile screens deliberately do NOT use this widget — they use
        // ManualLocationField for free-text entry.
        LocationAutocompleteField(
          fieldKey: 'post_case',
          initialText: _cityController.text,
          label: null,
          hintText: 'Start typing your city name...',
          onCleared: () {
            setState(() {
              _cityController.clear();
              _selectedCityName = null;
              _selectedDistrictName = null;
              _selectedStateName = null;
              _selectedCountryName = null;
              _selectedLatitude = null;
              _selectedLongitude = null;
              _selectedCourtName = null;
              _courtController.clear();
              _courtFilter = "";
            });
            ref.read(courtsProvider.notifier).clear();
            _saveDraft();
          },
          onSelected: (place) {
            setState(() {
              // Keep the local controller in step so the draft, the review
              // step and the submit payload all read the same value.
              _cityController.text = place.description;

              _selectedCityName = place.city;
              _selectedDistrictName = place.district;
              _selectedStateName = place.state;
              _selectedCountryName = place.country;
              _selectedLatitude = place.latitude;
              _selectedLongitude = place.longitude;

              // Court list is city-scoped, so a new city invalidates it.
              _selectedCourtName = null;
              _courtController.clear();
              _courtFilter = "";
            });

            ref
                .read(courtsProvider.notifier)
                .fetchCourtsForLocation(
                  city: place.city,
                  district: place.district,
                  stateName: place.state,
                );
            _saveDraft();
          },
        ),
        const SizedBox(height: 16),

        // 3. Preferred Court Location (Optional)
        Text(
          "Preferred Court Location (Optional)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _selectedCityName == null
                ? theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5)
                : primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _courtController,
          enabled: _selectedCityName != null && !courtsState.isLoading,
          style: TextStyle(color: primaryTextColor),
          onChanged: (val) {
            setState(() {
              _courtFilter = val;
              _showCourtSuggestions = true;
            });
          },
          onTap: () {
            setState(() {
              _showCourtSuggestions = true;
            });
          },
          decoration: InputDecoration(
            hintText: _selectedCityName == null
                ? "Select a city first"
                : (courtsState.isLoading
                      ? "Loading courts..."
                      : "Select court location"),
            hintStyle: TextStyle(color: secondaryTextColor),
            suffixIcon: courtsState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.arrow_drop_down),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_selectedCityName != null && courtsState.isLoading) ...[
          const SizedBox(height: 8),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_selectedCityName != null &&
            !courtsState.isLoading &&
            courtsState.courts.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            "No courts available.",
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (_selectedCityName != null &&
            _showCourtSuggestions &&
            !courtsState.isLoading &&
            courtsState.courts.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: Builder(
              builder: (context) {
                final filtered = courtsState.courts
                    .where(
                      (court) => court.courtName.toLowerCase().contains(
                        _courtFilter.toLowerCase(),
                      ),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "No matching courts found.",
                      style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final court = filtered[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        court.courtName,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${court.courtType} • ${court.courtAddress}",
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _courtController.text = court.courtName;
                          _selectedCourtName = court.courtName;
                          _showCourtSuggestions = false;
                        });
                        _saveDraft();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 4. When do you need help?
        Text(
          "When do you need help?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedUrgency,
          style: TextStyle(color: primaryTextColor),
          dropdownColor: theme.colorScheme.surface,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items:
              [
                    "Immediately (Within 24 Hours)",
                    "This Week",
                    "Within 15 Days",
                    "Within One Month",
                  ]
                  .map(
                    (val) => DropdownMenuItem(
                      value: val,
                      child: Text(
                        val,
                        style: TextStyle(color: primaryTextColor),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (val) {
            setState(() => _selectedUrgency = val);
            _saveDraft();
          },
          hint: Text(
            "Select urgency",
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
        const SizedBox(height: 24),

        // 5. Incident date — relevant to almost every category, so always shown.
        Text(
          "Date of Incident",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickIncidentDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: _incidentDate == null
                  ? const Icon(Icons.calendar_today_outlined, size: 18)
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear date',
                      onPressed: () {
                        setState(() => _incidentDate = null);
                        _saveDraft();
                      },
                    ),
            ),
            child: Text(
              _incidentDate == null
                  ? "Not specified"
                  : DateFormat('dd MMM yyyy').format(_incidentDate!),
              style: TextStyle(
                color: _incidentDate == null
                    ? secondaryTextColor
                    : primaryTextColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 6. Opposing party — who the case is against.
        Text(
          "Other Party (Optional)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _opposingPartyController,
          style: TextStyle(color: primaryTextColor),
          onChanged: (_) => _saveDraft(),
          decoration: InputDecoration(
            hintText: "Person, company, employer or bank involved",
            hintStyle: TextStyle(color: secondaryTextColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),

        // 7. FIR / police station / bail — revealed only for the three
        // categories where they apply, so a GST or divorce case is not asked
        // for a police station.
        if (_showCriminalFields) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_outlined,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      "Criminal case details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "All optional — fill in whatever you have.",
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _firNumberController,
                  style: TextStyle(color: primaryTextColor),
                  onChanged: (_) => _saveDraft(),
                  decoration: InputDecoration(
                    labelText: "FIR / Case Number",
                    labelStyle: TextStyle(color: secondaryTextColor),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _policeStationController,
                  style: TextStyle(color: primaryTextColor),
                  onChanged: (_) => _saveDraft(),
                  decoration: InputDecoration(
                    labelText: "Police Station",
                    labelStyle: TextStyle(color: secondaryTextColor),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bailDetailsController,
                  style: TextStyle(color: primaryTextColor),
                  maxLines: 2,
                  minLines: 1,
                  onChanged: (_) => _saveDraft(),
                  decoration: InputDecoration(
                    labelText: "Bail status / sections charged",
                    labelStyle: TextStyle(color: secondaryTextColor),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 8. Terms & Conditions
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
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Upload Acknowledgement",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const Text(
              " *",
              style: TextStyle(
                color: AppColors.error,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Upload one acknowledgement or supporting document related to your legal issue.",
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Exactly one of the three states renders, and AnimatedSize glides
        // between their heights instead of snapping. The error banner lives
        // inside the same animated subtree so it cannot jolt the layout
        // below it when it appears.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // All three states share _kDocPanelMinHeight so the panel keeps a
              // stable size regardless of which one is showing.
              if (_isDocUploading)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: _kDocPanelMinHeight,
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Uploading document...",
                          style: TextStyle(color: AppColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_uploadedDocRecord != null)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: _kDocPanelMinHeight,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            radius: 28,
                            child: Icon(
                              _uploadedDocRecord!.mimeType.contains("pdf")
                                  ? Icons.picture_as_pdf
                                  : Icons.image,
                              color:
                                  _uploadedDocRecord!.mimeType.contains("pdf")
                                  ? AppColors.error
                                  : theme.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uploadedDocRecord!.originalName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: primaryTextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${(_uploadedDocRecord!.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB",
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                      size: 14,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Uploaded Successfully",
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton.icon(
                            onPressed: _viewDocument,
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: const Text("View"),
                          ),
                          TextButton.icon(
                            onPressed: _replaceDocument,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text("Replace"),
                          ),
                          TextButton.icon(
                            onPressed: _deleteDocument,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                              size: 18,
                            ),
                            label: const Text(
                              "Delete",
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                InkWell(
                  onTap: _showUploadOptionsBottomSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(
                      minHeight: _kDocPanelMinHeight,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Upload Documents",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "PDF, JPG, JPEG, PNG (Max 10MB)",
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_docErrorText != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _docErrorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Validates and uploads the picked acknowledgement document.
  ///
  /// Three banner bugs were fixed here:
  ///
  /// 1. **Contradictory banners shown together.** A validation failure only set
  ///    `_docErrorText` and left `_uploadedDocRecord` pointing at the previous
  ///    document, so the UI rendered the green "uploaded" card for the OLD file
  ///    *and* a red error underneath at the same time. `_setDocError` now clears
  ///    the success record whenever an error is raised, so exactly one banner
  ///    can ever be on screen.
  ///
  /// 2. **The previous document was deleted before the replacement succeeded.**
  ///    The old record was deleted server-side up front; if the new upload then
  ///    failed, the success card kept showing a file that no longer existed and
  ///    tapping it 404'd. The replacement is uploaded first and the old one is
  ///    only deleted once the new upload has actually returned a record.
  ///
  /// 3. **`context` used across an async gap.** The success SnackBar was shown
  ///    without a `mounted` check, so backing out mid-upload threw.
  Future<void> _processPickedFile(
    String filePath,
    String fileName, {
    List<int>? bytes,
    int? size,
  }) async {
    setState(() => _docErrorText = null);

    final extension = fileName.split('.').last.toLowerCase();
    const allowed = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!allowed.contains(extension)) {
      _setDocError("Only PDF, JPG, JPEG and PNG files are allowed.");
      return;
    }

    try {
      int finalSize = 0;
      if (kIsWeb) {
        if (size == null || bytes == null) {
          _setDocError("Could not read that file. Please pick it again.");
          return;
        }
        finalSize = size;
      } else {
        finalSize = await File(filePath).length();
      }

      if (finalSize / (1024 * 1024) > 10.0) {
        _setDocError("Maximum allowed file size is 10 MB.");
        return;
      }

      if (!mounted) return;
      setState(() {
        _isDocUploading = true;
        _docErrorText = null;
      });

      // Remember what we are replacing, but do not remove it yet.
      final previous = _uploadedDocRecord;

      final doc = await ref
          .read(documentsProvider.notifier)
          .uploadDocument(kIsWeb ? null : filePath, fileName, bytes: bytes);

      if (!mounted) return;

      if (doc == null) {
        // Replacement failed. The previous document was NOT deleted, so it is
        // still valid and stays selected; _setDocError reports this as a
        // transient message rather than an inline banner that would sit
        // underneath the success card.
        _setDocError("Upload failed. Please try again.");
        return;
      }

      setState(() {
        _uploadedDocRecord = doc;
        _uploadedDocs
          ..clear()
          ..add(
            DocumentModel(
              name: doc.originalName,
              url: Environment.getAttachmentUrl(doc.filePath),
              size: "${(doc.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB",
            ),
          );
        _isDocUploading = false;
        _docErrorText = null;
      });

      // Only now is it safe to drop the file we replaced. A failure here is not
      // worth surfacing — the new document is uploaded and selected; the stale
      // one is just an orphan for the retention job to clean up.
      if (previous != null && previous.id != doc.id) {
        try {
          await ref
              .read(documentsProvider.notifier)
              .deleteDocument(previous.id);
        } catch (e) {
          debugPrint("Could not remove replaced document ${previous.id}: $e");
        }
      }

      _saveDraft();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document uploaded successfully!")),
      );
    } catch (e) {
      _setDocError(e.toString().replaceAll("Exception: ", ""));
    }
  }

  /// Reports an upload/validation failure without ever producing two
  /// contradictory banners.
  ///
  /// The rule is simply "one persistent banner at a time":
  ///
  /// * **A valid document is already selected** — it is untouched and its card
  ///   stays. The failure refers to the file the user just *tried* to add, not
  ///   to the one they have, so it is transient (SnackBar). This is what fixes
  ///   the original bug: the old code set the inline error while leaving the
  ///   success card up, so the screen claimed success and failure at once.
  ///
  /// * **Nothing is selected** — the inline error banner is the only thing in
  ///   the section, which is correct and unambiguous.
  void _setDocError(String message) {
    if (!mounted) return;

    final hasValidDocument = _uploadedDocRecord != null;

    setState(() {
      _isDocUploading = false;
      // Never let the inline banner coexist with the success card.
      _docErrorText = hasValidDocument ? null : message;
    });

    if (hasValidDocument) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  void _showUploadOptionsBottomSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.primaryGold,
                ),
                title: Text(
                  "Take Photo",
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (photo != null) {
                    final bytes = await photo.readAsBytes();
                    _processPickedFile(
                      photo.path,
                      photo.name,
                      bytes: bytes,
                      size: bytes.length,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.primaryGold,
                ),
                title: Text(
                  "Choose From Gallery",
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    _processPickedFile(
                      image.path,
                      image.name,
                      bytes: bytes,
                      size: bytes.length,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppColors.primaryGold,
                ),
                title: Text(
                  "Choose PDF",
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final FilePickerResult? result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                    withData: true,
                  );
                  if (result != null) {
                    final file = result.files.single;
                    _processPickedFile(
                      file.path ?? '',
                      file.name,
                      bytes: file.bytes,
                      size: file.bytes?.length,
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close, color: AppColors.mutedText),
                title: Text(
                  "Cancel",
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _viewDocument() {
    if (_uploadedDocRecord == null) return;

    final url = Environment.getAttachmentUrl(_uploadedDocRecord!.filePath);
    final isPdf = _uploadedDocRecord!.mimeType.contains("pdf");

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) {
        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryBackground,
            title: Text(
              _uploadedDocRecord!.originalName,
              style: const TextStyle(color: AppColors.primaryText),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: AppColors.primaryText),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: isPdf
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf,
                        size: 80,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "PDF Reader Mode",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _uploadedDocRecord!.originalName,
                        style: const TextStyle(color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Allow opening in browser
                        },
                        icon: const Icon(Icons.link),
                        label: const Text("Open in Browser"),
                      ),
                    ],
                  )
                : InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            "Error loading image",
                            style: TextStyle(color: AppColors.primaryText),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _deleteDocument() async {
    if (_uploadedDocRecord == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Acknowledgement?"),
        content: const Text(
          "Are you sure you want to delete this acknowledgement document?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isDocUploading = true;
      });
      final success = await ref
          .read(documentsProvider.notifier)
          .deleteDocument(_uploadedDocRecord!.id);
      if (!mounted) return;
      if (success) {
        setState(() {
          _uploadedDocRecord = null;
          _uploadedDocs.clear();
          _isDocUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document deleted successfully.")),
        );
      } else {
        setState(() {
          _isDocUploading = false;
          _docErrorText = "Delete failed. Please try again.";
        });
      }
    }
  }

  void _replaceDocument() {
    _showUploadOptionsBottomSheet();
  }


  Widget _buildWhyTheseLawyersButton() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              "Why these lawyers?",
              style: TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              "GenieLaw matches the best lawyers based on your category, subcategory, and location.\n\n"
              "We prioritize lawyers in your Same City first, followed by your Same District, and then Same State, "
              "sorting them by match percentage, experience, ratings, and active status.",
              style: TextStyle(
                color: AppColors.mutedText,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Got It",
                  style: TextStyle(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGold, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "Why these lawyers?",
              style: TextStyle(
                color: AppColors.primaryGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.info_outline, color: AppColors.primaryGold, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            "Best Match",
            isSelected: _sortByFilter == "Best Match",
            hasStar: true,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            "Experience",
            isSelected: _sortByFilter == "Experience",
          ),
          const SizedBox(width: 8),
          _buildFilterChip("Rating", isSelected: _sortByFilter == "Rating"),
          const SizedBox(width: 8),
          _buildFilterChip(
            "Fees: Low to High",
            isSelected: _sortByFilter == "Fees: Low to High",
          ),
          const SizedBox(width: 8),
          _buildFilterIconButton(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label, {
    required bool isSelected,
    bool hasStar = false,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortByFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasStar) ...[
              Icon(
                Icons.star,
                color: isSelected ? AppColors.onGold : AppColors.primaryGold,
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.onGold
                    : AppColors.primaryText.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : const TextStyle().fontWeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterIconButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Filter",
            style: TextStyle(
              color: AppColors.primaryText.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 6),
          Icon(
            Icons.filter_list,
            color: AppColors.primaryText.withValues(alpha: 0.7),
            size: 14,
          ),
        ],
      ),
    );
  }


  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
        ),
      ),
    );
  }





  Widget _buildStep5Review() {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Review Your Case",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 16),
        if (widget.prefill != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryGold.withValues(alpha: 0.15), theme.colorScheme.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.primaryGold, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "AI Smart Assistant Auto-Selected",
                        style: TextStyle(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Category '${_selectedCategory ?? 'Legal Issue'}' and issue description extracted from your document. Tap below to select your lawyer.",
                        style: TextStyle(color: primaryTextColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow(
                "Title",
                _titleController.text.trim().isNotEmpty
                    ? _titleController.text.trim()
                    : (_selectedSubcategory ?? "Not set"),
              ),
              const Divider(height: 24),
              _buildReviewRow(
                "Category",
                _selectedCategory != null && _selectedSubcategory != null
                    ? "$_selectedCategory - $_selectedSubcategory"
                    : (_selectedCategory ?? "Not Selected"),
              ),
              const Divider(height: 24),
              _buildReviewRow(
                "Description",
                _descriptionController.text,
                isMultiline: true,
              ),
              const Divider(height: 24),
              _buildReviewRow("Location", _cityController.text),
              if (_selectedCourtName != null) ...[
                const Divider(height: 24),
                _buildReviewRow("Preferred Court", _selectedCourtName!),
              ],
              const Divider(height: 24),
              _buildReviewRow("Urgency", _selectedUrgency ?? "Flexible"),

              // Structured detail. Shown only when set, so a case that has no
              // FIR does not display an empty row — but anything the extractor
              // filled in IS surfaced here, so the client sees every value they
              // are about to submit rather than only the ones they typed.
              if (_incidentDate != null) ...[
                const Divider(height: 24),
                _buildReviewRow(
                  "Date of Incident",
                  DateFormat('dd MMM yyyy').format(_incidentDate!),
                ),
              ],
              if (_opposingPartyController.text.trim().isNotEmpty) ...[
                const Divider(height: 24),
                _buildReviewRow(
                  "Other Party",
                  _opposingPartyController.text.trim(),
                ),
              ],
              if (_showCriminalFields &&
                  _firNumberController.text.trim().isNotEmpty) ...[
                const Divider(height: 24),
                _buildReviewRow(
                  "FIR / Case Number",
                  _firNumberController.text.trim(),
                ),
              ],
              if (_showCriminalFields &&
                  _policeStationController.text.trim().isNotEmpty) ...[
                const Divider(height: 24),
                _buildReviewRow(
                  "Police Station",
                  _policeStationController.text.trim(),
                ),
              ],
              if (_showCriminalFields &&
                  _bailDetailsController.text.trim().isNotEmpty) ...[
                const Divider(height: 24),
                _buildReviewRow(
                  "Bail / Sections",
                  _bailDetailsController.text.trim(),
                  isMultiline: true,
                ),
              ],

              if (_claimAmount != null && _claimAmount! > 0) ...[
                const Divider(height: 24),
                _buildReviewRow(
                  "Amount Claimed",
                  NumberFormat.currency(
                    locale: 'en_IN',
                    symbol: '₹',
                    decimalDigits: 0,
                  ).format(_claimAmount),
                ),
              ],

              const Divider(height: 24),
              // Every attached document, not just the one the single-record
              // field happens to hold. The AI intake attaches several, and this
              // row used to read "None Uploaded" for all of them.
              _buildReviewRow(
                _uploadedDocs.length > 1 ? "Documents" : "Uploaded Document",
                _uploadedDocs.isEmpty
                    ? "None uploaded"
                    : _uploadedDocs.map((d) => d.name).join('\n'),
                isMultiline: _uploadedDocs.length > 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Final step: pick the advocate the case will be filed with.
  ///
  /// Backed by the existing `/lawyers/recommend` endpoint through
  /// [recommendedLawyersProvider], and rendered with the existing
  /// [AdvocateCard] from the Advocates screen — no parallel lawyer list, no
  /// duplicated card, no second source of lawyer data.
  Widget _buildStep6Lawyer() {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;

    final category = _selectedCategory;
    if (category == null) {
      return _buildStepNotice(
        "Choose a category first",
        "Go back to step 1 and pick the area of law, and we will show the advocates who practise it.",
      );
    }

    // The same query the backend ranks on: category, sub-type and the case's
    // own location.
    final query = Uri(queryParameters: {
      'category': category,
      'subcategory': ?_selectedSubcategory,
      if (_selectedCityName != null && _selectedCityName!.isNotEmpty)
        'city': _selectedCityName!,
      if (_selectedDistrictName != null && _selectedDistrictName!.isNotEmpty)
        'district': _selectedDistrictName!,
      if (_selectedStateName != null && _selectedStateName!.isNotEmpty)
        'state': _selectedStateName!,
      'sortBy': _sortByFilter,
    }).query;

    final lawyersAsync = ref.watch(recommendedLawyersProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                "Choose Your Advocate",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
            ),
            _buildWhyTheseLawyersButton(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Advocates practising $category${_selectedCityName != null && _selectedCityName!.isNotEmpty ? ", nearest to ${_selectedCityName!} first" : ""}.",
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildFiltersRow(),
        const SizedBox(height: 16),

        lawyersAsync.when(
          loading: () => Column(
            children: List.generate(3, (_) => _buildSkeletonCard()),
          ),
          error: (error, _) => _buildStepNotice(
            "Could not load advocates",
            "$error",
            action: TextButton(
              onPressed: () => ref.invalidate(recommendedLawyersProvider(query)),
              child: const Text("Try again"),
            ),
          ),
          data: (lawyers) {
            if (lawyers.isEmpty) {
              return _buildStepNotice(
                "No advocates available yet",
                "No verified advocate currently lists $category. Try a different category, or check back shortly.",
              );
            }

            return Column(
              children: [
                for (final lawyer in lawyers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSelectableLawyer(lawyer),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Wraps the shared [AdvocateCard] with selection affordance, so the card
  /// itself stays the single implementation used by the Advocates screen.
  Widget _buildSelectableLawyer(LawyerModel lawyer) {
    final isSelected = _selectedLawyerModel?.userId == lawyer.userId;

    return GestureDetector(
      onTap: () => setState(() => _selectedLawyerModel = isSelected ? null : lawyer),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            AdvocateCard(
              name: lawyer.fullName,
              specialization: lawyer.specialization,
              location: lawyer.location,
              rating: lawyer.rating,
              reviews: lawyer.totalReviews,
              imageUrl: lawyer.profileImage,
              experience: lawyer.experience,
              onViewProfile: () => context.push('/lawyer-profile/${lawyer.userId}'),
            ),
            if (isSelected)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primaryGold,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shared empty/error panel for a step that cannot render its content.
  Widget _buildStepNotice(String title, String body, {Widget? action}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.bodyMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, color: primaryTextColor, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    final bool isLast = _currentStep == _lawyerStepIndex;
    final theme = Theme.of(context);

    final bool isForm1Valid =
        _descriptionController.text.trim().length >= 20 &&
        _selectedCityName != null &&
        _selectedUrgency != null &&
        _agreedToTerms;

    final bool nextDisabled =
        (_currentStep == 0 && _selectedSubcategory == null) ||
        (_currentStep == 1 && !isForm1Valid) ||
        (_currentStep == 2 && _uploadedDocRecord == null) ||
        // The case is filed with the chosen advocate attached, so the choice
        // has to be made before submit rather than after.
        (_currentStep == _lawyerStepIndex && _selectedLawyerModel == null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                child: const Text("Back"),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: ElevatedButton(
              style: nextDisabled
                  ? ElevatedButton.styleFrom(
                      backgroundColor: AppColors.border,
                      foregroundColor: AppColors.disabledText,
                    )
                  : null,
              onPressed: nextDisabled || _isSubmitting
                  ? null
                  : () {
                      if (isLast) {
                        _submitCase();
                      } else {
                        setState(() => _currentStep++);
                      }
                    },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast
                        ? (_isSubmitting ? "Posting case…" : "Post Case")
                        : "Next",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (isLast && _selectedLawyerModel == null)
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        "(Select a lawyer to continue)",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.normal,
                          color: AppColors.primaryText.withValues(alpha: 0.54),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;

    _drawDashedLine(canvas, const Offset(12, 0), Offset(width - 12, 0), paint);
    _drawDashedLine(
      canvas,
      Offset(width, 12),
      Offset(width, height - 12),
      paint,
    );
    _drawDashedLine(
      canvas,
      Offset(width - 12, height),
      Offset(12, height),
      paint,
    );
    _drawDashedLine(canvas, Offset(0, height - 12), const Offset(0, 12), paint);

    // Draw corners
    canvas.drawArc(const Rect.fromLTWH(0, 0, 24, 24), 3.14, 1.57, false, paint);
    canvas.drawArc(
      Rect.fromLTWH(width - 24, 0, 24, 24),
      4.71,
      1.57,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(width - 24, height - 24, 24, 24),
      0,
      1.57,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, height - 24, 24, 24),
      1.57,
      1.57,
      false,
      paint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double len = math.sqrt(dx * dx + dy * dy);
    int count = (len / (gap * 2)).floor();
    for (int i = 0; i < count; i++) {
      double startFraction = (i * 2) / (count * 2);
      double endFraction = (i * 2 + 1) / (count * 2);
      canvas.drawLine(
        Offset(p1.dx + dx * startFraction, p1.dy + dy * startFraction),
        Offset(p1.dx + dx * endFraction, p1.dy + dy * endFraction),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _PulsingRecordDot extends StatefulWidget {
  const _PulsingRecordDot();

  @override
  State<_PulsingRecordDot> createState() => _PulsingRecordDotState();
}

class _PulsingRecordDotState extends State<_PulsingRecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
