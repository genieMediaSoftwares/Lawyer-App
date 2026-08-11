import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the platform says about the microphone, in the detail the voice note
/// needs to say something useful about it.
///
/// `record` and `speech_to_text` both collapse every one of these into a bare
/// `false`, which is why a client who had refused the microphone once saw
/// "the microphone is not available" — a message that is wrong about the cause,
/// wrong about the remedy, and offers no way out. Each state below has a
/// different remedy, so each is kept distinct all the way to the UI.
enum MicPermissionState {
  /// Recording may proceed.
  granted,

  /// Refused, but the OS will still show the prompt again. Asking is worth it.
  denied,

  /// Refused for good ("Don't ask again", or a second refusal on iOS). The
  /// system prompt will never appear again, so the only way forward is the
  /// Settings app.
  permanentlyDenied,

  /// Blocked by parental controls or device policy. The client cannot grant it
  /// themselves and Settings will not help.
  restricted,

  /// No microphone, or a platform with no concept of one (web builds of this
  /// screen, desktop without an input device).
  unavailable,
}

/// The microphone permission, asked for and reported honestly.
///
/// A thin wrapper over `permission_handler` that exists for two reasons: it
/// keeps the plugin out of the recorder's own logic, and it is injectable, so
/// the widget and service tests can drive every state above without a device.
class MicrophonePermission {
  /// Reads the current status without prompting.
  final Future<PermissionStatus> Function() _check;

  /// Prompts, if the platform will still show a prompt.
  final Future<PermissionStatus> Function() _request;

  /// Opens the app's own page in the system Settings app.
  final Future<bool> Function() _openSettings;

  MicrophonePermission({
    Future<PermissionStatus> Function()? check,
    Future<PermissionStatus> Function()? request,
    Future<bool> Function()? openSettings,
  })  : _check = check ?? (() => Permission.microphone.status),
        _request = request ?? (() => Permission.microphone.request()),
        _openSettings = openSettings ?? openAppSettings;

  /// Grants, or explains why not.
  ///
  /// Checks first and only prompts when the OS would actually show something:
  /// calling `request()` on a permanently denied permission returns instantly
  /// with the same refusal and no dialog, which reads to the client as the
  /// button doing nothing at all.
  Future<MicPermissionState> ensure() async {
    try {
      final current = _map(await _check());
      if (current != MicPermissionState.denied) return current;

      return _map(await _request());
    } catch (e) {
      // A missing platform implementation is not a refusal. Report it as the
      // "no microphone here" case so the caller degrades instead of accusing
      // the client of having denied something.
      debugPrint('MicrophonePermission check failed: $e');
      return MicPermissionState.unavailable;
    }
  }

  /// Sends the client to the app's settings page. Only offered for
  /// [MicPermissionState.permanentlyDenied], where it is the sole way back.
  Future<bool> openSettings() async {
    try {
      return await _openSettings();
    } catch (e) {
      debugPrint('MicrophonePermission openSettings failed: $e');
      return false;
    }
  }

  static MicPermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return MicPermissionState.granted;
    if (status.isPermanentlyDenied) return MicPermissionState.permanentlyDenied;
    if (status.isRestricted) return MicPermissionState.restricted;
    if (status.isDenied) return MicPermissionState.denied;
    return MicPermissionState.unavailable;
  }
}
