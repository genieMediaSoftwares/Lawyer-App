import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../routes/route_names.dart';
import '../../../../models/category_item.dart';
import '../../../../providers/category_provider.dart';
import '../widgets/category_card.dart';

class AllCategoriesScreen extends ConsumerStatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  ConsumerState<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends ConsumerState<AllCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<CategoryData> _filteredCategories = List.from(allCategories);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = List.from(allCategories);
      } else {
        _filteredCategories = allCategories
            .where((category) => category.title.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.textTheme.titleLarge?.color;
    final selectedCategoryState = ref.watch(selectedCategoryProvider);
    final selectedCategoryId = selectedCategoryState.categoryId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("All Categories", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: primaryTextColor),
                decoration: InputDecoration(
                  hintText: "Search categories...",
                  hintStyle: TextStyle(color: theme.textTheme.bodySmall?.color),
                  prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),
            
            // Categories Grid Section
            Expanded(
              child: _filteredCategories.isEmpty
                  ? Center(
                      child: Text(
                        "No matching categories found.",
                        style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _filteredCategories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      itemBuilder: (context, index) {
                        final category = _filteredCategories[index];
                        final isSelected = selectedCategoryId == category.id;
                        return CategoryCard(
                          title: category.title,
                          icon: category.icon,
                          isSelected: isSelected,
                          onTap: () {
                            ref.read(selectedCategoryProvider.notifier).selectCategory(category.id);
                            context.push('${RouteNames.postCase}?categoryId=${category.id}');
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
