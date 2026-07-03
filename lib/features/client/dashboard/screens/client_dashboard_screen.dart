import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../routes/route_names.dart';
import 'package:law/models/category_item.dart';

final unreadNotificationsCountProvider = StateProvider<int>((ref) => 1); // Mock 1 notification matching Figma red dot

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final userName = authState.userName ?? "User";
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.navyBlue, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Genie",
                style: TextStyle(
                  color: AppColors.navyBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'Outfit',
                ),
              ),
              TextSpan(
                text: "Law",
                style: TextStyle(
                  color: AppColors.gold,
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
                icon: const Icon(Icons.notifications_none_outlined, color: AppColors.navyBlue, size: 26),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
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
              // 1. Curved Navy Blue Banner Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF031A38), AppColors.navyBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyBlue.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hi, Welcome!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "How can we help you today?",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Clickable Search Field
                    GestureDetector(
                      onTap: () => context.push(RouteNames.lawyerSearch),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              "Search legal issue or lawyer...",
                              style: TextStyle(color: AppColors.grey400, fontSize: 13),
                            ),
                            Icon(Icons.search, color: AppColors.navyBlue, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Categories Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Categories",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.navyBlue,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.lawyerSearch),
                    child: const Text(
                      "View All",
                      style: TextStyle(
                        color: AppColors.navyBlue,
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
                itemCount: legalCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.76,
                ),
                itemBuilder: (context, index) {
                  final category = legalCategories[index];
                  return CategoryCard(
                    title: category.title,
                    icon: category.icon,
                    color: category.backgroundColor,
                    iconColor: category.iconColor,
                    onTap: () => context.push(category.route),
                  );
                },
              ),
              const SizedBox(height: 28),

              // 3. AI Legal Assistant Banner
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF031A38), AppColors.navyBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navyBlue.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "AI Legal Assistant",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Get instant answers to\nyour legal questions",
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push(RouteNames.aiChat),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.navyBlue,
                              minimumSize: const Size(100, 36),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            ),
                            child: const Text("Ask Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Robot Avatar with Emblem scales overlay
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12, width: 1.5),
                          ),
                          child: const Icon(Icons.smart_toy_outlined, size: 48, color: Colors.white),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.balance, size: 12, color: AppColors.navyBlue),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. How It Works? Section
              const Text(
                "How It Works?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _StepCard(label: "Post Issue", icon: Icons.description_outlined),
                  _StepCard(label: "Get Matched", icon: Icons.people_outline),
                  _StepCard(label: "Consult", icon: Icons.chat_bubble_outline_rounded),
                  _StepCard(label: "Resolve", icon: Icons.verified_user_outlined),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StepCard({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.grey200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.navyBlue, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B), // Darker text for high legibility
          ),
        ),
      ],
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B), // Darker text for legibility
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}