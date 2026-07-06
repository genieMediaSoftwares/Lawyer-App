import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../providers/faq_provider.dart';
import '../../../../providers/article_provider.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  final String categoryName;

  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  // Category Info Lookup
  Map<String, dynamic> _getCategoryData() {
    switch (widget.categoryName) {
      case "Criminal Law":
        return {
          "desc": "Defend your rights with expert criminal defense representation. Specializing in FIR filings, bail, and litigation representation.",
          "services": ["FIR Filling", "Bail Application", "Police Harassment", "Court Appeal"],
          "banner": "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600"
        };
      case "Divorce & Family":
        return {
          "desc": "Resolving delicate family matters with professional sensitivity. Mutual divorce filings, maintenance, and child custody.",
          "services": ["Mutual Divorce", "Child Custody", "Alimony & Maintenance", "Domestic Violence Counsel"],
          "banner": "https://images.unsplash.com/photo-1505664194779-8bebcb95c557?w=600"
        };
      case "Property Disputes":
        return {
          "desc": "Resolving land title and registration problems. Property verification, partition deeds, and encumbrance checking.",
          "services": ["Partition Deed", "Property Verification", "Builder Dispute", "Registration Issues"],
          "banner": "https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=600"
        };
      case "Civil Cases":
        return {
          "desc": "Advocating client interests in civil breach and disputes. Legal notices, agreements, consumer redressal, and recovery suits.",
          "services": ["Legal Notice", "Breach of Contract", "Consumer Complaints", "Debt Recovery"],
          "banner": "https://images.unsplash.com/photo-1450133064473-71024230f91b?w=600"
        };
      case "Cyber Crime":
        return {
          "desc": "Advocating data privacy and defense from online crimes. Social media fraud, identity theft, and corporate cyber hacks.",
          "services": ["Cyber Fraud Defense", "Identity Theft Recovery", "Social Media Defamation", "Online Extortion"],
          "banner": "https://images.unsplash.com/photo-1563986768609-322da13575f3?w=600"
        };
      case "GST & Taxation":
        return {
          "desc": "Corporate and individual tax registration and audits. GST compliance, audit representation, and corporate tax dispute filing.",
          "services": ["GST Registration", "Tax Return Audit", "Business Tax Planning", "TDS Returns"],
          "banner": "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?w=600"
        };
      case "Labour Law":
        return {
          "desc": "Protecting worker rights and corporate policies. Wrongful dismissal counsel, salary issues, and trade union disputes.",
          "services": ["Wrongful Termination", "Salary Recovery", "Workplace Harassment", "Gratuity Claims"],
          "banner": "https://images.unsplash.com/photo-1521791136364-7286472b5b5c?w=600"
        };
      default:
        return {
          "desc": "Get legal consult from premium verified advocates representing all court chambers.",
          "services": ["General Litigation", "Legal Notice Drafting", "Court Representation"],
          "banner": "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=600"
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final catData = _getCategoryData();
    final lawyersState = ref.watch(lawyersProvider);
    final faqsState = ref.watch(faqsProvider);
    final articlesState = ref.watch(articlesProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(widget.categoryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.getMatched),
        backgroundColor: AppColors.navyBlue,
        icon: const Icon(Icons.psychology, color: Colors.white),
        label: const Text("Match Me With Lawyer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(image: NetworkImage(catData['banner']), fit: BoxFilter.cover),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.55),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.categoryName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 26, fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      catData['desc'],
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Popular Services
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Popular Services", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: (catData['services'] as List<String>).map((srv) {
                      return Chip(
                        label: Text(srv),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.grey200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Top Specialization Lawyers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Top Specialization Lawyers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                  const SizedBox(height: 12),
                  lawyersState.when(
                    data: (lawyers) {
                      final filtered = lawyers.where((l) => l.specialization.toLowerCase() == widget.categoryName.toLowerCase()).toList();
                      if (filtered.isEmpty) {
                        return const Text("No lawyers currently listed for this practice area.");
                      }
                      return SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final lawyer = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(right: 12, bottom: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.grey200)),
                              child: Container(
                                width: 260,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundImage: lawyer.profileImage.isNotEmpty ? NetworkImage(lawyer.profileImage) : null,
                                      child: lawyer.profileImage.isEmpty ? const Icon(Icons.person) : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(lawyer.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                                          Text("${lawyer.experience} yrs exp", style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: AppColors.gold, size: 14),
                                              Text(" ${lawyer.rating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          GestureDetector(
                                            onTap: () => context.push('/lawyer-profile/${lawyer.userId}'),
                                            child: const Text("View Profile", style: TextStyle(color: AppColors.navyBlue, fontWeight: FontWeight.bold, fontSize: 11, decoration: TextDecoration.underline)),
                                          )
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text("Error: $err"),
                  )
                ],
              ),
            ),
            const SizedBox(height: 28),

            // FAQs Section Accordion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Frequently Asked Questions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navyBlue)),
                  const SizedBox(height: 12),
                  faqsState.when(
                    data: (faqs) {
                      final filteredFaqs = faqs.where((f) => f.category.toLowerCase() == widget.categoryName.toLowerCase()).toList();
                      if (filteredFaqs.isEmpty) {
                        return const Text("No FAQs available for this category yet.");
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredFaqs.length,
                        itemBuilder: (context, index) {
                          final faq = filteredFaqs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.grey200)),
                            child: ExpansionTile(
                              title: Text(faq.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(faq.answer, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.grey500)),
                                )
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Text("Error: $err"),
                  )
                ],
              ),
            ),
            const SizedBox(height: 100), // FAB spacing buffer
          ],
        ),
      ),
    );
  }
}

class BoxFilter {
  static const cover = BoxFit.cover;
}
