import 'package:flutter/material.dart';
import '../routes/route_names.dart';

class CategoryItem {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final int priority;
  final String route;

  const CategoryItem({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.priority,
    required this.route,
  });
}

// Reorder this list (or change `priority`) to control what shows first.
// Swap `route` per category once each practice area gets its own filtered screen.
final List<CategoryItem> legalCategories = [
  CategoryItem(title: "Criminal Law", icon: Icons.gavel_rounded, backgroundColor: const Color(0xFFFFF9E6), iconColor: Color(0xFFD4AF37), priority: 1, route: RouteNames.lawyerSearch),
  CategoryItem(title: "Divorce &\nFamily", icon: Icons.people_rounded, backgroundColor: const Color(0xFFFDECEB), iconColor: Colors.red.shade600, priority: 2, route: RouteNames.lawyerSearch),
  CategoryItem(title: "Property\nDisputes", icon: Icons.home_rounded, backgroundColor: const Color(0xFFFEF2E9), iconColor: Colors.orange.shade700, priority: 3, route: RouteNames.lawyerSearch),
  CategoryItem(title: "Civil Cases", icon: Icons.balance_rounded, backgroundColor: const Color(0xFFF2F4F4), iconColor: const Color(0xFF0F172A), priority: 4, route: RouteNames.lawyerSearch),
  CategoryItem(title: "Cyber Crime", icon: Icons.shield_outlined, backgroundColor: const Color(0xFFEEF2FF), iconColor: Colors.indigo, priority: 5, route: RouteNames.lawyerSearch),
  CategoryItem(title: "GST &\nTaxation", icon: Icons.receipt_long_rounded, backgroundColor: const Color(0xFFE8F8F5), iconColor: Colors.green.shade700, priority: 6, route: RouteNames.lawyerSearch),
  CategoryItem(title: "Labour Law", icon: Icons.person_outline, backgroundColor: const Color(0xFFEBF5FB), iconColor: Colors.blue.shade700, priority: 7, route: RouteNames.lawyerSearch),
  CategoryItem(title: "More", icon: Icons.apps_rounded, backgroundColor: const Color(0xFFF2F4F4), iconColor: const Color(0xFF0F172A), priority: 8, route: RouteNames.lawyerSearch),
];