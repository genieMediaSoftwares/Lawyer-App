import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/config/env.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/ai_smart_case_models.dart';

/// One event from the backend analysis pipeline.
///
/// Exactly one of [progress], [result] or [error] is set. The pipeline only
/// ever produces events for work it has actually performed.
class AnalysisEvent {
  final AnalysisProgress? progress;
  final ExtractionResult? result;
  final String? error;

  const AnalysisEvent.progress(AnalysisProgress this.progress)
      : result = null,
        error = null;

  const AnalysisEvent.complete(ExtractionResult this.result)
      : progress = null,
        error = null;

  const AnalysisEvent.failed(String this.error)
      : progress = null,
        result = null;
}

/// Talks to the AI intake endpoints and to the `/ai` Socket.IO namespace.
///
/// `POST /ai/smart-case/analyze` no longer waits for the analysis: it returns a
/// session id as soon as the upload lands, and the run reports over the socket.
/// That is why there is no long receive timeout here any more — the request is
/// an upload, not a computation.
class AISmartCaseRepository {
  /// Covers the upload itself only. Large scans over a slow connection can
  /// still take a while to send; nothing waits on AI work.
  static const _uploadTimeout = Duration(minutes: 2);

  /// If the socket drops, the session is polled at this interval instead. The
  /// session document carries the same progress the events do, so a client on
  /// a flaky connection still tracks the run accurately, just less smoothly.
  static const _pollInterval = Duration(seconds: 3);

