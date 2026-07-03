import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/token_storage.dart';
import '../core/network/dio_client.dart';

enum UserRole {
  client,
  lawyer,
}

class AuthState {
  final bool isLoggedIn;
  final UserRole? role;
  final bool onboardingCompleted;
  final String? userName;
  final String? userEmail;
  final String? userMobile;
  final String? userId;
  final String? userPhotoUrl;

  const AuthState({
    required this.isLoggedIn,
    required this.role,
    required this.onboardingCompleted,
    this.userName,
    this.userEmail,
    this.userMobile,
    this.userId,
    this.userPhotoUrl,
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
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final TokenStorage _tokenStorage = TokenStorage();

  AuthNotifier()
      : super(
    const AuthState(
      isLoggedIn: false,
      role: null,
      onboardingCompleted: false,
    ),
  ) {
    initialize();
  }

  Future<void> initialize() async {
    final onboardingCompleted = await _tokenStorage.isOnboardingCompleted();
    final token = await _tokenStorage.getToken();
    final roleStr = await _tokenStorage.getRole();
    final details = await _tokenStorage.getUserDetails();

    UserRole? role;
    if (roleStr == 'client') {
      role = UserRole.client;
    } else if (roleStr == 'lawyer') {
      role = UserRole.lawyer;
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
    );
  }

  Future<void> completeOnboarding() async {
    await _tokenStorage.setOnboardingCompleted(true);
    state = state.copyWith(
      onboardingCompleted: true,
    );
  }

  Future<void> login(
      String token,
      UserRole role, {
        required String id,
        required String name,
        required String email,
        required String mobile,
        String? photoUrl,
      }) async {
    await _tokenStorage.saveToken(token);
    await _tokenStorage.saveRole(role.name);
    await _tokenStorage.saveUserDetails(
      id: id,
      name: name,
      email: email,
      mobile: mobile,
      // photo: photoUrl,
    );
    state = state.copyWith(
      isLoggedIn: true,
      role: role,
      userName: name,
      userEmail: email,
      userMobile: mobile,
      userId: id,
      userPhotoUrl: photoUrl,
    );
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
    await _tokenStorage.deleteRole();
    await _tokenStorage.deleteUserDetails();
    state = AuthState(
      isLoggedIn: false,
      role: null,
      onboardingCompleted: state.onboardingCompleted,
      userName: null,
      userEmail: null,
      userMobile: null,
      userId: null,
      userPhotoUrl: null,
    );
  }

  Future<bool> updateUserProfile({required String name, required String mobile}) async {
    try {
      final response = await DioClient.dio.put("/auth/profile", data: {
        "fullName": name,
        "mobile": mobile,
      });

      if (response.data != null && response.data['success'] == true) {
        final userData = response.data['data'];
        await _tokenStorage.saveUserDetails(
          id: userData['id'] ?? state.userId ?? '',
          name: userData['fullName'] ?? '',
          email: userData['email'] ?? '',
          mobile: userData['mobile'] ?? '',
        );
        state = state.copyWith(
          userName: userData['fullName'],
          userMobile: userData['mobile'],
        );
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<void> resetOnboarding() async {
    await _tokenStorage.setOnboardingCompleted(false);
    state = state.copyWith(
      onboardingCompleted: false,
    );
  }
}

final authProvider =
StateNotifierProvider<AuthNotifier, AuthState>(
      (ref) => AuthNotifier(),
);