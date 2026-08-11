import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/ai_smart_case_models.dart';
import '../utils/ai_smart_case_logger.dart';

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

/// Raised when the upload could not even be attempted — a file vanished
/// between picking and sending, or the selection breaks a server limit.
///
/// Distinguished from a transport failure so the caller can report the file
/// name instead of "check your connection", and so the retry logic does not
/// resend something that will fail identically.
class AnalysisInputException implements Exception {
  final String message;
  const AnalysisInputException(this.message);
  @override
  String toString() => message;
}

/// Talks to the AI intake endpoints and to the `/ai` Socket.IO namespace.
///
/// `POST /ai/smart-case/analyze` does not wait for the analysis: it returns a
/// session id as soon as the upload lands, and the run reports over the socket.
/// That is why there is no long receive timeout here — the request is an
/// upload, not a computation.
class AISmartCaseRepository {
  // Every value below is configured in .env and read through [AppConfig];
  // see that class for what each one governs. They are getters rather than
  // constants precisely so no default survives in this file.

  /// Covers the upload itself only. Large scans over a slow connection can
  /// still take a while to send; nothing waits on AI work.
  static Duration get _uploadTimeout => AppConfig.aiUploadTimeout;

  /// Server-side limits, mirrored so a doomed upload is rejected before it is
  /// sent rather than after several megabytes have gone over a mobile link.
  static int get maxFileBytes => AppConfig.aiMaxFileBytes;
  static int get maxFileCount => AppConfig.aiMaxFileCount;

  /// How often the session is polled while the socket is *down*. This is the
  /// path that has to keep the screen moving, so it is the tighter of the two.
  static Duration get _pollIntervalDisconnected =>
      AppConfig.aiPollIntervalDisconnected;

  /// How often it is polled while the socket is up. The socket is already
  /// delivering every transition; this is a slow reconciliation heartbeat that
  /// catches a silently half-open connection — the case where the socket
  /// believes it is connected and no packets are actually flowing.
  static Duration get _pollIntervalConnected =>
      AppConfig.aiPollIntervalConnected;

  /// A poll that fails is retried with exponential backoff up to this delay,
  /// so a server hiccup does not turn into a request every few seconds.
  static Duration get _pollBackoffMax => AppConfig.aiPollBackoffMax;

  /// Consecutive poll failures tolerated before the run is reported as failed.
  /// Below this the socket may still deliver, so a failed poll is not itself
  /// an error.
  static int get _maxConsecutivePollFailures =>
      AppConfig.aiMaxConsecutivePollFailures;

  /// No progress *and* no successful poll for this long means the run is not
  /// coming back — the server died mid-pipeline, or the device lost the network
  /// entirely. Reported instead of leaving the screen spinning forever.
  static Duration get _stallTimeout => AppConfig.aiStallTimeout;

  /// Absolute ceiling on one watch. Kept above the server's own pipeline
  /// budget so a server that fails the run on time always wins the race and
  /// the client shows the real reason.
  static Duration get _hardTimeout => AppConfig.aiHardTimeout;

  // ───────────────────────────────────────────────────────────────────────────
  // Upload
  // ───────────────────────────────────────────────────────────────────────────

