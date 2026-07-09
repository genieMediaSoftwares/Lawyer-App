import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../routes/route_names.dart';

class SupportHelpScreen extends StatelessWidget {
  const SupportHelpScreen({super.key});

  void _showContactSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1B1B1B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Contact Support",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Our support panel is available 24/7. Reach out to us through any channel below:",
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildContactMethodTile(
              icon: Icons.email_outlined,
              title: "Email Support",
              value: "support@genielaw.com",
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildContactMethodTile(
              icon: Icons.phone_outlined,
              title: "Phone Helpline",
              value: "+1 (800) 555-0199",
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildContactMethodTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: "Live Chat Support",
              value: "Response time: < 2 mins",
              onTap: () {},
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildContactMethodTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFFD4AF37)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(value, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
      ),
    );
  }

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
                    context.push(RouteNames.faq);
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.support_agent, "Contact Support", () {
                    _showContactSupportSheet(context);
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.info_outline, "About Us", () {
                    context.push(RouteNames.faq);
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.privacy_tip_outlined, "Privacy Policy", () {
                    context.push(RouteNames.articles);
                  }),
                  const Divider(color: Color(0xFF2B2B2B), height: 1),
                  _buildMenuRow(context, Icons.gavel_outlined, "Terms & Conditions", () {
                    context.push(RouteNames.articles);
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
