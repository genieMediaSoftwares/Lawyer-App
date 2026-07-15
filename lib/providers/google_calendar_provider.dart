import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';

class GoogleCalendarState {
  final bool isConnected;
  final String email;
  final bool isLoading;

  GoogleCalendarState({
    required this.isConnected,
    required this.email,
    required this.isLoading,
  });

  GoogleCalendarState copyWith({
    bool? isConnected,
    String? email,
    bool? isLoading,
  }) {
    return GoogleCalendarState(
      isConnected: isConnected ?? this.isConnected,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class GoogleCalendarNotifier extends StateNotifier<GoogleCalendarState> {
  GoogleCalendarNotifier()
      : super(GoogleCalendarState(isConnected: false, email: "", isLoading: false)) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await DioClient.dio.get("/lawyers/google-calendar/status");
      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        state = GoogleCalendarState(
          isConnected: data['connected'] ?? false,
          email: data['email'] ?? "",
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> connect(String email, {bool simulate = true}) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await DioClient.dio.post(
        "/lawyers/google-calendar/connect",
        data: {
          "email": email,
          "isSimulated": simulate,
          "code": "mock_auth_code_12345",
        },
      );
      if (response.data != null && response.data['success'] == true) {
        state = GoogleCalendarState(
          isConnected: true,
          email: email,
          isLoading: false,
        );
        return true;
      }
    } catch (e) {
      // Handle error
    }
    state = state.copyWith(isLoading: false);
    return false;
  }

  Future<bool> disconnect() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await DioClient.dio.post("/lawyers/google-calendar/disconnect");
      if (response.data != null && response.data['success'] == true) {
        state = GoogleCalendarState(
          isConnected: false,
          email: "",
          isLoading: false,
        );
        return true;
      }
    } catch (e) {
      // Handle error
    }
    state = state.copyWith(isLoading: false);
    return false;
  }
}

final googleCalendarProvider =
    StateNotifierProvider<GoogleCalendarNotifier, GoogleCalendarState>(
  (ref) => GoogleCalendarNotifier(),
);
