import 'package:flutter/material.dart';

abstract final class AppColors {
  AppColors._();

  // Primary backgrounds (No pure white backgrounds anywhere)
  static const Color primaryBackground = Color(0xFF0A0A0A);
  static const Color secondaryBackground = Color(0xFF111111);
  static const Color cardBackground = Color(0xFF171717);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color border = Color(0xFF2A2A2A);

  // Golds
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color darkGold = Color(0xFFB8860B);
  static const Color goldHover = Color(0xFFE6C35C);
  static const Color accentGold = Color(0xFFF4C95D);

  // Texts (Dark white text)
  static const Color primaryText = Color(0xFFF5F5F5);
  static const Color secondaryText = Color(0xFFD0D0D0);
  static const Color mutedText = Color(0xFF9A9A9A);
  static const Color disabledText = Color(0xFF707070);

  // Semantics
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFB300);

  // Divider
  static const Color divider = Color(0xFF2C2C2C);
}
