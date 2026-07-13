import '../core/network/dio_client.dart';
import '../models/advocate_model.dart';

class LawyerRepository {
  Future<List<AdvocateModel>> getAdvocates({
    String? search,
    String? specialization,
    String? location,
    String? experience,
    double? minFee,
    double? maxFee,
    double? minRating,
    List<String>? languages,
    bool? verifiedOnly,
    bool? availableNow,
    String? sortBy,
  }) async {
    final Map<String, dynamic> queryParams = {};
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (specialization != null && specialization != 'All' && specialization != 'All Practice Areas') {
      queryParams['specialization'] = specialization;
    }
    if (location != null && location != 'All' && location != 'All Locations') {
      queryParams['location'] = location;
    }
    if (experience != null && experience != 'All' && experience != 'All Experience') {
      queryParams['experience'] = experience;
    }
    if (minFee != null) {
      queryParams['minFee'] = minFee.toInt();
    }
    if (maxFee != null) {
      queryParams['maxFee'] = maxFee.toInt();
    }
    if (minRating != null) {
      queryParams['rating'] = '${minRating.toStringAsFixed(1)}★+';
    }
    if (languages != null && languages.isNotEmpty) {
      queryParams['language'] = languages;
    }
    if (verifiedOnly == true) {
      queryParams['verifiedOnly'] = 'true';
    }
    if (availableNow == true) {
      queryParams['availableNow'] = 'true';
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sortBy'] = sortBy;
    }

    final response = await DioClient.dio.get("/lawyers", queryParameters: queryParams);
    if (response.data != null && response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((item) => AdvocateModel.fromJson(item)).toList();
    }
    return [];
  }
}
