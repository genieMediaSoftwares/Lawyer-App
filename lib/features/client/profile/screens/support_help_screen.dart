import 'package:flutter/material.dart';

import 'help_center_screen.dart';
import 'contact_support_screen.dart';
import 'about_us_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';

class SupportHelpScreen extends StatelessWidget {
  const SupportHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Support & Help",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
              ),
              child: Column(
                children: [
                  _buildMenuRow(context, Icons.help_outline, "Help Center", () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HelpCenterScreen()),
                    );
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.support_agent, "Contact Support", () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                    );
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.info_outline, "About Us", () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                    );
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.privacy_tip_outlined, "Privacy Policy", () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    );
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.gavel_outlined, "Terms & Conditions", () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const TermsConditionsScreen()),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Icon(icon, color: const Color(0xFFD4AF37), size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 18),
    );
  }
}
