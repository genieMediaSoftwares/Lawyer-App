import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          "Privacy Policy",
          style: TextStyle(
            color: Colors.white,
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
            const Text(
              "Last Updated: July 2026",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),

            _buildSectionHeader("1. Introduction"),
            _buildParagraph(
              "Welcome to GenieLaw. We respect your privacy and are committed to protecting your personal data. "
              "This Privacy Policy explains how we collect, use, store, and share your personal information when you use "
              "our mobile application and services."
            ),

            _buildSectionHeader("2. Information We Collect"),
            _buildParagraph(
              "We collect several types of information from and about users of our application, including:\n"
              "• Personal Identifiers: Name, email address, mobile number, and physical location coordinates.\n"
              "• Case Information: Written summaries, audio notes, files, and legal documents uploaded when posting a case.\n"
              "• Payment Records: Transaction history, invoice records, and related billing metadata.\n"
              "• Technical Data: Device IP address, operating system, login logs, and application performance metrics."
            ),

            _buildSectionHeader("3. How We Use Information"),
            _buildParagraph(
              "We use the information we collect about you to:\n"
              "• Connect you with qualified, bar-certified advocates matching your case criteria.\n"
              "• Facilitate secure chat interactions and schedule voice or video consultations.\n"
              "• Maintain and monitor transaction history, processing refunds and payouts.\n"
              "• Improve app functionality, diagnose server errors, and optimize client experience.\n"
              "• Deliver system notifications, security updates, and promotional advisories."
            ),

            _buildSectionHeader("4. Data Security"),
            _buildParagraph(
              "We implement state-of-the-art security measures to protect your sensitive legal case records. All data transfers "
              "use TLS 1.3 encryption, and static file attachments are stored in AES-256 encrypted directories. Access is restricted "
              "exclusively to the client and hired advocate."
            ),

            _buildSectionHeader("5. Sharing of Information"),
            _buildParagraph(
              "We do not sell, rent, or lease your private personal or case details to third-party marketing entities. We only share "
              "your details with registered advocates when you explicitly invite them, or to secure payment gateways to process transactions, "
              "and where required under judicial court orders."
            ),

            _buildSectionHeader("6. Cookies"),
            _buildParagraph(
              "We use session identifiers and secure local tokens to keep you logged in and preserve application settings. "
              "No tracking cookies or marketing pixels are deployed inside our mobile application environment."
            ),

            _buildSectionHeader("7. User Rights"),
            _buildParagraph(
              "Under applicable data protection acts, you hold the right to access the personal data we store, request correction "
              "of any incorrect details, restrict processing, or request portability of your case data profile."
            ),

            _buildSectionHeader("8. Account Deletion"),
            _buildParagraph(
              "You can trigger deletion of your account at any time under Settings > Account Management. Upon confirmation, "
              "all personal identifiers and unarchived case records will be permanently purged from our servers, subject to "
              "regulatory legal transaction record retention periods."
            ),

            _buildSectionHeader("9. Children's Privacy"),
            _buildParagraph(
              "Our services are strictly directed to individuals aged 18 and older. We do not knowingly collect personal "
              "identifiable details from minors. If we detect registration from a minor, we will terminate the account immediately."
            ),

            _buildSectionHeader("10. Changes to Policy"),
            _buildParagraph(
              "We may update our Privacy Policy periodically. We will notify you of any material changes by posting the new policy "
              "inside this screen and triggering an in-app system notification."
            ),

            _buildSectionHeader("11. Contact Information"),
            _buildParagraph(
              "If you have questions, concerns, or complaints regarding our data protection policies, please contact our Compliance Officer at:\n"
              "• Email: privacy@genielaw.com\n"
              "• Address: GenieLaw Legal-Tech Private Limited, High Court Chambers, Hyderabad - 500066"
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 13,
        height: 1.55,
      ),
    );
  }
}
