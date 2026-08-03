import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/token_storage.dart';
import '../core/network/dio_client.dart';
import 'lawyer_provider.dart';

enum UserRole { client, lawyer, admin }

class AuthState {
  final bool isLoggedIn;
  final UserRole? role;
  final bool onboardingCompleted;
  final String? userName;
  final String? userEmail;
  final String? userMobile;
  final String? userId;
  final String? userPhotoUrl;
  final String? userLocation;

  const AuthState({
    required this.isLoggedIn,
    required this.role,
    required this.onboardingCompleted,
    this.userName,
    this.userEmail,
    this.userMobile,
    this.userId,
    this.userPhotoUrl,
    this.userLocation,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    UserRole? role,
    bool? onboardingCompleted,
    String? userName,
    String? userEmail,
    String? userMobile,
    String? userId,
    String? userPhotoUrl,
    String? userLocation,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      role: role ?? this.role,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userMobile: userMobile ?? this.userMobile,
      userId: userId ?? this.userId,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      userLocation: userLocation ?? this.userLocation,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final TokenStorage _tokenStorage = TokenStorage();
  final Ref _ref;

  AuthNotifier(this._ref)
    : super(
        const AuthState(
          isLoggedIn: false,
          role: null,
          onboardingCompleted: false,
        ),
      ) {
    initialize();
  }

  /// Single fan-out point for "the signed-in user's own profile changed".
  ///
  /// [AuthState] is only one of the places the current user's name and photo
  /// are held; caches keyed by their id hold copies too. Those used to be
  /// refreshed by whichever screen happened to perform the edit, so a surface
  /// stayed stale whenever a new edit path forgot to do it — which is why the
  /// avatar updated in some places and not others. Making the refresh part of
  /// the write instead of part of the caller means no future edit screen can
  /// forget.
  ///
  /// Safe to invalidate from here: none of these providers depend on
  /// [authProvider], so `Ref.invalidate` cannot find this notifier among their
  /// ancestors and throw CircularDependencyError.
  void _profileChanged(String? userId) {
    if (!mounted || userId == null || userId.isEmpty) return;
    _ref.invalidate(lawyerDetailsProvider(userId));
  }

  /// Bumped by every sign-in and sign-out.
  ///
  /// [initialize] reads four values from secure storage and only then writes
  /// state. A sign-in completing inside that window is newer than what it
  /// read, so its result must not be overwritten when the read finally lands —
  /// otherwise a fast login at startup is silently rolled back to signed-out.
  int _sessionGeneration = 0;

  Future<void> initialize() async {
    final generation = _sessionGeneration;

    final onboardingCompleted = await _tokenStorage.isOnboardingCompleted();
    final token = await _tokenStorage.getToken();
    final roleStr = await _tokenStorage.getRole();
    final details = await _tokenStorage.getUserDetails();

    // `mounted` because the read outlives a provider torn down mid-flight —
    // writing state then throws. `generation` because a sign-in that landed
    // while we were reading is newer than what we read.
    if (!mounted || generation != _sessionGeneration) return;

    UserRole? role;
    if (roleStr == 'client') {
      role = UserRole.client;
    } else if (roleStr == 'lawyer') {
      role = UserRole.lawyer;
    } else if (roleStr == 'admin') {
      role = UserRole.admin;
    }

    state = AuthState(
      isLoggedIn: token != null,
      role: role,
      onboardingCompleted: onboardingCompleted,
      userName: details['name'],
      userEmail: details['email'],
      userMobile: details['mobile'],
      userId: details['id'],
      userPhotoUrl: details['photo'],
      userLocation: details['location'],
    );
  }

  Future<void> completeOnboarding() async {
    await _tokenStorage.setOnboardingCompleted(true);
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> login(
    String token,
    UserRole role, {
    required String id,
    required String name,
    required String email,
    required String mobile,
    String? photoUrl,
    String? location,
  }) async {
    _sessionGeneration++;
    await _tokenStorage.saveToken(token);
    await _tokenStorage.saveRole(role.name);
    await _tokenStorage.saveUserDetails(
      id: id,
      name: name,
      email: email,
      mobile: mobile,
      photo: photoUrl,
      location: location,
    );
    if (!mounted) return;
    state = state.copyWith(
      isLoggedIn: true,
      role: role,
      userName: name,
      userEmail: email,
      userMobile: mobile,
      userId: id,
      userPhotoUrl: photoUrl,
      userLocation: location,
    );
  }

  Future<void> logout() async {
    _sessionGeneration++;

    // Drop the outgoing user's cached profile before the state clears, while
    // their id is still known. Otherwise it survives into the next session and
    // the new user briefly sees the previous one's details.
    _profileChanged(state.userId);

    await _tokenStorage.deleteToken();
    await _tokenStorage.deleteRole();
    await _tokenStorage.deleteUserDetails();
    if (!mounted) return;
    state = AuthState(
      isLoggedIn: false,
      role: null,
      onboardingCompleted: state.onboardingCompleted,
      userName: null,
      userEmail: null,
      userMobile: null,
      userId: null,
      userPhotoUrl: null,
      userLocation: null,
    );
  }

  Future<void> updateLocalDetails({
    String? name,
    String? email,
    String? mobile,
    String? location,
    String? photoUrl,
  }) async {
    final newName = name ?? state.userName ?? '';
    final newEmail = email ?? state.userEmail ?? '';
    final newMobile = mobile ?? state.userMobile ?? '';
    final newLocation = location ?? state.userLocation ?? '';
    final newPhoto = photoUrl ?? state.userPhotoUrl ?? '';

    await _tokenStorage.saveUserDetails(
      id: state.userId ?? '',
      name: newName,
      email: newEmail,
      mobile: newMobile,
      photo: newPhoto,
      location: newLocation,
    );

    // A sign-out during the write disposes this notifier; the stale details
    // must not be written back over the cleared session.
    if (!mounted) return;

    state = state.copyWith(
      userName: newName,
      userEmail: newEmail,
      userMobile: newMobile,
      userLocation: newLocation,
      userPhotoUrl: newPhoto,
    );
    _profileChanged(state.userId);
  }

  Future<bool> updateUserProfile({
    required String name,
    required String mobile,
    required String location,
  }) async {
    try {
      final response = await DioClient.dio.put(
        "/auth/profile",
        data: {"fullName": name, "mobile": mobile, "location": location},
      );

      if (response.data != null && response.data['success'] == true) {
        final userData = response.data['data'];
        await _tokenStorage.saveUserDetails(
          id: userData['id'] ?? state.userId ?? '',
          name: userData['fullName'] ?? '',
          email: userData['email'] ?? '',
          mobile: userData['mobile'] ?? '',
          photo: userData['profileImage'] ?? state.userPhotoUrl ?? '',
          location: userData['location'] ?? '',
        );
        if (!mounted) return false;
        state = state.copyWith(
          userName: userData['fullName'],
          userMobile: userData['mobile'],
          userPhotoUrl: userData['profileImage'] ?? state.userPhotoUrl,
          userLocation: userData['location'],
        );
        _profileChanged(state.userId);
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> updateProfileImage(List<int> bytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        "image": MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await DioClient.dio.post(
        "/auth/profile/image",
        data: formData,
      );

      if (response.data != null && response.data['success'] == true) {
        final userData = response.data['data'];
        await _tokenStorage.saveUserDetails(
          id: userData['id'] ?? state.userId ?? '',
          name: userData['fullName'] ?? '',
          email: userData['email'] ?? '',
          mobile: userData['mobile'] ?? '',
          photo: userData['profileImage'] ?? '',
          location: userData['location'] ?? state.userLocation ?? '',
        );
        if (!mounted) return false;
        state = state.copyWith(
          userName: userData['fullName'],
          userEmail: userData['email'],
          userMobile: userData['mobile'],
          userPhotoUrl: userData['profileImage'],
          userLocation: userData['location'],
        );
        _profileChanged(state.userId);
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<void> resetOnboarding() async {
    await _tokenStorage.setOnboardingCompleted(false);
    state = state.copyWith(onboardingCompleted: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);
