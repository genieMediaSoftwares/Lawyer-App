import 'package:dio/dio.dart';

import 'dio_client.dart';

class ApiClient {
  ApiClient._();

  static Future<Response> get(
      String endpoint,
      ) async {
    return await DioClient.dio.get(endpoint);
  }

  static Future<Response> post(
      String endpoint,
      dynamic data,
      ) async {
    return await DioClient.dio.post(
      endpoint,
      data: data,
    );
  }

  static Future<Response> put(
      String endpoint,
      dynamic data,
      ) async {
    return await DioClient.dio.put(
      endpoint,
      data: data,
    );
  }

  static Future<Response> delete(
      String endpoint,
      ) async {
    return await DioClient.dio.delete(endpoint);
  }
}