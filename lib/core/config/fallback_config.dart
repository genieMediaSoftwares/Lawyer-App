/// The values [AppConfig] falls back to whenever `.env` does not supply a
/// usable one — a key that is missing, renamed, commented out or blank, or an
/// `.env` that fails to load at all.
///
/// **This is active by default.** `.env` always wins where it defines a value;
/// this file only fills gaps. The effect is that the app keeps working instead
/// of stopping at a configuration error screen, and the startup log names the
/// keys that were covered.
///
/// A build can opt out and make any gap fatal, which is worth doing in CI or
/// before a release to prove the shipped `.env` stands on its own:
///
/// ```sh
/// flutter build apk --dart-define=STRICT_ENV_CONFIG=true
/// ```
///
/// Because it is the safety net for real builds, the endpoints below are the
/// real deployment rather than placeholders — a fallback pointing at
/// `localhost` would "work" in the sense of starting up and fail at the first
/// request, which helps nobody.
///
/// ## What may live here
///
/// Endpoints, limits and flags — nothing that is a secret. This file is
/// compiled into the binary and is trivially recoverable from an APK, so it
/// must never contain:
///
///  * credentials of any kind — API keys, tokens, signing keys, passwords,
///    connection strings, service-account JSON;
///  * anything whose disclosure would cause harm.
///
/// A public hostname is not a secret and belongs here; `GEMINI_API_KEY` is and
/// does not. The app's real secrets live in `backend/.env` and are only ever
/// used server-side, which is what makes a client-side fallback safe at all.
///
/// That constraint is not merely documented — `test/app_config_test.dart`
/// fails the build if a secret-shaped key or value appears below, and if any
/// key `AppConfig` reads is missing from this map.
class FallbackConfig {
  FallbackConfig._();

