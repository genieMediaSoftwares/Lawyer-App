import 'package:flutter/material.dart';

import '../config/app_config.dart';
import 'app_circle_avatar.dart';

/// The one place a stored profile-image value becomes something displayable.
///
/// Before this, every screen that showed a face repeated
/// `AppConfig.getAttachmentUrl(x)` with its own null and empty checks — about
/// twenty of them — so a fix to URL handling had to be made twenty times and
/// the screens that were missed kept showing a broken image.
///
/// [UserAvatar] takes the RAW value as the API returned it and resolves it
/// itself. Callers pass `lawyer.profileImage` or `authState.userPhotoUrl`
/// straight through; what shape that value is in is this widget's problem.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.imagePath,
    this.radius = 24,
    this.fallbackInitials,
    this.fallbackIcon,
    this.backgroundColor,
  });

  /// The value exactly as stored: an absolute URL, a `/uploads/...` path, a
  /// Cloudinary URL, an empty string or null. Never pre-resolved by the caller.
  final String? imagePath;

  final double radius;

  /// Shown instead of an icon when the person has no picture — initials read
  /// better than a generic silhouette in a list of people.
  final String? fallbackInitials;

  final IconData? fallbackIcon;
  final Color? backgroundColor;

  /// Resolves [imagePath] to something loadable, or null when there is nothing
  /// to load.
  ///
  /// `getAttachmentUrl` already handles the absolute/relative split and leaves
  /// a full `https://` URL — a Cloudinary one included — alone apart from
  /// re-hosting its path. Everything here is about NOT calling it with a value
  /// that would produce a URL pointing at nothing, which is what renders as a
  /// broken image rather than as the fallback.
  static String? resolve(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    // Values seen in stored records that mean "no image" rather than a path.
    if (value == 'null' || value == 'undefined' || value == '/') return null;

    // A URL on someone else's host is used as-is.
    //
    // `getAttachmentUrl` keeps only the PATH of an absolute URL and re-hosts it
    // on the configured backend. For our own uploads that is what we want — it
    // is how a record still holding `http://localhost:5000/...` from a
    // development session resolves correctly in production. Applied to a CDN it
    // is destructive: a Cloudinary URL came back as
    // `<our-host>/demo/image/upload/v1/a.jpg`, which is nothing.
    //
    // Cloudinary is not wired up today (see CLOUDINARY_* in .env.example), so
    // nothing currently takes this branch; it is here so the integration does
    // not arrive with every avatar broken.
    if (_isForeignHost(value)) return value;

    final resolved = AppConfig.getAttachmentUrl(value);
    return resolved.isEmpty ? null : resolved;
  }

  /// Hosts that mean "this app's own backend, recorded from a machine that is
  /// not the one now reading it".
  ///
  /// A record written during development keeps the developer's host forever.
  /// Left alone, `http://localhost:5000/uploads/profiles/x.jpg` is a dead link
  /// on every real device — so these are re-hosted onto the configured backend
  /// rather than passed through, which is the whole reason the path-only
  /// rewrite exists.
  static bool _isDevelopmentHost(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' ||
        h == '127.0.0.1' ||
        h == '0.0.0.0' ||
        // The Android emulator's alias for the host machine.
        h == '10.0.2.2' ||
        h.startsWith('192.168.') ||
        h.startsWith('10.0.') ||
        h.startsWith('172.16.');
  }

  /// True when [value] is an absolute URL pointing at a host that is genuinely
  /// somebody else's — a CDN — rather than at our backend under another name.
  static bool _isForeignHost(String value) {
    if (!value.startsWith('http')) return false;

    final target = Uri.tryParse(value);
    if (target == null || target.host.isEmpty) return false;

    // Not foreign: ours, recorded from a dev machine. Re-host it.
    if (_isDevelopmentHost(target.host)) return false;

    final ours = Uri.tryParse(AppConfig.socketBaseUrl);
    if (ours == null || ours.host.isEmpty) return false;

    return target.host.toLowerCase() != ours.host.toLowerCase();
  }

  /// "Ananya Rao" -> "AR". Falls back to one letter, then to nothing.
  static String? initialsFrom(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = resolve(imagePath);
    final initials = fallbackInitials;

    // AppCircleAvatar already owns the loading spinner and the error fallback,
    // so this adds resolution and initials rather than a second avatar widget.
    return AppCircleAvatar(
      radius: radius,
      imageUrl: url,
      backgroundColor: backgroundColor,
      fallback: (initials != null && initials.isNotEmpty)
          ? Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          : Icon(
              fallbackIcon ?? Icons.person,
              color: theme.colorScheme.primary,
              size: radius,
            ),
    );
  }
}
