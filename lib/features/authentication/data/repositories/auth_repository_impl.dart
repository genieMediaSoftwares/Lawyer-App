import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../core/errors/exceptions.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<AuthResponse> signup({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String role,
  }) async {
    try {
      return await remoteDataSource.signup(
        fullName: fullName,
        email: email,
        mobile: mobile,
        password: password,
        role: role,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      return await remoteDataSource.login(
        email: email,
        password: password,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
