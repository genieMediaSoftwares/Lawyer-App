import 'package:flutter/material.dart';

/// The single source of truth for every color used in GenieLaw.
///
/// No screen or widget should ever write `Color(0xFF...)` or a bare
/// `Colors.xxx` inline. Every color reaches the UI through one of two paths:
///   1. `Theme.of(context)` — for anything ThemeData already models
///      (colorScheme, textTheme, appBarTheme, etc.), which is itself built
///      from this file in `app_theme.dart`.
///   2. `AppColors.xxx` directly — for the handful of cases ThemeData has no
///      slot for (status badges, gradients, a feature-specific accent).
///
/// This file previously existed twice — a divergent copy lived at
/// `core/constants/app_colors.dart` with a *different* gold (`0xFFDE9D32` vs
/// this file's `0xFFDAA02F`) — plus a third, entirely unused 1293-line
/// `app_theme.dart` under `lib/shared/themes/`. Both are deleted. A codebase
/// sweep also found 497 raw `Color(0x...)` literals and ~94 distinct hex
/// values hardcoded directly in screens, including two more "golds"
/// (`0xFFD4AF37`, `0xFFE6B325`) used interchangeably with this file's
/// `primaryGold` for the exact same purpose. All of that has been folded in
/// below and every call site repointed here — see AUDIT_2026-07-27.md /
/// the theme-refactor changelog for the full file list.
abstract final class AppColors {
  AppColors._();

  // ── Core neutrals (dark surface scale) ───────────────────────────────────
  // Five deliberate steps, darkest to lightest. Every near-black shade found
  // hardcoded in screens (0x0B0B0B, 0x131314, 0x161616, 0x181818, 0x1A1A1A,
  // 0x1B1B1B, 0x1E1E20, 0x222222, 0x282828, 0x2B2B2B, 0x2B2B2C, 0x333333,
  // 0x3B3B3B, ...) was a slightly-off variant of one of these five and has
  // been normalized onto the nearest step — that normalization *is* the fix
  // for the "doesn't quite match" feeling: a dozen near-identical near-blacks
  // reads as a mismatch; five deliberate ones read as a system.
  static const Color primaryBackground = Color(0xFF0A0A0A); // scaffold
  static const Color secondaryBackground = Color(0xFF111111); // raised section
  static const Color cardBackground = Color(0xFF171717); // cards / tiles
  static const Color surface = Color(0xFF1E1E1E); // modals, elevated surfaces
  static const Color border = Color(0xFF2A2A2A); // dividers, outlines

  // ── Brand gold ────────────────────────────────────────────────────────────
  // The one and only gold. `0xFFDE9D32` (the duplicate file) and the two
  // raw literals `0xFFD4AF37` (92 call sites) / `0xFFE6B325` (43 call sites)
  // all collapse to this single value.
  static const Color primaryGold = Color(0xFFDAA02F);
  static const Color darkGold = Color(0xFFB8860B);
  static const Color goldHover = Color(0xFFE6C35C);
  static const Color accentGold = Color(0xFFF4C95D);

  /// Gold → amber gradient used for the "premium" upsell surfaces
  /// (subscription plan highlight, premium badge). Previously three separate
  /// near-identical stop lists were hand-copied across files.
  static const List<Color> premiumGradient = [
    Color(0xFF7A531D),
    darkGold,
    accentGold,
  ];

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color primaryText = Color(0xFFF5F5F5);
  static const Color secondaryText = Color(0xFFD0D0D0);
  static const Color mutedText = Color(0xFF9A9A9A);
  static const Color disabledText = Color(0xFF707070);

