// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../constants/app_colors.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // CustomAppBar
// //
// // A fully composable AppBar for the Genie Law App.
// //
// // Variants:
// //   standard   — title + optional back + actions (most screens)
// //   search     — with embedded search field
// //   transparent— overlaid on content (profile hero, onboarding)
// //   large      — large title with subtitle (section headers)
// //   branded    — logo + app name (dashboard home)
// //
// // Implements PreferredSizeWidget — drop in as Scaffold.appBar directly.
// // ─────────────────────────────────────────────────────────────────────────────
//
// enum AppBarVariant { standard, search, transparent, large, branded }
//
// class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
//   const CustomAppBar({
//     super.key,
//     this.title,
//     this.subtitle,
//     this.variant = AppBarVariant.standard,
//     this.actions,
//     this.leading,
//     this.showBack = true,
//     this.onBackPressed,
//     this.centerTitle = false,
//     this.backgroundColor,
//     this.foregroundColor,
//     this.elevation,
//     this.bottom,
//     // Search variant
//     this.searchHint,
//     this.searchController,
//     this.onSearchChanged,
//     this.onSearchSubmitted,
//     // Badge on back button
//     this.notificationCount = 0,
//   });
//
//   final String? title;
//   final String? subtitle;
//   final AppBarVariant variant;
//   final List<Widget>? actions;
//   final Widget? leading;
//   final bool showBack;
//   final VoidCallback? onBackPressed;
//   final bool centerTitle;
//   final Color? backgroundColor;
//   final Color? foregroundColor;
//   final double? elevation;
//   final PreferredSizeWidget? bottom;
//
//   // Search
//   final String? searchHint;
//   final TextEditingController? searchController;
//   final ValueChanged<String>? onSearchChanged;
//   final ValueChanged<String>? onSearchSubmitted;
//
//   // Notification badge
//   final int notificationCount;
//
//   @override
//   Size get preferredSize => Size.fromHeight(
//     switch (variant) {
//       AppBarVariant.large => 96 + (bottom?.preferredSize.height ?? 0),
//       AppBarVariant.search => 64 + (bottom?.preferredSize.height ?? 0),
//       _ => kToolbarHeight + (bottom?.preferredSize.height ?? 0),
//     },
//   );
//
//   @override
//   Widget build(BuildContext context) {
//     return switch (variant) {
//       AppBarVariant.branded => _buildBranded(context),
//       AppBarVariant.transparent => _buildTransparent(context),
//       AppBarVariant.large => _buildLarge(context),
//       AppBarVariant.search => _buildSearch(context),
//       AppBarVariant.standard => _buildStandard(context),
//     };
//   }
//
//   // ── Standard ─────────────────────────────────────────────────────────────
//
//   Widget _buildStandard(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final bg = backgroundColor ?? cs.surface;
//     final fg = foregroundColor ?? cs.onSurface;
//
//     _applySystemUiOverlay(context, bg);
//
//     return AppBar(
//       backgroundColor: bg,
//       foregroundColor: fg,
//       elevation: elevation ?? 0,
//       scrolledUnderElevation: 1,
//       shadowColor: cs.shadow,
//       surfaceTintColor: Colors.transparent,
//       centerTitle: centerTitle,
//       automaticallyImplyLeading: false,
//       leading: _buildLeading(context, fg),
//       title: title != null ? _buildTitle(context, fg) : null,
//       actions: _buildActions(context, fg),
//       bottom: bottom,
//       titleSpacing: showBack || leading != null ? 0 : 16,
//     );
//   }
//
//   // ── Branded (Dashboard home) ──────────────────────────────────────────────
//
//   Widget _buildBranded(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bg = backgroundColor ?? cs.surface;
//
//     _applySystemUiOverlay(context, bg);
//
//     return AppBar(
//       backgroundColor: bg,
//       elevation: elevation ?? 0,
//       scrolledUnderElevation: 1,
//       shadowColor: cs.shadow,
//       surfaceTintColor: Colors.transparent,
//       automaticallyImplyLeading: false,
//       titleSpacing: 16,
//       title: Row(
//         children: [
//           _AppLogoMark(size: 36),
//           const SizedBox(width: 10),
//           Text(
//             'Genie Law',
//             style: TextStyle(
//               fontFamily: 'Playfair Display',
//               fontSize: 20,
//               fontWeight: FontWeight.w700,
//               color: isDark ? AppColors.goldOnDark : AppColors.navyPrimary,
//               letterSpacing: 0.3,
//             ),
//           ),
//         ],
//       ),
//       actions: _buildActions(context, cs.onSurface),
//       bottom: bottom,
//     );
//   }
//
//   // ── Transparent (overlaid on hero image) ─────────────────────────────────
//
//   Widget _buildTransparent(BuildContext context) {
//     final fg = foregroundColor ?? Colors.white;
//
//     SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
//       statusBarColor: Colors.transparent,
//     ));
//
//     return AppBar(
//       backgroundColor: Colors.transparent,
//       foregroundColor: fg,
//       elevation: 0,
//       scrolledUnderElevation: 0,
//       surfaceTintColor: Colors.transparent,
//       automaticallyImplyLeading: false,
//       leading: _buildLeading(context, fg, forceCircle: true),
//       title: title != null
//           ? Text(
//         title!,
//         style: TextStyle(
//           fontFamily: 'Playfair Display',
//           fontSize: 18,
//           fontWeight: FontWeight.w600,
//           color: fg,
//         ),
//       )
//           : null,
//       actions: _buildActions(context, fg, forceCircle: true),
//       centerTitle: centerTitle,
//       bottom: bottom,
//     );
//   }
//
//   // ── Large title + subtitle ────────────────────────────────────────────────
//
//   Widget _buildLarge(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final bg = backgroundColor ?? cs.surface;
//     final fg = foregroundColor ?? cs.onSurface;
//
//     _applySystemUiOverlay(context, bg);
//
//     return PreferredSize(
//       preferredSize: preferredSize,
//       child: AppBar(
//         backgroundColor: bg,
//         foregroundColor: fg,
//         elevation: elevation ?? 0,
//         scrolledUnderElevation: 1,
//         shadowColor: cs.shadow,
//         surfaceTintColor: Colors.transparent,
//         automaticallyImplyLeading: false,
//         titleSpacing: showBack ? 0 : 16,
//         leading: _buildLeading(context, fg),
//         actions: _buildActions(context, fg),
//         bottom: bottom,
//         flexibleSpace: SafeArea(
//           child: Align(
//             alignment:
//             showBack ? Alignment.bottomLeft : Alignment.centerLeft,
//             child: Padding(
//               padding: EdgeInsets.fromLTRB(
//                 showBack ? 56 : 16,
//                 0,
//                 16,
//                 subtitle != null ? 12 : 16,
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   if (title != null)
//                     Text(
//                       title!,
//                       style: TextStyle(
//                         fontFamily: 'Playfair Display',
//                         fontSize: 26,
//                         fontWeight: FontWeight.w700,
//                         color: fg,
//                         letterSpacing: 0,
//                         height: 1.2,
//                       ),
//                     ),
//                   if (subtitle != null) ...[
//                     const SizedBox(height: 4),
//                     Text(
//                       subtitle!,
//                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                         color: cs.onSurfaceVariant,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Search bar ────────────────────────────────────────────────────────────
//
//   Widget _buildSearch(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final bg = backgroundColor ?? cs.surface;
//     final fg = foregroundColor ?? cs.onSurface;
//
//     _applySystemUiOverlay(context, bg);
//
//     return AppBar(
//       backgroundColor: bg,
//       foregroundColor: fg,
//       elevation: elevation ?? 0,
//       scrolledUnderElevation: 1,
//       shadowColor: cs.shadow,
//       surfaceTintColor: Colors.transparent,
//       automaticallyImplyLeading: false,
//       titleSpacing: 0,
//       title: Padding(
//         padding: EdgeInsets.only(
//           left: (showBack || leading != null) ? 4 : 16,
//           right: 16,
//         ),
//         child: Row(
//           children: [
//             if (showBack || leading != null)
//               _buildLeading(context, fg) ?? const SizedBox.shrink(),
//             Expanded(
//               child: Container(
//                 height: 44,
//                 decoration: BoxDecoration(
//                   color: isDark
//                       ? AppColors.darkSurfaceVariant
//                       : AppColors.lightSurfaceVariant,
//                   borderRadius: BorderRadius.circular(50),
//                   border: Border.all(
//                     color: cs.outline,
//                     width: 1,
//                   ),
//                 ),
//                 child: TextField(
//                   controller: searchController,
//                   onChanged: onSearchChanged,
//                   onSubmitted: onSearchSubmitted,
//                   autofocus: false,
//                   textInputAction: TextInputAction.search,
//                   style: TextStyle(fontSize: 14, color: cs.onSurface),
//                   decoration: InputDecoration(
//                     hintText: searchHint ?? 'Search lawyers…',
//                     hintStyle: TextStyle(
//                       fontSize: 14,
//                       color: cs.onSurfaceVariant.withOpacity(0.6),
//                     ),
//                     prefixIcon: Icon(
//                       Icons.search_rounded,
//                       size: 18,
//                       color: cs.onSurfaceVariant,
//                     ),
//                     suffixIcon: searchController?.text.isNotEmpty == true
//                         ? GestureDetector(
//                       onTap: () {
//                         searchController?.clear();
//                         onSearchChanged?.call('');
//                       },
//                       child: Icon(Icons.close_rounded,
//                           size: 16, color: cs.onSurfaceVariant),
//                     )
//                         : null,
//                     border: InputBorder.none,
//                     enabledBorder: InputBorder.none,
//                     focusedBorder: InputBorder.none,
//                     contentPadding:
//                     const EdgeInsets.symmetric(vertical: 12),
//                     isDense: true,
//                   ),
//                 ),
//               ),
//             ),
//             if (actions != null) ...[
//               const SizedBox(width: 8),
//               ...actions!,
//             ],
//           ],
//         ),
//       ),
//       bottom: bottom,
//     );
//   }
//
//   // ── Helpers ───────────────────────────────────────────────────────────────
//
//   Widget? _buildLeading(BuildContext context, Color fg,
//       {bool forceCircle = false}) {
//     if (leading != null) return leading;
//     if (!showBack) return null;
//
//     final canPop = Navigator.of(context).canPop();
//     if (!canPop) return null;
//
//     final icon = IconButton(
//       onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
//       icon: const Icon(Icons.arrow_back_ios_new_rounded),
//       iconSize: 20,
//       color: forceCircle ? Colors.white : fg,
//       style: forceCircle
//           ? IconButton.styleFrom(
//         backgroundColor: Colors.black.withOpacity(0.25),
//         shape: const CircleBorder(),
//         padding: const EdgeInsets.all(8),
//       )
//           : null,
//     );
//
//     return icon;
//   }
//
//   List<Widget>? _buildActions(BuildContext context, Color fg,
//       {bool forceCircle = false}) {
//     if (actions == null && notificationCount == 0) return null;
//
//     final items = <Widget>[];
//
//     if (actions != null) {
//       if (forceCircle) {
//         for (final action in actions!) {
//           items.add(
//             Container(
//               margin: const EdgeInsets.only(right: 4),
//               decoration: BoxDecoration(
//                 color: Colors.black.withOpacity(0.25),
//                 shape: BoxShape.circle,
//               ),
//               child: action,
//             ),
//           );
//         }
//       } else {
//         items.addAll(actions!);
//       }
//     }
//
//     items.add(const SizedBox(width: 4));
//     return items;
//   }
//
//   Widget _buildTitle(BuildContext context, Color fg) {
//     final cs = Theme.of(context).colorScheme;
//     return Column(
//       crossAxisAlignment:
//       centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Text(
//           title!,
//           style: TextStyle(
//             fontFamily: 'Playfair Display',
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: fg,
//             letterSpacing: 0,
//           ),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//         if (subtitle != null)
//           Text(
//             subtitle!,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w400,
//               color: cs.onSurfaceVariant,
//               letterSpacing: 0.2,
//             ),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//           ),
//       ],
//     );
//   }
//
//   void _applySystemUiOverlay(BuildContext context, Color bg) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     SystemChrome.setSystemUIOverlayStyle(
//       isDark
//           ? SystemUiOverlayStyle.light
//           .copyWith(statusBarColor: Colors.transparent)
//           : SystemUiOverlayStyle.dark
//           .copyWith(statusBarColor: Colors.transparent),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // Notification icon with badge — use in actions
// // ─────────────────────────────────────────────
//
// class NotificationIconButton extends StatelessWidget {
//   const NotificationIconButton({
//     super.key,
//     required this.onPressed,
//     this.count = 0,
//     this.color,
//   });
//
//   final VoidCallback onPressed;
//   final int count;
//   final Color? color;
//
//   @override
//   Widget build(BuildContext context) {
//     final fg = color ?? Theme.of(context).colorScheme.onSurface;
//
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         IconButton(
//           onPressed: onPressed,
//           icon: Icon(Icons.notifications_outlined, color: fg),
//           iconSize: 24,
//         ),
//         if (count > 0)
//           Positioned(
//             top: 8,
//             right: 8,
//             child: Container(
//               width: count > 9 ? 18 : 16,
//               height: 16,
//               decoration: const BoxDecoration(
//                 color: AppColors.error,
//                 shape: BoxShape.circle,
//               ),
//               alignment: Alignment.center,
//               child: Text(
//                 count > 99 ? '99+' : count.toString(),
//                 style: const TextStyle(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w800,
//                   color: Colors.white,
//                   height: 1,
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // App logo mark — small icon used in branded bar
// // ─────────────────────────────────────────────
//
// class _AppLogoMark extends StatelessWidget {
//   const _AppLogoMark({this.size = 36});
//   final double size;
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: size,
//       height: size,
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: AppColors.navyGradient,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(size * 0.28),
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.navyPrimary.withOpacity(0.35),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Icon(
//         Icons.balance_rounded,
//         color: AppColors.goldPrimary,
//         size: size * 0.55,
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool centerTitle;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.actions,
    this.leading,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(bottom == null ? kToolbarHeight : 100);
}