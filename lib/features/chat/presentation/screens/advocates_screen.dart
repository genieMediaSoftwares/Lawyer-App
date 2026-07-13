import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../providers/lawyer_provider.dart';
import '../../../../core/config/env.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/sort_by_sheet.dart';

class AdvocatesScreen extends ConsumerStatefulWidget {
  const AdvocatesScreen({super.key});

  @override
  ConsumerState<AdvocatesScreen> createState() => _AdvocatesScreenState();
}

class _AdvocatesScreenState extends ConsumerState<AdvocatesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(advocateFiltersProvider).search;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(advocateFiltersProvider.notifier).update(
          (state) => state.copyWith(search: _searchController.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final advocatesState = ref.watch(advocatesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: const AppDrawer(),
      endDrawer: const FilterDrawer(), // Sliding drawer for Tablet/Desktop
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Advocates',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 24),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search, Sort & Filter Bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      cursorColor: AppColors.primaryGold,
                      decoration: const InputDecoration(
                        hintText: 'Search advocates...',
                        hintStyle: TextStyle(color: Color(0xFF707070), fontSize: 15),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF707070), size: 22),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Sort Button
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const SortBySheet(),
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: const Center(
                      child: Icon(Icons.sort_rounded, color: AppColors.primaryGold, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Filter Button
                Builder(
                  builder: (buttonContext) => GestureDetector(
                    onTap: () {
                      final isTablet = MediaQuery.of(buttonContext).size.width >= 600;
                      if (isTablet) {
                        Scaffold.of(buttonContext).openEndDrawer();
                      } else {
                        showModalBottomSheet(
                          context: buttonContext,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const FilterBottomSheet(),
                        );
                      }
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: const Center(
                        child: Icon(Icons.filter_alt_outlined, color: AppColors.primaryGold, size: 22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Advocates List ───────────────────────────────────────────
          Expanded(
            child: advocatesState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGold),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load advocates.\n$err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(advocatesProvider),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGold),
                          foregroundColor: AppColors.primaryGold,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'No advocates found',
                      style: TextStyle(color: Color(0xFF707070), fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final advocate = list[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: AdvocateCard(
                        name: advocate.fullName,
                        specialization: advocate.specialization,
                        location: advocate.location,
                        rating: advocate.rating,
                        reviews: advocate.totalReviews,
                        imageUrl: advocate.profileImage,
                        experience: advocate.experience,
                        onViewProfile: () =>
                            context.push('/lawyer-profile/${advocate.userId}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Advocate Card ─────────────────────────────────────────────────────

class AdvocateCard extends StatelessWidget {
  final String name;
  final String specialization;
  final String location;
  final double rating;
  final int reviews;
  final String imageUrl;
  final int experience;
  final VoidCallback onViewProfile;

  const AdvocateCard({
    super.key,
    required this.name,
    required this.specialization,
    required this.location,
    required this.rating,
    required this.reviews,
    required this.imageUrl,
    required this.experience,
    required this.onViewProfile,
  });

  ImageProvider? _resolveImage(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    // Relative path from local uploads — prepend server root
    final base = Environment.baseUrl.replaceAll('/api', '');
    final clean = url.startsWith('/') ? url : '/$url';
    return NetworkImage('$base$clean');
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImage(imageUrl);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ──────────────────────────────────────
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage: imageProvider,
            onBackgroundImageError: imageProvider != null
                ? (Object exception, StackTrace? stack) {}
                : null,
            child: imageProvider == null
                ? const Icon(Icons.person, color: Colors.white54, size: 36)
                : null,
          ),

          const SizedBox(width: 14),

          // ── Info Column ─────────────────────────────────
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + verified badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.verified, color: AppColors.primaryGold, size: 15),
                  ],
                ),

                const SizedBox(height: 3),

                // Specialization
                Text(
                  specialization,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
                ),

                const SizedBox(height: 5),

                // Location
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Color(0xFF9A9A9A), size: 13),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location.isNotEmpty ? location : 'Hyderabad, Telangana',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                // Star rating + review count
                Row(
                  children: [
                    // 5 stars (filled proportionally based on rating)
                    ...List.generate(5, (i) {
                      final full = i < rating.floor();
                      final half = !full && i < rating;
                      return Icon(
                        full
                            ? Icons.star_rounded
                            : half
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                        color: AppColors.primaryGold,
                        size: 15,
                      );
                    }),
                    const SizedBox(width: 4),
                    Text(
                      '($reviews)',
                      style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── View Profile Button ─────────────────────────
          OutlinedButton(
            onPressed: onViewProfile,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryGold, width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.primaryGold,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: Size.zero,
            ),
            child: const Text(
              'View Profile',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