  /// Uploads the documents and voice note and starts the analysis.
  ///
  /// Returns the new session id. Progress arrives through [watch].
  ///
  /// [requestId] makes the call idempotent: the server records it on the
  /// session and returns the *same* session for a repeat of the same key, so a
  /// retry after a timeout cannot start a second analysis of the same
  /// documents. Callers must reuse one key across retries of a single intake
  /// and generate a fresh one per intake.
  Future<String> startAnalysis({
    required List<PlatformFile> files,
    File? voiceFile,
    String? voiceTranscript,
    String? voiceLanguage,
    String? issueDescription,
    required String requestId,
    CancelToken? cancelToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    _validateSelection(files);

    // Built fresh on every attempt. A FormData whose parts are file streams
    // cannot be replayed — the streams are consumed by the first send, so a
    // retry with the same instance uploads zero bytes and the server reports
    // "no documents".
    final formData = await _buildFormData(
      files: files,
      requestId: requestId,
      voiceFile: voiceFile,
      voiceTranscript: voiceTranscript,
      voiceLanguage: voiceLanguage,
      issueDescription: issueDescription,
    );

    AILog.info('upload:start', '${files.length} file(s), voice=${voiceFile != null}');

    final response = await DioClient.dio.post(
      '/ai/smart-case/analyze',
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onProgress,
      options: Options(
        // `X-Request-Id` is not a CORS-safelisted header, so sending it from a
        // browser forces a preflight and the server must name it in
        // `Access-Control-Allow-Headers`. The deployment's reverse proxy
        // answers OPTIONS itself and allows only `Content-Type, Authorization`,
        // so every web upload failed the preflight with an opaque
        // XMLHttpRequest error before it was ever sent.
        //
        // The key travels as a form field instead (see [_buildFormData]),
        // which needs no preflight approval. The header is still sent on
        // native, where CORS does not apply and it remains useful for tracing
        // a request through the proxy's own logs.
        headers: kIsWeb ? null : {'X-Request-Id': requestId},
        sendTimeout: _uploadTimeout,
        receiveTimeout: _uploadTimeout,
        // 202 Accepted is the success case here.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    final body = _asJsonMap(response.data);
    final data = _asJsonMap(body?['data']) ?? const <String, dynamic>{};
    final sessionId = (data['sessionId'] ?? '').toString();

    if (sessionId.isEmpty) {
      final message = (body?['message'] ?? '').toString();
      AILog.error('upload:no-session-id', message);
      throw Exception(
        message.isNotEmpty ? message : 'Could not start the analysis. Please try again.',
      );
    }

    AILog.session = sessionId;
    AILog.info('upload:accepted', 'session $sessionId');
    return sessionId;
  }

  /// Rejects a selection the server is guaranteed to refuse, before uploading.
  void _validateSelection(List<PlatformFile> files) {
    if (files.isEmpty) {
      throw const AnalysisInputException(
        'Please upload at least one document before starting the analysis.',
      );
    }

    if (files.length > maxFileCount) {
      throw AnalysisInputException(
        'You can analyse up to $maxFileCount documents at a time. '
        'Please remove ${files.length - maxFileCount} and try again.',
      );
    }

    final oversized = files.where((f) => f.size > maxFileBytes).map((f) => f.name);
    if (oversized.isNotEmpty) {
      throw AnalysisInputException(
        'These files are over 10 MB and cannot be uploaded: ${oversized.join(', ')}.',
      );
    }
  }

  Future<FormData> _buildFormData({
    required List<PlatformFile> files,
    required String requestId,
    File? voiceFile,
    String? voiceTranscript,
    String? voiceLanguage,
    String? issueDescription,
  }) async {
    final formData = FormData();

    // First part, before any file: the idempotency key.
    //
    // It also travels as the `X-Request-Id` header on native, but not on web —
    // see the note in [uploadForAnalysis]. Multer fills `req.body` from the
    // non-file parts, so the server finds it here either way, and putting it
    // ahead of the documents means it has been parsed before any large part is
    // read.
    formData.fields.add(MapEntry('requestId', requestId));

    for (final file in files) {
      final bytes = file.bytes;
      final path = file.path;

      final MultipartFile part;
      if (bytes != null) {
        // Web (and native when withData was requested).
        part = MultipartFile.fromBytes(bytes, filename: file.name);
      } else if (path != null && !kIsWeb) {
        // Native: stream from disk rather than loading the whole file into RAM.
        // Confirm it is still there — a file picked from a cache directory can
        // be reclaimed by the OS between picking and uploading, and
        // `fromFile` on a missing path fails mid-send with an opaque error.
        if (!await File(path).exists()) {
          throw AnalysisInputException(
            '"${file.name}" is no longer available on this device. '
            'Please remove it and select it again.',
          );
        }
        part = await MultipartFile.fromFile(path, filename: file.name);
      } else {
        // Skipping would silently drop the client's document — fail loudly.
        throw AnalysisInputException(
          'Could not read "${file.name}". Please remove it and try again.',
        );
      }

      formData.files.add(MapEntry('documents', part));
    }

    if (voiceFile != null) {
      // A recording that has been cleaned up must not abort the whole intake:
      // it is an optional supplement to the documents.
      if (await voiceFile.exists()) {
        final voiceName = voiceFile.path.split('/').last.split('\\').last;
        formData.files.add(
          MapEntry(
            'voice',
            await MultipartFile.fromFile(voiceFile.path, filename: voiceName),
          ),
        );
      } else {
        AILog.warn('upload:voice-missing', voiceFile.path);
      }
    }

    final transcript = voiceTranscript?.trim() ?? '';
    if (transcript.isNotEmpty) {
      formData.fields.add(MapEntry('voiceTranscript', transcript));

      // The language the client actually spoke, travelling with their words so
      // the backend labels the transcript rather than inferring — or
      // normalising — a language for it. Sent only alongside a transcript,
      // since on its own it describes nothing.
      final language = voiceLanguage?.trim() ?? '';
      if (language.isNotEmpty) {
        formData.fields.add(MapEntry('voiceLanguage', language));
      }
    }

    final description = (issueDescription ?? '').trim();
    if (description.isNotEmpty) {
      formData.fields.add(MapEntry('issueDescription', description));
    }

    return formData;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Watch
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams the real progress of [sessionId] until it completes or fails.
  ///
  /// Two independent channels feed this stream and both read the same
  /// server-side state, so they cannot disagree:
  ///
  ///  * **Socket.IO** on the authenticated `/ai` namespace, which delivers each
  ///    transition the moment it happens. It reconnects on its own, and every
  ///    reconnect triggers an immediate reconcile poll because events that
  ///    occurred while it was down were not queued anywhere.
  ///  * **Polling** `GET /ai/smart-case/session/:id`, fast while the socket is
  ///    down and a slow heartbeat while it is up. The heartbeat is what catches
  ///    a half-open socket that reports itself connected while no packets flow.
  ///
  /// The stream always terminates: on a result, on a failure, on a stall with
  /// no news from either channel, or on the hard timeout. It never hangs.
  Stream<AnalysisEvent> watch(String sessionId) {
    late StreamController<AnalysisEvent> controller;

    io.Socket? socket;
    Timer? pollTimer;
    Timer? stallTimer;
    Timer? hardTimer;

    var finished = false;
    var polling = false;
    var socketConnected = false;
    var consecutivePollFailures = 0;
    var lastPercent = -1;
    var lastStage = '';

    /// Everything this watch owns, released exactly once.
    void cleanUp() {
      pollTimer?.cancel();
      pollTimer = null;
      stallTimer?.cancel();
      stallTimer = null;
      hardTimer?.cancel();
      hardTimer = null;

      final s = socket;
      socket = null;
      if (s != null) {
        // Clear handlers before disposing. A queued callback that fires during
        // teardown would otherwise touch a closed controller.
        s.clearListeners();
        s.dispose();
      }
    }

    /// Guards every emission. Between an `await` and its continuation the
    /// stream may have been closed by the other channel or cancelled by the
    /// listener, and adding to a closed controller throws.
    void safeAdd(AnalysisEvent event) {
      if (finished || controller.isClosed) return;
      controller.add(event);
    }

    void finish(AnalysisEvent event, String reason) {
      if (finished) return;
      finished = true;
      AILog.info('watch:finish', reason);
      if (!controller.isClosed) {
        controller.add(event);
        controller.close();
      }
      cleanUp();
    }

    /// Restarts the "nothing is happening" countdown. Called on every genuine
    /// sign of life, from either channel.
    void noteActivity() {
      if (finished) return;
      stallTimer?.cancel();
      stallTimer = Timer(_stallTimeout, () {
        finish(
          const AnalysisEvent.failed(
            'We lost contact with the analysis and it stopped responding. '
            'Please check your connection and try again.',
          ),
          'stalled for ${_stallTimeout.inMinutes}m',
        );
      });
    }

    /// Emits progress, dropping repeats.
    ///
    /// The socket and the poll both report the same state, so without this the
    /// progress bar receives the same value several times a second on a healthy
    /// connection and every listener rebuilds for nothing.
    void emitProgress(AnalysisProgress progress) {
      noteActivity();
      if (progress.stage == lastStage && progress.percent == lastPercent) return;
      lastStage = progress.stage;
      lastPercent = progress.percent;
      safeAdd(AnalysisEvent.progress(progress));
    }

    /// Turns any completion-shaped payload into a result, from either channel.
    void handleComplete(Map<String, dynamic> data, String source) {
      final id = (data['sessionId'] ?? '').toString();
      if (id != sessionId) {
        // Another intake of this same user, delivered to the shared user room.
        AILog.debug('watch:ignored-foreign-complete', id);
        return;
      }
      finish(AnalysisEvent.complete(ExtractionResult.fromJson(data)), 'complete via $source');
    }

    void handleFailure(String message, String source) {
      finish(
        AnalysisEvent.failed(
          message.isNotEmpty
              ? message
              : 'The analysis could not be completed. Please try again.',
        ),
        'failed via $source',
      );
    }

    /// Assigned below, once [pollOnce] exists. Declared here because the two
    /// are mutually recursive: a poll schedules the next one, and the scheduler
    /// runs a poll.
    late final void Function(Duration delay) schedulePoll;

    /// One reconciliation against the authoritative session document.
    Future<void> pollOnce({String reason = 'timer'}) async {
      if (finished || polling) return;
      polling = true;

      try {
        final response = await DioClient.dio.get(
          '/ai/smart-case/session/$sessionId',
          options: Options(
            receiveTimeout: AppConfig.aiStatusReceiveTimeout,
            // Handled below rather than thrown, so a 404 or a 401 produces a
            // real message instead of being swallowed as "a poll failed".
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (finished) return;

        final status = response.statusCode ?? 0;

        if (status == 401 || status == 403) {
          handleFailure('Your session expired. Please sign in again.', 'poll');
          return;
        }

        if (status == 404) {
          handleFailure(
            'This analysis is no longer available. Please start a new one.',
            'poll',
          );
          return;
        }

        if (status >= 400) {
          throw DioException.badResponse(
            statusCode: status,
            requestOptions: response.requestOptions,
            response: response,
          );
        }

        final body = _asJsonMap(response.data);
        final data = _asJsonMap(body?['data']);
        if (data == null) {
          AILog.warn('poll:unexpected-body', response.data.runtimeType);
          return;
        }

        // A response arrived and parsed: the run is reachable.
        consecutivePollFailures = 0;
        noteActivity();

        final sessionStatus = (data['status'] ?? '').toString();

        if (sessionStatus == 'extracted') {
          handleComplete(data, 'poll($reason)');
          return;
        }

        if (sessionStatus == 'failed') {
          handleFailure((data['failureReason'] ?? '').toString(), 'poll($reason)');
          return;
        }

        final progress = _asJsonMap(data['progress']);
        if (progress != null) {
          emitProgress(AnalysisProgress.fromJson(progress));
        }
      } catch (e) {
        if (finished) return;

        consecutivePollFailures += 1;
        AILog.warn('poll:failed', '#$consecutivePollFailures $e');

        // Only fatal once the socket has clearly stopped covering for it. While
        // the socket is up, a failing poll is a nuisance, not an outage.
        if (!socketConnected && consecutivePollFailures >= _maxConsecutivePollFailures) {
          handleFailure(
            'We could not reach the server to check on your analysis. '
            'Please check your connection and try again.',
            'poll',
          );
        }
      } finally {
        polling = false;
        if (!finished) schedulePoll(_nextPollDelay(socketConnected, consecutivePollFailures));
      }
    }

    /// Self-rescheduling rather than `Timer.periodic`.
    ///
    /// A periodic timer fires on a fixed cadence regardless of whether the
    /// previous poll finished, so on a slow connection requests pile up and
    /// arrive out of order — the exact "random failures" this flow was showing.
    /// Here the next poll is only scheduled once the previous one has returned.
    schedulePoll = (Duration delay) {
      if (finished) return;
      pollTimer?.cancel();
      pollTimer = Timer(delay, () => pollOnce());
    };

    Future<void> connectSocket() async {
      final token = await TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        finish(
          const AnalysisEvent.failed('Your session expired. Please sign in again.'),
          'no auth token',
        );
        return;
      }
      if (finished) return;

      final created = io.io(
        AppConfig.aiSocketUrl,
        io.OptionBuilder()
            // Websocket first, long-polling second. Websocket-only meant that
            // on any network where it is blocked (corporate proxies, some
            // mobile carriers, captive portals) the socket never connected at
            // all and the whole run limped along on the HTTP poll.
            .setTransports(['websocket', 'polling'])
            // Never share a Manager with another watch or with /chat. Without
            // this, socket.io caches the connection per URI and `dispose()` at
            // the end of one run tears down a concurrent one.
            .enableForceNew()
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(
              AppConfig.aiSocketReconnectDelay.inMilliseconds,
            )
            .setReconnectionDelayMax(
              AppConfig.aiSocketReconnectDelayMax.inMilliseconds,
            )
            // AI_SOCKET_RECONNECT_ATTEMPTS is set high enough to retry for as
            // long as the watch is alive. A capped count means a device that
            // spends a minute on a dead network never reconnects, and the run
            // silently degrades to polling forever.
            .setReconnectionAttempts(AppConfig.aiSocketReconnectAttempts)
            .setTimeout(AppConfig.aiSocketConnectTimeout.inMilliseconds)
            .build(),
      );

      // A function, not a literal map: it is re-evaluated on every connect
      // attempt, so a reconnect after the token was refreshed presents the
      // current token rather than the one captured when the watch started.
      created.auth = (callback) => callback({
            'token': TokenStorage.cachedToken ?? token,
          });

      created
        ..on('analysis_progress', (raw) {
          final data = _asJsonMap(raw);
          if (data == null) return;
          if ((data['sessionId'] ?? '').toString() != sessionId) return;
          emitProgress(AnalysisProgress.fromJson(data));
        })
        ..on('analysis_complete', (raw) {
          final data = _asJsonMap(raw);
          if (data == null) return;
          handleComplete(data, 'socket');
        })
        ..on('analysis_failed', (raw) {
          final data = _asJsonMap(raw);
          if (data == null) return;
          if ((data['sessionId'] ?? '').toString() != sessionId) return;
          handleFailure((data['message'] ?? '').toString(), 'socket');
        })
        ..onConnect((_) {
          socketConnected = true;
          AILog.info('socket:connected');
          noteActivity();
          // Events emitted while the socket was down were not queued anywhere,
          // so reconcile against the session immediately instead of waiting for
          // the next scheduled poll.
          pollOnce(reason: 'connect');
        })
        ..onDisconnect((reason) {
          socketConnected = false;
          AILog.warn('socket:disconnected', reason);
          // Fall back to the fast cadence straight away rather than waiting out
          // the slow heartbeat that was scheduled while the socket was healthy.
          schedulePoll(_pollIntervalDisconnected);
        })
        ..onConnectError((e) {
          socketConnected = false;
          AILog.warn('socket:connect-error', e);
        })
        ..onError((e) {
          AILog.warn('socket:error', e);
        });

      if (finished) {
        created.clearListeners();
        created.dispose();
        return;
      }

      socket = created;
      created.connect();
    }

    Future<void> start() async {
      AILog.session = sessionId;
      AILog.info('watch:start');

      noteActivity();

      hardTimer = Timer(_hardTimeout, () {
        finish(
          const AnalysisEvent.failed(
            'The analysis is taking longer than expected and was stopped. '
            'Please try again with fewer or smaller documents.',
          ),
          'hard timeout',
        );
      });

      // The run may already have finished between the POST returning and this
      // subscription starting — a small text file can analyse that fast. Poll
      // before the socket so that case is caught even if the socket never
      // connects. This also schedules the recurring poll.
      await pollOnce(reason: 'initial');

      if (finished) return;
      await connectSocket();
    }

    controller = StreamController<AnalysisEvent>(
      onListen: () {
        start().catchError((Object e, StackTrace s) {
          AILog.error('watch:start-failed', e, s);
          finish(
            const AnalysisEvent.failed(
              'Could not follow the analysis. Please try again.',
            ),
            'start threw',
          );
        });
      },
      // The listener went away (screen closed, provider reset). Release the
      // socket and both timers immediately — without this a poll kept running
      // every few seconds for up to ten minutes after the screen was gone.
      onCancel: () {
        finished = true;
        AILog.info('watch:cancelled');
        cleanUp();
      },
    );

    return controller.stream;
  }

  /// Poll cadence: fast while the socket is down, a slow heartbeat while it is
  /// up, and exponential backoff once polls start failing so a struggling
  /// server is not hammered.
  static Duration _nextPollDelay(bool socketConnected, int consecutiveFailures) {
    final base = socketConnected ? _pollIntervalConnected : _pollIntervalDisconnected;
    if (consecutiveFailures == 0) return base;

    final backoff = base * math.pow(2, math.min(consecutiveFailures, 4)).toDouble();
    return backoff > _pollBackoffMax ? _pollBackoffMax : backoff;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Audit trail
  // ───────────────────────────────────────────────────────────────────────────

  /// Records which case this intake session produced, closing the audit trail
  /// from uploaded document to filed case.
  ///
  /// Best-effort with a couple of retries: a failure here must never block the
  /// client, whose case has already been created, but a single dropped packet
  /// should not silently break the trail either.
  Future<void> linkSessionToCase({
    required String sessionId,
    required String caseId,
  }) async {
    if (sessionId.isEmpty || caseId.isEmpty) return;

    final maxAttempts = AppConfig.aiRequestMaxRetries;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await DioClient.dio.post(
          '/ai/smart-case/session/$sessionId/link-case',
          data: {'caseId': caseId},
          options: Options(receiveTimeout: AppConfig.aiResultReceiveTimeout),
        );
        AILog.info('link-case:ok', caseId);
        return;
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        // A rejected link will be rejected identically next time.
        if (status >= 400 && status < 500) {
          AILog.warn('link-case:rejected', 'HTTP $status');
          return;
        }
        AILog.warn('link-case:retry', 'attempt ${attempt + 1}: $e');
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(
            AppConfig.aiRetryBaseDelay * (attempt + 1),
          );
        }
      } catch (e) {
        AILog.warn('link-case:failed', e);
        return;
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Payload normalisation
  // ───────────────────────────────────────────────────────────────────────────

  /// Normalises a socket or HTTP payload into plain Dart JSON.
  ///
  /// socket.io hands over maps keyed `dynamic`, and on Flutter Web the values
  /// come back as JS-backed collections. The model parsers test
  /// `is Map<String, dynamic>` and `as Map`, which fail or throw for those, so
  /// a nested object such as `extracted` or `uploadedDocuments` was read as
  /// empty. Converting the whole tree once, here, keeps every parser
  /// downstream working on real JSON — the same approach `ChatSocketService`
  /// already uses.
  static Map<String, dynamic>? _asJsonMap(dynamic value) {
    final converted = _convert(value);
    return converted is Map<String, dynamic> ? converted : null;
  }

  static dynamic _convert(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries) entry.key.toString(): _convert(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_convert).toList();
    }
    return value;
  }
}
