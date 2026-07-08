import '../core/network/dio_client.dart';
import '../models/court_model.dart';

class CourtRepository {
  // Cache map: "city_state" -> List<CourtModel>
  final Map<String, List<CourtModel>> _courtCache = {};

  Future<List<CourtModel>> getCourtsByLocation({
    required String city,
    required String state,
  }) async {
    final cacheKey = "${city.toLowerCase().trim()}_${state.toLowerCase().trim()}";
    if (_courtCache.containsKey(cacheKey)) {
      return _courtCache[cacheKey]!;
    }

    final response = await DioClient.dio.get(
      "/courts",
      queryParameters: {
        "city": city,
        "state": state,
      },
    );

    if (response.data != null && response.data['success'] == true) {
      final list = response.data['data'] as List;
      final courts = list.map((item) => CourtModel.fromJson(item)).toList();
      
      // Cache the result
      _courtCache[cacheKey] = courts;
      return courts;
    }
    throw Exception(response.data?['message'] ?? "Failed to fetch courts");
  }
}
