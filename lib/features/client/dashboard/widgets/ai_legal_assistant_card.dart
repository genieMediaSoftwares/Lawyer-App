import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../routes/route_names.dart';

const String robotBodySvg = '''
<svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="headGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" />
      <stop offset="100%" stop-color="#E2E8F0" />
    </linearGradient>
    <linearGradient id="visorGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#1E293B" />
      <stop offset="100%" stop-color="#0F172A" />
    </linearGradient>
    <linearGradient id="blueGlow" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8" />
      <stop offset="100%" stop-color="#0284C7" />
    </linearGradient>
  </defs>

  <!-- Antenna -->
  <line x1="50" y1="28" x2="50" y2="12" stroke="#64748B" stroke-width="2" />
  <circle cx="50" cy="10" r="3.5" fill="url(#blueGlow)" />

  <!-- Ear headphones -->
  <rect x="10" y="46" width="6" height="18" rx="3" fill="#94A3B8" />
  <rect x="84" y="46" width="6" height="18" rx="3" fill="#94A3B8" />
  <circle cx="13" cy="55" r="6" fill="url(#headGrad)" stroke="#94A3B8" stroke-width="0.8"/>
  <circle cx="87" cy="55" r="6" fill="url(#headGrad)" stroke="#94A3B8" stroke-width="0.8"/>

  <!-- Head -->
  <rect x="17" y="26" width="66" height="54" rx="27" fill="url(#headGrad)" stroke="#CBD5E1" stroke-width="1" />

  <!-- Visor -->
  <rect x="27" y="36" width="46" height="32" rx="14" fill="url(#visorGrad)" stroke="#334155" stroke-width="0.8" />

  <!-- Glowing Blue Eyes -->
  <rect x="35" y="45" width="8" height="12" rx="4" fill="#00D2FF" />
  <rect x="57" y="45" width="8" height="12" rx="4" fill="#00D2FF" />
  
  <!-- Smile -->
  <path d="M46,62 Q50,65 54,62" stroke="#00D2FF" stroke-width="1.8" fill="none" stroke-linecap="round" />

  <!-- Neck & Shoulders -->
  <path d="M34,80 C34,80 38,88 50,88 C62,88 66,80 66,80 Z" fill="url(#headGrad)" stroke="#CBD5E1" stroke-width="0.8" />
  <circle cx="50" cy="83" r="3" fill="#E2E8F0" stroke="#94A3B8" stroke-width="0.8" />
</svg>
''';

const String robotArmSvg = ''; // Unused in this layout

const String scaleSvg = '''
<svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="blueScale" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38BDF8" />
      <stop offset="100%" stop-color="#1D4ED8" />
    </linearGradient>
  </defs>
  
  <g transform="translate(20, 18.4) scale(0.93)">
    <!-- Base -->
    <path d="M14 54H50V51H14V54Z" fill="url(#blueScale)" />
    <path d="M20 51H44V48H20V51Z" fill="url(#blueScale)" />
    <!-- Pillar -->
    <path d="M30 48H34V18H30V48Z" fill="url(#blueScale)" />
    <circle cx="32" cy="15" r="4" fill="url(#blueScale)" />
    <!-- Beam -->
    <path d="M8 23C8 23 20 18 32 18C44 18 56 23 56 23" stroke="url(#blueScale)" stroke-width="3" stroke-linecap="round" />
    <!-- Left Pan -->
    <path d="M8 23L3 38" stroke="url(#blueScale)" stroke-width="2" />
    <path d="M8 23L13 38" stroke="url(#blueScale)" stroke-width="2" />
    <path d="M0 38H16C16 44 0 44 0 38Z" fill="url(#blueScale)" />
    <!-- Right Pan -->
    <path d="M56 23L51 38" stroke="url(#blueScale)" stroke-width="2" />
    <path d="M56 23L61 38" stroke="url(#blueScale)" stroke-width="2" />
    <path d="M48 38H64C64 44 48 44 48 38Z" fill="url(#blueScale)" />
  </g>
</svg>
''';

class AILegalAssistantCard extends StatelessWidget {
  const AILegalAssistantCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isSmall = width < 460;
        final bool isExtraSmall = width < 360;

        final double cardHeight = isSmall ? 150 : 128;
        final double padding = isExtraSmall ? 12 : 20;
        final double spacing = isExtraSmall ? 8 : 16;

