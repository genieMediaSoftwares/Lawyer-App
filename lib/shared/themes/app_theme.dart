// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../../core/constants/app_colors.dart';
//
// /// AppTheme — Genie Law App
// /// Material 3 theme with Gold + Navy Blue palette.
// /// Provides both light and dark [ThemeData] and a [AppTextStyles] extension.
// /// Use: MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark)
//
// abstract final class AppTheme {
//   // ─────────────────────────────────────────────
//   // FONT FAMILIES
//   // ─────────────────────────────────────────────
//
//   static const String _displayFont = 'Playfair Display'; // authority, elegance
//   static const String _bodyFont = 'Inter'; // clean, highly legible
//
//   // ─────────────────────────────────────────────
//   // COLOR SCHEMES
//   // ─────────────────────────────────────────────
//
//   static const ColorScheme _lightColorScheme = ColorScheme(
//     brightness: Brightness.light,
//
//     // Primary — Navy
//     primary: AppColors.navyPrimary,
//     onPrimary: Colors.white,
//     primaryContainer: AppColors.navyLight,
//     onPrimaryContainer: Colors.white,
//
//     // Secondary — Gold
//     secondary: AppColors.goldPrimary,
//     onSecondary: AppColors.navyDeep,
//     secondaryContainer: AppColors.goldPale,
//     onSecondaryContainer: AppColors.navyDeep,
//
//     // Tertiary — Client Blue
//     tertiary: AppColors.clientAccent,
//     onTertiary: Colors.white,
//     tertiaryContainer: AppColors.clientAccentLight,
//     onTertiaryContainer: AppColors.navyDeep,
//
//     // Error
//     error: AppColors.error,
//     onError: Colors.white,
//     errorContainer: AppColors.errorLight,
//     onErrorContainer: AppColors.errorDark,
//
//     // Surfaces
//     surface: AppColors.lightSurface,
//     onSurface: AppColors.lightOnSurface,
//     surfaceContainerHighest: AppColors.lightSurfaceVariant,
//     onSurfaceVariant: AppColors.lightOnSurfaceVariant,
//
//     // Outline
//     outline: AppColors.lightOutline,
//     outlineVariant: AppColors.lightOutlineVariant,
//
//     // Background
//     background: AppColors.lightBackground,
//     onBackground: AppColors.lightOnBackground,
//
//     // Misc
//     shadow: AppColors.lightShadow,
//     scrim: AppColors.lightScrim,
//     inverseSurface: AppColors.navyDeep,
//     onInverseSurface: Colors.white,
//     inversePrimary: AppColors.goldOnDark,
//   );
//
//   static const ColorScheme _darkColorScheme = ColorScheme(
//     brightness: Brightness.dark,
//
//     // Primary — Gold (flipped for dark: gold becomes primary CTA)
//     primary: AppColors.goldOnDark,
//     onPrimary: AppColors.navyDeep,
//     primaryContainer: AppColors.navyLight,
//     onPrimaryContainer: AppColors.goldOnDark,
//
//     // Secondary — Navy (surface-adjacent)
//     secondary: AppColors.navyLight,
//     onSecondary: AppColors.goldOnDark,
//     secondaryContainer: AppColors.navyMedium,
//     onSecondaryContainer: AppColors.goldLight,
//
//     // Tertiary — Client Blue
//     tertiary: AppColors.clientAccent,
//     onTertiary: Colors.white,
//     tertiaryContainer: Color(0xFF0D2645),
//     onTertiaryContainer: AppColors.clientAccentLight,
//
//     // Error
//     error: Color(0xFFE57373),
//     onError: AppColors.navyDeep,
//     errorContainer: AppColors.statusCancelledDark,
//     onErrorContainer: Color(0xFFFFCDD2),
//
//     // Surfaces
//     surface: AppColors.darkSurface,
//     onSurface: AppColors.darkOnSurface,
//     surfaceContainerHighest: AppColors.darkSurfaceVariant,
//     onSurfaceVariant: AppColors.darkOnSurfaceVariant,
//
//     // Outline
//     outline: AppColors.darkOutline,
//     outlineVariant: AppColors.darkOutlineVariant,
//
//     // Background
//     background: AppColors.darkBackground,
//     onBackground: AppColors.darkOnBackground,
//
//     // Misc
//     shadow: AppColors.darkShadow,
//     scrim: AppColors.darkScrim,
//     inverseSurface: AppColors.lightSurface,
//     onInverseSurface: AppColors.navyDeep,
//     inversePrimary: AppColors.navyPrimary,
//   );
//
//   // ─────────────────────────────────────────────
//   // SHARED TEXT THEME
//   // ─────────────────────────────────────────────
//
//   static TextTheme _textTheme(ColorScheme cs) => TextTheme(
//     // Display — Playfair Display, for hero headings
//     displayLarge: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 57,
//       fontWeight: FontWeight.w700,
//       letterSpacing: -0.25,
//       color: cs.onBackground,
//       height: 1.12,
//     ),
//     displayMedium: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 45,
//       fontWeight: FontWeight.w700,
//       letterSpacing: 0,
//       color: cs.onBackground,
//       height: 1.15,
//     ),
//     displaySmall: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 36,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0,
//       color: cs.onBackground,
//       height: 1.2,
//     ),
//
//     // Headline — Playfair Display, section titles
//     headlineLarge: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 32,
//       fontWeight: FontWeight.w700,
//       letterSpacing: 0,
//       color: cs.onBackground,
//       height: 1.25,
//     ),
//     headlineMedium: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 28,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0,
//       color: cs.onBackground,
//       height: 1.28,
//     ),
//     headlineSmall: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 24,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0,
//       color: cs.onBackground,
//       height: 1.33,
//     ),
//
//     // Title — Inter, card/section labels
//     titleLarge: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 22,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0,
//       color: cs.onSurface,
//       height: 1.27,
//     ),
//     titleMedium: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 16,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0.15,
//       color: cs.onSurface,
//       height: 1.5,
//     ),
//     titleSmall: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0.1,
//       color: cs.onSurface,
//       height: 1.43,
//     ),
//
//     // Body — Inter, readable copy
//     bodyLarge: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 16,
//       fontWeight: FontWeight.w400,
//       letterSpacing: 0.5,
//       color: cs.onSurface,
//       height: 1.5,
//     ),
//     bodyMedium: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w400,
//       letterSpacing: 0.25,
//       color: cs.onSurface,
//       height: 1.43,
//     ),
//     bodySmall: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 12,
//       fontWeight: FontWeight.w400,
//       letterSpacing: 0.4,
//       color: cs.onSurfaceVariant,
//       height: 1.33,
//     ),
//
//     // Label — Inter, buttons, chips, captions
//     labelLarge: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w600,
//       letterSpacing: 0.1,
//       color: cs.onSurface,
//       height: 1.43,
//     ),
//     labelMedium: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 12,
//       fontWeight: FontWeight.w500,
//       letterSpacing: 0.5,
//       color: cs.onSurfaceVariant,
//       height: 1.33,
//     ),
//     labelSmall: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 11,
//       fontWeight: FontWeight.w500,
//       letterSpacing: 0.5,
//       color: cs.onSurfaceVariant,
//       height: 1.45,
//     ),
//   );
//
//   // ─────────────────────────────────────────────
//   // SHARED COMPONENT THEMES
//   // ─────────────────────────────────────────────
//
//   static AppBarTheme _appBarTheme(ColorScheme cs) => AppBarTheme(
//     backgroundColor: cs.surface,
//     foregroundColor: cs.onSurface,
//     elevation: 0,
//     scrolledUnderElevation: 1,
//     shadowColor: cs.shadow,
//     surfaceTintColor: Colors.transparent,
//     centerTitle: false,
//     titleTextStyle: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 20,
//       fontWeight: FontWeight.w600,
//       color: cs.onSurface,
//       letterSpacing: 0,
//     ),
//     iconTheme: IconThemeData(color: cs.onSurface, size: 24),
//     actionsIconTheme: IconThemeData(color: cs.onSurface, size: 24),
//     systemOverlayStyle: cs.brightness == Brightness.light
//         ? SystemUiOverlayStyle.dark.copyWith(
//       statusBarColor: Colors.transparent,
//       statusBarBrightness: Brightness.light,
//     )
//         : SystemUiOverlayStyle.light.copyWith(
//       statusBarColor: Colors.transparent,
//       statusBarBrightness: Brightness.dark,
//     ),
//   );
//
//   static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme cs) =>
//       ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: cs.primary,
//           foregroundColor: cs.onPrimary,
//           disabledBackgroundColor: cs.onSurface.withOpacity(0.12),
//           disabledForegroundColor: cs.onSurface.withOpacity(0.38),
//           elevation: 0,
//           shadowColor: Colors.transparent,
//           minimumSize: const Size(double.infinity, 52),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           textStyle: TextStyle(
//             fontFamily: _bodyFont,
//             fontSize: 15,
//             fontWeight: FontWeight.w600,
//             letterSpacing: 0.5,
//           ),
//         ),
//       );
//
//   static OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme cs) =>
//       OutlinedButtonThemeData(
//         style: OutlinedButton.styleFrom(
//           foregroundColor: cs.primary,
//           side: BorderSide(color: cs.primary, width: 1.5),
//           minimumSize: const Size(double.infinity, 52),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           textStyle: TextStyle(
//             fontFamily: _bodyFont,
//             fontSize: 15,
//             fontWeight: FontWeight.w600,
//             letterSpacing: 0.5,
//           ),
//         ),
//       );
//
//   static TextButtonThemeData _textButtonTheme(ColorScheme cs) =>
//       TextButtonThemeData(
//         style: TextButton.styleFrom(
//           foregroundColor: cs.secondary,
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//           textStyle: TextStyle(
//             fontFamily: _bodyFont,
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             letterSpacing: 0.25,
//           ),
//         ),
//       );
//
//   static FilledButtonThemeData _filledButtonTheme(ColorScheme cs) =>
//       FilledButtonThemeData(
//         style: FilledButton.styleFrom(
//           backgroundColor: cs.secondary,
//           foregroundColor: cs.onSecondary,
//           minimumSize: const Size(double.infinity, 52),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           textStyle: TextStyle(
//             fontFamily: _bodyFont,
//             fontSize: 15,
//             fontWeight: FontWeight.w700,
//             letterSpacing: 0.5,
//           ),
//         ),
//       );
//
//   static InputDecorationTheme _inputDecorationTheme(ColorScheme cs) =>
//       InputDecorationTheme(
//         filled: true,
//         fillColor: cs.brightness == Brightness.light
//             ? AppColors.lightSurfaceVariant
//             : AppColors.darkSurfaceVariant,
//         contentPadding:
//         const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: cs.outline, width: 1),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: cs.outline, width: 1),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: cs.primary, width: 1.8),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: cs.error, width: 1.5),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide(color: cs.error, width: 1.8),
//         ),
//         disabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide:
//           BorderSide(color: cs.outline.withOpacity(0.5), width: 1),
//         ),
//         labelStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 14,
//           fontWeight: FontWeight.w500,
//           color: cs.onSurfaceVariant,
//         ),
//         hintStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 14,
//           fontWeight: FontWeight.w400,
//           color: cs.onSurfaceVariant.withOpacity(0.6),
//         ),
//         errorStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 12,
//           fontWeight: FontWeight.w400,
//           color: cs.error,
//         ),
//         prefixIconColor: cs.onSurfaceVariant,
//         suffixIconColor: cs.onSurfaceVariant,
//         floatingLabelStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 13,
//           fontWeight: FontWeight.w600,
//           color: cs.primary,
//         ),
//       );
//
//   static CardTheme _cardTheme(ColorScheme cs) => CardTheme(
//     elevation: 0,
//     color: cs.surface,
//     surfaceTintColor: Colors.transparent,
//     shadowColor: cs.shadow,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(16),
//       side: BorderSide(color: cs.outlineVariant, width: 1),
//     ),
//     margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
//     clipBehavior: Clip.antiAlias,
//   );
//
//   static BottomNavigationBarThemeData _bottomNavTheme(ColorScheme cs) =>
//       BottomNavigationBarThemeData(
//         backgroundColor: cs.surface,
//         selectedItemColor: cs.primary,
//         unselectedItemColor: cs.onSurfaceVariant,
//         selectedLabelStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 11,
//           fontWeight: FontWeight.w600,
//         ),
//         unselectedLabelStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 11,
//           fontWeight: FontWeight.w400,
//         ),
//         showSelectedLabels: true,
//         showUnselectedLabels: true,
//         type: BottomNavigationBarType.fixed,
//         elevation: 8,
//       );
//
//   static NavigationBarThemeData _navigationBarTheme(ColorScheme cs) =>
//       NavigationBarThemeData(
//         backgroundColor: cs.surface,
//         indicatorColor: cs.secondaryContainer,
//         iconTheme: WidgetStateProperty.resolveWith((states) {
//           if (states.contains(WidgetState.selected)) {
//             return IconThemeData(color: cs.onSecondaryContainer, size: 24);
//           }
//           return IconThemeData(color: cs.onSurfaceVariant, size: 24);
//         }),
//         labelTextStyle: WidgetStateProperty.resolveWith((states) {
//           final base = TextStyle(
//             fontFamily: _bodyFont,
//             fontSize: 12,
//           );
//           if (states.contains(WidgetState.selected)) {
//             return base.copyWith(
//               fontWeight: FontWeight.w600,
//               color: cs.onSecondaryContainer,
//             );
//           }
//           return base.copyWith(
//             fontWeight: FontWeight.w400,
//             color: cs.onSurfaceVariant,
//           );
//         }),
//         surfaceTintColor: Colors.transparent,
//         shadowColor: cs.shadow,
//         elevation: 8,
//         height: 72,
//       );
//
//   static TabBarTheme _tabBarTheme(ColorScheme cs) => TabBarTheme(
//     labelColor: cs.primary,
//     unselectedLabelColor: cs.onSurfaceVariant,
//     indicatorColor: cs.secondary,
//     indicatorSize: TabBarIndicatorSize.label,
//     dividerColor: cs.outlineVariant,
//     labelStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w600,
//     ),
//     unselectedLabelStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w400,
//     ),
//     overlayColor: WidgetStateProperty.all(cs.primary.withOpacity(0.08)),
//   );
//
//   static ChipThemeData _chipTheme(ColorScheme cs) => ChipThemeData(
//     backgroundColor: cs.surfaceContainerHighest,
//     selectedColor: cs.secondaryContainer,
//     secondarySelectedColor: cs.primaryContainer,
//     labelStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 13,
//       fontWeight: FontWeight.w500,
//       color: cs.onSurface,
//     ),
//     secondaryLabelStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 13,
//       fontWeight: FontWeight.w600,
//       color: cs.onSecondaryContainer,
//     ),
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(20),
//       side: BorderSide(color: cs.outline, width: 0.8),
//     ),
//     elevation: 0,
//     pressElevation: 0,
//     showCheckmark: false,
//   );
//
//   static DialogTheme _dialogTheme(ColorScheme cs) => DialogTheme(
//     backgroundColor: cs.surface,
//     surfaceTintColor: Colors.transparent,
//     elevation: 8,
//     shadowColor: cs.shadow,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(20),
//     ),
//     titleTextStyle: TextStyle(
//       fontFamily: _displayFont,
//       fontSize: 20,
//       fontWeight: FontWeight.w600,
//       color: cs.onSurface,
//     ),
//     contentTextStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w400,
//       color: cs.onSurfaceVariant,
//       height: 1.5,
//     ),
//   );
//
//   static SnackBarThemeData _snackBarTheme(ColorScheme cs) => SnackBarThemeData(
//     backgroundColor: cs.brightness == Brightness.light
//         ? AppColors.navyDeep
//         : AppColors.navyLight,
//     contentTextStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 14,
//       fontWeight: FontWeight.w400,
//       color: Colors.white,
//     ),
//     actionTextColor: AppColors.goldOnDark,
//     behavior: SnackBarBehavior.floating,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(10),
//     ),
//     elevation: 4,
//   );
//
//   static DividerThemeData _dividerTheme(ColorScheme cs) => DividerThemeData(
//     color: cs.outlineVariant,
//     thickness: 1,
//     space: 1,
//   );
//
//   static SwitchThemeData _switchTheme(ColorScheme cs) => SwitchThemeData(
//     thumbColor: WidgetStateProperty.resolveWith((states) {
//       if (states.contains(WidgetState.selected)) {
//         return cs.brightness == Brightness.light
//             ? AppColors.goldPrimary
//             : AppColors.goldOnDark;
//       }
//       return cs.onSurfaceVariant;
//     }),
//     trackColor: WidgetStateProperty.resolveWith((states) {
//       if (states.contains(WidgetState.selected)) {
//         return cs.brightness == Brightness.light
//             ? AppColors.goldLight
//             : AppColors.navyLight;
//       }
//       return cs.surfaceContainerHighest;
//     }),
//   );
//
//   static CheckboxThemeData _checkboxTheme(ColorScheme cs) => CheckboxThemeData(
//     fillColor: WidgetStateProperty.resolveWith((states) {
//       if (states.contains(WidgetState.selected)) return cs.primary;
//       return Colors.transparent;
//     }),
//     checkColor: WidgetStateProperty.all(cs.onPrimary),
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
//     side: BorderSide(color: cs.outline, width: 1.5),
//   );
//
//   static RadioThemeData _radioTheme(ColorScheme cs) => RadioThemeData(
//     fillColor: WidgetStateProperty.resolveWith((states) {
//       if (states.contains(WidgetState.selected)) return cs.primary;
//       return cs.onSurfaceVariant;
//     }),
//   );
//
//   static ListTileThemeData _listTileTheme(ColorScheme cs) => ListTileThemeData(
//     tileColor: Colors.transparent,
//     contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//     titleTextStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 15,
//       fontWeight: FontWeight.w500,
//       color: cs.onSurface,
//     ),
//     subtitleTextStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 13,
//       fontWeight: FontWeight.w400,
//       color: cs.onSurfaceVariant,
//     ),
//     leadingAndTrailingTextStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 13,
//       fontWeight: FontWeight.w400,
//       color: cs.onSurfaceVariant,
//     ),
//     iconColor: cs.onSurfaceVariant,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//   );
//
//   static FloatingActionButtonThemeData _fabTheme(ColorScheme cs) =>
//       FloatingActionButtonThemeData(
//         backgroundColor: cs.secondary,
//         foregroundColor: cs.onSecondary,
//         elevation: 4,
//         highlightElevation: 8,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         extendedTextStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 15,
//           fontWeight: FontWeight.w600,
//           letterSpacing: 0.5,
//         ),
//       );
//
//   static PopupMenuThemeData _popupMenuTheme(ColorScheme cs) =>
//       PopupMenuThemeData(
//         color: cs.surface,
//         elevation: 8,
//         shadowColor: cs.shadow,
//         surfaceTintColor: Colors.transparent,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//           side: BorderSide(color: cs.outlineVariant, width: 0.8),
//         ),
//         textStyle: TextStyle(
//           fontFamily: _bodyFont,
//           fontSize: 14,
//           fontWeight: FontWeight.w400,
//           color: cs.onSurface,
//         ),
//       );
//
//   static ProgressIndicatorThemeData _progressIndicatorTheme(ColorScheme cs) =>
//       ProgressIndicatorThemeData(
//         color: cs.primary,
//         linearTrackColor: cs.primary.withOpacity(0.15),
//         circularTrackColor: cs.primary.withOpacity(0.15),
//         linearMinHeight: 4,
//         borderRadius: BorderRadius.circular(2),
//       );
//
//   static TooltipThemeData _tooltipTheme(ColorScheme cs) => TooltipThemeData(
//     decoration: BoxDecoration(
//       color: cs.brightness == Brightness.light
//           ? AppColors.navyDeep
//           : AppColors.navyLight,
//       borderRadius: BorderRadius.circular(8),
//     ),
//     textStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 12,
//       color: Colors.white,
//     ),
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//   );
//
//   static BadgeThemeData _badgeTheme(ColorScheme cs) => BadgeThemeData(
//     backgroundColor: cs.error,
//     textColor: cs.onError,
//     smallSize: 8,
//     largeSize: 18,
//     textStyle: TextStyle(
//       fontFamily: _bodyFont,
//       fontSize: 11,
//       fontWeight: FontWeight.w700,
//     ),
//   );
//
//   // ─────────────────────────────────────────────
//   // THEME BUILDERS
//   // ─────────────────────────────────────────────
//
//   static ThemeData get light {
//     const cs = _lightColorScheme;
//     final text = _textTheme(cs);
//     return ThemeData(
//       useMaterial3: true,
//       brightness: Brightness.light,
//       colorScheme: cs,
//       textTheme: text,
//       fontFamily: _bodyFont,
//
//       // Scaffold
//       scaffoldBackgroundColor: AppColors.lightBackground,
//       canvasColor: AppColors.lightBackground,
//
//       // Components
//       appBarTheme: _appBarTheme(cs),
//       elevatedButtonTheme: _elevatedButtonTheme(cs),
//       outlinedButtonTheme: _outlinedButtonTheme(cs),
//       textButtonTheme: _textButtonTheme(cs),
//       filledButtonTheme: _filledButtonTheme(cs),
//       inputDecorationTheme: _inputDecorationTheme(cs),
//       cardTheme: _cardTheme(cs),
//       bottomNavigationBarTheme: _bottomNavTheme(cs),
//       navigationBarTheme: _navigationBarTheme(cs),
//       tabBarTheme: _tabBarTheme(cs),
//       chipTheme: _chipTheme(cs),
//       dialogTheme: _dialogTheme(cs),
//       snackBarTheme: _snackBarTheme(cs),
//       dividerTheme: _dividerTheme(cs),
//       switchTheme: _switchTheme(cs),
//       checkboxTheme: _checkboxTheme(cs),
//       radioTheme: _radioTheme(cs),
//       listTileTheme: _listTileTheme(cs),
//       floatingActionButtonTheme: _fabTheme(cs),
//       popupMenuTheme: _popupMenuTheme(cs),
//       progressIndicatorTheme: _progressIndicatorTheme(cs),
//       tooltipTheme: _tooltipTheme(cs),
//       badgeTheme: _badgeTheme(cs),
//
//       // Misc
//       splashFactory: InkRipple.splashFactory,
//       visualDensity: VisualDensity.adaptivePlatformDensity,
//       materialTapTargetSize: MaterialTapTargetSize.padded,
//       pageTransitionsTheme: const PageTransitionsTheme(
//         builders: {
//           TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
//           TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
//         },
//       ),
//     );
//   }
//
//   static ThemeData get dark {
//     const cs = _darkColorScheme;
//     final text = _textTheme(cs);
//     return ThemeData(
//       useMaterial3: true,
//       brightness: Brightness.dark,
//       colorScheme: cs,
//       textTheme: text,
//       fontFamily: _bodyFont,
//
//       // Scaffold
//       scaffoldBackgroundColor: AppColors.darkBackground,
//       canvasColor: AppColors.darkBackground,
//
//       // Components
//       appBarTheme: _appBarTheme(cs),
//       elevatedButtonTheme: _elevatedButtonTheme(cs),
//       outlinedButtonTheme: _outlinedButtonTheme(cs),
//       textButtonTheme: _textButtonTheme(cs),
//       filledButtonTheme: _filledButtonTheme(cs),
//       inputDecorationTheme: _inputDecorationTheme(cs),
//       cardTheme: _cardTheme(cs),
//       bottomNavigationBarTheme: _bottomNavTheme(cs),
//       navigationBarTheme: _navigationBarTheme(cs),
//       tabBarTheme: _tabBarTheme(cs),
//       chipTheme: _chipTheme(cs),
//       dialogTheme: _dialogTheme(cs),
//       snackBarTheme: _snackBarTheme(cs),
//       dividerTheme: _dividerTheme(cs),
//       switchTheme: _switchTheme(cs),
//       checkboxTheme: _checkboxTheme(cs),
//       radioTheme: _radioTheme(cs),
//       listTileTheme: _listTileTheme(cs),
//       floatingActionButtonTheme: _fabTheme(cs),
//       popupMenuTheme: _popupMenuTheme(cs),
//       progressIndicatorTheme: _progressIndicatorTheme(cs),
//       tooltipTheme: _tooltipTheme(cs),
//       badgeTheme: _badgeTheme(cs),
//
//       // Misc
//       splashFactory: InkRipple.splashFactory,
//       visualDensity: VisualDensity.adaptivePlatformDensity,
//       materialTapTargetSize: MaterialTapTargetSize.padded,
//       pageTransitionsTheme: const PageTransitionsTheme(
//         builders: {
//           TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
//           TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
//         },
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // CONVENIENCE EXTENSION
// // ─────────────────────────────────────────────
//
// /// Access pre-built text styles via context.
// /// Usage: context.textStyles.goldLabel
// extension AppTextStylesX on BuildContext {
//   AppTextStyles get textStyles => AppTextStyles(Theme.of(this));
// }
//
// /// Pre-built named text styles for common UI patterns in Genie Law.
// final class AppTextStyles {
//   const AppTextStyles(this._theme);
//   final ThemeData _theme;
//
//   TextTheme get _t => _theme.textTheme;
//   ColorScheme get _cs => _theme.colorScheme;
//
//   // Screen titles (Playfair Display)
//   TextStyle get screenTitle =>
//       _t.headlineSmall!.copyWith(fontWeight: FontWeight.w700);
//
//   // Section headings
//   TextStyle get sectionHeading =>
//       _t.titleLarge!.copyWith(fontWeight: FontWeight.w700);
//
//   // Card title
//   TextStyle get cardTitle => _t.titleMedium!;
//
//   // Card subtitle / helper
//   TextStyle get cardSubtitle => _t.bodySmall!;
//
//   // Gold accent label (e.g. rating, premium tag)
//   TextStyle get goldLabel => _t.labelMedium!.copyWith(
//     color: AppColors.goldPrimary,
//     fontWeight: FontWeight.w700,
//     letterSpacing: 0.8,
//   );
//
//   // Gold on dark backgrounds
//   TextStyle get goldOnDark => _t.labelLarge!.copyWith(
//     color: AppColors.goldOnDark,
//     fontWeight: FontWeight.w700,
//   );
//
//   // Status chip text
//   TextStyle get statusLabel => _t.labelSmall!.copyWith(
//     fontWeight: FontWeight.w700,
//     letterSpacing: 0.6,
//   );
//
//   // Primary CTA button text
//   TextStyle get buttonPrimary => _t.labelLarge!.copyWith(
//     color: _cs.onPrimary,
//     fontWeight: FontWeight.w700,
//     letterSpacing: 0.5,
//     fontSize: 15,
//   );
//
//   // Secondary/gold CTA button text
//   TextStyle get buttonGold => _t.labelLarge!.copyWith(
//     color: _cs.onSecondary,
//     fontWeight: FontWeight.w700,
//     letterSpacing: 0.5,
//     fontSize: 15,
//   );
//
//   // Amount / fee display (large)
//   TextStyle get amountLarge => _t.headlineMedium!.copyWith(
//     fontFamily: 'Inter',
//     fontWeight: FontWeight.w800,
//     color: AppColors.goldPrimary,
//   );
//
//   // Amount / fee display (medium)
//   TextStyle get amountMedium => _t.titleLarge!.copyWith(
//     fontFamily: 'Inter',
//     fontWeight: FontWeight.w700,
//     color: AppColors.goldPrimary,
//   );
//
//   // Lawyer name on profile/card
//   TextStyle get lawyerName => _t.titleMedium!.copyWith(
//     fontWeight: FontWeight.w700,
//     letterSpacing: 0,
//   );
//
//   // Lawyer specialisation line
//   TextStyle get lawyerSpeciality => _t.bodySmall!.copyWith(
//     color: _cs.onSurfaceVariant,
//     fontWeight: FontWeight.w500,
//   );
//
//   // Chat message text (sent)
//   TextStyle get messageSent => _t.bodyMedium!.copyWith(
//     color: Colors.white,
//     height: 1.45,
//   );
//
//   // Chat message text (received)
//   TextStyle get messageReceived => _t.bodyMedium!.copyWith(
//     color: _cs.onSurface,
//     height: 1.45,
//   );
//
//   // Timestamp / metadata
//   TextStyle get timestamp => _t.labelSmall!.copyWith(
//     fontSize: 10,
//     color: _cs.onSurfaceVariant.withOpacity(0.7),
//   );
//
//   // Empty state headline
//   TextStyle get emptyStateTitle => _t.titleMedium!.copyWith(
//     fontWeight: FontWeight.w600,
//     color: _cs.onSurfaceVariant,
//   );
//
//   // Empty state body
//   TextStyle get emptyStateBody => _t.bodySmall!.copyWith(
//     height: 1.5,
//     color: _cs.onSurfaceVariant.withOpacity(0.7),
//   );
//
//   // Verified badge text
//   TextStyle get verifiedBadge => _t.labelSmall!.copyWith(
//     color: AppColors.success,
//     fontWeight: FontWeight.w700,
//     letterSpacing: 0.3,
//   );
//
//   // Hyperlink / clickable text
//   TextStyle get link => _t.bodyMedium!.copyWith(
//     color: _cs.primary,
//     fontWeight: FontWeight.w500,
//     decoration: TextDecoration.underline,
//     decorationColor: _cs.primary.withOpacity(0.5),
//   );
//
//   // Onboarding headline (Playfair)
//   TextStyle get onboardTitle => _t.headlineMedium!.copyWith(
//     fontWeight: FontWeight.w700,
//     height: 1.3,
//   );
//
//   // Onboarding body
//   TextStyle get onboardBody => _t.bodyLarge!.copyWith(
//     color: _cs.onSurfaceVariant,
//     height: 1.6,
//   );
// }
//
// // ─────────────────────────────────────────────
// // SPACING & RADIUS CONSTANTS
// // ─────────────────────────────────────────────
//
// /// Consistent spacing scale — use instead of raw doubles.
// abstract final class AppSpacing {
//   static const double xs = 4;
//   static const double sm = 8;
//   static const double md = 12;
//   static const double base = 16;
//   static const double lg = 20;
//   static const double xl = 24;
//   static const double xxl = 32;
//   static const double xxxl = 48;
//
//   // Named semantic spacing
//   static const double screenPadding = base;
//   static const double sectionGap = xl;
//   static const double cardPadding = base;
//   static const double listItemGap = sm;
//   static const double buttonHeight = 52;
//   static const double inputHeight = 52;
//   static const double appBarHeight = 56;
//   static const double bottomNavHeight = 72;
//
//   // EdgeInsets shorthands
//   static const EdgeInsets screenEdge =
//   EdgeInsets.symmetric(horizontal: screenPadding);
//   static const EdgeInsets cardEdge = EdgeInsets.all(cardPadding);
//   static const EdgeInsets sectionEdge =
//   EdgeInsets.symmetric(vertical: sectionGap, horizontal: screenPadding);
// }
//
// /// Consistent border-radius scale.
// abstract final class AppRadius {
//   static const double xs = 4;
//   static const double sm = 8;
//   static const double md = 12;
//   static const double lg = 16;
//   static const double xl = 20;
//   static const double xxl = 24;
//   static const double full = 999;
//
//   static BorderRadius get xsAll => BorderRadius.circular(xs);
//   static BorderRadius get smAll => BorderRadius.circular(sm);
//   static BorderRadius get mdAll => BorderRadius.circular(md);
//   static BorderRadius get lgAll => BorderRadius.circular(lg);
//   static BorderRadius get xlAll => BorderRadius.circular(xl);
//   static BorderRadius get xxlAll => BorderRadius.circular(xxl);
//   static BorderRadius get fullAll => BorderRadius.circular(full);
// }
//
// /// Elevation / shadow helpers.
// abstract final class AppShadows {
//   static List<BoxShadow> card(Color shadow) => [
//     BoxShadow(
//       color: shadow.withOpacity(0.06),
//       blurRadius: 12,
//       offset: const Offset(0, 2),
//     ),
//     BoxShadow(
//       color: shadow.withOpacity(0.04),
//       blurRadius: 4,
//       offset: const Offset(0, 1),
//     ),
//   ];
//
//   static List<BoxShadow> elevated(Color shadow) => [
//     BoxShadow(
//       color: shadow.withOpacity(0.12),
//       blurRadius: 24,
//       offset: const Offset(0, 8),
//     ),
//     BoxShadow(
//       color: shadow.withOpacity(0.06),
//       blurRadius: 8,
//       offset: const Offset(0, 2),
//     ),
//   ];
//
//   static List<BoxShadow> gold = [
//     BoxShadow(
//       color: AppColors.goldPrimary.withOpacity(0.25),
//       blurRadius: 20,
//       offset: const Offset(0, 6),
//     ),
//   ];
//
//   static List<BoxShadow> navyGlow = [
//     BoxShadow(
//       color: AppColors.navyPrimary.withOpacity(0.3),
//       blurRadius: 24,
//       offset: const Offset(0, 8),
//     ),
//   ];
// }

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    colorScheme: const ColorScheme.light(
      primary: AppColors.navyBlue,
      secondary: AppColors.gold,
      surface: AppColors.lightSurface,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.lightBackground,

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.navyBlue,
      titleTextStyle: TextStyle(
        color: AppColors.navyBlue,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: AppColors.lightCard,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.gold,
          width: 2,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimaryLight,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryLight,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryLight,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: AppColors.textPrimaryLight,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.textSecondaryLight,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderLight,
      thickness: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.goldLight,
      surface: AppColors.darkSurface,
      error: AppColors.error,
    ),

    scaffoldBackgroundColor: AppColors.darkBackground,

    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.darkBackground,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 2,
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.borderDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.gold,
          width: 2,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.navyBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimaryDark,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: AppColors.textPrimaryDark,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: AppColors.textSecondaryDark,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
    ),
  );
}