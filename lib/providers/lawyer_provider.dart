import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/lawyer_model.dart';
import '../models/advocate_model.dart';
import '../repositories/lawyer_repository.dart';

final lawyerRepositoryProvider = Provider((ref) => LawyerRepository());

class AdvocateFilters {
  final String search;
  final String specialization;
  final String location;
  final String experience;
  final double? minFee;
  final double? maxFee;
  final double? minRating;
  final List<String> languages;
  final bool verifiedOnly;
  final bool availableNow;
  final String sortBy;

  AdvocateFilters({
    this.search = "",
    this.specialization = "All",
    this.location = "All",
    this.experience = "All",
    this.minFee,
    this.maxFee,
    this.minRating,
    this.languages = const [],
    this.verifiedOnly = false,
    this.availableNow = false,
    this.sortBy = "Most Relevant",
  });

  AdvocateFilters copyWith({
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
  }) {
    return AdvocateFilters(
      search: search ?? this.search,
      specialization: specialization ?? this.specialization,
      location: location ?? this.location,
      experience: experience ?? this.experience,
      minFee: minFee ?? this.minFee,
      maxFee: maxFee ?? this.maxFee,
      minRating: minRating ?? this.minRating,
      languages: languages ?? this.languages,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      availableNow: availableNow ?? this.availableNow,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

final advocateFiltersProvider = StateProvider<AdvocateFilters>((ref) => AdvocateFilters());

final filterOptionsProvider = FutureProvider<Map<String, List<String>>>((ref) async {
  try {
    final repository = ref.watch(lawyerRepositoryProvider);
    final allAdvocates = await repository.getAdvocates();
    final specializations = allAdvocates
        .map((a) => a.specialization.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final locations = allAdvocates
        .map((a) => a.location.trim())
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    return {
      'specializations': ['All Practice Areas', ...specializations],
      'locations': ['All Locations', ...locations],
    };
  } catch (e) {
    return {
      'specializations': ['All Practice Areas'],
      'locations': ['All Locations'],
    };
  }
});

final advocatesProvider = FutureProvider<List<AdvocateModel>>((ref) async {
  final repository = ref.watch(lawyerRepositoryProvider);
  final filters = ref.watch(advocateFiltersProvider);
  return repository.getAdvocates(
    search: filters.search,
    specialization: filters.specialization,
    location: filters.location,
    experience: filters.experience,
    minFee: filters.minFee,
    maxFee: filters.maxFee,
    minRating: filters.minRating,
    languages: filters.languages,
    verifiedOnly: filters.verifiedOnly,
    availableNow: filters.availableNow,
    sortBy: filters.sortBy,
  );
});


final lawyersProvider = FutureProvider<List<LawyerModel>>((ref) async {
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

final recommendedLawyersProvider = FutureProvider.family<List<LawyerModel>, Map<String, String?>>((ref, params) async {
  final response = await DioClient.dio.get("/lawyers/recommend", queryParameters: params);
  if (response.data != null && response.data['success'] == true) {
    final list = response.data['data'] as List;
    return list.map((item) => LawyerModel.fromJson(item)).toList();
  }
  return [];
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
