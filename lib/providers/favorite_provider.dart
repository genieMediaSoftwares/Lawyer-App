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

final favoritesProvider =
    StateNotifierProvider<FavoriteNotifier, AsyncValue<List<FavoriteItem>>>((
      ref,
    ) {
      return FavoriteNotifier();
    });

class FavoriteNotifier extends StateNotifier<AsyncValue<List<FavoriteItem>>> {
  FavoriteNotifier() : super(const AsyncValue.loading()) {
    fetchFavorites();
  }

  /// Reloads the list from the server.
  ///
  /// Only shows a loading state when there is nothing to show yet. Setting
  /// `AsyncValue.loading()` unconditionally threw away the current list on
  /// every refresh, so a screen watching this provider blanked out mid-toggle
  /// and — if the reload then failed — was left showing empty or an error
  /// rather than the favourites it already had.
  Future<void> fetchFavorites() async {
    try {
      if (!state.hasValue) state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/favorites");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final items = list.map((item) => FavoriteItem.fromJson(item)).toList();
        state = AsyncValue.data(items);
      } else if (!state.hasValue) {
        state = AsyncValue.error(
          "Failed to load favorites",
          StackTrace.current,
        );
      }
    } catch (e, stack) {
      // Keep whatever is already on screen; a failed refresh should not erase
      // a list the user can still act on.
      if (!state.hasValue) state = AsyncValue.error(e, stack);
    }
  }

  /// Adds or removes [lawyerUserId] from favourites.
  ///
  /// The server endpoint is a toggle and reports which way it went. An
  /// un-favourite is applied to local state straight away — the entry is
  /// already in the list, so no round trip is needed to drop it. An add has to
  /// reload, because the POST response carries the bare Favorite document
  /// without the populated lawyer and profile this list renders.
  Future<bool> toggleFavorite(String lawyerUserId) async {
    final previous = state;
    try {
      final response = await DioClient.dio.post(
        "/favorites",
        data: {"lawyerId": lawyerUserId},
      );

      if (response.data != null && response.data['success'] == true) {
        final isFavorite = response.data['data']?['isFavorite'] == true;

        if (!isFavorite) {
          state.whenData(
            (current) => state = AsyncValue.data(
              current.where((f) => f.lawyerUserId != lawyerUserId).toList(),
            ),
          );
        } else {
          await fetchFavorites();
        }
        return true;
      }
    } catch (e) {
      // Put back exactly what was there before, so a failed toggle leaves the
      // heart and the list agreeing with the server.
      state = previous;
    }
    return false;
  }

  Future<bool> removeFavorite(String favoriteId) async {
    try {
      final response = await DioClient.dio.delete("/favorites/$favoriteId");
      if (response.data != null && response.data['success'] == true) {
        state.whenData((currentFavs) {
          state = AsyncValue.data(
            currentFavs.where((f) => f.id != favoriteId).toList(),
          );
        });
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
