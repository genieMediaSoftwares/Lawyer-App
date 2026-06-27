import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/token_storage.dart';

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

  const AuthState({
    required this.isLoggedIn,
    required this.role,
    required this.onboardingCompleted,
    this.userName,
    this.userEmail,
    this.userMobile,
    this.userId,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    UserRole? role,
    bool? onboardingCompleted,
    String? userName,
    String? userEmail,
    String? userMobile,
    String? userId,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      role: role ?? this.role,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userMobile: userMobile ?? this.userMobile,
      userId: userId ?? this.userId,
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
  }) async {
    await _tokenStorage.saveToken(token);
    await _tokenStorage.saveRole(role.name);
    await _tokenStorage.saveUserDetails(
      id: id,
      name: name,
      email: email,
      mobile: mobile,
    );
    state = state.copyWith(
      isLoggedIn: true,
      role: role,
      userName: name,
      userEmail: email,
      userMobile: mobile,
      userId: id,
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
    );
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