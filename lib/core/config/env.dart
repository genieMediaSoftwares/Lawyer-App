import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  Environment._();

  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://localhost:5000/api';
}