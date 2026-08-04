import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';

class SubscriptionPlansScreen extends StatefulWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  String _selectedPlan = "Premium";

  final List<Map<String, dynamic>> _plans = [
    {
      "name": "Starter",
      "price": "₹999 / month",
      "features": ["Chat Support", "Basic Profile Listing"],
      "popular": false,
    },
    {
      "name": "Professional",
      "price": "₹2,999 / month",
      "features": ["Priority Support", "Featured in Search"],
      "popular": false,
    },
    {
      "name": "Premium",
      "price": "₹5,999 / month",
      "features": ["Priority Support", "Featured Listing", "Profile Highlight"],
      "popular": true,
    },
    {
      "name": "Elite",
      "price": "₹12,999 / month",
      "features": ["Top Ranking", "Featured Profile", "Dedicated Manager"],
      "popular": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(loc.subscription_plans),
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
                    Text(
                      loc.choose_subscription_plan_subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._plans.map((plan) => _buildPlanCard(plan)),
                  ],
                ),
              ),
            ),
            _buildContinueButton(loc),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan["name"];
    final isPopular = plan["popular"] == true;
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan["name"]),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : isPopular
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.colorScheme.outline,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleMedium?.color),
                      ),
                      Text(
                        plan["price"],
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textTheme.titleMedium?.color),
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
                          const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            plan["features"][index],
                            style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13),
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
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    loc.most_popular,
                    style: const TextStyle(color: AppColors.onGold, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(AppLocalizations loc) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.scaffoldBackgroundColor,
      child: ElevatedButton(
        onPressed: () {
          context.go('/lawyer-dashboard');
        },
        child: Text(loc.continue_button, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
