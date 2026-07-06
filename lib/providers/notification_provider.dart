import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/dio_client.dart';
import '../models/notification_model.dart';

final notificationsProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<List<NotificationModel>>>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationNotifier() : super(const AsyncValue.loading()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      state = const AsyncValue.loading();
      final response = await DioClient.dio.get("/notifications");
      if (response.data != null && response.data['success'] == true) {
        final list = response.data['data'] as List;
        final notifications = list.map((item) => NotificationModel.fromJson(item)).toList();
        state = AsyncValue.data(notifications);
      } else {
        state = AsyncValue.error("Failed to load notifications", StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final response = await DioClient.dio.put("/notifications/$id/read");
      if (response.data != null && response.data['success'] == true) {
        state.whenData((currentNotifications) {
          state = AsyncValue.data(
            currentNotifications.map((n) => n.id == id ? NotificationModel.fromJson(response.data['data']) : n).toList()
          );
        });
      }
    } catch (e) {
      // Handle error
    }
  }
}
