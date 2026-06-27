import '../repositories/auth_repository.dart';

class SignupUseCase {
  final AuthRepository repository;

  SignupUseCase(this.repository);

  Future<AuthResponse> call({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String role,
  }) {
    return repository.signup(
      fullName: fullName,
      email: email,
      mobile: mobile,
      password: password,
      role: role,
    );
  }
}
