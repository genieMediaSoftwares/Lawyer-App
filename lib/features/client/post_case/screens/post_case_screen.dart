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
import '../../../../core/widgets/app_circle_avatar.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/document_model.dart';
import '../../../../providers/case_provider.dart';
import '../../../../providers/document_provider.dart';
import '../../../../providers/category_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import '../widgets/voice_recording_visualizer.dart';
import '../widgets/premium_audio_player.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/category_item.dart';
import '../../../../models/place_model.dart';
import '../../../../providers/court_provider.dart';
import '../../../../providers/place_provider.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../providers/lawyer_provider.dart';

class PostCaseScreen extends ConsumerStatefulWidget {
  final String? preselectedCategoryId;
  const PostCaseScreen({super.key, this.preselectedCategoryId});

  @override
  ConsumerState<PostCaseScreen> createState() => _PostCaseScreenState();
}

class _PostCaseScreenState extends ConsumerState<PostCaseScreen> {
  int _currentStep = 0;

  // Selected lawyer state
  LawyerModel? _selectedLawyer;
  bool _viewAllLawyers = false;
  String _sortByFilter = "Best Match";

  // Form State State Getters linked to Riverpod Single Source of Truth
  String? get _selectedCategory {
    final activeState = ref.read(selectedCategoryProvider);
    if (activeState.categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == activeState.categoryId).title;
    } catch (_) {
      return null;
    }
  }

  String? get _selectedSubcategory {
    return ref.read(selectedCategoryProvider).subcategory;
  }

  String? _expandedCategory;
  final Map<String, GlobalKey> _categoryKeys = {};

  // Voice Recording & Transcription State
  late final AudioRecorder _audioRecorder;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  List<double> _amplitudes = [];
  String? _recordedFilePath;

  // Transcription states
  bool _isTranscribing = false;
  String? _transcribeError;

  // Replay source path
  String? _audioPlayerSource;

  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _courtController = TextEditingController();
  String? _selectedUrgency;
  bool _agreedToTerms = false;

  final List<DocumentModel> _uploadedDocs = [];

  // Location Autocomplete State
  String? _selectedCityName;
  String? _selectedDistrictName;
  String? _selectedStateName;
  String? _selectedCountryName;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedGooglePlaceId;

  List<PlaceSuggestionModel> _locationSuggestions = [];
  bool _isLocationLoading = false;
  Timer? _locationDebounce;
  final Map<String, List<PlaceSuggestionModel>> _autocompleteCache = {};
  String? _locationError;
  late final FocusNode _cityFocusNode;

  // Court Suggestions State
  String? _selectedCourtName;
  String _courtFilter = "";
  bool _showCourtSuggestions = false;

  bool _hasTouchedDescription = false;

  // Document Upload State
  DocumentRecord? _uploadedDocRecord;
  bool _isDocUploading = false;
  String? _docErrorText;

  final List<CategoryData> _categories = allCategories;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _cityFocusNode = FocusNode();

    _loadDraft().then((_) {
      if (widget.preselectedCategoryId != null) {
        final preselectedId = widget.preselectedCategoryId!.trim();
        try {
          final matchedCategory = _categories.firstWhere(
            (c) => c.id == preselectedId,
          );
          ref.read(selectedCategoryProvider.notifier).selectCategory(matchedCategory.id);
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
            final cat = _categories.firstWhere((c) => c.id == activeState.categoryId);
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
        ref.read(courtsProvider.notifier).fetchCourtsForLocation(
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
    _cityFocusNode.dispose();
    _amplitudeSubscription?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _courtController.dispose();
    _locationDebounce?.cancel();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeState = ref.read(selectedCategoryProvider);
      await prefs.setString("draft_selectedCategoryId", activeState.categoryId ?? "");
      await prefs.setString("draft_selectedSubcategory", activeState.subcategory ?? "");
      await prefs.setString("draft_expandedCategory", _expandedCategory ?? "");
      await prefs.setString("draft_description", _descriptionController.text);
      await prefs.setString("draft_recordedFilePath", _recordedFilePath ?? "");
      await prefs.setString("draft_cityName", _selectedCityName ?? "");
      await prefs.setString("draft_stateName", _selectedStateName ?? "");
      await prefs.setString("draft_cityText", _cityController.text);
      await prefs.setString("draft_courtName", _selectedCourtName ?? "");
      await prefs.setString("draft_urgency", _selectedUrgency ?? "");
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

      if (mounted) {
        if (catId != null && catId.isNotEmpty) {
          ref.read(selectedCategoryProvider.notifier).selectSubcategory(catId, sub);
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
          if (desc != null && desc.isNotEmpty) _descriptionController.text = desc;
          if (path != null && path.isNotEmpty) {
            _recordedFilePath = path;
            _audioPlayerSource = path;
          }
          if (city != null && city.isNotEmpty) _selectedCityName = city;
          if (state != null && state.isNotEmpty) _selectedStateName = state;
          if (cityText != null && cityText.isNotEmpty) _cityController.text = cityText;
          if (court != null && court.isNotEmpty) _selectedCourtName = court;
          if (urgency != null && urgency.isNotEmpty) _selectedUrgency = urgency;
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
      ref.read(selectedCategoryProvider.notifier).clearSelection();
    } catch (e) {
      debugPrint("Error clearing draft: $e");
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await Permission.microphone.request().isGranted;
      if (!hasPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Microphone permission is required to record audio.")),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final String path = "${tempDir.path}/case_desc_${DateTime.now().millisecondsSinceEpoch}.m4a";

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _amplitudes = [];
        _recordedFilePath = null;
        _audioPlayerSource = null;
        _transcribeError = null;
      });

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingSeconds++;
          });
          _saveDraft();
        }
      });

      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        if (mounted) {
          setState(() {
            double val = (amp.current + 160.0) / 160.0;
            if (val < 0.0) val = 0.0;
            _amplitudes.add(val);
            if (_amplitudes.length > 25) {
              _amplitudes.removeAt(0);
            }
          });
        }
      });
      _saveDraft();
    } catch (e) {
      debugPrint("Error starting recording: $e");
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();

    try {
      final path = await _audioRecorder.stop();
      if (cancel) {
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        setState(() {
          _isRecording = false;
          _recordingSeconds = 0;
          _amplitudes = [];
          _recordedFilePath = null;
          _audioPlayerSource = null;
        });
        _saveDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Recording cancelled")),
          );
        }
        return;
      }

      if (path != null) {
        setState(() {
          _isRecording = false;
          _recordedFilePath = path;
          _audioPlayerSource = path;
        });
        _saveDraft();
        _transcribeAudio(path);
      } else {
        setState(() {
          _isRecording = false;
        });
        _saveDraft();
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      setState(() {
        _isRecording = false;
      });
      _saveDraft();
    }
  }

  Future<void> _cancelRecording() async {
    await _stopRecording(cancel: true);
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
                child: const Text("APPEND", style: TextStyle(color: AppColors.primaryGold)),
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
                child: const Text("REPLACE", style: TextStyle(color: AppColors.primaryGold)),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildDescriptionSection(ThemeData theme, Color? primaryTextColor, Color? secondaryTextColor) {
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
                  bottom: 40, // Space so text doesn't hide behind positioned mic button
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: _isRecording
                  ? IconButton(
                      onPressed: () => _stopRecording(),
                      icon: const Icon(Icons.stop_circle_rounded, color: Colors.red, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : IconButton(
                      onPressed: () => _startRecording(),
                      icon: const Icon(Icons.mic, color: AppColors.primaryGold, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ),
            if (_isTranscribing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
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
        if (_isRecording) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                const _PulsingRecordDot(),
                const SizedBox(width: 8),
                Text(
                  "Recording: ${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VoiceRecordingVisualizer(amplitudes: _amplitudes, isRecording: _isRecording),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _cancelRecording(),
                  child: const Text("Cancel", style: TextStyle(color: AppColors.mutedText, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
        if (_transcribeError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Transcription error: $_transcribeError",
                  style: const TextStyle(color: Colors.red, fontSize: 11),
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
            onReRecord: () {
              setState(() {
                _audioPlayerSource = null;
                _recordedFilePath = null;
              });
              _saveDraft();
              _startRecording();
            },
          ),
        ],
      ],
    );
  }

  void _onCitySearchChanged(String query) {
    _locationDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _locationSuggestions = [];
        _isLocationLoading = false;
        _locationError = null;
      });
      return;
    }

    final cacheKey = query.trim().toLowerCase();
    final cached = _autocompleteCache[cacheKey];
    if (cached != null) {
      setState(() {
        _locationSuggestions = cached;
        _isLocationLoading = false;
        _locationError = null;
      });
      return;
    }

    setState(() {
      _isLocationLoading = true;
      _locationError = null;
    });

    _locationDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final suggestions = await ref.read(placeServiceProvider).autocomplete(query);
        if (mounted) {
          setState(() {
            _locationSuggestions = suggestions;
            _autocompleteCache[cacheKey] = suggestions;
            _isLocationLoading = false;
            _locationError = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLocationLoading = false;
            _locationError = "Failed to load suggestions. Tap retry.";
          });
        }
      }
    });
  }

  Future<void> _selectPlace(PlaceSuggestionModel sug) async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final details = await ref.read(placeServiceProvider).details(sug.placeId);
      if (mounted) {
        setState(() {
          _cityController.text = details.description;
          _selectedCityName = details.city;
          _selectedDistrictName = details.district;
          _selectedStateName = details.state;
          _selectedCountryName = details.country;
          _selectedLatitude = details.latitude;
          _selectedLongitude = details.longitude;
          _selectedGooglePlaceId = details.placeId;

          _locationSuggestions = [];
          _isLocationLoading = false;

          _courtController.clear();
          _selectedCourtName = null;
          _courtFilter = "";
        });

        ref.read(courtsProvider.notifier).fetchCourtsForLocation(
              city: details.city,
              district: details.district,
              stateName: details.state,
            );
        _saveDraft();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch location details.")),
        );
      }
    }
  }




  Future<void> _submitCase() async {
    if (_selectedCategory == null ||
        _selectedSubcategory == null ||
        _descriptionController.text.trim().length < 20 ||
        _selectedCityName == null ||
        _selectedLawyer == null ||
        !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all required fields and agree to the terms.")),
      );
      return;
    }

    String? voiceUrl;
    if (_recordedFilePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading voice description recording...")),
      );
      try {
        final docRecord = await ref.read(documentsProvider.notifier).uploadDocument(
          _recordedFilePath!,
          "voice_description_${DateTime.now().millisecondsSinceEpoch}.m4a",
        );
        if (docRecord != null) {
          voiceUrl = Environment.getAttachmentUrl(docRecord.filePath);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload audio recording: $e")),
        );
        return;
      }
    }

    final newCase = await ref.read(casesProvider.notifier).createCase(
          title: _selectedSubcategory!,
          description: _descriptionController.text,
          category: _selectedCategory!,
          subcategory: _selectedSubcategory!,
          location: _cityController.text,
          urgency: _selectedUrgency ?? "Flexible",
          preferredCourt: _selectedCourtName,
          documents: _uploadedDocs,
          selectedLawyer: _selectedLawyer!.userId,
          voiceUrl: voiceUrl,
          voiceTranscript: _recordedFilePath != null ? _descriptionController.text : null,
          city: _selectedCityName,
          district: _selectedDistrictName,
          stateName: _selectedStateName,
          country: _selectedCountryName,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
        );

    if (newCase != null) {
      _clearDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Case posted successfully!")),
      );
      context.pop();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to post case. Please try again.")),
      );
    }
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
          _buildStepIndicator(1, "Category", _currentStep >= 0),
          _buildStepDivider(_currentStep >= 1),
          _buildStepIndicator(2, "Details", _currentStep >= 1),
          _buildStepDivider(_currentStep >= 2),
          _buildStepIndicator(3, "Documents", _currentStep >= 2),
          _buildStepDivider(_currentStep >= 3),
          _buildStepIndicator(4, "Lawyers", _currentStep >= 3),
          _buildStepDivider(_currentStep >= 4),
          _buildStepIndicator(5, "Review", _currentStep >= 4),
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
                  ? Colors.black
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
        )
      ],
    );
  }

  Widget _buildStepDivider(bool isActive) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        height: 2,
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
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
        return _buildStep4RecommendedLawyers();
      case 4:
        return _buildStep5Review();
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
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
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
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
                    ref.read(selectedCategoryProvider.notifier).clearSelection();
                  }
                } else {
                  _expandedCategory = cat.title;
                  ref.read(selectedCategoryProvider.notifier).selectCategory(cat.id);
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
                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.white70,
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
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Column(
                      children: [
                        Divider(color: theme.colorScheme.outline.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        ...cat.subcategories.map((sub) => _buildSubcategoryItem(cat.id, sub)),
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
    final isSelected = selectedCategoryState.categoryId == categoryId && selectedCategoryState.subcategory == subcategoryName;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            ref.read(selectedCategoryProvider.notifier).selectCategory(categoryId);
          } else {
            ref.read(selectedCategoryProvider.notifier).selectSubcategory(categoryId, subcategoryName);
          }
        });
        _saveDraft();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.5),
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

  Widget _buildHighlightedText(String text, String query, TextStyle defaultStyle, TextStyle highlightStyle) {
    if (query.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();

    final List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch = lowerText.indexOf(lowerQuery, start);

    while (indexOfMatch != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch), style: defaultStyle));
      }

      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: highlightStyle,
      ));

      start = indexOfMatch + query.length;
      indexOfMatch = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 16),
        
        // 1. Brief Description of Your Case *
        Row(
          children: [
            Text(
              "Brief Description of Your Case",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
            ),
            const Text(
              " *",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
            ),
            const Text(
              " *",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        RawAutocomplete<PlaceSuggestionModel>(
          focusNode: _cityFocusNode,
          textEditingController: _cityController,
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _locationSuggestions;
          },
          optionsViewBuilder: (context, onSelected, options) {
            final listOptions = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: MediaQuery.of(context).size.width - 40,
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: listOptions.length,
                    itemBuilder: (context, index) {
                      final option = listOptions[index];
                      final isFocused = AutocompleteHighlightedOption.of(context) == index;
                      return InkWell(
                        onTap: () => onSelected(option),
                        child: Container(
                          color: isFocused ? theme.colorScheme.primary.withOpacity(0.08) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: isFocused ? theme.colorScheme.primary : AppColors.mutedText,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildHighlightedText(
                                  option.description,
                                  _cityController.text,
                                  theme.textTheme.bodyMedium?.copyWith(
                                    color: isFocused ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
                                  ) ?? const TextStyle(),
                                  TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (option) {
            _selectPlace(option);
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              style: TextStyle(color: primaryTextColor),
              onChanged: (val) {
                setState(() {
                  _selectedCityName = null;
                  _selectedDistrictName = null;
                  _selectedStateName = null;
                  _selectedCountryName = null;
                  _selectedLatitude = null;
                  _selectedLongitude = null;
                  _selectedGooglePlaceId = null;

                  _selectedCourtName = null;
                  _courtController.clear();
                  ref.read(courtsProvider.notifier).clear();
                });
                _onCitySearchChanged(val);
              },
              decoration: InputDecoration(
                hintText: "Start typing your city name...",
                hintStyle: TextStyle(color: secondaryTextColor),
                suffixIcon: _isLocationLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
        if (_locationError != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _locationError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _onCitySearchChanged(_cityController.text);
                },
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text("Retry", style: TextStyle(fontSize: 12)),
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
        const SizedBox(height: 16),

        // 3. Preferred Court Location (Optional)
        Text(
          "Preferred Court Location (Optional)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: _selectedCityName == null 
                ? theme.textTheme.bodySmall?.color?.withOpacity(0.5) 
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
                : (courtsState.isLoading ? "Loading courts..." : "Select court location"),
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
        if (_selectedCityName != null && !courtsState.isLoading && courtsState.courts.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            "No courts available.",
            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
        if (_selectedCityName != null && _showCourtSuggestions && !courtsState.isLoading && courtsState.courts.isNotEmpty) ...[
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
                    .where((court) => court.courtName.toLowerCase().contains(_courtFilter.toLowerCase()))
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
                      title: Text(court.courtName, style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold)),
                      subtitle: Text("${court.courtType} • ${court.courtAddress}", style: TextStyle(color: secondaryTextColor, fontSize: 11)),
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
              }
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 4. When do you need help?
        Text("When do you need help?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedUrgency,
          style: TextStyle(color: primaryTextColor),
          dropdownColor: theme.colorScheme.surface,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            "Immediately (Within 24 Hours)",
            "This Week",
            "Within 15 Days",
            "Within One Month"
          ]
              .map((val) => DropdownMenuItem(value: val, child: Text(val, style: TextStyle(color: primaryTextColor))))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedUrgency = val);
            _saveDraft();
          },
          hint: Text("Select urgency", style: TextStyle(color: secondaryTextColor)),
        ),
        const SizedBox(height: 24),

        // 5. Terms & Conditions
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
            ),
            const Text(
              " *",
              style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Upload one acknowledgement or supporting document related to your legal issue.",
          style: TextStyle(color: secondaryTextColor, fontSize: 13),
        ),
        const SizedBox(height: 20),

        if (_isDocUploading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60),
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
                  Text("Uploading document...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else if (_uploadedDocRecord != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      radius: 28,
                      child: Icon(
                        _uploadedDocRecord!.mimeType.contains("pdf")
                            ? Icons.picture_as_pdf
                            : Icons.image,
                        color: _uploadedDocRecord!.mimeType.contains("pdf")
                            ? Colors.red
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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${(_uploadedDocRecord!.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB",
                            style: TextStyle(color: secondaryTextColor, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 14),
                              SizedBox(width: 4),
                              Text(
                                "Uploaded Successfully",
                                style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
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
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text("View"),
                    ),
                    TextButton.icon(
                      onPressed: _replaceDocument,
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text("Replace"),
                    ),
                    TextButton.icon(
                      onPressed: _deleteDocument,
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                      label: const Text("Delete", style: TextStyle(color: AppColors.error)),
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
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.cloud_upload_outlined, size: 36, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text("Upload Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor)),
                  const SizedBox(height: 6),
                  Text("PDF, JPG, JPEG, PNG (Max 10MB)", style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12)),
                ],
              ),
            ),
          ),

        if (_docErrorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _docErrorText!,
            style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  Future<void> _processPickedFile(
    String filePath,
    String fileName, {
    List<int>? bytes,
    int? size,
  }) async {
    setState(() {
      _docErrorText = null;
    });

    final extension = fileName.split('.').last.toLowerCase();
    final allowed = ['pdf', 'jpg', 'jpeg', 'png'];
    if (!allowed.contains(extension)) {
      setState(() {
        _docErrorText = "Only PDF, JPG, JPEG and PNG files are allowed.";
      });
      return;
    }

    try {
      int finalSize = 0;
      if (kIsWeb) {
        if (size == null || bytes == null) {
          setState(() {
            _docErrorText = "Failed to read file data.";
          });
          return;
        }
        finalSize = size;
      } else {
        final file = File(filePath);
        finalSize = await file.length();
      }

      final sizeInMb = finalSize / (1024 * 1024);

      if (sizeInMb > 10.0) {
        setState(() {
          _docErrorText = "Maximum allowed file size is 10 MB.";
        });
        return;
      }

      setState(() {
        _isDocUploading = true;
      });

      if (_uploadedDocRecord != null) {
        await ref.read(documentsProvider.notifier).deleteDocument(_uploadedDocRecord!.id);
      }

      final doc = await ref.read(documentsProvider.notifier).uploadDocument(
            kIsWeb ? null : filePath,
            fileName,
            bytes: bytes,
          );
      if (doc != null) {
        setState(() {
          _uploadedDocRecord = doc;
          _uploadedDocs.clear();
          _uploadedDocs.add(DocumentModel(
            name: doc.originalName,
            url: Environment.getAttachmentUrl(doc.filePath),
            size: "${(doc.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB",
          ));
          _isDocUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document uploaded successfully!")),
        );
      } else {
        setState(() {
          _isDocUploading = false;
          _docErrorText = "Upload failed. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _isDocUploading = false;
        _docErrorText = e.toString().replaceAll("Exception: ", "");
      });
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
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primaryGold),
                title: Text("Take Photo", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                onTap: () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final XFile? photo = await picker.pickImage(source: ImageSource.camera);
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
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryGold),
                title: Text("Choose From Gallery", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                onTap: () async {
                  Navigator.pop(context);
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
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
                leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryGold),
                title: Text("Choose PDF", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
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
                leading: const Icon(Icons.close, color: Colors.grey),
                title: Text("Cancel", style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
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
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(_uploadedDocRecord!.originalName, style: const TextStyle(color: Colors.white)),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: isPdf
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        "PDF Reader Mode",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _uploadedDocRecord!.originalName,
                        style: const TextStyle(color: Colors.grey),
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
                          child: Text("Error loading image", style: TextStyle(color: Colors.white)),
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
        content: const Text("Are you sure you want to delete this acknowledgement document?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isDocUploading = true;
      });
      final success = await ref.read(documentsProvider.notifier).deleteDocument(_uploadedDocRecord!.id);
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
  Widget _buildStep4RecommendedLawyers() {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;

    final queryKey = "category=${Uri.encodeComponent(_selectedCategory ?? '')}"
        "&subcategory=${Uri.encodeComponent(_selectedSubcategory ?? '')}"
        "&city=${Uri.encodeComponent(_selectedCityName ?? '')}"
        "&district=${Uri.encodeComponent(_selectedDistrictName ?? '')}"
        "&state=${Uri.encodeComponent(_selectedStateName ?? '')}"
        "&sortBy=${Uri.encodeComponent(_sortByFilter)}";

    final recommendedState = ref.watch(recommendedLawyersProvider(queryKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recommended Lawyers",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "We've matched the best lawyers for your issue (${_selectedSubcategory ?? _selectedCategory}) in ${_selectedCityName ?? 'your area'} and nearby areas.",
                    style: TextStyle(color: secondaryTextColor, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildWhyTheseLawyersButton(),
          ],
        ),
        const SizedBox(height: 20),

        // Filter Chips Row
        _buildFiltersRow(),
        const SizedBox(height: 20),

        recommendedState.when(
          data: (lawyers) {
            if (lawyers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      Icon(Icons.person_search_outlined, size: 64, color: AppColors.mutedText.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        "No Recommended Lawyers Found",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Try picking a different city or location in the previous step.",
                        style: TextStyle(color: secondaryTextColor, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final visibleCount = _viewAllLawyers ? lawyers.length : (lawyers.length > 5 ? 5 : lawyers.length);
            final visibleLawyers = lawyers.take(visibleCount).toList();

            return Column(
              children: [
                ...visibleLawyers.map((lawyer) {
                  final isSelected = _selectedLawyer?.userId == lawyer.userId;
                  return _buildLawyerCard(lawyer, isSelected);
                }),
                const SizedBox(height: 16),
                
                // Bottom Dotted prompt
                _buildViewMorePrompt(),
              ],
            );
          },
          loading: () => Column(
            children: List.generate(3, (index) => _buildSkeletonCard()),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text("Error loading recommendations: $err", style: TextStyle(color: primaryTextColor)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(recommendedLawyersProvider(queryKey)),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhyTheseLawyersButton() {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1B1B1B),
            title: const Text("Why these lawyers?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text(
              "GenieLaw matches the best lawyers based on your category, subcategory, and location.\n\n"
              "We prioritize lawyers in your Same City first, followed by your Same District, and then Same State, "
              "sorting them by match percentage, experience, ratings, and active status.",
              style: TextStyle(color: Colors.grey, height: 1.4, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Got It", style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
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
          border: Border.all(color: const Color(0xFFD4AF37), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "Why these lawyers?",
              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 4),
            Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 12),
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
          _buildFilterChip("Best Match", isSelected: _sortByFilter == "Best Match", hasStar: true),
          const SizedBox(width: 8),
          _buildFilterChip("Experience", isSelected: _sortByFilter == "Experience"),
          const SizedBox(width: 8),
          _buildFilterChip("Rating", isSelected: _sortByFilter == "Rating"),
          const SizedBox(width: 8),
          _buildFilterChip("Fees: Low to High", isSelected: _sortByFilter == "Fees: Low to High"),
          const SizedBox(width: 8),
          _buildFilterIconButton(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {required bool isSelected, bool hasStar = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortByFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF2B2B2B),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasStar) ...[
              Icon(
                Icons.star,
                color: isSelected ? Colors.black : const Color(0xFFD4AF37),
                size: 14,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : const TextStyle().fontWeight,
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
        border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Filter",
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 6),
          Icon(Icons.filter_list, color: Colors.white70, size: 14),
        ],
      ),
    );
  }

  Widget _buildViewMorePrompt() {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: const Color(0xFFD4AF37),
        strokeWidth: 1.0,
        gap: 5.0,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _viewAllLawyers = true;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_shared_outlined, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Can't find the right lawyer? View more lawyers",
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131314),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
        ),
      ),
    );
  }

  Widget _buildLawyerCard(LawyerModel lawyer, bool isSelected) {
    final displayedTags = lawyer.languages.take(3).toList();
    final remainingTagsCount = lawyer.languages.length - displayedTags.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131314),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF2B2B2B),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Profile photo stack
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: lawyer.profileImage.isNotEmpty
                          ? Image.network(
                              Environment.getAttachmentUrl(lawyer.profileImage),
                              width: 80,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (c, o, s) => Container(
                                width: 80,
                                height: 88,
                                color: const Color(0xFF2B2B2B),
                                child: const Icon(Icons.person, color: Colors.white54, size: 40),
                              ),
                            )
                          : Container(
                              width: 80,
                              height: 88,
                              color: const Color(0xFF2B2B2B),
                              child: const Icon(Icons.person, color: Colors.white54, size: 40),
                            ),
                    ),
                    if (lawyer.onlineStatus)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                "Online",
                                style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (lawyer.isVerified)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // 2. Center info details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lawyer.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lawyer.specialization,
                        style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Colors.grey, size: 13),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              lawyer.location,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFD4AF37), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            "${lawyer.rating}  (${lawyer.totalReviews} Reviews)",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${lawyer.experience}+ Years Exp  •  ${lawyer.casesHandled}+ Cases",
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Right status/stats details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Gold Circular Tick Selection Indicator
                    Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? const Color(0xFFD4AF37) : Colors.white30,
                      size: 20,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_fixed, color: Colors.green, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          "${lawyer.matchPercentage}% Match",
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.grey, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          lawyer.responseTime,
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "Consultation Fee",
                          style: TextStyle(color: Colors.grey, fontSize: 9),
                        ),
                        Text(
                          "₹${lawyer.consultationFee}",
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Practice Area Tag Chips row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...displayedTags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1C),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2B2B2C)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    )),
                if (remainingTagsCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B1C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2B2B2C)),
                    ),
                    child: Text(
                      "+$remainingTagsCount",
                      style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Action Buttons row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewLawyerProfileBottomSheet(lawyer),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1.0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("View Profile", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (isSelected) {
                          _selectedLawyer = null;
                        } else {
                          _selectedLawyer = lawyer;
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : const Color(0xFFD4AF37),
                      foregroundColor: isSelected ? const Color(0xFFD4AF37) : Colors.black,
                      side: isSelected ? const BorderSide(color: Color(0xFFD4AF37), width: 1.2) : null,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check, size: 14),
                          const SizedBox(width: 4),
                          const Text("Selected", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ] else ...[
                          const Text("Select Lawyer", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewLawyerProfileBottomSheet(LawyerModel lawyer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      AppCircleAvatar(
                        radius: 40,
                        imageUrl: lawyer.profileImage.isNotEmpty
                            ? Environment.getAttachmentUrl(lawyer.profileImage)
                            : null,
                        fallback: const Icon(Icons.person, size: 40, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lawyer.fullName,
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.verified, color: AppColors.primaryGold, size: 20),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lawyer.specialization,
                              style: const TextStyle(color: AppColors.primaryGold, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lawyer.location,
                              style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileStat("Experience", "${lawyer.experience} Yrs"),
                      _buildProfileStat("Rating", "${lawyer.rating} ★"),
                      _buildProfileStat("Cases", "${lawyer.casesHandled}"),
                      _buildProfileStat("Win Rate", "${lawyer.winPercentage}%"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  
                  const Text("About Lawyer", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    lawyer.bio.isNotEmpty ? lawyer.bio : "Professional legal counsel.",
                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text("Practice Areas", style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSheetChip(lawyer.specialization),
                      _buildSheetChip("Legal Consultation"),
                      _buildSheetChip("Case Representation"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildDetailRow("Education", lawyer.education.isNotEmpty ? lawyer.education : "LLB, Law University"),
                  _buildDetailRow("Bar Council Reg", lawyer.barCouncilNumber.isNotEmpty ? lawyer.barCouncilNumber : "IND/2026/BAR"),
                  _buildDetailRow("Languages", lawyer.languages.isEmpty ? 'English' : lawyer.languages.join(", ")),
                  _buildDetailRow("Office Address", lawyer.officeAddress.isNotEmpty ? lawyer.officeAddress : "Office Suite, City Center"),
                  _buildDetailRow("Working Hours", lawyer.workingHours),
                  _buildDetailRow("Consultation Fee", "₹${lawyer.consultationFee}", valueColor: AppColors.primaryGold, isBoldValue: true),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedLawyer = lawyer;
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("Select This Lawyer"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
      ],
    );
  }

  Widget _buildSheetChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.primaryGold, fontSize: 12)),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.mutedText, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.secondaryText,
                fontSize: 13,
                fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
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
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
        ),
        const SizedBox(height: 16),
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
                "Category",
                _selectedCategory != null && _selectedSubcategory != null
                    ? "$_selectedCategory - $_selectedSubcategory"
                    : (_selectedCategory ?? "Not Selected"),
              ),
              const Divider(height: 24),
              _buildReviewRow("Description", _descriptionController.text, isMultiline: true),
              const Divider(height: 24),
              _buildReviewRow("Location", _cityController.text),
              if (_selectedCourtName != null) ...[
                const Divider(height: 24),
                _buildReviewRow("Preferred Court", _selectedCourtName!),
              ],
              const Divider(height: 24),
              _buildReviewRow("Urgency", _selectedUrgency ?? "Flexible"),
              const Divider(height: 24),
              _buildReviewRow("Uploaded Acknowledgement", _uploadedDocRecord?.originalName ?? "None Uploaded"),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_selectedLawyer != null) ...[
          Text(
            "Selected Lawyer",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGold, width: 1.5),
            ),
            child: Row(
              children: [
                AppCircleAvatar(
                  radius: 28,
                  imageUrl: _selectedLawyer!.profileImage.isNotEmpty
                      ? Environment.getAttachmentUrl(_selectedLawyer!.profileImage)
                      : null,
                  fallback: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedLawyer!.fullName,
                              style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const Icon(Icons.verified, color: AppColors.primaryGold, size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_selectedLawyer!.specialization} • ${_selectedLawyer!.experience} Yrs Exp",
                        style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.primaryGold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "${_selectedLawyer!.rating} (${_selectedLawyer!.totalReviews} Reviews)",
                            style: const TextStyle(color: AppColors.primaryText, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "Fee: ₹${_selectedLawyer!.consultationFee}",
                            style: const TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isMultiline = false}) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.bodyMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;
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
    final bool isLast = _currentStep == 4;
    final theme = Theme.of(context);
    
    final bool isForm1Valid = _descriptionController.text.trim().length >= 20 &&
        _selectedCityName != null &&
        _selectedUrgency != null &&
        _agreedToTerms;

    final bool nextDisabled = (_currentStep == 0 && _selectedSubcategory == null) ||
        (_currentStep == 1 && !isForm1Valid) ||
        (_currentStep == 2 && _uploadedDocRecord == null) ||
        (_currentStep == 3 && _selectedLawyer == null);

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
              onPressed: nextDisabled
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
                  Text(isLast ? "Submit Case" : "Next", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if (!isLast && _currentStep == 3 && nextDisabled)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        "(Select a lawyer to continue)",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.normal, color: Colors.white54),
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
    _drawDashedLine(canvas, Offset(width, 12), Offset(width, height - 12), paint);
    _drawDashedLine(canvas, Offset(width - 12, height), Offset(12, height), paint);
    _drawDashedLine(canvas, Offset(0, height - 12), const Offset(0, 12), paint);
    
    // Draw corners
    canvas.drawArc(const Rect.fromLTWH(0, 0, 24, 24), 3.14, 1.57, false, paint);
    canvas.drawArc(Rect.fromLTWH(width - 24, 0, 24, 24), 4.71, 1.57, false, paint);
    canvas.drawArc(Rect.fromLTWH(width - 24, height - 24, 24, 24), 0, 1.57, false, paint);
    canvas.drawArc(Rect.fromLTWH(0, height - 24, 24, 24), 1.57, 1.57, false, paint);
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

class _PulsingRecordDotState extends State<_PulsingRecordDot> with SingleTickerProviderStateMixin {
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
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}



