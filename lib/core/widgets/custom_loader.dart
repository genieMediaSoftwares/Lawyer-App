// import 'package:flutter/material.dart';
// import '../constants/app_colors.dart';
//
// // ─────────────────────────────────────────────────────────────────────────────
// // CustomLoader
// //
// // Loader and skeleton variants for the Genie Law App.
// //
// // Widgets:
// //   CustomLoader            — circular progress (inline or fullscreen overlay)
// //   ShimmerBox              — single animated shimmer placeholder
// //   ShimmerCard             — lawyer card skeleton
// //   ShimmerList             — list of shimmer rows
// //   ShimmerAvatar           — circular avatar placeholder
// //   OverlayLoader           — semi-transparent fullscreen blocker
// //   LoaderWrapper           — wraps a child; shows loader when [isLoading]
// // ─────────────────────────────────────────────────────────────────────────────
//
// // ─────────────────────────────────────────────
// // 1. CustomLoader — circular spinner
// // ─────────────────────────────────────────────
//
// enum LoaderVariant { inline, fullscreen }
//
// class CustomLoader extends StatelessWidget {
//   const CustomLoader({
//     super.key,
//     this.variant = LoaderVariant.inline,
//     this.size = 28,
//     this.strokeWidth = 2.5,
//     this.color,
//     this.message,
//   });
//
//   final LoaderVariant variant;
//   final double size;
//   final double strokeWidth;
//   final Color? color;
//   final String? message;
//
//   @override
//   Widget build(BuildContext context) {
//     final loaderColor =
//         color ?? Theme.of(context).colorScheme.primary;
//
//     final spinner = SizedBox(
//       width: size,
//       height: size,
//       child: CircularProgressIndicator(
//         strokeWidth: strokeWidth,
//         valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
//         strokeCap: StrokeCap.round,
//       ),
//     );
//
//     if (variant == LoaderVariant.inline) {
//       if (message == null) return Center(child: spinner);
//       return Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             spinner,
//             const SizedBox(height: 16),
//             Text(
//               message!,
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                 color: Theme.of(context)
//                     .colorScheme
//                     .onSurfaceVariant,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     // Fullscreen
//     return Scaffold(
//       backgroundColor: Theme.of(context).colorScheme.background,
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             _GenieLawLogo(),
//             const SizedBox(height: 32),
//             SizedBox(
//               width: size,
//               height: size,
//               child: CircularProgressIndicator(
//                 strokeWidth: strokeWidth,
//                 valueColor: AlwaysStoppedAnimation<Color>(
//                     AppColors.goldPrimary),
//                 strokeCap: StrokeCap.round,
//               ),
//             ),
//             if (message != null) ...[
//               const SizedBox(height: 20),
//               Text(
//                 message!,
//                 style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                   color: Theme.of(context)
//                       .colorScheme
//                       .onSurfaceVariant,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 2. OverlayLoader — semi-transparent blocker
// // ─────────────────────────────────────────────
//
// class OverlayLoader extends StatelessWidget {
//   const OverlayLoader({
//     super.key,
//     this.isLoading = true,
//     required this.child,
//     this.message,
//     this.barrierColor,
//   });
//
//   final bool isLoading;
//   final Widget child;
//   final String? message;
//   final Color? barrierColor;
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         child,
//         if (isLoading)
//           Positioned.fill(
//             child: AnimatedOpacity(
//               opacity: isLoading ? 1 : 0,
//               duration: const Duration(milliseconds: 200),
//               child: ColoredBox(
//                 color: barrierColor ??
//                     Theme.of(context).colorScheme.scrim.withOpacity(0.5),
//                 child: Center(
//                   child: _LoaderCard(message: message),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }
//
// class _LoaderCard extends StatelessWidget {
//   const _LoaderCard({this.message});
//   final String? message;
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.15),
//             blurRadius: 24,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           SizedBox(
//             width: 36,
//             height: 36,
//             child: CircularProgressIndicator(
//               strokeWidth: 3,
//               valueColor: AlwaysStoppedAnimation<Color>(
//                   AppColors.goldPrimary),
//               strokeCap: StrokeCap.round,
//             ),
//           ),
//           if (message != null) ...[
//             const SizedBox(height: 16),
//             Text(
//               message!,
//               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
//                 color: cs.onSurface,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 3. LoaderWrapper — show/hide content
// // ─────────────────────────────────────────────
//
// class LoaderWrapper extends StatelessWidget {
//   const LoaderWrapper({
//     super.key,
//     required this.isLoading,
//     required this.child,
//     this.loader,
//   });
//
//   final bool isLoading;
//   final Widget child;
//   final Widget? loader;
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 250),
//       switchInCurve: Curves.easeInOut,
//       switchOutCurve: Curves.easeInOut,
//       child: isLoading
//           ? KeyedSubtree(
//         key: const ValueKey('loader'),
//         child: loader ??
//             const Center(
//               child: CustomLoader(),
//             ),
//       )
//           : KeyedSubtree(
//         key: const ValueKey('content'),
//         child: child,
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 4. Shimmer infrastructure
// // ─────────────────────────────────────────────
//
// class _ShimmerGradient extends StatefulWidget {
//   const _ShimmerGradient({required this.child});
//   final Widget child;
//
//   @override
//   State<_ShimmerGradient> createState() => _ShimmerGradientState();
// }
//
// class _ShimmerGradientState extends State<_ShimmerGradient>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat();
//     _animation = Tween<double>(begin: -2, end: 2).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final base =
//     isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
//     final highlight = isDark
//         ? AppColors.shimmerHighlightDark
//         : AppColors.shimmerHighlight;
//
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return ShaderMask(
//           blendMode: BlendMode.srcATop,
//           shaderCallback: (bounds) => LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.centerRight,
//             colors: [base, highlight, base],
//             stops: const [0.0, 0.5, 1.0],
//             transform: _SlidingGradientTransform(_animation.value),
//           ).createShader(bounds),
//           child: child,
//         );
//       },
//       child: widget.child,
//     );
//   }
// }
//
// class _SlidingGradientTransform extends GradientTransform {
//   const _SlidingGradientTransform(this.slidePercent);
//   final double slidePercent;
//
//   @override
//   Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
//     return Matrix4.translationValues(
//         bounds.width * slidePercent, 0, 0);
//   }
// }
//
// // ─────────────────────────────────────────────
// // 5. ShimmerBox — raw box placeholder
// // ─────────────────────────────────────────────
//
// class ShimmerBox extends StatelessWidget {
//   const ShimmerBox({
//     super.key,
//     required this.width,
//     required this.height,
//     this.borderRadius = 8,
//   });
//
//   final double width;
//   final double height;
//   final double borderRadius;
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final base =
//     isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
//
//     return _ShimmerGradient(
//       child: Container(
//         width: width,
//         height: height,
//         decoration: BoxDecoration(
//           color: base,
//           borderRadius: BorderRadius.circular(borderRadius),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 6. ShimmerAvatar
// // ─────────────────────────────────────────────
//
// class ShimmerAvatar extends StatelessWidget {
//   const ShimmerAvatar({super.key, this.radius = 24});
//   final double radius;
//
//   @override
//   Widget build(BuildContext context) {
//     return ShimmerBox(
//       width: radius * 2,
//       height: radius * 2,
//       borderRadius: radius,
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 7. ShimmerCard — lawyer profile card skeleton
// // ─────────────────────────────────────────────
//
// class ShimmerCard extends StatelessWidget {
//   const ShimmerCard({super.key, this.showAvatar = true});
//   final bool showAvatar;
//
//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: cs.surface,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: cs.outlineVariant, width: 1),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               if (showAvatar) ...[
//                 const ShimmerAvatar(radius: 28),
//                 const SizedBox(width: 12),
//               ],
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     ShimmerBox(
//                         width: double.infinity, height: 14, borderRadius: 6),
//                     const SizedBox(height: 8),
//                     ShimmerBox(width: 120, height: 11, borderRadius: 6),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           ShimmerBox(
//               width: double.infinity, height: 11, borderRadius: 6),
//           const SizedBox(height: 6),
//           ShimmerBox(width: 200, height: 11, borderRadius: 6),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               ShimmerBox(width: 60, height: 28, borderRadius: 20),
//               const SizedBox(width: 8),
//               ShimmerBox(width: 60, height: 28, borderRadius: 20),
//               const SizedBox(width: 8),
//               ShimmerBox(width: 60, height: 28, borderRadius: 20),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 8. ShimmerList — repeated row placeholders
// // ─────────────────────────────────────────────
//
// class ShimmerList extends StatelessWidget {
//   const ShimmerList({
//     super.key,
//     this.itemCount = 5,
//     this.showAvatar = true,
//     this.itemHeight = 72,
//   });
//
//   final int itemCount;
//   final bool showAvatar;
//   final double itemHeight;
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: List.generate(itemCount, (i) {
//         return Padding(
//           padding: const EdgeInsets.only(bottom: 12),
//           child: _ShimmerListRow(
//             showAvatar: showAvatar,
//             height: itemHeight,
//           ),
//         );
//       }),
//     );
//   }
// }
//
// class _ShimmerListRow extends StatelessWidget {
//   const _ShimmerListRow({
//     required this.showAvatar,
//     required this.height,
//   });
//
//   final bool showAvatar;
//   final double height;
//
//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       height: height,
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           if (showAvatar) ...[
//             const ShimmerAvatar(radius: 22),
//             const SizedBox(width: 12),
//           ],
//           Expanded(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 ShimmerBox(
//                     width: double.infinity, height: 13, borderRadius: 6),
//                 const SizedBox(height: 8),
//                 ShimmerBox(width: 160, height: 11, borderRadius: 6),
//                 const SizedBox(height: 6),
//                 ShimmerBox(width: 100, height: 10, borderRadius: 6),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),
//           ShimmerBox(width: 56, height: 32, borderRadius: 8),
//         ],
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────
// // 9. Internal: Genie Law logo mark for fullscreen
// // ─────────────────────────────────────────────
//
// class _GenieLawLogo extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     return Column(
//       children: [
//         Container(
//           width: 64,
//           height: 64,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: AppColors.navyGradient,
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.circular(18),
//             boxShadow: [
//               BoxShadow(
//                 color: AppColors.navyPrimary.withOpacity(0.4),
//                 blurRadius: 20,
//                 offset: const Offset(0, 8),
//               ),
//             ],
//           ),
//           child: const Icon(
//             Icons.balance_rounded,
//             color: AppColors.goldPrimary,
//             size: 32,
//           ),
//         ),
//         const SizedBox(height: 16),
//         Text(
//           'Genie Law',
//           style: TextStyle(
//             fontFamily: 'Playfair Display',
//             fontSize: 22,
//             fontWeight: FontWeight.w700,
//             color: isDark
//                 ? AppColors.goldOnDark
//                 : AppColors.navyPrimary,
//             letterSpacing: 0.5,
//           ),
//         ),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';

class CustomLoader extends StatelessWidget {
  final double size;
  final String? message;

  const CustomLoader({
    super.key,
    this.size = 40,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ]
        ],
      ),
    );
  }
}