import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../storage/token_storage.dart';
import 'fallback_config.dart';

/// Raised when configuration omits a value the app requires, or supplies one
/// that cannot be parsed into the expected type.
///
/// A missing key is a deployment error and is reported as one at startup,
/// rather than silently degrading into an empty base URL or a zero-second
/// timeout. The only thing that can stand in for a missing value is
/// [FallbackConfig], and only when [AppConfig.fallbackEnabled].
///
/// Messages name the offending key and, for a malformed value, show what was
/// read — with the value redacted whenever the key's name marks it as a
/// secret, since this text reaches logs and the on-device error screen.
class AppConfigError extends Error {
  AppConfigError(this.problems);

  /// One human-readable line per offending key. Never contains a secret value.
  final List<String> problems;

  @override
  String toString() {
    final buffer = StringBuffer(
      'Invalid application configuration.\n'
      'Every configurable value is read from .env; the code defines no '
      'defaults. Fix the following and rebuild:\n',
    );
    for (final problem in problems) {
      buffer.writeln('  • $problem');
    }
    if (AppConfig.strictConfig) {
      buffer.writeln(
        '\nThis build was compiled with --dart-define=STRICT_ENV_CONFIG=true, '
        'so FallbackConfig was not consulted. Drop that flag to let the '
        'fallback cover gaps in .env.',
      );
    }
    return buffer.toString();
  }
}

/// The single source of truth for every environment-specific and operationally
/// tunable value in the app.
///
/// Nothing outside this class may read [dotenv] or [FallbackConfig] directly,
/// and nothing may hardcode a URL, timeout, limit or flag that belongs here.
/// Adding a value means adding a getter *and* registering it in [_probes], so
/// that [validate] catches its absence at launch instead of at the call site.
///
/// ## Resolution order
///
/// 1. `.env`, loaded by [load] and bundled as a Flutter asset.
/// 2. [FallbackConfig], whenever `.env` does not supply a usable value. This
///    is **on by default**: a key that is missing, commented out, blank, or an
///    `.env` that fails to load at all, resolves here and the app keeps
///    running. Which keys were served this way is reported by
///    [keysServedByFallback] and logged at startup.
/// 3. [AppConfigError] — only if a key is absent from *both*, or the value
///    found is malformed (a non-numeric timeout, a relative URL). A bad value
///    is a mistake to fix, not a gap to paper over, so it is never swallowed.
///
/// Strict mode turns step 2 off, making any gap in `.env` fatal:
///
/// ```sh
/// flutter build apk --dart-define=STRICT_ENV_CONFIG=true
/// ```
///
/// That is worth running in CI or before a release, to prove the shipped
/// `.env` is complete on its own rather than leaning on the fallback.
class AppConfig {
  AppConfig._();

  /// Whether a gap in `.env` is fatal rather than filled from
  /// [FallbackConfig]. Off unless the build asks for it with
  /// `--dart-define=STRICT_ENV_CONFIG=true`.
  static const bool strictConfig = bool.fromEnvironment('STRICT_ENV_CONFIG');

  /// Whether [FallbackConfig] may stand in for values `.env` does not supply.
  ///
  /// True unless [strictConfig] was set at build time. The fallback is the
  /// default so that a missing, renamed or commented-out key degrades to a
  /// working app rather than a configuration error screen.
  static const bool fallbackEnabled = !strictConfig;

  /// Keys being served by [FallbackConfig] rather than `.env`.
  ///
  /// Exposed so a build can report that it is running on fallback values.
  /// Holds key names only — never values.
  ///
  /// Accumulated as keys are read, so it is complete only after something has
  /// read all of them. [load] does exactly that via [validate] before the
  /// first frame, which is why the startup log can be trusted; a caller
  /// inspecting it later should call [validate] first.
  static Set<String> get keysServedByFallback =>
      Set<String>.unmodifiable(_fallbackKeys);

  static final Set<String> _fallbackKeys = <String>{};

  /// True when at least one value came from [FallbackConfig].
  static bool get isRunningOnFallback => _fallbackKeys.isNotEmpty;

  // ───────────────────────────────────────────────────────────────────────────
  // Secret hygiene
  // ───────────────────────────────────────────────────────────────────────────

  /// Key names whose values must never appear in an error message, a log line
  /// or the on-device error screen.
  ///
  /// The app holds no client-side secrets today — credentials such as
  /// `GEMINI_API_KEY` live in `backend/.env` and stay server-side. This exists
  /// so that if one is ever added, it cannot leak through a validation message
  /// written before anyone thought about it.
  static final RegExp _sensitiveKey = RegExp(
    r'SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|PRIVATE|SIGNING|API_KEY|_KEY$|^KEY_',
  );

