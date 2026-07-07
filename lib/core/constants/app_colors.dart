import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ===========================================================
  // BRAND COLORS
  // ===========================================================

  // Primary Black Theme
  static const Color navyBlue = Color(0xFF131211);
  static const Color navyBlueLight = Color(0xFF1A1A1C);

  // Gold Palette
  static const Color gold = Color(0xFFDE9D32);
  static const Color goldLight = Color(0xFFF0C763);
  static const Color goldDark = Color(0xFF955F25);

  // Extra Gold
  static const Color goldSoft = Color(0xFFE5AF4F);
  static const Color goldBorder = Color(0xFF644D23);

  // ===========================================================
  // LIGHT THEME
  // ===========================================================

  static const Color lightBackground = Color(0xFFF7F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);

  // ===========================================================
  // DARK THEME
  // ===========================================================

  static const Color darkBackground = Color(0xFF131211);

  static const Color darkSurface = Color(0xFF1A1A1C);

  static const Color darkCard = Color(0xFF232325);

  static const Color darkCard2 = Color(0xFF2B2B2D);

  // ===========================================================
  // TEXT
  // ===========================================================

  static const Color textPrimaryLight = Color(0xFF121212);
  static const Color textSecondaryLight = Color(0xFF5B5B5B);

  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFD1D1D0);

  static const Color textMuted = Color(0xFFA1A1A0);

  // ===========================================================
  // STATUS
  // ===========================================================

  static const Color success = Color(0xFF28C76F);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF4D4F);
  static const Color info = Color(0xFF3B82F6);

  // ===========================================================
  // BORDERS
  // ===========================================================

  static const Color borderLight = Color(0xFFE7E7E7);

  static const Color borderDark = Color(0xFF3A3A3C);

  static const Color dividerDark = Color(0xFF2B2B2D);

  // ===========================================================
  // APPOINTMENT STATUS
  // ===========================================================

  static const Color booked = Color(0xFF3B82F6);

  static const Color completed = Color(0xFF28C76F);

  static const Color cancelled = Color(0xFFFF4D4F);

  static const Color pending = Color(0xFFFFB020);

  // ===========================================================
  // GREYS
  // ===========================================================

  static const Color grey100 = Color(0xFFF8F8F8);
  static const Color grey200 = Color(0xFFEAEAEA);
  static const Color grey300 = Color(0xFFD4D4D4);
  static const Color grey400 = Color(0xFFA1A1A0);
  static const Color grey500 = Color(0xFF707070);

  // ===========================================================
  // BUTTONS
  // ===========================================================

  static const Color buttonPrimary = gold;

  static const Color buttonPrimaryHover = goldLight;

  static const Color buttonSecondary = darkCard;

  // ===========================================================
  // ICONS
  // ===========================================================

  static const Color iconPrimary = gold;

  static const Color iconSecondary = Color(0xFFD1D1D0);

  // ===========================================================
  // PREMIUM CARD
  // ===========================================================

  static const List<Color> premiumGradient = [
    Color(0xFF7A531D),
    Color(0xFFB88327),
    Color(0xFFF0C763),
  ];

  // ===========================================================
  // GOLD BUTTON
  // ===========================================================

  static const List<Color> goldGradient = [
    Color(0xFF955F25),
    Color(0xFFDE9D32),
    Color(0xFFF0C763),
  ];

  // ===========================================================
  // DARK BACKGROUND
  // ===========================================================

  static const List<Color> darkGradient = [
    Color(0xFF131211),
    Color(0xFF1A1A1C),
    Color(0xFF232325),
  ];
}