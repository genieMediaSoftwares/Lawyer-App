import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppCardTheme {
  AppCardTheme._();

  static CardThemeData get cardTheme {
    return CardThemeData(
      color: AppColors.cardBackground,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
    );
  }
}
