import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/place_repository.dart';
import '../services/place_service.dart';

final placeRepositoryProvider = Provider<PlaceRepository>((ref) {
  return PlaceRepository();
});

final placeServiceProvider = Provider<PlaceService>((ref) {
  final repository = ref.watch(placeRepositoryProvider);
  return PlaceService(repository);
});
