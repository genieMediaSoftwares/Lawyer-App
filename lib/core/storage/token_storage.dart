import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _tokenKey = 'jwt_token';
  static const String _roleKey = 'user_role';
  static const String _onboardingKey = 'onboarding_completed';

  static const String _idKey = 'user_id';
  static const String _nameKey = 'user_name';
  static const String _emailKey = 'user_email';
  static const String _mobileKey = 'user_mobile';
  static const String _photoKey = 'user_photo';

  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (_) {}
  }

  Future<void> saveRole(String role) async {
    try {
      await _secureStorage.write(key: _roleKey, value: role);
    } catch (_) {}
  }

  Future<String?> getRole() async {
    try {
      return await _secureStorage.read(key: _roleKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteRole() async {
    try {
      await _secureStorage.delete(key: _roleKey);
    } catch (_) {}
  }

  Future<void> saveUserDetails({
    required String id,
    required String name,
    required String email,
    required String mobile,
    String? photo,
  }) async {
    try {
      await _secureStorage.write(key: _idKey, value: id);
      await _secureStorage.write(key: _nameKey, value: name);
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _mobileKey, value: mobile);
      if (photo != null) {
        await _secureStorage.write(key: _photoKey, value: photo);
      }
    } catch (_) {}
  }

  Future<Map<String, String?>> getUserDetails() async {
    try {
      return {
        'id': await _secureStorage.read(key: _idKey),
        'name': await _secureStorage.read(key: _nameKey),
        'email': await _secureStorage.read(key: _emailKey),
        'mobile': await _secureStorage.read(key: _mobileKey),
        'photo': await _secureStorage.read(key: _photoKey),
      };
    } catch (_) {
      return {
        'id': null,
        'name': null,
        'email': null,
        'mobile': null,
        'photo': null,
      };
    }
  }

  Future<void> deleteUserDetails() async {
    try {
      await _secureStorage.delete(key: _idKey);
      await _secureStorage.delete(key: _nameKey);
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _mobileKey);
      await _secureStorage.delete(key: _photoKey);
    } catch (_) {}
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      await _secureStorage.write(
        key: _onboardingKey,
        value: completed ? 'true' : 'false',
      );
    } catch (_) {}
  }

  Future<bool> isOnboardingCompleted() async {
    try {
      final value = await _secureStorage.read(key: _onboardingKey);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAll() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _roleKey);
      await deleteUserDetails();
    } catch (_) {}
  }
}
