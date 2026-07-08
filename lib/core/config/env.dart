import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  Environment._();

  static String get baseUrl {
    // Flutter Web always uses localhost (same machine)
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    // Mobile/Desktop: read from .env — set BASE_URL to your PC's LAN IP
    // e.g. http://192.168.x.x:5000/api for physical device
    // or   http://10.0.2.2:5000/api  for Android emulator
    return dotenv.env['BASE_URL'] ?? 'http://localhost:5000/api';
  }
}