import '../models/court_model.dart';
import '../repositories/court_repository.dart';

class CourtService {
  final CourtRepository _repository;

  CourtService(this._repository);

  Future<List<CourtModel>> getCourts({
    required String city,
    required String state,
  }) {
    return _repository.getCourtsByLocation(city: city, state: state);
  }
}
