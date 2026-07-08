import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/court_repository.dart';
import '../services/court_service.dart';
import '../models/court_model.dart';

final courtRepositoryProvider = Provider<CourtRepository>((ref) {
  return CourtRepository();
});

final courtServiceProvider = Provider<CourtService>((ref) {
  final repository = ref.watch(courtRepositoryProvider);
  return CourtService(repository);
});

class CourtsState {
  final bool isLoading;
  final String? error;
  final List<CourtModel> courts;

  CourtsState({
    required this.isLoading,
    this.error,
    required this.courts,
  });

  factory CourtsState.initial() => CourtsState(isLoading: false, courts: []);
  factory CourtsState.loading() => CourtsState(isLoading: true, courts: []);
  factory CourtsState.error(String err) => CourtsState(isLoading: false, error: err, courts: []);
  factory CourtsState.success(List<CourtModel> list) => CourtsState(isLoading: false, courts: list);
}

class CourtsNotifier extends StateNotifier<CourtsState> {
  final CourtService _service;

  CourtsNotifier(this._service) : super(CourtsState.initial());

  Future<void> fetchCourtsForLocation({
    required String city,
    required String stateName,
  }) async {
    try {
      state = CourtsState.loading();
      final courtsList = await _service.getCourts(city: city, state: stateName);
      state = CourtsState.success(courtsList);
    } catch (e) {
      state = CourtsState.error("Failed to load courts for the selected location.");
    }
  }

  void clear() {
    state = CourtsState.initial();
  }
}

final courtsProvider = StateNotifierProvider<CourtsNotifier, CourtsState>((ref) {
  final service = ref.watch(courtServiceProvider);
  return CourtsNotifier(service);
});
