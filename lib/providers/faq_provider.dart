import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/faq_model.dart';

final faqsProvider = StateNotifierProvider<FaqNotifier, AsyncValue<List<FaqModel>>>((ref) {
  return FaqNotifier();
});

class FaqNotifier extends StateNotifier<AsyncValue<List<FaqModel>>> {
  FaqNotifier() : super(const AsyncValue.loading()) {
    fetchFaqs();
  }

  Future<void> fetchFaqs({String? category, String? search}) async {
    try {
      state = const AsyncValue.loading();
      final Map<String, dynamic> params = {};
      if (category != null && category != "All") params['category'] = category;
      if (search != null && search.isNotEmpty) params['search'] = search;

      final response = await DioClient.dio.get("/faqs", queryParameters: params);
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final faqs = list.map((item) => FaqModel.fromJson(item)).toList();
        state = AsyncValue.data(faqs);
      } else {
        state = AsyncValue.error("Failed to load FAQs", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
