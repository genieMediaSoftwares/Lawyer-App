import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../routes/route_names.dart';

final dashboardTabProvider = StateProvider<int>((ref) => 0);

class ClientDashboardScreen extends ConsumerWidget {
  const ClientDashboardScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final userName = authState.userName ?? "Rahul";

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: PopScope(
        canPop: false,
        child: SafeArea(
          child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Greeting Header Row
              Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.grey200,
                    child: Icon(Icons.person, size: 26, color: AppColors.grey500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello, $userName",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: const [
                            Icon(Icons.location_on, size: 14, color: AppColors.grey500),
                            SizedBox(width: 4),
                            Text(
                              "Hyderabad, Telangana",
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.grey500,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.grey500),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      try {
                        await ref.read(authProvider.notifier).logout();
                      } catch (e) {
                        debugPrint("Logout error: $e");
                      }
                      router.go(RouteNames.login);
                    },
                    icon: const Icon(
                      Icons.logout,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// Search Bar
               TextField(
                readOnly: true,
                onTap: () => context.push(RouteNames.lawyerSearch),
                decoration: InputDecoration(
                  hintText: "How can we help you today?",
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.grey500,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 24),

              /// Popular Categories Grid Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Popular Categories",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text("See All"),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              /// Categories Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
                children: [
                  CategoryCard(
                    title: "Divorce &\nFamily",
                    icon: Icons.family_restroom,
                    color: const Color(0xFFFEF3C7), // Amber Light
                    iconColor: Colors.amber,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "Criminal\nLaw",
                    icon: Icons.gavel_rounded,
                    color: const Color(0xFFFEE2E2), // Red Light
                    iconColor: Colors.red,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "Property\nDisputes",
                    icon: Icons.home,
                    color: const Color(0xFFECFDF5), // Green Light
                    iconColor: Colors.green,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "Civil\nCases",
                    icon: Icons.account_balance,
                    color: const Color(0xFFE0F2FE), // Blue Light
                    iconColor: Colors.blue,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "Cyber\nCrime",
                    icon: Icons.security,
                    color: const Color(0xFFEEF2F6), // Grey Light
                    iconColor: Colors.indigo,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "Consumer\nDisputes",
                    icon: Icons.shopping_bag,
                    color: const Color(0xFFFAE8FF), // Purple Light
                    iconColor: Colors.purple,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "Labour\nLaw",
                    icon: Icons.work,
                    color: const Color(0xFFFFF7ED), // Orange Light
                    iconColor: Colors.orange,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                  CategoryCard(
                    title: "More\n",
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xFFF1F5F9), // Slate Light
                    iconColor: Colors.blueGrey,
                    onTap: () => context.push(RouteNames.lawyerSearch),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              /// AI Legal Assistant Banner
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.navyBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Need Quick Legal Help?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Talk to our AI Legal Assistant",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.navyBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: const Text("Start Chat"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Robot Avatar Placeholder
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        size: 45,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              /// How GenieLaw Works?
              Text(
                "How GenieLaw Works?",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepCard("Post Your Case", Icons.post_add),
                  _buildStepCard("Get Responses", Icons.quickreply_outlined),
                  _buildStepCard("Choose Lawyer", Icons.how_to_reg_outlined),
                  _buildStepCard("Consult & Solve", Icons.handshake_outlined),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: AppColors.navyBlue),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.folder_open, color: AppColors.grey500),
              onPressed: () {},
            ),
            const SizedBox(width: 48), // Floating Action Button space
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.grey500),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, color: AppColors.grey500),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.navyBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildStepCard(String label, IconData icon) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.navyBlue, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// CATEGORY CARD
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
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}