  /// Every key `AppConfig` reads, keyed exactly as in `.env`.
  static const Map<String, String> values = <String, String>{
    // ── Backend endpoints ────────────────────────────────────────────────────
    // The real deployment, so a build whose .env is missing or incomplete
    // still reaches a working backend — which is the whole point of the
    // fallback being on by default.
    //
    // These are public hostnames, not credentials: the same values already
    // ship inside the bundled .env asset, so naming them here exposes nothing
    // that was not already readable from the APK. To develop against a local
    // server, set BASE_URL/SOCKET_BASE_URL in your own .env — it always wins.
    'BASE_URL': 'https://lawyerappvizag.duckdns.org/api',
    'SOCKET_BASE_URL': 'https://lawyerappvizag.duckdns.org',

    // ── Socket.IO namespaces ─────────────────────────────────────────────────
    'SOCKET_NAMESPACE_CHAT': '/chat',
    'SOCKET_NAMESPACE_NOTIFICATIONS': '/notifications',
    'SOCKET_NAMESPACE_AI': '/ai',
    'SOCKET_NAMESPACE_CASES': '/cases',

    // ── HTTP client ──────────────────────────────────────────────────────────
    'HTTP_CONNECT_TIMEOUT_SECONDS': '15',
    'HTTP_RECEIVE_TIMEOUT_SECONDS': '15',
    'HTTP_SEND_TIMEOUT_SECONDS': '15',
    'HTTP_MAX_RETRIES': '3',
    'HTTP_RETRY_BASE_DELAY_SECONDS': '2',
    // Off even in the fallback: the logger prints Authorization headers, and
    // fallback mode is exactly when a build is already in an odd state.
    'HTTP_LOG_REQUESTS': 'false',

    // ── Chat socket ──────────────────────────────────────────────────────────
    'CHAT_SOCKET_RECONNECT_DELAY_MS': '1000',
    'CHAT_SOCKET_RECONNECT_DELAY_MAX_MS': '10000',
    // 2^30. Anything above that overflows to a negative count in a web build.
    'CHAT_SOCKET_RECONNECT_ATTEMPTS': '1073741824',

    // ── Notification socket ──────────────────────────────────────────────────
    'NOTIFICATION_SOCKET_RECONNECT_DELAY_MS': '2000',
    'NOTIFICATION_SOCKET_RECONNECT_DELAY_MAX_MS': '5000',
    'NOTIFICATION_SOCKET_RECONNECT_ATTEMPTS': '99',

    // ── AI intake socket ─────────────────────────────────────────────────────
    'AI_SOCKET_RECONNECT_DELAY_MS': '1000',
    'AI_SOCKET_RECONNECT_DELAY_MAX_MS': '10000',
    'AI_SOCKET_RECONNECT_ATTEMPTS': '1073741824',
    'AI_SOCKET_CONNECT_TIMEOUT_MS': '20000',

    // ── AI smart-case pipeline ───────────────────────────────────────────────
    'AI_UPLOAD_TIMEOUT_MINUTES': '3',
    'AI_MAX_FILE_BYTES': '10485760',
    'AI_MAX_FILE_COUNT': '10',
    'AI_ALLOWED_UPLOAD_EXTENSIONS': 'pdf,png,jpg,jpeg,webp,docx,txt,csv,md',
    'AI_UPLOAD_PICKER_EXTENSIONS': 'pdf,png,jpg,jpeg,webp,docx,txt,csv',
    'AI_POLL_INTERVAL_DISCONNECTED_SECONDS': '3',
    'AI_POLL_INTERVAL_CONNECTED_SECONDS': '12',
    'AI_POLL_BACKOFF_MAX_SECONDS': '30',
    'AI_MAX_CONSECUTIVE_POLL_FAILURES': '8',
    'AI_STALL_TIMEOUT_MINUTES': '3',
    'AI_HARD_TIMEOUT_MINUTES': '10',
    'AI_RUN_TIMEOUT_MINUTES': '12',
    'AI_STATUS_RECEIVE_TIMEOUT_SECONDS': '20',
    'AI_RESULT_RECEIVE_TIMEOUT_SECONDS': '15',
    'AI_REQUEST_MAX_RETRIES': '3',
    'AI_RETRY_BASE_DELAY_SECONDS': '2',
    'AI_RETRY_MAX_DELAY_SECONDS': '8',

    // ── Uploads ──────────────────────────────────────────────────────────────
    'PUBLIC_UPLOAD_FOLDERS': 'profiles',

    // ── Practice-area banner artwork ─────────────────────────────────────────
    // Public stock photography: no credentials, nothing user-specific, and
    // nothing that identifies the production deployment.
    'CATEGORY_BANNER_URLS':
        'Criminal Law=https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600'
            '|Divorce & Family=https://images.unsplash.com/photo-1505664194779-8bebcb95c557?w=600'
            '|Property Disputes=https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=600'
            '|Civil Cases=https://images.unsplash.com/photo-1450133064473-71024230f91b?w=600'
            '|Cyber Crime=https://images.unsplash.com/photo-1563986768609-322da13575f3?w=600'
            '|GST & Taxation=https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600'
            '|Labour Law=https://images.unsplash.com/photo-1521791136364-7286472b5b5c?w=600',
    'CATEGORY_BANNER_FALLBACK_URL':
        'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600',

    // ── App metadata ─────────────────────────────────────────────────────────
    // Mirrors .env rather than using a placeholder: a client who opens Contact
    // Support on a fallback build should still reach a real inbox, and a
    // version string reading "0.0.0-fallback" in the UI looks like a bug.
    // The startup log, not these values, is what flags fallback use.
    'SUPPORT_EMAIL': 'kkdigitalteamwork@gmail.com',
    'APP_VERSION': '1.0.0',
    'BUILD_NUMBER': '1',

    // ── Place search ─────────────────────────────────────────────────────────
    'PLACE_SEARCH_DEBOUNCE_MS': '350',
    'PLACE_SEARCH_MIN_QUERY_LENGTH': '2',

    // ── Voice capture ────────────────────────────────────────────────────────
    'VOICE_NOTE_MAX_DURATION_MINUTES': '5',
    'SPEECH_PREFERRED_LOCALES': 'en_IN,en_US',
    'MAX_TRANSCRIPT_CHARS': '20000',
  };
}
