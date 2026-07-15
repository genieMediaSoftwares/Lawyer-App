import 'package:flutter/material.dart';

class AppCircleAvatar extends StatelessWidget {
  final double radius;
  final String? imageUrl;
  final Widget? fallback;
  final Color? backgroundColor;

  const AppCircleAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    this.fallback,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = radius * 2;

    Widget fallbackWidget = fallback ??
        Icon(
          Icons.person,
          color: theme.colorScheme.primary,
          size: radius,
        );

    final bg = backgroundColor ?? theme.colorScheme.outline.withOpacity(0.2);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: radius * 0.8,
                      height: radius * 0.8,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return fallbackWidget;
                },
              )
            : fallbackWidget,
      ),
    );
  }
}
