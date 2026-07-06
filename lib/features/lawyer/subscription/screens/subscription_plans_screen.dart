import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  String _selectedPlan = "Premium"; // Default plan selected

  final List<Map<String, dynamic>> _plans = [
    {
      "name": "Starter",
      "price": "₹999 / month",
      "features": ["20 Leads / Month", "Chat Support", "Basic Profile Listing"],
      "popular": false,
    },
    {
      "name": "Professional",
      "price": "₹2,999 / month",
      "features": ["100 Leads / Month", "Priority Support", "Featured in Search"],
      "popular": false,
    },
    {
      "name": "Premium",
      "price": "₹5,999 / month",
      "features": ["Unlimited Leads", "Priority Support", "Featured Listing", "Profile Highlight"],
      "popular": true,
    },
    {
      "name": "Elite",
      "price": "₹12,999 / month",
      "features": ["Unlimited Leads", "Top Ranking", "Featured Profile", "Dedicated Manager"],
      "popular": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Subscription Plans"),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Choose the plan that's right for your practice",
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._plans.map((plan) => _buildPlanCard(plan)),
                  ],
                ),
              ),
            ),
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan["name"];
    final isPopular = plan["popular"] == true;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan["name"]),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : isPopular
                    ? AppColors.gold.withOpacity(0.5)
                    : AppColors.grey200,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.gold.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        plan["name"],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue),
                      ),
                      Text(
                        plan["price"],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    (plan["features"] as List).length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            plan["features"][index],
                            style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isPopular)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Most Popular",
                    style: TextStyle(color: AppColors.navyBlue, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: ElevatedButton(
        onPressed: () {
          // Proceed to lawyer dashboard
          context.go('/lawyer-dashboard');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text("Continue", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
