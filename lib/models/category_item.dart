import 'package:flutter/material.dart';

class CategoryData {
  final String id;
  final String title;
  final String slug;
  final int index;
  final IconData icon;
  final List<String> subcategories;

  const CategoryData({
    required this.id,
    required this.title,
    required this.slug,
    required this.index,
    required this.icon,
    required this.subcategories,
  });
}

final List<CategoryData> allCategories = const [
  CategoryData(
    id: "criminal_law",
    title: "Criminal Law",
    slug: "criminal-law",
    index: 0,
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
    id: "family_divorce",
    title: "Family & Divorce",
    slug: "family-divorce",
    index: 1,
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
    id: "property_land",
    title: "Property & Land",
    slug: "property-land",
    index: 2,
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
    id: "civil_cases",
    title: "Civil Cases",
    slug: "civil-cases",
    index: 3,
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
    id: "cyber_crime",
    title: "Cyber Crime",
    slug: "cyber-crime",
    index: 4,
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
    id: "gst_taxation",
    title: "GST & Taxation",
    slug: "gst-taxation",
    index: 5,
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
    id: "employment_labour",
    title: "Employment & Labour",
    slug: "employment-labour",
    index: 6,
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
    id: "consumer_complaints",
    title: "Consumer Complaints",
    slug: "consumer-complaints",
    index: 7,
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
    id: "banking_financial",
    title: "Banking & Financial",
    slug: "banking-financial",
    index: 8,
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
    id: "business_corporate",
    title: "Business & Corporate",
    slug: "business-corporate",
    index: 9,
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
    id: "documentation",
    title: "Documentation",
    slug: "documentation",
    index: 10,
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
    id: "motor_accident_claims",
    title: "Motor Accident Claims",
    slug: "motor-accident-claims",
    index: 11,
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
    id: "medical_negligence",
    title: "Medical Negligence",
    slug: "medical-negligence",
    index: 12,
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
    id: "education_law",
    title: "Education Law",
    slug: "education-law",
    index: 13,
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
    id: "immigration_visa",
    title: "Immigration & Visa",
    slug: "immigration-visa",
    index: 14,
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