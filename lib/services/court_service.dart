import '../models/court_model.dart';
import '../repositories/court_repository.dart';

class CourtService {
  final CourtRepository _repository;

  CourtService(this._repository);

  Future<List<CourtModel>> getCourts({
    required String city,
    String? district,
    required String state,
  }) async {
    // 1. Try exact city + state
    try {
      final exactCourts = await _repository.getCourtsByLocation(city: city, state: state);
      if (exactCourts.isNotEmpty) {
        return exactCourts;
      }
    } catch (_) {}

    // 2. Fallback to district + state
    if (district != null && district.isNotEmpty && district.toLowerCase() != city.toLowerCase()) {
      try {
        final districtCourts = await _repository.getCourtsByLocation(city: district, state: state);
        if (districtCourts.isNotEmpty) {
          return districtCourts;
        }
      } catch (_) {}
    }

    // 3. Fallback to state-wide courts
    try {
      final stateCourts = await _repository.getCourtsByLocation(state: state);
      if (stateCourts.isNotEmpty) {
        return stateCourts;
      }
    } catch (_) {}

    return [];
  }
}