  static bool isSensitive(String key) => _sensitiveKey.hasMatch(key);

  /// Renders a value for an error message, redacting it if [key] is sensitive.
  static String _show(String key, String value) =>
      isSensitive(key) ? '<redacted>' : '"$value"';

  // ───────────────────────────────────────────────────────────────────────────
  // Typed readers — every one throws rather than inventing a default.
  // ───────────────────────────────────────────────────────────────────────────

  static String _raw(String key) {
    // `dotenv.env` throws if load() never ran or failed, which is a legitimate
    // state when the fallback is carrying an emergency build.
    final fromEnv = dotenv.isInitialized ? dotenv.env[key]?.trim() : null;
    if (fromEnv != null && fromEnv.isNotEmpty) {
      _fallbackKeys.remove(key);
      return fromEnv;
    }

    if (fallbackEnabled) {
      final fromFallback = FallbackConfig.values[key]?.trim();
      if (fromFallback != null && fromFallback.isNotEmpty) {
        _fallbackKeys.add(key);
        return fromFallback;
      }
      throw AppConfigError([
        '$key is missing from .env and has no entry in FallbackConfig',
      ]);
    }

    throw AppConfigError([
      '$key is missing or empty in .env (strict mode: no fallback)',
    ]);
  }

  static int _int(String key) {
    final raw = _raw(key);
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw AppConfigError([
        '$key must be an integer, got ${_show(key, raw)}',
      ]);
    }
    return parsed;
  }

  /// Rejects zero and negatives for values used as counts, limits and delays,
  /// where a non-positive number is never a meaningful configuration.
  static int _positiveInt(String key) {
    final value = _int(key);
    if (value <= 0) {
      throw AppConfigError(['$key must be greater than 0, got $value']);
    }
    return value;
  }

  static bool _bool(String key) {
    final raw = _raw(key).toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    throw AppConfigError([
      '$key must be true or false, got ${_show(key, raw)}',
    ]);
  }

  static Duration _millis(String key) =>
      Duration(milliseconds: _positiveInt(key));

  static Duration _seconds(String key) => Duration(seconds: _positiveInt(key));

  static Duration _minutes(String key) => Duration(minutes: _positiveInt(key));

  /// An absolute `scheme://host` URL. Any trailing slash is removed so callers
  /// can concatenate a path without producing a double slash.
  static String _url(String key) {
    final raw = _raw(key);
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw AppConfigError([
        '$key must be an absolute URL such as https://host/api, '
            'got ${_show(key, raw)}',
      ]);
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// A Socket.IO namespace path, normalised to a single leading slash.
  static String _namespace(String key) {
    final raw = _raw(key);
    final trimmed = raw.replaceAll(RegExp(r'^/+|/+$'), '');
    if (trimmed.isEmpty) {
      throw AppConfigError([
        '$key must name a socket namespace such as /chat, '
            'got ${_show(key, raw)}',
      ]);
    }
    return '/$trimmed';
  }

  static String _email(String key) {
    final raw = _raw(key);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw)) {
      throw AppConfigError([
        '$key must be an email address, got ${_show(key, raw)}',
      ]);
    }
    return raw;
  }

  /// A comma-separated list, blanks discarded, order preserved.
  static List<String> _csvList(String key) {
    final values = _raw(key)
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isEmpty) {
      throw AppConfigError([
        '$key must list at least one comma-separated value',
      ]);
    }
    return values;
  }

  /// As [_csvList], where order does not matter and duplicates are meaningless.
  static Set<String> _csvSet(String key) => _csvList(key).toSet();

  /// A `name=value|name=value` map. Pipe-separated because the values are URLs
  /// and the names are display strings, both of which may contain commas.
  /// Only the first `=` splits, so values keep any of their own.
  static Map<String, String> _pipedMap(String key) {
    final entries = <String, String>{};
    for (final chunk in _raw(key).split('|')) {
      final pair = chunk.trim();
      if (pair.isEmpty) continue;

      final separator = pair.indexOf('=');
      if (separator <= 0 || separator == pair.length - 1) {
        throw AppConfigError([
          '$key entry ${_show(key, pair)} must be written as name=value',
        ]);
      }
      entries[pair.substring(0, separator).trim()] =
          pair.substring(separator + 1).trim();
    }

    if (entries.isEmpty) {
      throw AppConfigError([
        '$key must list at least one name=value entry',
      ]);
    }
    return entries;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Backend endpoints
  // ───────────────────────────────────────────────────────────────────────────

  /// REST API root, including any `/api` prefix. Used as the Dio `baseUrl`.
  static String get baseUrl => _url('BASE_URL');

  /// Origin the Socket.IO namespaces and `/uploads` assets are served from.
  ///
  /// Configured outright rather than derived from [baseUrl] by stripping
  /// `/api`: that derivation silently produced the wrong origin whenever the
  /// API lived under a different prefix, or the socket server on a different
  /// host, and there was no way to correct it without editing source.
  static String get socketBaseUrl => _url('SOCKET_BASE_URL');

  static String get chatSocketUrl =>
      '$socketBaseUrl${_namespace('SOCKET_NAMESPACE_CHAT')}';

  static String get notificationSocketUrl =>
      '$socketBaseUrl${_namespace('SOCKET_NAMESPACE_NOTIFICATIONS')}';

  static String get aiSocketUrl =>
      '$socketBaseUrl${_namespace('SOCKET_NAMESPACE_AI')}';

  static String get caseSocketUrl =>
      '$socketBaseUrl${_namespace('SOCKET_NAMESPACE_CASES')}';

  // ───────────────────────────────────────────────────────────────────────────
  // HTTP client
  // ───────────────────────────────────────────────────────────────────────────

  static Duration get httpConnectTimeout =>
      _seconds('HTTP_CONNECT_TIMEOUT_SECONDS');

  static Duration get httpReceiveTimeout =>
      _seconds('HTTP_RECEIVE_TIMEOUT_SECONDS');

  static Duration get httpSendTimeout => _seconds('HTTP_SEND_TIMEOUT_SECONDS');

  static int get httpMaxRetries => _positiveInt('HTTP_MAX_RETRIES');

  /// First retry waits this long; each further attempt doubles it.
  static Duration get httpRetryBaseDelay =>
      _seconds('HTTP_RETRY_BASE_DELAY_SECONDS');

  /// Feature flag: attach the pretty request/response logger to Dio.
  static bool get httpLogRequests => _bool('HTTP_LOG_REQUESTS');

  // ───────────────────────────────────────────────────────────────────────────
  // Chat socket
  // ───────────────────────────────────────────────────────────────────────────

  static Duration get chatSocketReconnectDelay =>
      _millis('CHAT_SOCKET_RECONNECT_DELAY_MS');

  static Duration get chatSocketReconnectDelayMax =>
      _millis('CHAT_SOCKET_RECONNECT_DELAY_MAX_MS');

  static int get chatSocketReconnectAttempts =>
      _positiveInt('CHAT_SOCKET_RECONNECT_ATTEMPTS');

  // ───────────────────────────────────────────────────────────────────────────
  // Notification socket
  // ───────────────────────────────────────────────────────────────────────────

  static Duration get notificationSocketReconnectDelay =>
      _millis('NOTIFICATION_SOCKET_RECONNECT_DELAY_MS');

  static Duration get notificationSocketReconnectDelayMax =>
      _millis('NOTIFICATION_SOCKET_RECONNECT_DELAY_MAX_MS');

  static int get notificationSocketReconnectAttempts =>
      _positiveInt('NOTIFICATION_SOCKET_RECONNECT_ATTEMPTS');

  // ───────────────────────────────────────────────────────────────────────────
  // AI intake socket
  // ───────────────────────────────────────────────────────────────────────────

  static Duration get aiSocketReconnectDelay =>
      _millis('AI_SOCKET_RECONNECT_DELAY_MS');

  static Duration get aiSocketReconnectDelayMax =>
      _millis('AI_SOCKET_RECONNECT_DELAY_MAX_MS');

  static int get aiSocketReconnectAttempts =>
      _positiveInt('AI_SOCKET_RECONNECT_ATTEMPTS');

  static Duration get aiSocketConnectTimeout =>
      _millis('AI_SOCKET_CONNECT_TIMEOUT_MS');

  // ───────────────────────────────────────────────────────────────────────────
  // AI smart-case pipeline
  // ───────────────────────────────────────────────────────────────────────────

  /// Covers the upload itself only; no AI work is waited on inside it.
  static Duration get aiUploadTimeout => _minutes('AI_UPLOAD_TIMEOUT_MINUTES');

  /// Mirrors the server's per-file cap so a doomed upload is refused before it
  /// is sent. Keep in step with `backend/src/middleware/upload.middleware.js`.
  static int get aiMaxFileBytes => _positiveInt('AI_MAX_FILE_BYTES');

  /// Mirrors the `documents` maxCount in `backend/src/routes/ai.routes.js`.
  static int get aiMaxFileCount => _positiveInt('AI_MAX_FILE_COUNT');

  /// Extensions the backend can turn into text, checked after picking because
  /// `FileType.custom` is only advisory on some Android file providers.
  /// Mirrors EXTENSION_BY_MIME in `backend/src/middleware/upload.middleware.js`.
  static Set<String> get aiAllowedUploadExtensions =>
      _csvSet('AI_ALLOWED_UPLOAD_EXTENSIONS');

  /// Extensions offered in the system file picker. A subset of
  /// [aiAllowedUploadExtensions] — some accepted types are not worth surfacing.
  static List<String> get aiPickerExtensions =>
      _csvList('AI_UPLOAD_PICKER_EXTENSIONS');

  /// Poll cadence while the socket is down — the path that has to keep the
  /// screen moving, so the tighter of the two.
  static Duration get aiPollIntervalDisconnected =>
      _seconds('AI_POLL_INTERVAL_DISCONNECTED_SECONDS');

  /// Poll cadence while the socket is up: a slow reconciliation heartbeat that
  /// catches a silently half-open connection.
  static Duration get aiPollIntervalConnected =>
      _seconds('AI_POLL_INTERVAL_CONNECTED_SECONDS');

  /// Ceiling on the exponential backoff applied after a failed poll.
  static Duration get aiPollBackoffMax =>
      _seconds('AI_POLL_BACKOFF_MAX_SECONDS');

  /// Consecutive poll failures tolerated before the run is reported failed.
  static int get aiMaxConsecutivePollFailures =>
      _positiveInt('AI_MAX_CONSECUTIVE_POLL_FAILURES');

  /// No progress and no successful poll for this long ends the run.
  static Duration get aiStallTimeout => _minutes('AI_STALL_TIMEOUT_MINUTES');

  /// Absolute ceiling on one watch. Keep above the server's pipeline budget so
  /// the server always wins the race and reports the real reason.
  static Duration get aiHardTimeout => _minutes('AI_HARD_TIMEOUT_MINUTES');

  /// Absolute ceiling on one end-to-end run, covering the window before a
  /// watch even exists. Keep above [aiHardTimeout].
  static Duration get aiRunTimeout => _minutes('AI_RUN_TIMEOUT_MINUTES');

  static Duration get aiStatusReceiveTimeout =>
      _seconds('AI_STATUS_RECEIVE_TIMEOUT_SECONDS');

  static Duration get aiResultReceiveTimeout =>
      _seconds('AI_RESULT_RECEIVE_TIMEOUT_SECONDS');

  /// Attempts made for a best-effort AI request before it is given up on.
  static int get aiRequestMaxRetries =>
      _positiveInt('AI_REQUEST_MAX_RETRIES');

  /// Nth retry of an AI request waits `n × this`, capped at [aiRetryMaxDelay].
  static Duration get aiRetryBaseDelay =>
      _seconds('AI_RETRY_BASE_DELAY_SECONDS');

  static Duration get aiRetryMaxDelay => _seconds('AI_RETRY_MAX_DELAY_SECONDS');

  // ───────────────────────────────────────────────────────────────────────────
  // Uploads
  // ───────────────────────────────────────────────────────────────────────────

  /// Folders under `/uploads` the server serves without authentication.
  /// Keep in step with PUBLIC_FOLDERS in
  /// `backend/src/middleware/fileAuthMiddleware.js`.
  static Set<String> get publicUploadFolders =>
      _csvSet('PUBLIC_UPLOAD_FOLDERS');

  // ───────────────────────────────────────────────────────────────────────────
  // Practice-area banner artwork (third-party CDN)
  // ───────────────────────────────────────────────────────────────────────────

  /// Banner image per practice area, keyed by the category name shown in the
  /// UI. Hosted off a third-party CDN, so the URLs are deployment data rather
  /// than something to bake into a screen.
  static Map<String, String> get categoryBannerUrls =>
      _pipedMap('CATEGORY_BANNER_URLS');

  /// Banner for a category with no entry of its own.
  static String get categoryBannerFallbackUrl =>
      _url('CATEGORY_BANNER_FALLBACK_URL');

  /// The banner for [category], or [categoryBannerFallbackUrl] if unmapped.
  static String categoryBannerUrl(String category) =>
      categoryBannerUrls[category] ?? categoryBannerFallbackUrl;

  // ───────────────────────────────────────────────────────────────────────────
  // App metadata
  // ───────────────────────────────────────────────────────────────────────────

  static String get supportEmail => _email('SUPPORT_EMAIL');

  static String get appVersion => _raw('APP_VERSION');

  static String get buildNumber => _raw('BUILD_NUMBER');

  // ───────────────────────────────────────────────────────────────────────────
  // Place search
  // ───────────────────────────────────────────────────────────────────────────

  /// Debounce window on the location autocomplete field.
  static Duration get placeSearchDebounce =>
      _millis('PLACE_SEARCH_DEBOUNCE_MS');

  /// Shorter queries are too broad to be worth a request. The backend applies
  /// the same floor.
  static int get placeSearchMinQueryLength =>
      _positiveInt('PLACE_SEARCH_MIN_QUERY_LENGTH');

  // ───────────────────────────────────────────────────────────────────────────
  // Voice capture
  // ───────────────────────────────────────────────────────────────────────────

  static Duration get voiceNoteMaxDuration =>
      _minutes('VOICE_NOTE_MAX_DURATION_MINUTES');

  /// Locale ids offered to the speech recogniser, best first.
  static List<String> get speechPreferredLocales =>
      _csvList('SPEECH_PREFERRED_LOCALES');

  /// Ceiling on a dictated transcript. The backend applies the same limit.
  static int get maxTranscriptChars => _positiveInt('MAX_TRANSCRIPT_CHARS');

  // ───────────────────────────────────────────────────────────────────────────
  // Startup validation
  // ───────────────────────────────────────────────────────────────────────────

  /// Every configured value, read once so that [validate] can report *all*
  /// problems in a single message instead of one per run-and-crash cycle.
  static final List<void Function()> _probes = <void Function()>[
    () => baseUrl,
    () => socketBaseUrl,
    () => chatSocketUrl,
    () => notificationSocketUrl,
    () => aiSocketUrl,
    () => caseSocketUrl,
    () => httpConnectTimeout,
    () => httpReceiveTimeout,
    () => httpSendTimeout,
    () => httpMaxRetries,
    () => httpRetryBaseDelay,
    () => httpLogRequests,
    () => chatSocketReconnectDelay,
    () => chatSocketReconnectDelayMax,
    () => chatSocketReconnectAttempts,
    () => notificationSocketReconnectDelay,
    () => notificationSocketReconnectDelayMax,
    () => notificationSocketReconnectAttempts,
    () => aiSocketReconnectDelay,
    () => aiSocketReconnectDelayMax,
    () => aiSocketReconnectAttempts,
    () => aiSocketConnectTimeout,
    () => aiUploadTimeout,
    () => aiMaxFileBytes,
    () => aiMaxFileCount,
    () => aiAllowedUploadExtensions,
    () => aiPickerExtensions,
    () => aiPollIntervalDisconnected,
    () => aiPollIntervalConnected,
    () => aiPollBackoffMax,
    () => aiMaxConsecutivePollFailures,
    () => aiStallTimeout,
    () => aiHardTimeout,
    () => aiRunTimeout,
    () => aiStatusReceiveTimeout,
    () => aiResultReceiveTimeout,
    () => aiRequestMaxRetries,
    () => aiRetryBaseDelay,
    () => aiRetryMaxDelay,
    () => publicUploadFolders,
    () => categoryBannerUrls,
    () => categoryBannerFallbackUrl,
    () => supportEmail,
    () => appVersion,
    () => buildNumber,
    () => placeSearchDebounce,
    () => placeSearchMinQueryLength,
    () => voiceNoteMaxDuration,
    () => speechPreferredLocales,
    () => maxTranscriptChars,
  ];

  /// Loads `.env` and verifies it, or fails with a message that says what to
  /// do about it. The one entry point `main` needs.
  ///
  /// With [fallbackEnabled], a `.env` that is absent or unreadable is not
  /// fatal: [FallbackConfig] carries the whole configuration instead. That is
  /// the emergency-recovery path, and it announces itself in the log — by key
  /// name, never by value.
  static Future<void> load({String fileName = '.env'}) async {
    _fallbackKeys.clear();

    try {
      await dotenv.load(fileName: fileName);
    } on Object catch (error) {
      if (!fallbackEnabled) {
        throw AppConfigError([
          'Could not read $fileName ($error). Copy .env.example to $fileName '
              'and fill it in.',
        ]);
      }
      // Leave dotenv initialised but empty so every lookup misses cleanly and
      // resolves against the fallback, rather than throwing NotInitializedError
      // from whichever getter is touched first.
      dotenv.loadFromString(envString: '', isOptional: true);
    }

    validate();

    if (isRunningOnFallback) {
      // Key names only. A value could be a secret; the fact that a key was not
      // supplied never is.
      debugPrint(
        '⚠️  AppConfig: running on FallbackConfig for '
        '${_fallbackKeys.length} key(s): '
        '${(_fallbackKeys.toList()..sort()).join(', ')}. '
        'These are development values — this build must not reach users.',
      );
    }
  }

  /// Reads every configured value and throws a single
  /// [AppConfigError] listing everything that is missing or malformed.
  ///
  /// Called by [load] before the first frame, so a misconfigured build fails
  /// immediately and legibly rather than at whichever screen happens to touch
  /// the bad key first.
  static void validate() {
    final problems = <String>[];
    for (final probe in _probes) {
      try {
        probe();
      } on AppConfigError catch (error) {
        problems.addAll(error.problems);
      }
    }

    // Ordering constraints between values that are each individually valid.
    if (problems.isEmpty) {
      if (aiRunTimeout <= aiHardTimeout) {
        problems.add(
          'AI_RUN_TIMEOUT_MINUTES must exceed AI_HARD_TIMEOUT_MINUTES so the '
          'watch reports the real failure before the run gives up',
        );
      }
      final unpickable =
          aiPickerExtensions.toSet().difference(aiAllowedUploadExtensions);
      if (unpickable.isNotEmpty) {
        problems.add(
          'AI_UPLOAD_PICKER_EXTENSIONS offers ${unpickable.join(', ')}, which '
          'AI_ALLOWED_UPLOAD_EXTENSIONS rejects — every pickable extension '
          'must also be an accepted one',
        );
      }
      if (aiRetryMaxDelay < aiRetryBaseDelay) {
        problems.add(
          'AI_RETRY_MAX_DELAY_SECONDS must be at least '
          'AI_RETRY_BASE_DELAY_SECONDS',
        );
      }
      if (chatSocketReconnectDelayMax < chatSocketReconnectDelay) {
        problems.add(
          'CHAT_SOCKET_RECONNECT_DELAY_MAX_MS must be at least '
          'CHAT_SOCKET_RECONNECT_DELAY_MS',
        );
      }
      if (notificationSocketReconnectDelayMax <
          notificationSocketReconnectDelay) {
        problems.add(
          'NOTIFICATION_SOCKET_RECONNECT_DELAY_MAX_MS must be at least '
          'NOTIFICATION_SOCKET_RECONNECT_DELAY_MS',
        );
      }
      if (aiSocketReconnectDelayMax < aiSocketReconnectDelay) {
        problems.add(
          'AI_SOCKET_RECONNECT_DELAY_MAX_MS must be at least '
          'AI_SOCKET_RECONNECT_DELAY_MS',
        );
      }
    }

    if (problems.isNotEmpty) {
      throw AppConfigError(problems);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Attachment URLs
  // ───────────────────────────────────────────────────────────────────────────

  /// Maps a stored asset path — relative, or absolute against a server the app
  /// no longer talks to — onto the currently configured origin.
  static String getAttachmentUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final base = socketBaseUrl;
    String relative;
    String query = '';

    if (path.startsWith('http')) {
      try {
        final uri = Uri.parse(path);
        relative = uri.path; // e.g. /uploads/profiles/...
        // Preserve query parameters if any
        query = uri.hasQuery ? '?${uri.query}' : '';
      } catch (_) {
        return path;
      }
    } else {
      relative = path.startsWith('/') ? path : '/$path';
    }

    return '$base$relative${_withAccessToken(relative, query)}';
  }

  /// Appends the session JWT to URLs for protected upload folders.
  static String _withAccessToken(String relativePath, String existingQuery) {
    final segments = relativePath
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();

    final isUpload = segments.isNotEmpty && segments.first == 'uploads';
    final folder = segments.length > 1 ? segments[1] : '';
    if (!isUpload || publicUploadFolders.contains(folder)) {
      return existingQuery;
    }

    final token = TokenStorage.cachedToken;
    if (token == null || token.isEmpty) return existingQuery;

    final separator = existingQuery.isEmpty ? '?' : '&';
    return '$existingQuery$separator'
        'token=${Uri.encodeQueryComponent(token)}';
  }
}
