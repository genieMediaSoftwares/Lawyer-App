import '../core/network/dio_client.dart';
import '../models/place_model.dart';

class PlaceRepository {
  Future<List<PlaceSuggestionModel>> getAutocomplete(String input) async {
    final response = await DioClient.dio.get(
      "/places/autocomplete",
      queryParameters: {"input": input},
    );
    if (response.data != null && response.data['success'] == true) {
      final list = response.data['data'] as List;
      return list.map((item) => PlaceSuggestionModel.fromJson(item)).toList();
    }
    throw Exception(response.data?['message'] ?? "Failed to fetch autocomplete suggestions");
  }

  Future<PlaceDetailsModel> getDetails(String placeId) async {
    final response = await DioClient.dio.get(
      "/places/details",
      queryParameters: {"placeId": placeId},
    );
    if (response.data != null && response.data['success'] == true) {
      return PlaceDetailsModel.fromJson(response.data['data']);
    }
    throw Exception(response.data?['message'] ?? "Failed to fetch place details");
  }
}
