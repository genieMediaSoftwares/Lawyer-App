import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';

class FavoriteItem {
  final String id;
  final String lawyerUserId;
  final String lawyerName;
  final String lawyerImage;
  final String specialization;
  final double rating;
  final int fee;

  FavoriteItem({
    required this.id,
    required this.lawyerUserId,
    required this.lawyerName,
    required this.lawyerImage,
    required this.specialization,
    required this.rating,
    required this.fee,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    final lawyerUser = json['lawyer'] ?? {};
    final profile = json['profile'] ?? {};
    
    return FavoriteItem(
      id: json['_id'] ?? '',
      lawyerUserId: lawyerUser['_id'] ?? '',
      lawyerName: lawyerUser['fullName'] ?? 'Advocate',
      lawyerImage: lawyerUser['profileImage'] ?? '',
      specialization: profile['specialization'] ?? '',
      rating: (profile['rating'] as num?)?.toDouble() ?? 0.0,
      fee: profile['consultationFee'] ?? 0,
    );
  }
}

final favoritesProvider = StateNotifierProvider<FavoriteNotifier, AsyncValue<List<FavoriteItem>>>((ref) {
  return FavoriteNotifier();
});

class FavoriteNotifier extends StateNotifier<AsyncValue<List<FavoriteItem>>> {
  FavoriteNotifier() : super(const AsyncValue.loading()) {
    fetchFavorites();
  }

  Future<void> fetchFavorites() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/favorites");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final items = list.map((item) => FavoriteItem.fromJson(item)).toList();
        state = AsyncValue.data(items);
      } else {
        state = AsyncValue.error("Failed to load favorites", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> toggleFavorite(String lawyerUserId) async {
    try {
      final response = await DioClient.dio.post("/favorites", data: {
        "lawyerId": lawyerUserId,
      });
      if (response.data != null && response.data['success'] == true) {
        await fetchFavorites();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }

  Future<bool> removeFavorite(String favoriteId) async {
    try {
      final response = await DioClient.dio.delete("/favorites/$favoriteId");
      if (response.data != null && response.data['success'] == true) {
        state.whenData((currentFavs) {
          state = AsyncValue.data(currentFavs.where((f) => f.id != favoriteId).toList());
        });
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
