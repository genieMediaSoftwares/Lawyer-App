import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../models/client_profile_model.dart';
import '../models/activity_model.dart';
import '../models/client_stats_model.dart';

class ProfileRepository {
  Future<ClientProfileModel> getClientProfile() async {
    final response = await DioClient.dio.get("/client/profile");
    if (response.data != null && response.data['success'] == true) {
      return ClientProfileModel.fromJson(response.data['data']);
    }
    throw Exception(response.data?['message'] ?? "Failed to fetch profile");
  }

  Future<ClientProfileModel> updateClientProfile({
    required String fullName,
    required String mobile,
    required String location,
    required String dob,
    required String gender,
    required List<String> languages,
  }) async {
    final response = await DioClient.dio.put(
      "/client/profile",
      data: {
        "fullName": fullName,
        "mobile": mobile,
        "location": location,
        "dob": dob,
        "gender": gender,
        "languages": languages,
      },
    );
    if (response.data != null && response.data['success'] == true) {
      return ClientProfileModel.fromJson(response.data['data']);
    }
    throw Exception(response.data?['message'] ?? "Failed to update profile");
  }

  Future<List<ActivityModel>> getClientActivity() async {
    final response = await DioClient.dio.get("/client/activity");
    if (response.data != null && response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((item) => ActivityModel.fromJson(item)).toList();
    }
    throw Exception(response.data?['message'] ?? "Failed to fetch activity");
  }

  Future<ClientStatsModel> getClientStats() async {
    final response = await DioClient.dio.get("/client/stats");
    if (response.data != null && response.data['success'] == true) {
      return ClientStatsModel.fromJson(response.data['data']);
    }
    throw Exception(response.data?['message'] ?? "Failed to fetch stats");
  }

  Future<ClientProfileModel> uploadProfileImage(List<int> bytes, String fileName) async {
    final formData = FormData.fromMap({
      "image": MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
    });

    final response = await DioClient.dio.post(
      "/auth/profile/image",
      data: formData,
    );

    if (response.data != null && response.data['success'] == true) {
      return getClientProfile();
    }
    throw Exception(response.data?['message'] ?? "Failed to upload image");
  }
}
