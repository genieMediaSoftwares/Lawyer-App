import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/faq_provider.dart';
import '../../../../core/widgets/app_drawer.dart';

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = "All";

  final List<String> _categories = [
    "All",
    "Criminal Law",
    "Divorce & Family",
    "Property Disputes",
    "Civil Cases",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    ref.read(faqsProvider.notifier).fetchFaqs(
      category: _selectedCategory,
      search: _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final faqsState = ref.watch(faqsProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDarkMode ? Colors.white : AppColors.navyBlue;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("FAQ Accordion", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        
      ),
      body: Column(
        children: [
          // Search and Category Selector
          Container(
            color: isDarkMode ? AppColors.darkSurface : Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search FAQs...",
                    prefixIcon: const Icon(Icons.search, color: AppColors.grey400),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) => _triggerSearch(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: isDarkMode ? AppColors.gold : AppColors.navyBlue,
                          backgroundColor: isDarkMode ? AppColors.darkCard : AppColors.grey100,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? (isDarkMode ? AppColors.navyBlue : Colors.white)
                                : (isDarkMode ? Colors.white70 : AppColors.navyBlue),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedCategory = cat);
                              _triggerSearch();
                            }
                          },
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),

          // Collapsible list
          Expanded(
            child: faqsState.when(
              data: (faqs) {
                if (faqs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.question_answer_outlined, size: 64, color: AppColors.grey300),
                          const SizedBox(height: 12),
                          Text("No FAQs Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                          const Text("Try updating your search query or categories.", style: TextStyle(color: AppColors.grey400), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: faqs.length,
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDarkMode ? AppColors.borderDark : AppColors.grey200),
                      ),
                      child: ExpansionTile(
                        collapsedIconColor: isDarkMode ? Colors.white70 : AppColors.navyBlue,
                        iconColor: isDarkMode ? AppColors.gold : AppColors.navyBlue,
                        title: Text(faq.question, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(faq.answer, style: TextStyle(fontSize: 12, height: 1.5, color: isDarkMode ? AppColors.grey300 : AppColors.grey500)),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: $err")),
            ),
          )
        ],
      ),
    );
  }
}
