import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../routes/route_names.dart';
import 'package:law/models/category_item.dart';
import '../widgets/category_card.dart';
import '../widgets/hero_carousel_widget.dart';
import '../widgets/ai_legal_assistant_card.dart';

final unreadNotificationsCountProvider = StateProvider<int>((ref) => 1); // Mock 1 notification matching Figma red dot

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleLarge?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: primaryTextColor, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Genie",
                style: TextStyle(
                  color: primaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'Outfit',
                ),
              ),
              TextSpan(
                text: "Law",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () => context.push(RouteNames.notifications),
                icon: Icon(Icons.notifications_none_outlined, color: primaryTextColor, size: 26),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Image Carousel
              const HeroCarouselWidget(
                assetPaths: [
                  "assets/images/banner1.png",
                  "assets/images/banner2.png",
                  "assets/images/banner3.png",
                ],
              ),
              const SizedBox(height: 24),

              // 2. Categories Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Categories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: primaryTextColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/all-categories'),
                    child: Text(
                      "View All",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 8 Category Grid Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 10,
                  childAspectRatio: MediaQuery.of(context).size.width < 360 ? 0.63 : 0.76,
                ),
                itemBuilder: (context, index) {
                  final category = allCategories[index];
                  return CategoryCard(
                    title: category.title,
                    icon: category.icon,
                    onTap: () {
                      context.push('${RouteNames.postCase}?category=${category.title}');
                    },
                  );
                },
              ),
              const SizedBox(height: 28),

              // 3. AI Legal Assistant Banner
              const AILegalAssistantCard(),
              const SizedBox(height: 32),

              // 4. How It Works? Section
              const HowItWorksTimeline(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class HowItWorksTimeline extends StatefulWidget {
  const HowItWorksTimeline({super.key});

  @override
  State<HowItWorksTimeline> createState() => _HowItWorksTimelineState();
}

class _HowItWorksTimelineState extends State<HowItWorksTimeline> {
  int _activeStep = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _activeStep = (_activeStep + 1) % 5;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildDottedLine() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (index) => Container(
        width: 3,
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: const BoxDecoration(
          color: AppColors.primaryGold,
          shape: BoxShape.circle,
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "How It Works?",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepItem(
                  number: 1,
                  title: "Select Issue",
                  description: "Choose your legal issue category.",
                  iconData: Icons.category_outlined,
                  isActive: _activeStep == 0,
                  onTap: () {
                    _timer?.cancel();
                    setState(() => _activeStep = 0);
                    _startTimer();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 26.0),
                  child: _buildDottedLine(),
                ),
                _StepItem(
                  number: 2,
                  title: "Case Details",
                  description: "Add your issue description, location, court preference and urgency.",
                  iconData: Icons.assignment_outlined,
                  isActive: _activeStep == 1,
                  onTap: () {
                    _timer?.cancel();
                    setState(() => _activeStep = 1);
                    _startTimer();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 26.0),
                  child: _buildDottedLine(),
                ),
                _StepItem(
                  number: 3,
                  title: "Upload Document",
                  description: "Upload your acknowledgement or supporting document.",
                  iconData: Icons.upload_file_outlined,
                  isActive: _activeStep == 2,
                  onTap: () {
                    _timer?.cancel();
                    setState(() => _activeStep = 2);
                    _startTimer();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 26.0),
                  child: _buildDottedLine(),
                ),
                _StepItem(
                  number: 4,
                  title: "Recommended Lawyer",
                  description: "AI recommends the best lawyers based on your issue type and location. Select one lawyer to continue.",
                  iconData: Icons.verified_user_outlined,
                  isActive: _activeStep == 3,
                  onTap: () {
                    _timer?.cancel();
                    setState(() => _activeStep = 3);
                    _startTimer();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 26.0),
                  child: _buildDottedLine(),
                ),
                _StepItem(
                  number: 5,
                  title: "Review",
                  description: "Verify all details and submit your case.",
                  iconData: Icons.fact_check_outlined,
                  isActive: _activeStep == 4,
                  onTap: () {
                    _timer?.cancel();
                    setState(() => _activeStep = 4);
                    _startTimer();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final IconData iconData;
  final bool isActive;
  final VoidCallback onTap;

  const _StepItem({
    required this.number,
    required this.title,
    required this.description,
    required this.iconData,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primaryGold.withOpacity(0.12) : AppColors.cardBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? AppColors.primaryGold : AppColors.border,
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: [
                      if (isActive)
                        BoxShadow(
                          color: AppColors.primaryGold.withOpacity(0.15),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Icon(
                    iconData,
                    color: isActive ? AppColors.primaryGold : AppColors.mutedText,
                    size: 24,
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryGold : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "$number",
                      style: TextStyle(
                        color: isActive ? Colors.black : AppColors.mutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.secondaryText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Text(
                description,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 10,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