  /// Uploads the documents and voice note and starts the analysis.
  ///
  /// Returns the new session id. Progress arrives through [watch].
  Future<String> startAnalysis({
    required List<PlatformFile> files,
    File? voiceFile,
    String? voiceTranscript,
    String? issueDescription,
  }) async {
    final formData = FormData();

    for (final file in files) {
      final bytes = file.bytes;
      final path = file.path;

      final MultipartFile part;
      if (bytes != null) {
        // Web (and native when withData was requested).
        part = MultipartFile.fromBytes(bytes, filename: file.name);
      } else if (path != null && !kIsWeb) {
        // Native: stream from disk rather than loading the whole file into RAM.
        part = await MultipartFile.fromFile(path, filename: file.name);
      } else {
        // Skipping would silently drop the client's document — fail loudly.
        throw Exception(
          'Could not read "${file.name}". Please remove it and try again.',
        );
      }

      formData.files.add(MapEntry('documents', part));
    }

    if (voiceFile != null) {
      final voiceName = voiceFile.path.split('/').last.split('\\').last;
      formData.files.add(
        MapEntry(
          'voice',
          await MultipartFile.fromFile(voiceFile.path, filename: voiceName),
        ),
      );
    }

    // The device already transcribed the voice note while the client spoke, so
    // it travels as text. The pipeline uses it immediately instead of waiting
    // on transcription, and falls back to transcribing [voiceFile] only when
    // this is absent — which is what happens on a device with no recogniser.
    final transcript = voiceTranscript?.trim() ?? '';
    if (transcript.isNotEmpty) {
      formData.fields.add(MapEntry('voiceTranscript', transcript));
    }

    if (issueDescription != null && issueDescription.isNotEmpty) {
      formData.fields.add(MapEntry('issueDescription', issueDescription));
    }

    final response = await DioClient.dio.post(
      '/ai/smart-case/analyze',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        sendTimeout: _uploadTimeout,
        receiveTimeout: _uploadTimeout,
        // 202 Accepted is the success case here.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    final body = response.data;
    final data = (body is Map && body['data'] is Map)
        ? Map<String, dynamic>.from(body['data'] as Map)
        : const <String, dynamic>{};
    final sessionId = (data['sessionId'] ?? '').toString();

    if (sessionId.isEmpty) {
      final message = (body is Map ? body['message'] : null)?.toString();
      throw Exception(
        message != null && message.isNotEmpty
            ? message
            : 'Could not start the analysis. Please try again.',
      );
    }

    return sessionId;
  }

  /// Streams the real progress of [sessionId] until it completes or fails.
  ///
  /// Socket events drive the stream. A poll runs alongside as a safety net so a
  /// dropped connection degrades to slower updates rather than a stuck screen —
  /// both read the same server-side state, so they cannot disagree.
  Stream<AnalysisEvent> watch(String sessionId) {
    late StreamController<AnalysisEvent> controller;
    io.Socket? socket;
    Timer? poller;
    var finished = false;

    Future<void> cleanUp() async {
      poller?.cancel();
      poller = null;
      socket?.dispose();
      socket = null;
    }

    void finish(AnalysisEvent event) {
      if (finished) return;
      finished = true;
      controller.add(event);
      cleanUp();
      controller.close();
    }

    /// Turns any completion-shaped payload into a result, from either channel.
    void handlePayload(Map<String, dynamic> data) {
      if ((data['sessionId'] ?? '').toString() != sessionId) return;
      finish(AnalysisEvent.complete(ExtractionResult.fromJson(data)));
    }

    Future<void> pollOnce() async {
      if (finished) return;
      try {
        final response = await DioClient.dio.get('/ai/smart-case/session/$sessionId');
        final body = response.data;
        if (body is! Map || body['data'] is! Map) return;

        final data = Map<String, dynamic>.from(body['data'] as Map);
        final status = (data['status'] ?? '').toString();

        if (status == 'extracted') {
          handlePayload(data);
        } else if (status == 'failed') {
          finish(AnalysisEvent.failed(
            (data['failureReason'] ?? '').toString().isNotEmpty
                ? data['failureReason'].toString()
                : 'The analysis could not be completed. Please try again.',
          ));
        } else if (data['progress'] is Map) {
          controller.add(AnalysisEvent.progress(
            AnalysisProgress.fromJson(
              Map<String, dynamic>.from(data['progress'] as Map),
            ),
          ));
        }
      } catch (_) {
        // A failed poll is not itself an error: the socket may still deliver,
        // and the next poll will retry.
      }
    }

    Future<void> connect() async {
      final token = await TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        finish(const AnalysisEvent.failed('Your session expired. Please sign in again.'));
        return;
      }

      socket = io.io(
        '${Environment.baseSocketUrl}/ai',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .build(),
      );

      socket!
        ..on('analysis_progress', (raw) {
          if (raw is! Map) return;
          final data = Map<String, dynamic>.from(raw);
          if ((data['sessionId'] ?? '').toString() != sessionId) return;
          controller.add(AnalysisEvent.progress(AnalysisProgress.fromJson(data)));
        })
        ..on('analysis_complete', (raw) {
          if (raw is! Map) return;
          handlePayload(Map<String, dynamic>.from(raw));
        })
        ..on('analysis_failed', (raw) {
          if (raw is! Map) return;
          final data = Map<String, dynamic>.from(raw);
          if ((data['sessionId'] ?? '').toString() != sessionId) return;
          finish(AnalysisEvent.failed(
            (data['message'] ?? 'The analysis could not be completed.').toString(),
          ));
        })
        // A reconnect may have missed events while the socket was down, so
        // reconcile against the session immediately rather than waiting.
        ..onConnect((_) => pollOnce())
        ..connect();

      // Runs regardless of socket health: it is the fallback that makes a
      // dropped connection a slower experience rather than a broken one.
      poller = Timer.periodic(_pollInterval, (_) => pollOnce());

      // The run may already have finished between the POST returning and this
      // subscription starting — a small file can analyse that fast.
      await pollOnce();
    }

    controller = StreamController<AnalysisEvent>(
      onListen: connect,
      onCancel: cleanUp,
    );

    return controller.stream;
  }

  /// Records which case this intake session produced, closing the audit trail
  /// from uploaded document to filed case. Best-effort: a failure here must
  /// never block the client, whose case has already been created.
  Future<void> linkSessionToCase({
    required String sessionId,
    required String caseId,
  }) async {
    if (sessionId.isEmpty || caseId.isEmpty) return;
    try {
      await DioClient.dio.post(
        '/ai/smart-case/session/$sessionId/link-case',
        data: {'caseId': caseId},
      );
    } catch (_) {
      // Audit bookkeeping only.
    }
  }
}
