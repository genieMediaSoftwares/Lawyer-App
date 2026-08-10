import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../storage/token_storage.dart';

class Environment {
  Environment._();

  static const _localFallback = 'http://localhost:5000/api';

  /// Set once the fallback has been announced, so a getter called on every
  /// request does not repeat itself.
  static bool _warnedAboutFallback = false;

  /// Says loudly, once, why the app is about to talk to localhost.
  ///
  /// This fallback is silent by design and that is what makes it expensive:
  /// a stale or mis-edited `.env` produces a confident wrong base URL, and the
  /// only symptom is a connection error at every screen that reads like the
  /// server is down. Both times that has happened here it took a log dump to
  /// work out that the app, not the backend, was misconfigured.
  ///
  /// The returned value is unchanged — this only makes the reason visible.
  static String _fallback(String reason) {
    if (!_warnedAboutFallback) {
      _warnedAboutFallback = true;
      debugPrint(
        '⚠️  BASE_URL: $reason — falling back to $_localFallback.\n'
        '    The app will only reach a backend running on this machine.\n'
        '    Fix .env, then FULLY RESTART (hot reload does not reload assets):\n'
        '      flutter clean && flutter pub get && flutter run',
      );
    }
    return _localFallback;
  }

  static String get baseUrl {
    final url = dotenv.env['BASE_URL'];

    if (url == null || url.isEmpty) {
      return _fallback('not set in .env (missing, empty or commented out)');
    }

    // A LAN or emulator address cannot be reached from a browser tab, so the
    // web build substitutes localhost rather than failing obscurely.
    if (kIsWeb && (url.contains('192.168.') || url.contains('10.0.2.2'))) {
      return _fallback('"$url" is a device-only address and the web build '
          'cannot reach it');
    }

    return url;
  }

  // Get socket base URL (without /api suffix)
  static String get baseSocketUrl {
    return baseUrl.replaceAll('/api', '');
  }

  /// Configurable Support Email Address
  static String get supportEmail {
    return dotenv.env['SUPPORT_EMAIL'] ?? 'support@genielaw.com';
  }

  /// Configurable Application Version
  static String get appVersion {
    return dotenv.env['APP_VERSION'] ?? '1.0.0';
  }

  /// Configurable Application Build Number
  static String get buildNumber {
    return dotenv.env['BUILD_NUMBER'] ?? '1';
  }

  /// Folders under /uploads the server serves without authentication.
  /// Kept in sync with PUBLIC_FOLDERS in backend/src/middleware/fileAuthMiddleware.js.
  static const _publicUploadFolders = {'profiles'};

  // Helper method to dynamically map relative asset URLs to the correct server IP/port.
  // It also replaces any old/different IP address in already saved full URLs.
  static String getAttachmentUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final base = baseSocketUrl;
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
    if (!isUpload || _publicUploadFolders.contains(folder)) {
      return existingQuery;
    }

    final token = TokenStorage.cachedToken;
    if (token == null || token.isEmpty) return existingQuery;

    final separator = existingQuery.isEmpty ? '?' : '&';
    return '$existingQuery$separator'
        'token=${Uri.encodeQueryComponent(token)}';
  }
}
