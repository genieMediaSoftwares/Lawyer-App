import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class AISmartCaseAssistantCard extends StatefulWidget {
  const AISmartCaseAssistantCard({super.key});

  @override
  State<AISmartCaseAssistantCard> createState() => _AISmartCaseAssistantCardState();
}

class _AISmartCaseAssistantCardState extends State<AISmartCaseAssistantCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.aiSurfaceBackgroundAlt, // GenieLaw Deep Black
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.3 + 0.3 * _glowAnimation.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.aiAccentViolet.withValues(alpha: 0.12 * _glowAnimation.value), // Purple AI glow
                blurRadius: 14,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: AppColors.primaryGold.withValues(alpha: 0.08 * _glowAnimation.value), // Gold glow accent
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row: AI Powered Badge + Title + Modern AI Illustration Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // AI Illustration Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.aiAccentViolet, AppColors.aiAccentAmber],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.aiAccentViolet.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primaryText,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.primaryGold.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.bolt, color: AppColors.primaryGold, size: 11),
                                SizedBox(width: 3),
                                Text(
                                  "AI POWERED",
                                  style: TextStyle(
                                    color: AppColors.primaryGold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        "AI Smart Case Assistant",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        "Don't know how to post your legal case?",
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            const Text(
              "Upload your documents — add a voice note for extra detail if you like — and AI fills in your case for you, ready to find a lawyer.",
              style: TextStyle(
                color: AppColors.mutedText,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // Action Button: Upload Documents
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/ai-smart-case'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.onGold,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  shadowColor: AppColors.primaryGold.withValues(alpha: 0.3),
                ),
                icon: const Icon(Icons.document_scanner, size: 17, color: AppColors.onGold),
                label: const Text(
                  "Upload Documents & Create Case",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
