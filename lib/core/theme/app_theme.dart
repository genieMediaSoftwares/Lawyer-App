import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';
import 'app_button_theme.dart';
import 'app_input_theme.dart';
import 'app_card_theme.dart';
import 'theme_extensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get luxuryTheme {
    final ColorScheme colorScheme = const ColorScheme.dark(
      primary: AppColors.primaryGold,
      onPrimary: AppColors.onGold,
      primaryContainer: AppColors.darkGold,
      onPrimaryContainer: AppColors.primaryText,
      secondary: AppColors.accentGold,
      onSecondary: AppColors.onGold,
      surface: AppColors.cardBackground,
      onSurface: AppColors.primaryText,
      error: AppColors.error,
      onError: AppColors.primaryText,
      outline: AppColors.border,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.primaryBackground,
      canvasColor: AppColors.primaryBackground,
      textTheme: AppTextTheme.textTheme,
      elevatedButtonTheme: AppButtonTheme.elevatedButtonTheme,
      outlinedButtonTheme: AppButtonTheme.outlinedButtonTheme,
      textButtonTheme: AppButtonTheme.textButtonTheme,
      inputDecorationTheme: AppInputTheme.inputDecorationTheme,
      cardTheme: AppCardTheme.cardTheme,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primaryText),
        actionsIconTheme: IconThemeData(color: AppColors.primaryText),
        titleTextStyle: TextStyle(
          color: AppColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryBackground,
        selectedItemColor: AppColors.primaryGold,
        unselectedItemColor: AppColors.mutedText,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.primaryBackground,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: AppColors.primaryGold,
      ),
      primaryIconTheme: const IconThemeData(
        color: AppColors.primaryGold,
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        leadingAndTrailingTextStyle: TextStyle(color: AppColors.mutedText),
        iconColor: AppColors.primaryGold,
        titleTextStyle: TextStyle(color: AppColors.primaryText, fontSize: 16, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(color: AppColors.mutedText, fontSize: 13),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondaryBackground,
        disabledColor: Colors.transparent,
        selectedColor: AppColors.primaryGold,
        secondarySelectedColor: AppColors.primaryGold,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: const TextStyle(color: AppColors.primaryGold, fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: AppColors.onGold, fontSize: 13, fontWeight: FontWeight.w600),
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primaryGold, width: 0.8),
        ),
        showCheckmark: false,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryGold;
          }
          return AppColors.mutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryGold.withValues(alpha: 0.5);
          }
          return AppColors.disabledText.withValues(alpha: 0.3);
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryGold;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.onGold),
        side: const BorderSide(color: AppColors.mutedText),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryGold,
        inactiveTrackColor: AppColors.disabledText.withValues(alpha: 0.3),
        thumbColor: AppColors.primaryGold,
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryGold,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // SnackBar Theme
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.primaryText),
        actionTextColor: AppColors.primaryGold,
        behavior: SnackBarBehavior.floating,
      ),

      // Extensions
      extensions: [
        LuxuryThemeExtension.value,
      ],
    );
  }
}
