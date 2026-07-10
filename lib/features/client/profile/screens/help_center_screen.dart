import 'package:flutter/material.dart';
import 'contact_support_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "Getting Started",
    "Posting a Case",
    "Finding Lawyers",
    "Consultations",
    "Payments",
    "Documents",
    "Privacy & Security",
    "Account Management",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FAQItem> _getFilteredFaqs() {
    final query = _searchController.text.toLowerCase().trim();
    return _faqs.where((faq) {
      final matchesCategory = _selectedCategory == "All" || faq.category == _selectedCategory;
      final matchesSearch = query.isEmpty ||
          faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _showArticleDetails(BuildContext context, _PopularArticle article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(bottom: 24),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    article.tag.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  article.readTime,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Divider(color: Color(0xFF2B2B2B), height: 32),
            Text(
              article.content,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _getFilteredFaqs();

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
          "Help Center",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Search & Filters Panel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search guides, FAQs, and topics...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1B1B1B),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2B2B2B)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            showCheckmark: false,
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFFD4AF37).withOpacity(0.15),
                            backgroundColor: const Color(0xFF1B1B1B),
                            labelStyle: TextStyle(
                              color: isSelected ? const Color(0xFFD4AF37) : Colors.grey,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF2B2B2B),
                                width: 1,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Popular Help Articles (Show only when no search filter active, or matching)
          if (_searchController.text.isEmpty && _selectedCategory == "All") ...[
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20.0, top: 20.0, bottom: 12.0),
                    child: Text(
                      "POPULAR HELP ARTICLES",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 135,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: _popularArticles.length,
                      itemBuilder: (context, index) {
                        final article = _popularArticles[index];
                        return InkWell(
                          onTap: () => _showArticleDetails(context, article),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 250,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1B1B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF2B2B2B)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4AF37).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        article.tag,
                                        style: const TextStyle(
                                          color: Color(0xFFD4AF37),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      article.readTime,
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  article.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: const [
                                    Text(
                                      "Read Guide",
                                      style: TextStyle(color: Color(0xFFD4AF37), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward, color: Color(0xFFD4AF37), size: 12),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          // FAQs Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 28.0, bottom: 12.0),
              child: Text(
                _selectedCategory == "All" ? "ALL FREQUENTLY ASKED QUESTIONS" : "${_selectedCategory.toUpperCase()} FAQS",
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // Collapsible list
          filteredFaqs.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final faq = filteredFaqs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B1B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2B2B2B), width: 1),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              iconColor: const Color(0xFFD4AF37),
                              collapsedIconColor: Colors.grey,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              title: Text(
                                faq.question,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
                                  child: Text(
                                    faq.answer,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: filteredFaqs.length,
                    ),
                  ),
                ),

          // Bottom Spacing for Scroll View
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),

          // Still Need Help? Bottom Panel
          SliverToBoxAdapter(
            child: _buildStillNeedHelpSection(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B1B1B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_outlined,
              size: 48,
              color: Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Matches Found",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "We couldn't find any FAQs matching your exact query. Try another search or category filter.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStillNeedHelpSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          top: BorderSide(color: Color(0xFF2B2B2B), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "STILL NEED HELP?",
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "If you can't find answers in our guides, reach out to our dedicated support channels.",
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildContactActionCard(
                  icon: Icons.support_agent,
                  title: "Contact Support",
                  subtitle: "Create a support ticket",
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ContactSupportScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildContactActionCard(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: "Live Chat Support",
                  subtitle: "Instant 24/7 assistance",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Launching live chat assistant...")),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2B2B2B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 22),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQItem {
  final String category;
  final String question;
  final String answer;

  const _FAQItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class _PopularArticle {
  final String tag;
  final String readTime;
  final String title;
  final String content;

  const _PopularArticle({
    required this.tag,
    required this.readTime,
    required this.title,
    required this.content,
  });
}

const List<_PopularArticle> _popularArticles = [
  _PopularArticle(
    tag: "Advocate Search",
    readTime: "3 min read",
    title: "How to hire a verified advocate",
    content: "When choosing an advocate on GenieLaw, look for the gold verification badge. This badge signifies that the advocate has submitted and verified their Bar Council registration credentials, experience logs, and educational background. You can review detailed client reviews, success percentages, and specialize areas directly in their profile before initiating a consultation booking.",
  ),
  _PopularArticle(
    tag: "Billing",
    readTime: "5 min read",
    title: "Understanding fees and payouts",
    content: "GenieLaw ensures complete payment security. All consultation bookings require flat, upfront fee deposits processed through PCI-compliant gateways. Fees remain secure and are only transferred to the advocate after successful consultation summary delivery. If a session is cancelled by an advocate, the fee is fully refunded to the client's original payment source.",
  ),
  _PopularArticle(
    tag: "Legal Documents",
    readTime: "4 min read",
    title: "Preparing your case files",
    content: "To get the most out of your consultation, organize your case files before the session. Go to 'Post a Case' and upload details under relevant categories (like Property, Criminal, or Civil). Supported formats include PDF and JPG/PNG up to 25MB. Uploaded case files are securely encrypted and only accessible to you and your selected counsel.",
  ),
];

const List<_FAQItem> _faqs = [
  _FAQItem(
    category: "Getting Started",
    question: "How do I register a client account?",
    answer: "You can sign up directly on the login screen using your email address and mobile number. A verification link or OTP will be sent to complete registration.",
  ),
  _FAQItem(
    category: "Getting Started",
    question: "Is there any subscription fee for clients?",
    answer: "No, client registration and posting legal cases on GenieLaw is completely free. You only pay for the individual consultation services you book.",
  ),
  _FAQItem(
    category: "Getting Started",
    question: "Is my personal legal case information private?",
    answer: "Absolutely. GenieLaw uses advanced AES-256 encryption. Only you and the lawyer you choose to interact with can view your case documents and chat details.",
  ),
  _FAQItem(
    category: "Posting a Case",
    question: "How do I post a new legal case?",
    answer: "Navigate to your Dashboard, tap 'Post a Case', select a legal category, describe the issue, specify your location, and upload any relevant files. Tap submit to publish it.",
  ),
  _FAQItem(
    category: "Posting a Case",
    question: "Can I edit or close a posted case?",
    answer: "Yes, you can edit case details or withdraw your post directly from the 'My Cases' section on your profile as long as you haven't hired an advocate.",
  ),
  _FAQItem(
    category: "Finding Lawyers",
    question: "How can I find the right lawyer for my issue?",
    answer: "You can browse verified lawyers by their specialization, rating, and location, or utilize our 'Get Matched' smart feature to find the best match for your case category.",
  ),
  _FAQItem(
    category: "Finding Lawyers",
    question: "How are advocates on GenieLaw verified?",
    answer: "Every advocate must submit their State Bar Council registration details, educational credentials, and identity verification before being approved to practice on our platform.",
  ),
  _FAQItem(
    category: "Consultations",
    question: "How do I book a consultation with an advocate?",
    answer: "Open the advocate's profile, click on 'Schedule Consultation', choose a preferred date and time slot from their calendar, write a brief note about your request, and confirm.",
  ),
  _FAQItem(
    category: "Consultations",
    question: "Can I cancel or reschedule a consultation?",
    answer: "Yes, you can cancel or reschedule up to 12 hours before the scheduled time under the 'Consultations' tab in your Profile menu.",
  ),
  _FAQItem(
    category: "Payments",
    question: "What payment methods are supported?",
    answer: "We support major credit/debit cards, net banking, UPI, and digital wallets. All transactions are securely processed through integrated gateways.",
  ),
  _FAQItem(
    category: "Payments",
    question: "Can I get a refund if my consultation is cancelled?",
    answer: "If the consultation is cancelled by the advocate or cancelled by you within the eligible time frame (12 hours prior), a full refund will be initiated to your source payment method.",
  ),
  _FAQItem(
    category: "Documents",
    question: "Where are my legal documents stored?",
    answer: "All your uploaded files and consultation summaries are securely saved under Profile > Documents. You can access or download them anytime.",
  ),
  _FAQItem(
    category: "Documents",
    question: "What formats and file sizes are supported for uploads?",
    answer: "You can upload PDF, DOC/DOCX, and JPG/PNG files up to 25MB per document directly into your case details or secure chat workspace.",
  ),
  _FAQItem(
    category: "Privacy & Security",
    question: "How is my personal data protected?",
    answer: "Our systems are fully compliant with ISO 27001 standards and standard data protection regulations. We use end-to-end encryption for all real-time communications.",
  ),
  _FAQItem(
    category: "Privacy & Security",
    question: "How do I delete my account?",
    answer: "To delete your client account, go to Profile > Settings > Account Management and select 'Delete Account'. All non-essential personal information will be purged from our servers.",
  ),
  _FAQItem(
    category: "Account Management",
    question: "How do I update my email or phone number?",
    answer: "Go to Profile > My Profile to update your contact details. Changes to your mobile number or email will require standard OTP verification for security.",
  ),
  _FAQItem(
    category: "Account Management",
    question: "What should I do if my account is locked?",
    answer: "If you experience multiple failed login attempts, your account may be temporarily locked for security. Tap 'Forgot Password' to reset or contact our support desk.",
  ),
];
