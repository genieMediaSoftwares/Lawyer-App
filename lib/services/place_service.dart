import '../models/place_model.dart';
import '../repositories/place_repository.dart';

class PlaceService {
  final PlaceRepository _repository;

  PlaceService(this._repository);

  Future<List<PlaceSuggestionModel>> autocomplete(String input) {
    return _repository.getAutocomplete(input);
  }

  Future<PlaceDetailsModel> details(String placeId) {
    return _repository.getDetails(placeId);
  }
}
