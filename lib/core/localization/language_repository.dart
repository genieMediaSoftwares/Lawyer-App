import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';

class LanguageRepository {
  /// Sends a request to backend to update user language preference.
  Future<bool> updateUserLanguage(String languageCode) async {
    try {
      final response = await DioClient.dio.patch(
        '/users/preferences',
        data: {'language': languageCode},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      // Return false on failure while keeping app state reactive
      return false;
    }
  }
}

final languageRepositoryProvider = Provider<LanguageRepository>((ref) {
  return LanguageRepository();
});
