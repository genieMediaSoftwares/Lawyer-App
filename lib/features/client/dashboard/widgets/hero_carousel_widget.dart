import 'dart:async';
import 'package:flutter/material.dart';

class HeroCarouselWidget extends StatefulWidget {
  final List<String> assetPaths;
  final double height;

  const HeroCarouselWidget({
    super.key,
    required this.assetPaths,
    this.height = 180,
  });

  @override
  State<HeroCarouselWidget> createState() => _HeroCarouselWidgetState();
}

class _HeroCarouselWidgetState extends State<HeroCarouselWidget> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _timer;
  static const int _virtualItemCount = 10000;

  @override
  void initState() {
    super.initState();
    final initialPage = (_virtualItemCount ~/ 2) - ((_virtualItemCount ~/ 2) % widget.assetPaths.length);
    _pageController = PageController(initialPage: initialPage);
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _stopAutoSlide();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoSlide() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAutoSlide();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assetPaths.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.primary;

    return Column(
      children: [
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (virtualIndex) {
                setState(() {
                  _currentIndex = virtualIndex % widget.assetPaths.length;
                });
                _startAutoSlide();
              },
              itemBuilder: (context, virtualIndex) {
                final index = virtualIndex % widget.assetPaths.length;
                final assetPath = widget.assetPaths[index];
                return Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: widget.height,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.assetPaths.length, (index) {
            final isActive = _currentIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: isActive ? 20 : 8,
              decoration: BoxDecoration(
                color: isActive ? goldColor : Colors.grey.shade600,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}
