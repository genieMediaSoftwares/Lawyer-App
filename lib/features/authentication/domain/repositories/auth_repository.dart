import '../entities/user_entity.dart';

class AuthResponse {
  final String token;

  /// This device's refresh token, exchanged for a new access token when the
  /// current one expires. Empty when talking to a server that does not issue
  /// one, in which case the app behaves exactly as it did before.
  final String refreshToken;

  final UserEntity user;

  AuthResponse({
    required this.token,
    required this.user,
    this.refreshToken = '',
  });
}

abstract class AuthRepository {
  Future<AuthResponse> signup({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String role,
  });

  Future<AuthResponse> login({required String email, required String password});
}
