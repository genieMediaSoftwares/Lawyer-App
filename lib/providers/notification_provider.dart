import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/config/env.dart';
import '../core/network/dio_client.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final bool isLoadMore;
  final String? errorMessage;
  final int unreadCount;
  final bool isOffline;
  final int page;
  final bool hasMore;

  const NotificationState({
    required this.notifications,
    required this.isLoading,
    required this.isLoadMore,
    this.errorMessage,
    required this.unreadCount,
    required this.isOffline,
    required this.page,
    required this.hasMore,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? isLoadMore,
    String? errorMessage,
    int? unreadCount,
    bool? isOffline,
    int? page,
    bool? hasMore,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      errorMessage: errorMessage, // Note: does not support resetting to null if passing null is required, but it serves our resets
      unreadCount: unreadCount ?? this.unreadCount,
      isOffline: isOffline ?? this.isOffline,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final notificationsProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final authState = ref.watch(authProvider);
  return NotificationNotifier(authState.userId);
});

class NotificationNotifier extends StateNotifier<NotificationState> {
  final String? userId;
  IO.Socket? _socket;
  bool _isDisposed = false;

  NotificationNotifier(this.userId)
      : super(const NotificationState(
          notifications: [],
          isLoading: false,
          isLoadMore: false,
          unreadCount: 0,
          isOffline: false,
          page: 1,
          hasMore: true,
        )) {
    if (userId != null) {
      init();
    }
  }

  Future<void> init() async {
    await fetchNotifications(refresh: true);
    _initSocket();
  }

  void _initSocket() {
    if (userId == null) return;

    final base = Environment.baseUrl.replaceAll('/api', '');
    final socketUrl = '$base/notifications';

    _socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(2000)
      .setReconnectionDelayMax(5000)
      .setReconnectionAttempts(99)
      .build());

    _socket?.connect();

    _socket?.onConnect((_) {
      _socket?.emit('register', {'userId': userId});
      if (!_isDisposed) {
        state = state.copyWith(isOffline: false);
      }
    });

    _socket?.onDisconnect((_) {
      if (!_isDisposed) {
        state = state.copyWith(isOffline: true);
      }
    });

    _socket?.onConnectError((err) {
      if (!_isDisposed) {
        state = state.copyWith(isOffline: true);
      }
    });

    _socket?.on('new_notification', (data) {
      if (data != null && !_isDisposed) {
        final newNotification = NotificationModel.fromJson(data);
        
        state = state.copyWith(
          notifications: [newNotification, ...state.notifications],
          unreadCount: state.unreadCount + 1,
        );
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (userId == null) return;
    if (refresh) {
      if (!_isDisposed) {
        state = state.copyWith(isLoading: true, page: 1, hasMore: true, errorMessage: null);
      }
    } else {
      if (!state.hasMore || state.isLoadMore) return;
      if (!_isDisposed) {
        state = state.copyWith(isLoadMore: true, errorMessage: null);
      }
    }

    try {
      final pageToFetch = refresh ? 1 : state.page + 1;
      final response = await DioClient.dio.get("/notifications", queryParameters: {
        "page": pageToFetch,
        "limit": 15,
      });

      if (_isDisposed) return;

      if (response.data != null && response.data['success'] == true) {
        final responseData = response.data['data'];
        final list = responseData['notifications'] as List;
        final fetchedNotifications = list.map((item) => NotificationModel.fromJson(item)).toList();
        
        final unreadCount = responseData['unreadCount'] ?? 0;
        final pagination = responseData['pagination'] ?? {};
        final totalPages = pagination['pages'] ?? 1;
        final hasMore = pageToFetch < totalPages;

        state = state.copyWith(
          notifications: refresh
              ? fetchedNotifications
              : [...state.notifications, ...fetchedNotifications],
          isLoading: false,
          isLoadMore: false,
          unreadCount: unreadCount,
          page: pageToFetch,
          hasMore: hasMore,
          isOffline: false,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isLoadMore: false,
          errorMessage: "Failed to load notifications",
        );
      }
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        isLoadMore: false,
        errorMessage: "Network error occurred",
      );
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      // Optimistic UI update
      final wasUnread = state.notifications.any((n) => n.id == id && !n.isRead);
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
        unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 99999) : state.unreadCount,
      );

      final response = await DioClient.dio.put("/notifications/$id/read");
      if (response.data != null && response.data['success'] == true) {
        final updatedNotification = NotificationModel.fromJson(response.data['data']);
        state = state.copyWith(
          notifications: state.notifications.map((n) => n.id == id ? updatedNotification : n).toList(),
        );
      }
    } catch (e) {
      // Revert if error
    }
  }

  Future<void> markAllAsRead() async {
    try {
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
        unreadCount: 0,
      );

      await DioClient.dio.put("/notifications/read-all");
    } catch (e) {
      // Log error
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      final wasUnread = state.notifications.any((n) => n.id == id && !n.isRead);
      
      state = state.copyWith(
        notifications: state.notifications.where((n) => n.id != id).toList(),
        unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 99999) : state.unreadCount,
      );

      await DioClient.dio.delete("/notifications/$id");
    } catch (e) {
      // Log error
    }
  }

  Future<void> clearAllFromSender(String senderId) async {
    try {
      final countClearedUnread = state.notifications
          .where((n) => n.senderId == senderId && !n.isRead)
          .length;
      state = state.copyWith(
        notifications: state.notifications.where((n) => n.senderId != senderId).toList(),
        unreadCount: (state.unreadCount - countClearedUnread).clamp(0, 99999),
      );

      await DioClient.dio.delete("/notifications/clear-sender/$senderId");
    } catch (e) {
      // Log error
    }
  }

  Future<void> clearAll() async {
    try {
      state = state.copyWith(
        notifications: [],
        unreadCount: 0,
        hasMore: false,
      );

      await DioClient.dio.delete("/notifications/clear-all");
    } catch (e) {
      // Log error
    }
  }
}