  // ── Core semantics ────────────────────────────────────────────────────────
  // Used for simple UI feedback: form validation, snackbars, inline alerts.
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB300);
  static const Color info = Color(0xFF3B82F6);

  static const Color divider = Color(0xFF2C2C2C);

  /// Text/icon color for content sitting directly on a gold-filled surface
  /// (primary buttons, selected chips). Kept as its own named token rather
  /// than a bare `Colors.black` literal — the theme files should have zero
  /// unnamed colors, same as every screen.
  static const Color onGold = Colors.black;

  /// Shadow tint for elevated surfaces (cards, dialogs, bottom sheets).
  static const Color shadow = Colors.black;

  // ── Status pills (two-tone: dark tint background + bright foreground) ────
  // The "Active/Inactive" style badges (client lists, case status) use a
  // dark, low-saturation background with a brighter foreground of the same
  // hue. Verified against actual call sites — only success/error pairs are
  // real; a warning pill happens to reuse the same values as the stat-badge
  // warning pair below, so it is not duplicated as a separate token.
  static const Color statusSuccessBg = Color(0xFF14532D);
  static const Color statusSuccessFg = Color(0xFF4ADE80);
  static const Color statusErrorBg = Color(0xFF7F1D1D);
  static const Color statusErrorFg = Color(0xFFFCA5A5);

  // ── Admin dashboard stat-card icon badges ────────────────────────────────
  // Six colored circular icon badges on the admin metrics dashboard (clients,
  // cases, revenue, pending, lawyers, AI usage), each a tinted-background +
  // bright-icon pair. Previously six raw hex pairs typed directly into
  // admin_dashboard_screen.dart with no names at all.
  static const Color statSuccessBg = Color(0xFF064E3B);
  static const Color statSuccess = Color(0xFF34D399);
  static const Color statInfoBg = Color(0xFF1E293B);
  static const Color statInfo = Color(0xFF38BDF8);
  static const Color statIndigoBg = Color(0xFF312E81);
  static const Color statIndigo = Color(0xFF818CF8);
  static const Color statWarningBg = Color(0xFF78350F);
  static const Color statWarning = Color(0xFFFBBF24);
  static const Color statPurpleBg = Color(0xFF581C87);
  static const Color statPurple = Color(0xFFC084FC);
  static const Color statPinkBg = Color(0xFF701A75);
  static const Color statPink = Color(0xFFF472B6);

  // ── AI Smart Case feature accent ─────────────────────────────────────────
  // The AI intake flow (4 dedicated screens + 2 dashboard cards) uses a
  // deliberately distinct indigo/navy surface and a violet→amber gradient
  // badge, rather than the app's neutral gold/black identity — a reasonable
  // way to signal "this is the AI-powered flow." Centralized here rather
  // than removed, so it stays a *design choice*, not an accident. Two other
  // screens (settings, an unrelated lawyer-dashboard card) had borrowed one
  // of these navy values incidentally with no relation to the AI feature;
  // those were moved onto the core neutral scale above instead.
  static const Color aiSurfaceBackground = Color(0xFF060713);
  static const Color aiSurfaceBackgroundAlt = Color(0xFF080914);
  static const Color aiCardBackground = Color(0xFF0F1424);
  static const Color aiCardBackgroundAlt = Color(0xFF1E2436);
  static const Color aiAccentViolet = Color(0xFF7C3AED);
  static const Color aiAccentAmber = Color(0xFFD97706);

  /// The AI feature's signature violet → amber gradient badge.
  static const List<Color> aiGradient = [aiAccentViolet, aiAccentAmber];

  // ── Screen-specific accents ───────────────────────────────────────────────
  // Requirement: even a genuinely one-screen color belongs here, not inline.
  // These two were already deliberate, well-scoped choices (one was even
  // already a named local constant) — promoted as-is, zero visual change.

  /// Calendar month-picker navigation arrows and header accent
  /// (`appointment_booking/widgets/calendar_header.dart`).
  static const Color calendarAccent = Color(0xFF0B1F4D);

  /// Fine-print disclaimer text on the Contact Support screen.
  static const Color disclaimerText = Color(0xFFDCC3A0);

  // ── Semantic aliases ──────────────────────────────────────────────────────
  // Conventional names for the same tokens above, so call sites can use
  // whichever reads more naturally for their context. These are aliases, not
  // new colors — change the value once, above, and both names update.
  static const Color primaryColor = primaryGold;
  static const Color secondaryColor = accentGold;
  static const Color backgroundColor = primaryBackground;
  static const Color surfaceColor = surface;
  static const Color errorColor = error;
  static const Color textPrimary = primaryText;
  static const Color textSecondary = secondaryText;

  // ── AI assistant illustration (SVG) ──────────────────────────────────────
  // `ai_legal_assistant_card.dart` builds its robot-head and scale icons from
  // literal SVG XML strings (rendered via flutter_svg's `SvgPicture.string`),
  // which need `#RRGGBB` hex *strings*, not Dart `Color` objects — so these
  // are the one exception to "always use a Color". They are still the single
  // source of truth: change a value here and both SVGs pick it up on next
  // build. A deliberately cool slate/cyan illustration palette distinct from
  // the app's warm gold identity, kept self-contained rather than force-fit
  // onto unrelated tokens above.
  static const String illustrationWhite = 'FFFFFF';
  static const String illustrationSlate200 = 'E2E8F0';
  static const String illustrationSlate400 = '94A3B8';
  static const String illustrationSlate300 = 'CBD5E1';
  static const String illustrationSlate500 = '64748B';
  static const String illustrationSlate700 = '334155';
  static const String illustrationSlate800 = '1E293B';
  static const String illustrationSlate900 = '0F172A';
  static const String illustrationCyan = '00D2FF';
  static const String illustrationSkyLight = '38BDF8';
  static const String illustrationSkyDeep = '0284C7';
  static const String illustrationBlueDeep = '1D4ED8';

  /// The splash screen's background. It is intentionally the same value as
  /// [primaryBackground] — the whole point of this token existing separately
  /// is that if the splash background ever needs to differ from the rest of
  /// the app, there is exactly one place to change it, instead of a literal
  /// hidden inside splash_screen.dart that silently drifts out of sync (which
  /// is what caused the original seam: the screen background and the logo's
  /// own baked-in background were never the same color to begin with).
  static const Color splashBackgroundColor = primaryBackground;
}
