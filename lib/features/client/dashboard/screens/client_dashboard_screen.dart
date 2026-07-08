import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../routes/route_names.dart';
import 'package:law/models/category_item.dart';
import '../widgets/category_card.dart';

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
              // 1. Curved Premium Banner Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hi, Welcome!",
                      style: TextStyle(
                        color: primaryTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "How can we help you today?",
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color,
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
                          color: theme.inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Search legal issue or lawyer...",
                              style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13),
                            ),
                            Icon(Icons.search, color: theme.colorScheme.primary, size: 20),
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
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AI Legal Assistant",
                            style: TextStyle(color: primaryTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Get instant answers to\nyour legal questions",
                            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.push(RouteNames.aiChat),
                            child: const Text("Ask Now"),
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
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.outline, width: 1.5),
                          ),
                          child: Icon(Icons.smart_toy_outlined, size: 48, color: theme.colorScheme.primary),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.balance, size: 12, color: Colors.black),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4. How It Works? Section
              Text(
                "How It Works?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.push(RouteNames.postCase),
                    child: const _StepCard(label: "Post Issue", icon: Icons.description_outlined),
                  ),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.getMatched),
                    child: const _StepCard(label: "Get Matched", icon: Icons.people_outline),
                  ),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.consult),
                    child: const _StepCard(label: "Consult", icon: Icons.chat_bubble_outline_rounded),
                  ),
                  GestureDetector(
                    onTap: () => context.push(RouteNames.resolve),
                    child: const _StepCard(label: "Resolve", icon: Icons.verified_user_outlined),
                  ),
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }
}
