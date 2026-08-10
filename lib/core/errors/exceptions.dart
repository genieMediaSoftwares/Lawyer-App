class ServerException implements Exception {
  final String message;

  /// Stable identifier for the failure, when the backend supplied one — see
  /// [AuthErrorCodes]. Callers that need to branch on *why* a request failed
  /// should match on this rather than on [message], which is written for the
  /// user and may be reworded or translated at any time.
  final String? code;

  ServerException(this.message, {this.code});

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = "No Internet Connection"]);

  @override
  String toString() => message;
}

/// Authentication failure codes as sent by the backend.
///
/// Mirrors `backend/src/utils/authCodes.js`; the two lists must stay in step.
abstract final class AuthErrorCodes {
  AuthErrorCodes._();

  static const String emailAlreadyRegistered = 'EMAIL_ALREADY_REGISTERED';
  static const String mobileAlreadyRegistered = 'MOBILE_ALREADY_REGISTERED';
  static const String nameAlreadyInUse = 'NAME_ALREADY_IN_USE';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String activeSessionExists = 'ACTIVE_SESSION_EXISTS';
  static const String sessionExpired = 'SESSION_EXPIRED';
  static const String accountInactive = 'ACCOUNT_INACTIVE';
}
