import 'package:flutter_riverpod/flutter_riverpod.dart';

class SelectedCategoryState {
  final String? categoryId;
  final String? subcategory;

  const SelectedCategoryState({this.categoryId, this.subcategory});

  SelectedCategoryState copyWith({
    String? categoryId,
    String? subcategory,
    bool clearSubcategory = false,
  }) {
    return SelectedCategoryState(
      categoryId: categoryId ?? this.categoryId,
      subcategory: clearSubcategory ? null : (subcategory ?? this.subcategory),
    );
  }
}

class SelectedCategoryNotifier extends StateNotifier<SelectedCategoryState> {
  SelectedCategoryNotifier() : super(const SelectedCategoryState());

  void selectCategory(String? categoryId) {
    state = SelectedCategoryState(categoryId: categoryId, subcategory: null);
  }

  void selectSubcategory(String? categoryId, String? subcategory) {
    state = SelectedCategoryState(categoryId: categoryId, subcategory: subcategory);
  }

  void clearSelection() {
    state = const SelectedCategoryState();
  }
}

final selectedCategoryProvider =
    StateNotifierProvider<SelectedCategoryNotifier, SelectedCategoryState>((ref) {
  return SelectedCategoryNotifier();
});
