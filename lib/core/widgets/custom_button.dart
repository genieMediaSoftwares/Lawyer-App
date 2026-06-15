// import 'package:flutter/material.dart';
// import '../constants/app_colors.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // CustomButton
// //
// // A fully composable button for the Genie Law App.
// // Variants: primary (navy), gold (CTA), outlined, text, danger, icon-only.
// // Built on Material 3 — respects ThemeData automatically.
// // Supports loading state, leading/trailing icons, full-width or shrink-wrap.
// // ─────────────────────────────────────────────────────────────────────────────
//
// enum ButtonVariant { primary, gold, outlined, ghost, danger, success }
// enum ButtonSize { sm, md, lg }
//
// class CustomButton extends StatelessWidget {
//   const CustomButton({
//     super.key,
//     required this.label,
//     this.onPressed,
//     this.variant = ButtonVariant.primary,
//     this.size = ButtonSize.md,
//     this.isLoading = false,
//     this.isFullWidth = true,
//     this.leadingIcon,
//     this.trailingIcon,
//     this.borderRadius,
//   });
//
//   final String label;
//   final VoidCallback? onPressed;
//   final ButtonVariant variant;
//   final ButtonSize size;
//   final bool isLoading;
//   final bool isFullWidth;
//   final IconData? leadingIcon;
//   final IconData? trailingIcon;
//   final double? borderRadius;
//
//   // ── Size tokens ──────────────────────────────────────────────────────────
//   double get _height => switch (size) {
//     ButtonSize.sm => 40,
//     ButtonSize.md => 52,
//     ButtonSize.lg => 58,
//   };
//
//   EdgeInsets get _padding => switch (size) {
//     ButtonSize.sm => const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//     ButtonSize.md => const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
//     ButtonSize.lg => const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//   };
//
//   double get _fontSize => switch (size) {
//     ButtonSize.sm => 13,
//     ButtonSize.md => 15,
//     ButtonSize.lg => 16,
//   };
//
//   double get _iconSize => switch (size) {
//     ButtonSize.sm => 16,
//     ButtonSize.md => 18,
//     ButtonSize.lg => 20,
//   };
//
//   double get _radius => borderRadius ?? 12;
//
//   // ── Style resolution ─────────────────────────────────────────────────────
//   _ButtonStyle _resolveStyle(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//
//     return switch (variant) {
//       ButtonVariant.primary => _ButtonStyle(
//         background: cs.primary,
//         foreground: cs.onPrimary,
//         border: null,
//         loaderColor: cs.onPrimary,
//         pressedBackground: isDark ? AppColors.navyMedium : AppColors.navyLight,
//       ),
//       ButtonVariant.gold => _ButtonStyle(
//         background: AppColors.goldPrimary,
//         foreground: AppColors.navyDeep,
//         border: null,
//         loaderColor: AppColors.navyDeep,
//         pressedBackground: AppColors.goldRich,
//       ),
//       ButtonVariant.outlined => _ButtonStyle(
//         background: Colors.transparent,
//         foreground: cs.primary,
//         border: BorderSide(color: cs.primary, width: 1.5),
//         loaderColor: cs.primary,
//         pressedBackground: cs.primary.withOpacity(0.08),
//       ),
//       ButtonVariant.ghost => _ButtonStyle(
//         background: Colors.transparent,
//         foreground: cs.onSurface,
//         border: null,
//         loaderColor: cs.onSurface,
//         pressedBackground: cs.onSurface.withOpacity(0.06),
//       ),
//       ButtonVariant.danger => _ButtonStyle(
//         background: AppColors.error,
//         foreground: Colors.white,
//         border: null,
//         loaderColor: Colors.white,
//         pressedBackground: AppColors.errorDark,
//       ),
//       ButtonVariant.success => _ButtonStyle(
//         background: AppColors.success,
//         foreground: Colors.white,
//         border: null,
//         loaderColor: Colors.white,
//         pressedBackground: AppColors.successDark,
//       ),
//     };
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final style = _resolveStyle(context);
//     final disabled = onPressed == null || isLoading;
//
//     final shape = RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(_radius),
//       side: style.border ?? BorderSide.none,
//     );
//
//     final buttonStyle = ButtonStyle(
//       backgroundColor: WidgetStateProperty.resolveWith((states) {
//         if (states.contains(WidgetState.disabled)) {
//           return Theme.of(context).colorScheme.onSurface.withOpacity(0.12);
//         }
//         if (states.contains(WidgetState.pressed)) {
//           return style.pressedBackground;
//         }
//         return style.background;
//       }),
//       foregroundColor: WidgetStateProperty.resolveWith((states) {
//         if (states.contains(WidgetState.disabled)) {
//           return Theme.of(context).colorScheme.onSurface.withOpacity(0.38);
//         }
//         return style.foreground;
//       }),
//       overlayColor: WidgetStateProperty.all(style.foreground.withOpacity(0.08)),
//       elevation: WidgetStateProperty.all(0),
//       shadowColor: WidgetStateProperty.all(Colors.transparent),
//       minimumSize: WidgetStateProperty.all(
//         Size(isFullWidth ? double.infinity : 0, _height),
//       ),
//       padding: WidgetStateProperty.all(_padding),
//       shape: WidgetStateProperty.all(shape),
//       side: style.border != null
//           ? WidgetStateProperty.resolveWith((states) {
//         if (states.contains(WidgetState.disabled)) {
//           return BorderSide(
//             color: Theme.of(context)
//                 .colorScheme
//                 .onSurface
//                 .withOpacity(0.12),
//             width: 1.5,
//           );
//         }
//         return style.border!;
//       })
//           : null,
//       animationDuration: const Duration(milliseconds: 150),
//     );
//
//     final child = isLoading
//         ? _LoadingContent(color: style.loaderColor, size: _iconSize)
//         : _ButtonContent(
//       label: label,
//       leadingIcon: leadingIcon,
//       trailingIcon: trailingIcon,
//       iconSize: _iconSize,
//       fontSize: _fontSize,
//       fontWeight: FontWeight.w600,
//     );
//
//     final button = ElevatedButton(
//       onPressed: disabled ? null : onPressed,
//       style: buttonStyle,
//       child: child,
//     );
//
//     return isFullWidth ? button : IntrinsicWidth(child: button);
//   }
// }
//
// // ─────────────────────────────────────────────
// // Icon-only variant
// // ─────────────────────────────────────────────
//
// class CustomIconButton extends StatelessWidget {
//   const CustomIconButton({
//     super.key,
//     required this.icon,
//     this.onPressed,
//     this.variant = ButtonVariant.primary,
//     this.size = ButtonSize.md,
//     this.tooltip,
//     this.borderRadius,
//   });
//
//   final IconData icon;
//   final VoidCallback? onPressed;
//   final ButtonVariant variant;
//   final ButtonSize size;
//   final String? tooltip;
//   final double? borderRadius;
//
//   double get _dimension => switch (size) {
//     ButtonSize.sm => 36,
//     ButtonSize.md => 48,
//     ButtonSize.lg => 56,
//   };
//
//   double get _iconSize => switch (size) {
//     ButtonSize.sm => 16,
//     ButtonSize.md => 20,
//     ButtonSize.lg => 24,
//   };
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//
//     final (bg, fg) = switch (variant) {
//       ButtonVariant.primary => (cs.primary, cs.onPrimary),
//       ButtonVariant.gold => (AppColors.goldPrimary, AppColors.navyDeep),
//       ButtonVariant.outlined => (Colors.transparent, cs.primary),
//       ButtonVariant.ghost => (Colors.transparent, cs.onSurface),
//       ButtonVariant.danger => (AppColors.error, Colors.white),
//       ButtonVariant.success => (AppColors.success, Colors.white),
//     };
//
//     final radius = borderRadius ?? (size == ButtonSize.sm ? 8.0 : 12.0);
//
//     Widget btn = SizedBox(
//       width: _dimension,
//       height: _dimension,
//       child: Material(
//         color: bg,
//         borderRadius: BorderRadius.circular(radius),
//         border: variant == ButtonVariant.outlined
//             ? Border.all(color: cs.primary, width: 1.5)
//             : null,
//         child: InkWell(
//           onTap: onPressed,
//           borderRadius: BorderRadius.circular(radius),
//           splashColor: fg.withOpacity(0.12),
//           highlightColor: fg.withOpacity(0.06),
//           child: Icon(icon, color: fg, size: _iconSize),
//         ),
//       ),
//     );
//
//     if (tooltip != null) {
//       btn = Tooltip(message: tooltip!, child: btn);
//     }
//
//     return btn;
//   }
// }
//
// // ─────────────────────────────────────────────
// // Internal helpers
// // ─────────────────────────────────────────────
//
// class _ButtonStyle {
//   const _ButtonStyle({
//     required this.background,
//     required this.foreground,
//     required this.border,
//     required this.loaderColor,
//     required this.pressedBackground,
//   });
//   final Color background;
//   final Color foreground;
//   final BorderSide? border;
//   final Color loaderColor;
//   final Color pressedBackground;
// }
//
// class _ButtonContent extends StatelessWidget {
//   const _ButtonContent({
//     required this.label,
//     this.leadingIcon,
//     this.trailingIcon,
//     required this.iconSize,
//     required this.fontSize,
//     required this.fontWeight,
//   });
//
//   final String label;
//   final IconData? leadingIcon;
//   final IconData? trailingIcon;
//   final double iconSize;
//   final double fontSize;
//   final FontWeight fontWeight;
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         if (leadingIcon != null) ...[
//           Icon(leadingIcon, size: iconSize),
//           const SizedBox(width: 8),
//         ],
//         Flexible(
//           child: Text(
//             label,
//             style: TextStyle(
//               fontSize: fontSize,
//               fontWeight: fontWeight,
//               letterSpacing: 0.3,
//             ),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//         if (trailingIcon != null) ...[
//           const SizedBox(width: 8),
//           Icon(trailingIcon, size: iconSize),
//         ],
//       ],
//     );
//   }
// }
//
// class _LoadingContent extends StatelessWidget {
//   const _LoadingContent({required this.color, required this.size});
//   final Color color;
//   final double size;
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: size,
//       height: size,
//       child: CircularProgressIndicator(
//         strokeWidth: 2.2,
//         valueColor: AlwaysStoppedAnimation<Color>(color),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final double width;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 55,
    this.width = double.infinity,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        child: isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon),
              const SizedBox(width: 8),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}