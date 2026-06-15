import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../routes/route_names.dart';
import '../widgets/onboarding_page.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState
    extends ConsumerState<OnboardingScreen> {
  final PageController _pageController =
  PageController();

  int currentPage = 0;

  final List<Map<String, dynamic>> pages = [
    {
      "title": "Find Expert Lawyers",
      "description":
      "Connect with experienced and verified lawyers across multiple legal domains.",
      "icon": Icons.search,
    },
    {
      "title": "Book Consultation",
      "description":
      "Schedule appointments instantly with lawyers based on availability.",
      "icon": Icons.calendar_month,
    },
    {
      "title": "Video Consultation",
      "description":
      "Meet lawyers securely through online video consultations.",
      "icon": Icons.video_call,
    },
    {
      "title": "Secure Legal Documents",
      "description":
      "Upload, manage and access legal documents safely.",
      "icon": Icons.folder_copy,
    },
  ];

  void _completeOnboarding() {
    ref
        .read(authProvider.notifier)
        .completeOnboarding();

    context.go(RouteNames.login);
  }

  void _nextPage() {
    if (currentPage < pages.length - 1) {
      _pageController.nextPage(
        duration:
        const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget buildIndicator(int index) {
    final isActive = currentPage == index;

    return AnimatedContainer(
      duration:
      const Duration(milliseconds: 300),
      margin:
      const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context)
            .colorScheme
            .primary
            : Colors.grey.shade400,
        borderRadius:
        BorderRadius.circular(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage =
        currentPage == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            /// Skip Button
            Padding(
              padding:
              const EdgeInsets.only(right: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                  _completeOnboarding,
                  child: const Text("Skip"),
                ),
              ),
            ),

            /// Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return OnboardingPage(
                    title: pages[index]["title"],
                    description:
                    pages[index]
                    ["description"],
                    icon: pages[index]["icon"],
                  );
                },
              ),
            ),

            /// Indicator
            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                    (index) =>
                    buildIndicator(index),
              ),
            ),

            const SizedBox(height: 30),

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: Text(
                    isLastPage
                        ? "Get Started"
                        : "Next",
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