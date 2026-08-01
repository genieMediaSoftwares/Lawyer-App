import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "About Us",
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Branding Header
            Center(
              child: Column(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      size: 40,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "GenieLaw",
                    style: TextStyle(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Version 1.4.2",
                    style: TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 2. Company Description
            const Text(
              "WHO WE ARE",
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                "GenieLaw is a premier digital legal-tech platform connecting clients with top-tier verified advocates for virtual consultations, document drafting, and case tracking.",
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. Mission & Vision Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInfoCard(
                    title: "Our Mission",
                    description: "To democratize access to legal counsel, making professional representation affordable, transparent, and accessible to everyone, everywhere.",
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildInfoCard(
                    title: "Our Vision",
                    description: "To build the world's most trusted legal service ecosystem powered by state-of-the-art secure collaboration technology.",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 4. Our Services
            const Text(
              "OUR SERVICES",
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildBulletRow("Expert Legal Consultations", "Virtual case review and advisory"),
                  const Divider(color: AppColors.border, height: 1),
                  _buildBulletRow("Secure Document Workspace", "File storage and digital drafting"),
                  const Divider(color: AppColors.border, height: 1),
                  _buildBulletRow("Advocate Matchmaking", "Direct matching based on specialty"),
                  const Divider(color: AppColors.border, height: 1),
                  _buildBulletRow("Real-Time Case Progress", "Milestone tracking and task logs"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Why Choose Us
            const Text(
              "WHY CHOOSE US",
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildCheckmarkRow("Verified & Bar-Certified Advocates"),
                  const SizedBox(height: 8),
                  _buildCheckmarkRow("End-to-End Encryption for Case Files"),
                  const SizedBox(height: 8),
                  _buildCheckmarkRow("Transparent Billing & Flat Consultation Fees"),
                  const SizedBox(height: 8),
                  _buildCheckmarkRow("24/7 Priority Support Panel"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Legal Compliance
            const Text(
              "LEGAL COMPLIANCE",
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                "GenieLaw strictly complies with all national legal practice acts and Bar Council guidelines regarding online directories and advisory services. Our platform is a listing and secure communication directory, not a direct law firm.",
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 7. Contact Info Card
            const Text(
              "CONTACT INFORMATION",
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildContactRow(Icons.location_on_outlined, "12, Justice Chambers, High Court Road, Hyderabad, Telangana - 500066"),
                  const SizedBox(height: 14),
                  _buildContactRow(Icons.email_outlined, "info@genielaw.com"),
                  const SizedBox(height: 14),
                  _buildContactRow(Icons.language, "www.genielaw.com"),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 8. Social Icons Row
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(Icons.business), // LinkedIn mockup
                  const SizedBox(width: 20),
                  _buildSocialButton(Icons.language), // Web mockup
                  const SizedBox(width: 20),
                  _buildSocialButton(Icons.phone), // Call mockup
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 175,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryGold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 12,
                height: 1.45,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletRow(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3.0),
            child: Icon(Icons.lens, size: 6, color: AppColors.primaryGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckmarkRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check, color: AppColors.primaryGold, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.primaryText, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryGold, size: 20),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.primaryText, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        icon,
        color: AppColors.primaryGold,
        size: 20,
      ),
    );
  }
}
