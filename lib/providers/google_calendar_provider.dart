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
    : super(
        GoogleCalendarState(isConnected: false, email: "", isLoading: false),
      ) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await DioClient.dio.get(
        "/lawyers/google-calendar/status",
      );
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

  /// Connects the lawyer's Google Calendar.
  ///
  /// The server decides whether this is a real OAuth exchange or a simulated
  /// one, based on whether GOOGLE_CLIENT_ID/SECRET are configured
  /// (`googleCalendarService.isRealMode()`). The client used to force
  /// simulation — `simulate` defaulted to true and a literal
  /// "mock_auth_code_12345" was sent — so even a correctly configured
  /// deployment never performed a real calendar sync.
  ///
  /// [authCode] is the OAuth authorization code when one has been obtained.
  Future<bool> connect(String email, {String? authCode}) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await DioClient.dio.post(
        "/lawyers/google-calendar/connect",
        data: {
          "email": email,
          if (authCode != null && authCode.isNotEmpty) "code": authCode,
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
      final response = await DioClient.dio.post(
        "/lawyers/google-calendar/disconnect",
      );
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
