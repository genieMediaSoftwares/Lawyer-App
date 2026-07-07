import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../models/lawyer_model.dart';
import '../../../../core/widgets/app_drawer.dart';

class LawyerSearchScreen extends ConsumerStatefulWidget {
  const LawyerSearchScreen({super.key});

  @override
  ConsumerState<LawyerSearchScreen> createState() => _LawyerSearchScreenState();
}

class _LawyerSearchScreenState extends ConsumerState<LawyerSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialization = "All";

  final List<String> _specializations = [
    "All",
    "Criminal Law",
    "Divorce & Family",
    "Property Disputes",
    "Civil Cases",
    "Cyber Crime",
    "GST & Taxation",
    "Labour Law",
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lawyersState = ref.watch(lawyersProvider);
    final theme = Theme.of(context);

    final primaryTextColor = theme.textTheme.titleMedium?.color;
    final secondaryTextColor = theme.textTheme.bodySmall?.color;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Find Advocates", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    hintText: "Search by lawyer name...",
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}), // Trigger local filtering
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _specializations.length,
                    itemBuilder: (context, index) {
                      final spec = _specializations[index];
                      final isSelected = _selectedSpecialization == spec;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(spec),
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
                              setState(() => _selectedSpecialization = spec);
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

          // Lawyers List
          Expanded(
            child: lawyersState.when(
              data: (lawyers) {
                // Filter locally
                final filtered = lawyers.where((lawyer) {
                  final matchesSearch = lawyer.fullName.toLowerCase().contains(_searchController.text.toLowerCase());
                  final matchesSpec = _selectedSpecialization == "All" ||
                      lawyer.specialization.toLowerCase() == _selectedSpecialization.toLowerCase();
                  return matchesSearch && matchesSpec;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text("No Lawyers Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                          Text("Try search terms or category adjustments.", style: TextStyle(color: secondaryTextColor)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final lawyer = filtered[index];
                    return _buildLawyerCard(lawyer);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error loading lawyers: $err")),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLawyerCard(LawyerModel lawyer) {
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: lawyer.profileImage.isNotEmpty ? NetworkImage(lawyer.profileImage) : null,
                  child: lawyer.profileImage.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lawyer.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor)),
                      Text(lawyer.specialization, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: theme.colorScheme.primary, size: 12),
                          const SizedBox(width: 2),
                          Text(lawyer.location.isNotEmpty ? lawyer.location : "Hyderabad, Telangana", style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                          const SizedBox(width: 8),
                          Icon(Icons.star, color: theme.colorScheme.primary, size: 14),
                          Text(" ${lawyer.rating} (${lawyer.totalReviews} reviews)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryTextColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Consultation Fee", style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text("₹${lawyer.consultationFee}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.primary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Experience", style: TextStyle(color: secondaryTextColor, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text("${lawyer.experience} Years+", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    context.push('/lawyer-profile/${lawyer.userId}');
                  },
                  child: const Text("View Profile"),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}