import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/lawyer_model.dart';

final lawyersProvider = FutureProvider.autoDispose<List<LawyerModel>>((ref) async {
  final response = await DioClient.dio.get("/lawyers");
  if (response.data != null && response.data['success'] == true) {
    final list = response.data['data'] as List;
    return list.map((item) => LawyerModel.fromJson(item)).toList();
  }
  return [];
});

final lawyerDetailsProvider = FutureProvider.family<LawyerModel, String>((ref, userId) async {
  final response = await DioClient.dio.get("/lawyers/$userId");
  if (response.data != null && response.data['success'] == true) {
    return LawyerModel.fromJson(response.data['data']);
  }
  throw Exception("Failed to load lawyer profile");
});

final lawyerProfileUpdaterProvider = Provider((ref) => LawyerProfileUpdater(ref));

class LawyerProfileUpdater {
  final Ref ref;
  LawyerProfileUpdater(this.ref);

  Future<bool> updateProfile({
    required String specialization,
    required int experience,
    required String education,
    required String barCouncilNumber,
    required int consultationFee,
    required String bio,
    required String officeAddress,
    required String upiId,
    required String workingHours,
    required Map<String, dynamic> bankDetails,
  }) async {
    try {
      final response = await DioClient.dio.put("/lawyers/profile", data: {
        "specialization": specialization,
        "experience": experience,
        "education": education,
        "barCouncilNumber": barCouncilNumber,
        "consultationFee": consultationFee,
        "bio": bio,
        "officeAddress": officeAddress,
        "upiId": upiId,
        "workingHours": workingHours,
        "bankDetails": bankDetails,
      });

      if (response.data != null && response.data['success'] == true) {
        final lawyerData = response.data['data'];
        final userId = lawyerData['user'] is Map ? lawyerData['user']['_id'] : lawyerData['user'];
        ref.invalidate(lawyersProvider);
        if (userId != null) {
          ref.invalidate(lawyerDetailsProvider(userId));
        }
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
