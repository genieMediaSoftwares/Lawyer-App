import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  Environment._();

  static String get baseUrl {
    final url = dotenv.env['BASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('BASE_URL is not defined in the .env file. Please check your configuration.');
    }
    return url;
  }

  // Get socket base URL (without /api suffix)
  static String get baseSocketUrl {
    return baseUrl.replaceAll('/api', '');
  }

  // Helper method to dynamically map relative asset URLs to the correct server IP/port.
  // It also replaces any old/different IP address in already saved full URLs.
  static String getAttachmentUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    final base = baseSocketUrl;
    if (path.startsWith('http')) {
      try {
        final uri = Uri.parse(path);
        final relative = uri.path; // e.g. /uploads/profiles/...
        // Preserve query parameters if any
        final query = uri.hasQuery ? '?${uri.query}' : '';
        return '$base$relative$query';
      } catch (_) {
        return path;
      }
    }
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$base$cleanPath';
  }
}