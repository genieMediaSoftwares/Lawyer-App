// import 'package:flutter/material.dart';
//
// /// AppColors — Genie Law App
// /// Palette: Deep Navy Blue + Antique Gold + Neutral Greys
// /// Supports both Light and Dark Material 3 themes.
// /// All values are `static const` — zero runtime overhead.
//
// abstract final class AppColors {
//   // ─────────────────────────────────────────────
//   // BRAND PRIMARIES
//   // ─────────────────────────────────────────────
//
//   /// Deep Navy — primary brand color, trust & authority
//   static const Color navyDeep = Color(0xFF0A1628);
//
//   /// Royal Navy — primary interactive (buttons, links)
//   static const Color navyPrimary = Color(0xFF0D2045);
//
//   /// Navy Medium — cards, containers in dark theme
//   static const Color navyMedium = Color(0xFF152C5B);
//
//   /// Navy Light — subtle backgrounds, dividers
//   static const Color navyLight = Color(0xFF1E3A6E);
//
//   /// Navy Surface — elevated surfaces in dark theme
//   static const Color navySurface = Color(0xFF112040);
//
//   // ─────────────────────────────────────────────
//   // GOLD ACCENT
//   // ─────────────────────────────────────────────
//
//   /// Gold Primary — CTA buttons, active states, highlights
//   static const Color goldPrimary = Color(0xFFD4AF37);
//
//   /// Gold Rich — hover/pressed gold state
//   static const Color goldRich = Color(0xFFBF9B30);
//
//   /// Gold Light — soft gold for backgrounds, tags
//   static const Color goldLight = Color(0xFFF5E6A3);
//
//   /// Gold Muted — gold tint on dark surfaces
//   static const Color goldMuted = Color(0xFFE8C84A);
//
//   /// Gold On Dark — readable gold text on navy
//   static const Color goldOnDark = Color(0xFFEDD574);
//
//   /// Gold Pale — very light, for chip backgrounds
//   static const Color goldPale = Color(0xFFFDF6D8);
//
//   // ─────────────────────────────────────────────
//   // NEUTRAL GREYS (Light Theme)
//   // ─────────────────────────────────────────────
//
//   static const Color grey50 = Color(0xFFF8F9FA);
//   static const Color grey100 = Color(0xFFF1F3F5);
//   static const Color grey200 = Color(0xFFE9ECEF);
//   static const Color grey300 = Color(0xFFDEE2E6);
//   static const Color grey400 = Color(0xFFCED4DA);
//   static const Color grey500 = Color(0xFFADB5BD);
//   static const Color grey600 = Color(0xFF6C757D);
//   static const Color grey700 = Color(0xFF495057);
//   static const Color grey800 = Color(0xFF343A40);
//   static const Color grey900 = Color(0xFF212529);
//
//   // ─────────────────────────────────────────────
//   // SEMANTIC COLORS
//   // ─────────────────────────────────────────────
//
//   /// Success — verified, paid, confirmed
//   static const Color success = Color(0xFF1B8A5A);
//   static const Color successLight = Color(0xFFE6F6EE);
//   static const Color successDark = Color(0xFF146B45);
//
//   /// Error — validation, failed payment
//   static const Color error = Color(0xFFC0392B);
//   static const Color errorLight = Color(0xFFFDECEB);
//   static const Color errorDark = Color(0xFF922B21);
//
//   /// Warning — pending, expiring soon
//   static const Color warning = Color(0xFFD4820A);
//   static const Color warningLight = Color(0xFFFEF5E7);
//   static const Color warningDark = Color(0xFFA0620A);
//
//   /// Info — neutral info banners
//   static const Color info = Color(0xFF1565C0);
//   static const Color infoLight = Color(0xFFE3F0FF);
//
//   // ─────────────────────────────────────────────
//   // LIGHT THEME SEMANTIC MAPPING
//   // ─────────────────────────────────────────────
//
//   static const Color lightBackground = Color(0xFFF8F9FC);
//   static const Color lightSurface = Color(0xFFFFFFFF);
//   static const Color lightSurfaceVariant = Color(0xFFF1F3F8);
//   static const Color lightOnBackground = Color(0xFF0A1628);
//   static const Color lightOnSurface = Color(0xFF1A2340);
//   static const Color lightOnSurfaceVariant = Color(0xFF495A78);
//   static const Color lightOutline = Color(0xFFD0D7E8);
//   static const Color lightOutlineVariant = Color(0xFFE8ECF5);
//   static const Color lightShadow = Color(0x1A0A1628);
//   static const Color lightScrim = Color(0x800A1628);
//
//   // ─────────────────────────────────────────────
//   // DARK THEME SEMANTIC MAPPING
//   // ─────────────────────────────────────────────
//
//   static const Color darkBackground = Color(0xFF060E1C);
//   static const Color darkSurface = Color(0xFF0D1B33);
//   static const Color darkSurfaceVariant = Color(0xFF112040);
//   static const Color darkOnBackground = Color(0xFFEDF0F8);
//   static const Color darkOnSurface = Color(0xFFDCE4F5);
//   static const Color darkOnSurfaceVariant = Color(0xFFAABDD8);
//   static const Color darkOutline = Color(0xFF2A3D5C);
//   static const Color darkOutlineVariant = Color(0xFF1E2F48);
//   static const Color darkShadow = Color(0x33000000);
//   static const Color darkScrim = Color(0xCC000000);
//
//   // ─────────────────────────────────────────────
//   // ROLE-SPECIFIC ACCENT COLORS
//   // ─────────────────────────────────────────────
//
//   /// Client role accent
//   static const Color clientAccent = Color(0xFF2E86C1);
//   static const Color clientAccentLight = Color(0xFFD6EAF8);
//
//   /// Lawyer role accent (gold-tinted)
//   static const Color lawyerAccent = goldPrimary;
//   static const Color lawyerAccentLight = goldPale;
//
//   /// Admin role accent
//   static const Color adminAccent = Color(0xFF6C3483);
//   static const Color adminAccentLight = Color(0xFFF4ECF7);
//
//   // ─────────────────────────────────────────────
//   // STAR / RATING
//   // ─────────────────────────────────────────────
//
//   static const Color starFilled = Color(0xFFEDB941);
//   static const Color starEmpty = Color(0xFFDDE2EE);
//
//   // ─────────────────────────────────────────────
//   // SPECIAL UI
//   // ─────────────────────────────────────────────
//
//   static const Color shimmerBase = Color(0xFFE0E7F0);
//   static const Color shimmerHighlight = Color(0xFFF5F8FF);
//   static const Color shimmerBaseDark = Color(0xFF1C2E4A);
//   static const Color shimmerHighlightDark = Color(0xFF243858);
//
//   /// Divider
//   static const Color dividerLight = Color(0xFFE4EAF5);
//   static const Color dividerDark = Color(0xFF1E2F48);
//
//   /// Chat bubble colors
//   static const Color bubbleSent = navyPrimary;
//   static const Color bubbleReceived = Color(0xFFEEF2FB);
//   static const Color bubbleSentDark = navyLight;
//   static const Color bubbleReceivedDark = Color(0xFF152038);
//
//   /// Status pill backgrounds
//   static const Color statusPending = Color(0xFFFEF5E7);
//   static const Color statusConfirmed = Color(0xFFE6F6EE);
//   static const Color statusCancelled = Color(0xFFFDECEB);
//   static const Color statusCompleted = Color(0xFFEDF2FF);
//
//   static const Color statusPendingDark = Color(0xFF3D2A05);
//   static const Color statusConfirmedDark = Color(0xFF0C3320);
//   static const Color statusCancelledDark = Color(0xFF3D0E08);
//   static const Color statusCompletedDark = Color(0xFF0D1E4A);
//
//   /// Gradient stops — hero banner, premium card
//   static const List<Color> goldGradient = [
//     Color(0xFFEDD574),
//     Color(0xFFD4AF37),
//     Color(0xFFBF9B30),
//   ];
//
//   static const List<Color> navyGradient = [
//     Color(0xFF0D2045),
//     Color(0xFF0A1628),
//     Color(0xFF060E1C),
//   ];
//
//   static const List<Color> premiumCardGradient = [
//     Color(0xFF152C5B),
//     Color(0xFF0A1628),
//   ];
// }
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color navyBlue = Color(0xFF0F172A);
  static const Color navyBlueLight = Color(0xFF1E293B);

  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFE8C76A);
  static const Color goldDark = Color(0xFFB8922C);

  // Light Theme
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // Dark Theme
  static const Color darkBackground = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Border Colors
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  // Appointment Status
  static const Color booked = Color(0xFF3B82F6);
  static const Color completed = Color(0xFF22C55E);
  static const Color cancelled = Color(0xFFEF4444);
  static const Color pending = Color(0xFFF59E0B);

  // Extra Shades
  static const Color grey100 = Color(0xFFF1F5F9);
  static const Color grey200 = Color(0xFFE2E8F0);
  static const Color grey300 = Color(0xFFCBD5E1);
  static const Color grey400 = Color(0xFF94A3B8);
  static const Color grey500 = Color(0xFF64748B);
}