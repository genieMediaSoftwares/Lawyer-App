import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/article_model.dart';

final articlesProvider = StateNotifierProvider<ArticleNotifier, AsyncValue<List<ArticleModel>>>((ref) {
  return ArticleNotifier();
});

class ArticleNotifier extends StateNotifier<AsyncValue<List<ArticleModel>>> {
  ArticleNotifier() : super(const AsyncValue.loading()) {
    fetchArticles();
  }

  Future<void> fetchArticles({String? category, String? search}) async {
    try {
      state = const AsyncValue.loading();
      final Map<String, dynamic> params = {};
      if (category != null && category != "All") params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await DioClient.dio.get("/articles", queryParameters: params);
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final articles = list.map((item) => ArticleModel.fromJson(item)).toList();
        state = AsyncValue.data(articles);
      } else {
        state = AsyncValue.error("Failed to load articles", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> toggleBookmark(String articleId) async {
    try {
      final response = await DioClient.dio.post("/articles/$articleId/bookmark");
      if (response.data != null && response.data['success'] == true) {
        // Refresh articles to show bookmark state
        await fetchArticles();
        return true;
      }
    } catch (e) {
      // Handle error
    }
    return false;
  }
}
