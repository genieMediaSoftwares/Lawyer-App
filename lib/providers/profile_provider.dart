import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_profile_model.dart';
import '../models/activity_model.dart';
import '../models/client_stats_model.dart';
import '../repositories/profile_repository.dart';
import 'auth_provider.dart';

class ProfileState {
  final ClientProfileModel? profile;
  final List<ActivityModel> activities;
  final ClientStatsModel? stats;
  final bool isLoading;
  final String? errorMessage;

  const ProfileState({
    this.profile,
    this.activities = const [],
    this.stats,
    this.isLoading = false,
    this.errorMessage,
  });

  ProfileState copyWith({
    ClientProfileModel? profile,
    List<ActivityModel>? activities,
    ClientStatsModel? stats,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      activities: activities ?? this.activities,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileNotifier(this._repository, this._ref) : super(const ProfileState()) {
    fetchProfileData();
  }

  Future<void> fetchProfileData() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      
      final profileFuture = _repository.getClientProfile();
      final activityFuture = _repository.getClientActivity();
      final statsFuture = _repository.getClientStats();

      final results = await Future.wait([profileFuture, activityFuture, statsFuture]);

      final profile = results[0] as ClientProfileModel;
      final activities = results[1] as List<ActivityModel>;
      final stats = results[2] as ClientStatsModel;

      state = ProfileState(
        profile: profile,
        activities: activities,
        stats: stats,
        isLoading: false,
      );

      _ref.read(authProvider.notifier).updateLocalDetails(
        name: profile.fullName,
        mobile: profile.mobile,
        location: profile.location,
        photoUrl: profile.profileImage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String mobile,
    required String location,
    required String dob,
    required String gender,
    required List<String> languages,
  }) async {
    try {
      state = state.copyWith(isLoading: true);
      final updatedProfile = await _repository.updateClientProfile(
        fullName: fullName,
        mobile: mobile,
        location: location,
        dob: dob,
        gender: gender,
        languages: languages,
      );
      state = state.copyWith(
        profile: updatedProfile,
        isLoading: false,
      );
      
      _ref.read(authProvider.notifier).updateLocalDetails(
        name: fullName,
        mobile: mobile,
        location: location,
      );
      
      await fetchProfileData();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateProfileImage(List<int> bytes, String fileName) async {
    try {
      state = state.copyWith(isLoading: true);
      final updatedProfile = await _repository.uploadProfileImage(bytes, fileName);
      state = state.copyWith(
        profile: updatedProfile,
        isLoading: false,
      );
      _ref.read(authProvider.notifier).updateLocalDetails(
        photoUrl: updatedProfile.profileImage,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return ProfileNotifier(repo, ref);
});
