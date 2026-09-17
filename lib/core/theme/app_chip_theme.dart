import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Chips: the Documents screen's All / PDF / DOC / Images filters, and every
/// other chip in the app.
///
/// Its own file, like [AppButtonTheme] and [AppInputTheme], so the chip's
/// colours can be reasoned about — and tested — without building the whole
/// [ThemeData], whose text styles reach for a font over the network.
class AppChipTheme {
  AppChipTheme._();

  /// The label colour, resolved against the chip's own state.
  ///
  /// This has to be a [WidgetStateColor] rather than a plain colour, because a
  /// selected chip is drawn on [ChipThemeData.selectedColor] and an unselected
  /// one on [ChipThemeData.backgroundColor] — two backgrounds needing opposite
  /// text.
  ///
  /// It used to be a plain gold, with the selected colour parked in
  /// `secondaryLabelStyle`. That looks right and is not: in Material 3 only
  /// ChoiceChip reads `secondaryLabelStyle`, while FilterChip — which the
  /// document filters are — takes `labelStyle` for BOTH states. A selected
  /// filter therefore drew gold text on the gold `selectedColor`: one colour on
  /// itself, a contrast ratio of 1.0:1, the label invisible. The chip you had
  /// chosen was the one you could not read.
  ///
  /// RawChip resolves a state-dependent colour against the chip's states, so
  /// one style now serves every chip and each state gets the colour its own
  /// background needs.
  static final WidgetStateColor labelColor = WidgetStateColor.resolveWith(
    (states) {
      if (states.contains(WidgetState.disabled)) return AppColors.disabledText;
      // Black on gold (15.3:1) when selected, gold on near-black (8.1:1) when
      // not.
      if (states.contains(WidgetState.selected)) return AppColors.onGold;
      return AppColors.primaryGold;
    },
  );

  static ChipThemeData get chipTheme => ChipThemeData(
        backgroundColor: AppColors.secondaryBackground,
        disabledColor: Colors.transparent,
        selectedColor: AppColors.primaryGold,
        secondarySelectedColor: AppColors.primaryGold,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        labelStyle: TextStyle(
          color: labelColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        // Kept in step for ChoiceChip, the one chip that does read it.
        secondaryLabelStyle: const TextStyle(
          color: AppColors.onGold,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        // Leading icons sit on the same two backgrounds as the label.
        iconTheme: const IconThemeData(color: AppColors.primaryGold, size: 18),
        checkmarkColor: AppColors.onGold,
        selectedShadowColor: Colors.transparent,
        brightness: Brightness.dark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primaryGold, width: 0.8),
        ),
        showCheckmark: false,
      );

  /// Overflow menus — the document cards' actions, among others.
  ///
  /// There was no popup theme at all, so menus fell back to Material 3
  /// defaults: a surface tint the rest of the app does not use, and the muted
  /// grey `labelLarge` for entries sitting beside full-contrast ListTile
  /// titles in the same menu.
  static PopupMenuThemeData get popupMenuTheme => PopupMenuThemeData(
        color: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: const TextStyle(color: AppColors.primaryText, fontSize: 14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.disabled)
                ? AppColors.disabledText
                : AppColors.primaryText,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      );
}
