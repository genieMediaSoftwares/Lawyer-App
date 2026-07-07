import 'package:flutter/material.dart';
import 'app_colors.dart';

class LuxuryThemeExtension extends ThemeExtension<LuxuryThemeExtension> {
  final Color primaryBackground;
  final Color secondaryBackground;
  final Color border;
  final Color goldHover;
  final Color primaryGold;

  const LuxuryThemeExtension({
    required this.primaryBackground,
    required this.secondaryBackground,
    required this.border,
    required this.goldHover,
    required this.primaryGold,
  });

  @override
  LuxuryThemeExtension copyWith({
    Color? primaryBackground,
    Color? secondaryBackground,
    Color? border,
    Color? goldHover,
    Color? primaryGold,
  }) {
    return LuxuryThemeExtension(
      primaryBackground: primaryBackground ?? this.primaryBackground,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      border: border ?? this.border,
      goldHover: goldHover ?? this.goldHover,
      primaryGold: primaryGold ?? this.primaryGold,
    );
  }

  @override
  LuxuryThemeExtension lerp(ThemeExtension<LuxuryThemeExtension>? other, double t) {
    if (other is! LuxuryThemeExtension) {
      return this;
    }
    return LuxuryThemeExtension(
      primaryBackground: Color.lerp(primaryBackground, other.primaryBackground, t)!,
      secondaryBackground: Color.lerp(secondaryBackground, other.secondaryBackground, t)!,
      border: Color.lerp(border, other.border, t)!,
      goldHover: Color.lerp(goldHover, other.goldHover, t)!,
      primaryGold: Color.lerp(primaryGold, other.primaryGold, t)!,
    );
  }

  static LuxuryThemeExtension get value => const LuxuryThemeExtension(
        primaryBackground: AppColors.primaryBackground,
        secondaryBackground: AppColors.secondaryBackground,
        border: AppColors.border,
        goldHover: AppColors.goldHover,
        primaryGold: AppColors.primaryGold,
      );
}

extension BuildContextThemeExtension on BuildContext {
  LuxuryThemeExtension get luxuryTheme => Theme.of(this).extension<LuxuryThemeExtension>() ?? LuxuryThemeExtension.value;
}