        return Container(
          width: double.infinity,
          height: cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF060713), // Deep midnight blue/black background
            borderRadius: BorderRadius.circular(24), // Rounded corners (24px)
            border: Border.all(
              color: const Color(0xFF1E3A8A).withOpacity(0.4), // Thin blue border
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Constellation Network background on the left side
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const CustomPaint(
                    painter: _ConstellationPainter(),
                  ),
                ),
              ),

              // Horizontal Row content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Left Section: Robot Head inside Circle
                    Container(
                      width: isExtraSmall ? 64 : 76,
                      height: isExtraSmall ? 64 : 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF030712).withOpacity(0.6),
                        border: Border.all(
                          color: const Color(0xFF1D4ED8).withOpacity(0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.08),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const _FloatingRobotHead(),
                    ),
                    SizedBox(width: spacing),

                    // 2. Center Section: Badge, Title, and Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildAIPoweredBadge(isExtraSmall),
                          const SizedBox(height: 6),
                          Text(
                            "AI Legal Assistant",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isExtraSmall ? 15 : (isSmall ? 17 : 19),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Get instant answers to your legal questions.\nYour personal legal companion.",
                            style: TextStyle(
                              color: const Color(0xFF94A3B8), // Muted grey-blue text
                              fontSize: isExtraSmall ? 10 : (isSmall ? 11 : 12),
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: spacing),

                    // 3. Right Section: Row of [Button, Scale] on desktop/tablet, Column on mobile
                    isSmall
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const _GlowingScaleWidget(size: 38),
                              const SizedBox(height: 8),
                              PremiumButton(
                                onPressed: () => context.push(RouteNames.aiChat),
                                isSmall: true,
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PremiumButton(
                                onPressed: () => context.push(RouteNames.aiChat),
                                isSmall: false,
                              ),
                              const SizedBox(width: 14),
                              const _GlowingScaleWidget(size: 46),
                            ],
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAIPoweredBadge(bool isExtraSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.12), // Green transparency
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF22C55E).withOpacity(0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt,
            color: const Color(0xFF4ADE80), // Vibrant green
            size: isExtraSmall ? 10 : 12,
          ),
          const SizedBox(width: 3),
          Text(
            "AI Powered",
            style: TextStyle(
              color: const Color(0xFF4ADE80),
              fontSize: isExtraSmall ? 9 : 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  const _ConstellationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.08)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.16)
      ..style = PaintingStyle.fill;

    // Coordinates mapping for constellation points on the left half
    final points = [
      Offset(size.width * 0.05, size.height * 0.2),
      Offset(size.width * 0.12, size.height * 0.5),
      Offset(size.width * 0.04, size.height * 0.85),
      Offset(size.width * 0.22, size.height * 0.15),
      Offset(size.width * 0.18, size.height * 0.65),
      Offset(size.width * 0.25, size.height * 0.85),
      Offset(size.width * 0.29, size.height * 0.4),
    ];

    final connections = [
      [0, 1], [0, 3], [1, 2], [1, 4], [3, 4], [4, 5], [4, 6], [3, 6]
    ];

    for (final conn in connections) {
      if (conn[0] < points.length && conn[1] < points.length) {
        canvas.drawLine(points[conn[0]], points[conn[1]], paintLine);
      }
    }

    for (final pt in points) {
      canvas.drawCircle(pt, 2.5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingRobotHead extends StatefulWidget {
  const _FloatingRobotHead();

  @override
  State<_FloatingRobotHead> createState() => _FloatingRobotHeadState();
}

class _FloatingRobotHeadState extends State<_FloatingRobotHead>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: -4.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: SvgPicture.string(
        robotBodySvg,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _GlowingScaleWidget extends StatefulWidget {
  final double size;

  const _GlowingScaleWidget({required this.size});

  @override
  State<_GlowingScaleWidget> createState() => _GlowingScaleWidgetState();
}

class _GlowingScaleWidgetState extends State<_GlowingScaleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF030712).withOpacity(0.5),
            border: Border.all(
              color: const Color(0xFF1D4ED8).withOpacity(0.2 + 0.3 * _animation.value),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.06 * _animation.value),
                blurRadius: 10,
                spreadRadius: 3 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: SvgPicture.string(
          scaleSvg,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class PremiumButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isSmall;

  const PremiumButton({
    super.key,
    required this.onPressed,
    this.isSmall = false,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double scale = 1.0;
    if (_isPressed) {
      scale = 0.96;
    } else if (_isHovered) {
      scale = 1.04;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            height: widget.isSmall ? 28 : 34,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0F), // Dark pill-shaped button background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B), // Outlined gold border
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(_isHovered ? 0.25 : 0.12),
                  blurRadius: _isHovered ? 12 : 6,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer highlighting swipe
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: FractionallySizedBox(
                        widthFactor: 2.0,
                        child: Transform.translate(
                          offset: Offset(
                            (-1.5 + _shimmerController.value * 3.0) * 100.0,
                            0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  const Color(0xFFF59E0B).withOpacity(0.18),
                                  Colors.white.withOpacity(0.0),
                                ],
                                stops: const [0.35, 0.5, 0.65],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Ask Now",
                      style: TextStyle(
                        color: const Color(0xFFF59E0B), // Gold text
                        fontWeight: FontWeight.w800,
                        fontSize: widget.isSmall ? 11.5 : 13.0,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: const Color(0xFFF59E0B), // Gold icon
                      size: widget.isSmall ? 14 : 17,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
