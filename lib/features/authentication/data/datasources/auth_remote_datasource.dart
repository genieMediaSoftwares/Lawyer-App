import 'package:dio/dio.dart';
import '../models/auth_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/storage/token_storage.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponse> signup({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String role,
  });

  Future<AuthResponse> login({required String email, required String password});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;
  final TokenStorage _tokenStorage = TokenStorage();

  AuthRemoteDataSourceImpl({required this.dio});

  /// Turns a failed auth call into a [ServerException] that keeps the backend's
  /// message *and* its code.
  ///
  /// The code is what lets a caller distinguish "this email is already
  /// registered" from "invalid email or password" from "already signed in on
  /// another device"; before, every one of them arrived as an untyped string.
  /// [ErrorInterceptor] has usually mapped the response already, so prefer its
  /// result and only re-read the body when it has not.
  Never _throwMapped(DioException e, String fallback) {
    final mapped = e.error;
    if (mapped is ServerException) throw mapped;
    if (mapped is NetworkException) throw mapped;

    final responseData = e.response?.data;
    if (responseData is Map) {
      final message = responseData['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw ServerException(
          message,
          code: responseData['code']?.toString(),
        );
      }
    }

    throw ServerException(e.message ?? fallback);
  }

  @override
  Future<AuthResponse> signup({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String role,
  }) async {
    try {
      // Signing up leaves this device holding the new account's session, so it
      // has to identify itself the same way login does — otherwise the sign-in
      // that immediately follows looks like a second device and is refused.
      final deviceId = await _tokenStorage.getOrCreateDeviceId();

      final response = await dio.post(
        '/auth/signup',
        data: {
          'fullName': fullName,
          'email': email,
          'mobile': mobile,
          'password': password,
          'role': role,
          'deviceId': deviceId,
        },
      );

      final data = response.data['data'];
      final token = data['token'];
      final user = UserModel.fromJson(data['user']);
      return AuthResponse(token: token, user: user);
    } on DioException catch (e) {
      _throwMapped(e, 'An error occurred during signup');
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
      final deviceId = await _tokenStorage.getOrCreateDeviceId();

      final response = await dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'deviceId': deviceId,
        },
      );

      final data = response.data['data'];
      final token = data['token'];
      final user = UserModel.fromJson(data['user']);
      return AuthResponse(token: token, user: user);
    } on DioException catch (e) {
      _throwMapped(e, 'An error occurred during login');
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
