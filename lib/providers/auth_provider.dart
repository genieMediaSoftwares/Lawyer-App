import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRole {
  client,
  lawyer,
}

class AuthState {
  final bool isLoggedIn;
  final UserRole? role;
  final bool onboardingCompleted;

  const AuthState({
    required this.isLoggedIn,
    required this.role,
    required this.onboardingCompleted,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    UserRole? role,
    bool? onboardingCompleted,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      role: role ?? this.role,
      onboardingCompleted:
      onboardingCompleted ??
          this.onboardingCompleted,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier()
      : super(
    const AuthState(
      isLoggedIn: false,
      role: null,
      onboardingCompleted: false,
    ),
  );

  void completeOnboarding() {
    state = state.copyWith(
      onboardingCompleted: true,
    );
  }

  void login(UserRole role) {
    state = state.copyWith(
      isLoggedIn: true,
      role: role,
    );
  }

  void logout() {
    state = const AuthState(
      isLoggedIn: false,
      role: null,
      onboardingCompleted: true,
    );
  }

  void resetOnboarding() {
    state = state.copyWith(
      onboardingCompleted: false,
    );
  }
}

final authProvider =
StateNotifierProvider<AuthNotifier, AuthState>(
      (ref) => AuthNotifier(),
);