import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
          "Terms & Conditions",
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

            _buildSectionHeader("1. Acceptance of Terms"),
            _buildParagraph(
              "By installing, browsing, or utilizing the GenieLaw mobile application, you agree to comply with and be bound by "
              "these Terms & Conditions. If you disagree with any part of these terms, you must cease using our application immediately."
            ),

            _buildSectionHeader("2. Eligibility"),
            _buildParagraph(
              "You must be at least 18 years of age and possess the legal capacity to enter into binding agreements to create a client "
              "account. By registering, you warrant that all information provided is accurate and truthful."
            ),

            _buildSectionHeader("3. Posting Legal Cases"),
            _buildParagraph(
              "When posting a case, you must provide a clear and honest summary. You agree not to post false, misleading, defamatory, "
              "or illegal content. GenieLaw reserves the right to remove any post that violates platform safety guidelines."
            ),

            _buildSectionHeader("4. Lawyer Responsibilities"),
            _buildParagraph(
              "Advocates registered on the platform are independent practitioners. They are solely responsible for verifying the facts "
              "of your case, providing legal counsel, representing you in court, and adhering to the Professional Ethics and Standards of the Bar Council."
            ),

            _buildSectionHeader("5. Client Responsibilities"),
            _buildParagraph(
              "As a client, you are responsible for providing all requested case details, answering advocate queries honestly, paying scheduled "
              "consultation fees, and respecting the scheduled booking times."
            ),

            _buildSectionHeader("6. Payments and Invoices"),
            _buildParagraph(
              "Consultation booking fees must be paid in full prior to the consultation session. All platform invoice details are documented "
              "under your account dashboard. You agree to pay all charges incurred in connection with your booked sessions."
            ),

            _buildSectionHeader("7. Cancellation Policy"),
            _buildParagraph(
              "Clients can cancel or reschedule bookings up to 12 hours prior to the consultation time. Cancellations made inside the 12-hour "
              "window may attract a cancellation fee or result in forfeiture of the session booking fee."
            ),

            _buildSectionHeader("8. Consultation Policy"),
            _buildParagraph(
              "Consultation sessions are conducted virtually via secure text chat, voice, or video channels. Sessions must remain within the "
              "allotted time limits. Advocates reserve the right to terminate sessions showing abusive or threatening behavior."
            ),

            _buildSectionHeader("9. Prohibited Activities"),
            _buildParagraph(
              "You are strictly prohibited from:\n"
              "• Sharing or posting software viruses or malicious scripting.\n"
              "• Soliciting lawyers for off-platform payments to circumvent service guidelines.\n"
              "• Impersonating any other individual, legal entity, or advocate.\n"
              "• Scraping or harvesting user registry data."
            ),

            _buildSectionHeader("10. Intellectual Property"),
            _buildParagraph(
              "All graphics, logos, source code, features, brand assets, and platform text are the exclusive intellectual property "
              "of GenieLaw. You may not copy, replicate, or use them without prior written authorization."
            ),

            _buildSectionHeader("11. Disclaimer of Warranties"),
            _buildParagraph(
              "GenieLaw is a software matchmaking directory and does not provide legal representation or advocate services directly. "
              "We make no guarantees regarding the outcome of any case or the specific efficacy of advice provided by matched advocates."
            ),

            _buildSectionHeader("12. Limitation of Liability"),
            _buildParagraph(
              "To the maximum extent permitted under applicable law, GenieLaw shall not be liable for any direct, indirect, incidental, "
              "consequential, or punitive damages resulting from lawyer advice, case losses, or service disruptions."
            ),

            _buildSectionHeader("13. Termination of Service"),
            _buildParagraph(
              "We reserve the right to suspend, restrict, or terminate your client registry account immediately if you breach any part of "
              "these terms or engage in fraudulent activities."
            ),

            _buildSectionHeader("14. Applicable Law"),
            _buildParagraph(
              "These Terms & Conditions shall be governed by and construed in accordance with the laws of the jurisdiction in which the "
              "company is registered, without giving effect to conflicts of law provisions."
            ),

            _buildSectionHeader("15. Contact Information"),
            _buildParagraph(
              "For inquiries or formal communications regarding these Terms & Conditions, please contact us at:\n"
              "• Email: legal@genielaw.com\n"
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
