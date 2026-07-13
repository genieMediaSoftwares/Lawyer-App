import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/article_provider.dart';
import '../../../../models/article_model.dart';

class ArticlesScreen extends ConsumerStatefulWidget {
  const ArticlesScreen({super.key});

  @override
  ConsumerState<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends ConsumerState<ArticlesScreen> {
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
    ref.read(articlesProvider.notifier).fetchArticles(
      category: _selectedCategory,
      search: _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final articlesState = ref.watch(articlesProvider);
    final theme = Theme.of(context);

    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text("Legal Articles", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search legal articles...",
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
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
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.surface,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.black
                                : theme.textTheme.bodySmall?.color,
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

          // Articles List
          Expanded(
            child: articlesState.when(
              data: (articles) {
                if (articles.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text("No Articles Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                          Text("Try updating your search query or categories.", style: TextStyle(color: secondaryTextColor), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: articles.length,
                  itemBuilder: (context, index) {
                    final article = articles[index];
                    return _buildArticleCard(article);
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

  Widget _buildArticleCard(ArticleModel article) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.image.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                article.image,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(height: 150, color: theme.colorScheme.surface, child: const Icon(Icons.image)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        article.category,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(article.readTime, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11)),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(article.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                const SizedBox(height: 8),
                Text(
                  article.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: secondaryTextColor, fontSize: 12, height: 1.4),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => _showArticleDetails(article),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: const Text("Read Full Article", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(Icons.bookmark_border, color: theme.colorScheme.primary),
                      onPressed: () => ref.read(articlesProvider.notifier).toggleBookmark(article.id),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _showArticleDetails(ArticleModel article) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Container(height: 4, width: 40, decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)), margin: const EdgeInsets.symmetric(horizontal: 140, vertical: 8)),
            const SizedBox(height: 16),
            Text(article.category.toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            Text(article.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: theme.textTheme.titleLarge?.color)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(article.readTime, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 12)),
              ],
            ),
            const Divider(height: 32),
            Text(
              "${article.content}\n\n${_getLongContentPlaceholder()}",
              style: TextStyle(fontSize: 14, height: 1.6, color: theme.textTheme.bodyMedium?.color),
            ),
          ],
        ),
      ),
    );
  }

  String _getLongContentPlaceholder() {
    return "Legal protocols dictate that correct filing is half the battle. In all instances of consumer fraud, Cyber security regulations demand that identity validation and secure data transfers are logged immediately. Ensure that your advocate has verified all contract clauses before submitting to the district courts. Under CrPC Section 50, a detailed overview of the bail process requires direct presentation of active character guarantees.";
  }
}
