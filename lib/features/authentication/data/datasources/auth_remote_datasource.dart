import 'package:dio/dio.dart';
import '../models/auth_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/errors/exceptions.dart';

abstract class AuthRemoteDataSource {
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

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<AuthResponse> signup({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String role,
  }) async {
    try {
      final response = await dio.post(
        '/auth/signup',
        data: {
          'fullName': fullName,
          'email': email,
          'mobile': mobile,
          'password': password,
          'role': role,
        },
      );

      final data = response.data['data'];
      final token = data['token'];
      final user = UserModel.fromJson(data['user']);
      return AuthResponse(token: token, user: user);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorMessage = (responseData != null && responseData is Map && responseData.containsKey('message'))
          ? responseData['message']
          : (e.message ?? 'An error occurred during signup');
      throw ServerException(errorMessage.toString());
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
      final response = await dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data['data'];
      final token = data['token'];
      final user = UserModel.fromJson(data['user']);
      return AuthResponse(token: token, user: user);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorMessage = (responseData != null && responseData is Map && responseData.containsKey('message'))
          ? responseData['message']
          : (e.message ?? 'An error occurred during login');
      throw ServerException(errorMessage.toString());
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
