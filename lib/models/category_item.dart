import 'package:flutter/material.dart';

class CategoryData {
  final String title;
  final IconData icon;
  final List<String> subcategories;

  const CategoryData({
    required this.title,
    required this.icon,
    required this.subcategories,
  });
}

final List<CategoryData> allCategories = const [
  CategoryData(
    title: "Criminal Law",
    icon: Icons.gavel_outlined,
    subcategories: [
      "FIR Registration",
      "Bail",
      "Theft",
      "Assault",
      "Cheating & Fraud",
    ],
  ),
  CategoryData(
    title: "Family & Divorce",
    icon: Icons.family_restroom_outlined,
    subcategories: [
      "Divorce",
      "Child Custody",
      "Domestic Violence",
      "Maintenance / Alimony",
      "Marriage Registration",
    ],
  ),
  CategoryData(
    title: "Property & Land",
    icon: Icons.home_work_outlined,
    subcategories: [
      "Property Registration",
      "Builder Dispute",
      "Property Partition",
      "Land Encroachment",
      "RERA Complaint",
    ],
  ),
  CategoryData(
    title: "Civil Cases",
    icon: Icons.balance_outlined,
    subcategories: [
      "Money Recovery",
      "Civil Suit",
      "Property Injunction",
      "Contract Dispute",
      "Recovery of Possession",
    ],
  ),
  CategoryData(
    title: "Cyber Crime",
    icon: Icons.security_outlined,
    subcategories: [
      "Online Scam",
      "UPI Fraud",
      "Social Media Harassment",
      "Identity Theft",
      "Hacking",
    ],
  ),
  CategoryData(
    title: "GST & Taxation",
    icon: Icons.receipt_long_outlined,
    subcategories: [
      "GST Registration",
      "GST Notice",
      "Income Tax Notice",
      "Tax Filing",
      "Tax Consultation",
    ],
  ),
  CategoryData(
    title: "Employment & Labour",
    icon: Icons.work_outline,
    subcategories: [
      "Salary Issues",
      "Wrongful Termination",
      "Workplace Harassment",
      "Labour Dispute",
      "Employment Contract",
    ],
  ),
  CategoryData(
    title: "Consumer Complaints",
    icon: Icons.shopping_cart_outlined,
    subcategories: [
      "Refund Issue",
      "Defective Product",
      "Online Shopping Fraud",
      "Service Complaint",
      "Warranty Claim",
    ],
  ),
  CategoryData(
    title: "Banking & Financial",
    icon: Icons.account_balance_outlined,
    subcategories: [
      "Loan Dispute",
      "Bank Fraud",
      "Credit Card Dispute",
      "EMI Issues",
      "Cheque Bounce",
    ],
  ),
  CategoryData(
    title: "Business & Corporate",
    icon: Icons.business_outlined,
    subcategories: [
      "Company Registration",
      "Partnership Dispute",
      "Contract Review",
      "Trademark",
      "Startup Legal Help",
    ],
  ),
  CategoryData(
    title: "Documentation",
    icon: Icons.description_outlined,
    subcategories: [
      "Legal Notice",
      "Rental Agreement",
      "Affidavit",
      "Power of Attorney",
      "Will Preparation",
    ],
  ),
  CategoryData(
    title: "Motor Accident Claims",
    icon: Icons.car_crash_outlined,
    subcategories: [
      "Accident Compensation",
      "Insurance Claim",
      "Vehicle Damage",
      "Hit & Run",
      "Injury Claim",
    ],
  ),
  CategoryData(
    title: "Medical Negligence",
    icon: Icons.local_hospital_outlined,
    subcategories: [
      "Doctor Negligence",
      "Hospital Liability",
      "Wrong Diagnosis",
      "Surgical Error",
      "Treatment Delay",
    ],
  ),
  CategoryData(
    title: "Education Law",
    icon: Icons.school_outlined,
    subcategories: [
      "Admission Dispute",
      "Fee Dispute",
      "Degree Delay",
      "Harassment Case",
      "Exam Malpractice",
    ],
  ),
  CategoryData(
    title: "Immigration & Visa",
    icon: Icons.flight_takeoff_outlined,
    subcategories: [
      "Student Visa",
      "Work Permit",
      "PR Application",
      "Citizenship",
      "Deportation Case",
    ],
  ),
];