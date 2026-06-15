// import 'package:flutter/material.dart';
// import '../constants/app_colors.dart';
// import 'custom_button.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // CustomDialog
// //
// // A composable dialog system for the Genie Law App.
// //
// // Static helpers (call anywhere):
// //   CustomDialog.confirm(...)       — destructive / non-destructive confirm
// //   CustomDialog.info(...)          — informational alert
// //   CustomDialog.success(...)       — success confirmation
// //   CustomDialog.error(...)         — error message
// //   CustomDialog.loading(...)       — non-dismissible loading dialog
// //   CustomDialog.bottomSheet(...)   — modal bottom sheet
// //   CustomDialog.custom(...)        — arbitrary widget dialog
// //
// // All respect ThemeData (dark / light), Material 3, and safe area.
// // ─────────────────────────────────────────────────────────────────────────────
//
// enum DialogType { confirm, info, success, error, warning }
//
// class CustomDialog {
//   CustomDialog._();
//
//   // ── Confirm dialog ────────────────────────────────────────────────────────
//
//   static Future<bool?> confirm({
//     required BuildContext context,
//     required String title,
//     required String message,
//     String confirmLabel = 'Confirm',
//     String cancelLabel = 'Cancel',
//     bool isDangerous = false,
//     IconData? icon,
//     bool barrierDismissible = true,
//   }) {
//     return showDialog<bool>(
//       context: context,
//       barrierDismissible: barrierDismissible,
//       barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.5),
//       builder: (_) => _AppDialog(
//         icon: icon ?? (isDangerous ? Icons.warning_rounded : Icons.help_outline_rounded),
//         iconColor: isDangerous ? AppColors.error : AppColors.navyPrimary,
//         iconBackground: isDangerous ? AppColors.errorLight : AppColors.infoLight,
//         title: title,
//         message: message,
//         primaryLabel: confirmLabel,
//         secondaryLabel: cancelLabel,
//         primaryVariant: isDangerous ? ButtonVariant.danger : ButtonVariant.primary,
//         onPrimary: () => Navigator.of(_).pop(true),
//         onSecondary: () => Navigator.of(_).pop(false),
//       ),
//     );
//   }
//
//   // ── Info dialog ───────────────────────────────────────────────────────────
//
//   static Future<void> info({
//     required BuildContext context,
//     required String title,
//     required String message,
//     String buttonLabel = 'Got it',
//     IconData? icon,
//   }) {
//     return showDialog<void>(
//       context: context,
//       barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.5),
//       builder: (_) => _AppDialog(
//         icon: icon ?? Icons.info_outline_rounded,
//         iconColor: AppColors.info,
//         iconBackground: AppColors.infoLight,
//         title: title,
//         message: message,
//         primaryLabel: buttonLabel,
//         onPrimary: () => Navigator.of(_).pop(),
//       ),
//     );
//   }
//
//   // ── Success dialog ────────────────────────────────────────────────────────
//
//   static Future<void> success({
//     required BuildContext context,
//     required String title,
//     required String message,
//     String buttonLabel = 'Continue',
//     IconData? icon,
//     VoidCallback? onPressed,
//   }) {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.5),
//       builder: (_) => _AppDialog(
//         icon: icon ?? Icons.check_circle_outline_rounded,
//         iconColor: AppColors.success,
//         iconBackground: AppColors.successLight,
//         title: title,
//         message: message,
//         primaryLabel: buttonLabel,
//         primaryVariant: ButtonVariant.success,
//         onPrimary: () {
//           Navigator.of(_).pop();
//           onPressed?.call();
//         },
//       ),
//     );
//   }
//
//   // ── Error dialog ──────────────────────────────────────────────────────────
//
//   static Future<void> error({
//     required BuildContext context,
//     required String title,
//     required String message,
//     String buttonLabel = 'Close',
//     String? retryLabel,
//     VoidCallback? onRetry,
//   }) {
//     return showDialog<void>(
//       context: context,
//       barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.5),
//       builder: (_) => _AppDialog(
//         icon: Icons.error_outline_rounded,
//         iconColor: AppColors.error,
//         iconBackground: AppColors.errorLight,
//         title: title,
//         message: message,
//         primaryLabel: retryLabel ?? buttonLabel,
//         secondaryLabel: retryLabel != null ? buttonLabel : null,
//         primaryVariant:
//         retryLabel != null ? ButtonVariant.primary : ButtonVariant.outlined,
//         onPrimary: () {
//           Navigator.of(_).pop();
//           if (retryLabel != null) onRetry?.call();
//         },
//         onSecondary:
//         retryLabel != null ? () => Navigator.of(_).pop() : null,
//       ),
//     );
//   }
//
//   // ── Loading dialog (non-dismissible) ─────────────────────────────────────
//
//   static Future<void> loading({
//     required BuildContext context,
//     String message = 'Please wait…',
//   }) {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false,
//       barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.4),
//       builder: (_) => PopScope(
//         canPop: false,
//         child: _LoadingDialog(message: message),
//       ),
//     );
//   }
//
//   /// Close a previously-shown loading dialog.
//   static void closeLoading(BuildContext context) {
//     if (Navigator.of(context).canPop()) {
//       Navigator.of(context).pop();
//     }
//   }
//
//   // ── Custom content dialog ─────────────────────────────────────────────────
//
//   static Future<T?> custom<T>({
//     required BuildContext context,
//     required Widget child,
//     bool barrierDismissible = true,
//     bool useRootNavigator = true,
//   }) {
//     return showDialog<T>(
//       context: context,
//       barrierDismissible: barrierDismissible,
//       useRootNavigator: useRootNavigator,
//       barrierColor: Theme.of(context).colorScheme.scrim.withOpacity(0.5),
//       builder: (_) => Dialog(
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         surfaceTintColor: Colors.transparent,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
//         child: child,
//       ),
//     );
//   }
//
//   // ── Modal bottom sheet ────────────────────────────────────────────────────
//
//   static Future<T?> bottomSheet<T>({
//     required BuildContext context,
//     required Widget child,
//     String? title,
//     bool isDismissible = true,
//     bool showDragHandle = true,
//     bool isScrollControlled = true,
//     double? maxHeight,
//   }) {
//     return showModalBottomSheet<T>(
//       context: context,
//       isDismissible: isDismissible,
//       enableDrag: isDismissible,
//       isScrollControlled: isScrollControlled,
//       useRootNavigator: true,
//       backgroundColor: Theme.of(context).colorScheme.surface,
//       surfaceTintColor: Colors.transparent,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (_) => _BottomSheetWrapper(
//         title: title,
//         showDragHandle: showDragHandle,
//         maxHeight: maxHeight,
//         child: child,
//       ),
//     );
//   }
//
//   // ── Snack bar helper (not a dialog, but grouped here for convenience) ─────
//
//   static void showSnack(
//       BuildContext context, {
//         required String message,
//         bool isError = false,
//         bool isSuccess = false,
//         String? actionLabel,
//         VoidCallback? onAction,
//         Duration duration = const Duration(seconds: 3),
//       }) {
//     final cs = Theme.of(context).colorScheme;
//
//     final bg = isError
//         ? AppColors.error
//         : isSuccess
//         ? AppColors.success
//         : AppColors.navyDeep;
//
//     ScaffoldMessenger.of(context)
//       ..hideCurrentSnackBar()
//       ..showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               Icon(
//                 isError
//                     ? Icons.error_outline_rounded
//                     : isSuccess
//                     ? Icons.check_circle_outline_rounded
//                     : Icons.info_outline_rounded,
//                 color: Colors.white,
//                 size: 18,
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   message,
//                   style: const TextStyle(
//                     fontSize: 14,
//                     color: Colors.white,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           backgroundColor: bg,
//           duration: duration,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           margin: const EdgeInsets.all(16),
//           action: actionLabel != null
//               ? SnackBarAction(
//             label: actionLabel,
//             textColor: AppColors.goldOnDark,
//             onPressed: onAction ?? () {},
//           )
//               : null,
//         ),
//       );
//   }
// }
//
// // ─────────────────────────────────────────────
// // Internal: main dialog widget
// // ─────────────────────────────────────────────
//
// class _AppDialog extends StatelessWidget {
//   const _AppDialog({
//     required this.icon,
//     required this.iconColor,
//     required this.iconBackground,
//     required this.title,
//     required this.message,
//     required this.primaryLabel,
//     required this.onPrimary,
//     this.secondaryLabel,
//     this.onSecondary,
//     this.primaryVariant = ButtonVariant.primary,
//   });
//
//   final IconData icon;
//   final Color iconColor;
//   final Color iconBackground;
//   final String title;
//   final String message;
//   final String primaryLabel;
//   final VoidCallback onPrimary;
//   final String? secondaryLabel;
//   final VoidCallback? onSecondary;
//   final ButtonVariant primaryVariant;
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Dialog(
//       backgroundColor: cs.surface,
//       surfaceTintColor: Colors.transparent,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
//       elevation: 8,
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Icon
//             Container(
//               width: 64,
//               height: 64,
//               decoration: BoxDecoration(
//                 color: iconBackground,
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(icon, color: iconColor, size: 30),
//             ),
//             const SizedBox(height: 20),
//
//             // Title
//             Text(
//               title,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontFamily: 'Playfair Display',
//                 fontSize: 20,
//                 fontWeight: FontWeight.w700,
//                 color: cs.onSurface,
//                 height: 1.3,
//               ),
//             ),
//             const SizedBox(height: 10),
//
//             // Message
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w400,
//                 color: cs.onSurfaceVariant,
//                 height: 1.55,
//               ),
//             ),
//             const SizedBox(height: 28),
//
//             // Buttons
//             if (secondaryLabel != null) ...[
//               CustomButton(
//                 label: primaryLabel,
//                 onPressed: onPrimary,
//                 variant: primaryVariant,
//                 size: ButtonSize.md,
//               ),
//               const SizedBox(height: 10),
//               CustomButton(
//                 label: secondaryLabel!,
//                 onPressed: onSecondary,
//                 variant: ButtonVariant.ghost,
//                 size: ButtonSize.md,
//               ),
//             ] else
//               CustomButton(
//                 label: primaryLabel,
//                 onPressed: onPrimary,
//                 variant: primaryVariant,
//                 size: ButtonSize.md,
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // Internal: loading dialog
// // ─────────────────────────────────────────────
//
// class _LoadingDialog extends StatelessWidget {
//   const _LoadingDialog({required this.message});
//   final String message;
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Dialog(
//       backgroundColor: cs.surface,
//       surfaceTintColor: Colors.transparent,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//       insetPadding: const EdgeInsets.symmetric(horizontal: 80),
//       elevation: 8,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             SizedBox(
//               width: 44,
//               height: 44,
//               child: CircularProgressIndicator(
//                 strokeWidth: 3,
//                 valueColor: AlwaysStoppedAnimation<Color>(
//                     AppColors.goldPrimary),
//                 strokeCap: StrokeCap.round,
//               ),
//             ),
//             const SizedBox(height: 20),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 color: cs.onSurface,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // Internal: bottom sheet wrapper
// // ─────────────────────────────────────────────
//
// class _BottomSheetWrapper extends StatelessWidget {
//   const _BottomSheetWrapper({
//     required this.child,
//     this.title,
//     this.showDragHandle = true,
//     this.maxHeight,
//   });
//
//   final Widget child;
//   final String? title;
//   final bool showDragHandle;
//   final double? maxHeight;
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final mq = MediaQuery.of(context);
//
//     return Container(
//       constraints: BoxConstraints(
//         maxHeight: maxHeight ?? mq.size.height * 0.92,
//       ),
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           // Drag handle
//           if (showDragHandle)
//             Center(
//               child: Container(
//                 margin: const EdgeInsets.only(top: 12, bottom: 4),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: cs.outlineVariant,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//             ),
//
//           // Optional title
//           if (title != null)
//             Padding(
//               padding:
//               const EdgeInsets.fromLTRB(20, 12, 20, 0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     title!,
//                     style: TextStyle(
//                       fontFamily: 'Playfair Display',
//                       fontSize: 18,
//                       fontWeight: FontWeight.w700,
//                       color: cs.onSurface,
//                     ),
//                   ),
//                   IconButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     icon: Icon(
//                       Icons.close_rounded,
//                       size: 20,
//                       color: cs.onSurfaceVariant,
//                     ),
//                     style: IconButton.styleFrom(
//                       backgroundColor: cs.surfaceContainerHighest,
//                       shape: const CircleBorder(),
//                       padding: const EdgeInsets.all(6),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//           if (title != null)
//             Divider(
//               color: cs.outlineVariant,
//               height: 16,
//               thickness: 1,
//               indent: 20,
//               endIndent: 20,
//             ),
//
//           // Content
//           Flexible(
//             child: Padding(
//               padding: EdgeInsets.only(
//                 bottom: mq.viewInsets.bottom,
//               ),
//               child: child,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // Exported: composable dialog content for custom()
// // ─────────────────────────────────────────────
//
// /// Use inside CustomDialog.custom() to render structured content
// /// without building from scratch.
// class DialogContent extends StatelessWidget {
//   const DialogContent({
//     super.key,
//     this.title,
//     this.subtitle,
//     required this.body,
//     this.actions,
//     this.padding,
//   });
//
//   final String? title;
//   final String? subtitle;
//   final Widget body;
//   final List<Widget>? actions;
//   final EdgeInsets? padding;
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Padding(
//       padding: padding ?? const EdgeInsets.all(24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (title != null)
//             Text(
//               title!,
//               style: TextStyle(
//                 fontFamily: 'Playfair Display',
//                 fontSize: 20,
//                 fontWeight: FontWeight.w700,
//                 color: cs.onSurface,
//               ),
//             ),
//           if (subtitle != null) ...[
//             const SizedBox(height: 6),
//             Text(
//               subtitle!,
//               style: TextStyle(
//                 fontSize: 13,
//                 color: cs.onSurfaceVariant,
//               ),
//             ),
//           ],
//           if (title != null || subtitle != null)
//             Divider(
//               color: cs.outlineVariant,
//               height: 24,
//               thickness: 1,
//             ),
//           body,
//           if (actions != null && actions!.isNotEmpty) ...[
//             const SizedBox(height: 20),
//             ...actions!,
//           ],
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = "OK",
    String cancelText = "Cancel",
    bool showCancel = false,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            if (showCancel)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onCancel?.call();
                },
                child: Text(cancelText),
              ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }
}