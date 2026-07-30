import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../storage/token_storage.dart';

class Environment {
  Environment._();

  static String get baseUrl {
    final url = dotenv.env['BASE_URL'];
    if (kIsWeb) {
      if (url == null || url.isEmpty || url.contains('192.168.') || url.contains('10.0.2.2')) {
        return 'http://localhost:5000/api';
      }
    }
    if (url == null || url.isEmpty) {
      return 'http://localhost:5000/api';
    }
    return url;
  }

  // Get socket base URL (without /api suffix)
  static String get baseSocketUrl {
    return baseUrl.replaceAll('/api', '');
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
  ///
  /// Image.network, audioplayers and url_launcher cannot attach an
  /// Authorization header, so the token travels as a query parameter for these
  /// requests only. Public folders (avatars) are left clean so they stay
  /// cacheable and no token leaks into widely-shared URLs.
  static String _withAccessToken(String relativePath, String existingQuery) {
    final segments = relativePath.split('/').where((s) => s.isNotEmpty).toList();

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