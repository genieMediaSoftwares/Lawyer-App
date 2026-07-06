import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../providers/favorite_provider.dart';
import '../../../../routes/route_names.dart';
import '../../../../core/widgets/app_drawer.dart';

class FavoriteLawyersScreen extends ConsumerStatefulWidget {
  const FavoriteLawyersScreen({super.key});

  @override
  ConsumerState<FavoriteLawyersScreen> createState() => _FavoriteLawyersScreenState();
}

class _FavoriteLawyersScreenState extends ConsumerState<FavoriteLawyersScreen> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(favoritesProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("Favorite Lawyers", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: favoritesState.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border, size: 72, color: AppColors.grey300),
                    const SizedBox(height: 16),
                    const Text("No Favorites Added Yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.navyBlue)),
                    const SizedBox(height: 8),
                    const Text("Select the heart icon on any lawyer's profile page to save them here.", textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey400)),
                  ],
                ),
              ),
            );
          }

          return _isGridView ? _buildGrid(items) : _buildList(items);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildList(List<FavoriteItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final fav = items[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.grey200)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: fav.lawyerImage.isNotEmpty ? NetworkImage(fav.lawyerImage) : null,
                  child: fav.lawyerImage.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fav.lawyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navyBlue)),
                      Text(fav.specialization, style: const TextStyle(color: AppColors.grey500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: AppColors.gold, size: 14),
                          Text(" ${fav.rating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                      onPressed: () => _removeFavorite(fav.id),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/lawyer-profile/${fav.lawyerUserId}'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(60, 30)),
                      child: const Text("Book", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<FavoriteItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final fav = items[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.grey200)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: fav.lawyerImage.isNotEmpty ? NetworkImage(fav.lawyerImage) : null,
                      child: fav.lawyerImage.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    Positioned(
                      right: -10,
                      top: -10,
                      child: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red, size: 18),
                        onPressed: () => _removeFavorite(fav.id),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(fav.lawyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navyBlue), textAlign: TextAlign.center, maxLines: 1),
                Text(fav.specialization, style: const TextStyle(color: AppColors.grey500, fontSize: 11), textAlign: TextAlign.center, maxLines: 1),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: AppColors.gold, size: 14),
                    Text(" ${fav.rating}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => context.push('/lawyer-profile/${fav.lawyerUserId}'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navyBlue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 32)),
                  child: const Text("Book Now", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeFavorite(String favoriteId) async {
    final success = await ref.read(favoritesProvider.notifier).removeFavorite(favoriteId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Removed from favorite lawyers.")));
    }
  }
}
