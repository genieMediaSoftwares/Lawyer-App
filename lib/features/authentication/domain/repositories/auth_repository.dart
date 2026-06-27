import '../entities/user_entity.dart';

class AuthResponse {
  final String token;
  final UserEntity user;

  AuthResponse({
    required this.token,
    required this.user,
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

  Future<AuthResponse> login({
    required String email,
    required String password,
  });
}
