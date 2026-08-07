import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/config/app_config.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
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

/// Live counts for the notification centre's filter tabs.
///
/// Derived from the same list the screen renders, so a tab badge can never
/// disagree with what is below it.
class NotificationCounts {
  /// Everything currently loaded.
  final int all;

  final int unread;

  /// Raised by the other party (a client, or a lawyer) rather than by the
  /// system. Backs the "Clients"/"Lawyers" tab.
  final int fromPeople;

  const NotificationCounts({
    required this.all,
    required this.unread,
    required this.fromPeople,
  });
}

final notificationCountsProvider = Provider<NotificationCounts>((ref) {
  final items = ref.watch(
    notificationsProvider.select((s) => s.notifications),
  );
  return NotificationCounts(
    all: items.length,
    unread: items.where((n) => !n.isRead).length,
    fromPeople: items.where((n) => (n.senderId ?? '').isNotEmpty).length,
  );
});

final notificationsProvider = StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  // Only the identity matters. Watching the whole auth state tore the notifier
  // down — socket included — every time an unrelated field changed, such as
  // the user editing their name or photo.
  final userId = ref.watch(authProvider.select((s) => s.userId));
  return NotificationNotifier(userId);
});

class NotificationNotifier extends StateNotifier<NotificationState> {
  final String? userId;
  io.Socket? _socket;
  bool _isDisposed = false;

  /// Distinguishes the first connect from a reconnect. Only the latter means
  /// notifications may have been missed.
  bool _hasConnected = false;

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
    unawaited(_initSocket());
  }

  Future<void> _initSocket() async {
    if (userId == null) return;

    // The handshake is rejected without a valid JWT.
    final token = await TokenStorage().getToken();
    if (token == null || token.isEmpty) return;

    _socket = io.io(AppConfig.notificationSocketUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      // Connected explicitly below, once the auth callback is in place.
      .disableAutoConnect()
      .enableReconnection()
      .setReconnectionDelay(
        AppConfig.notificationSocketReconnectDelay.inMilliseconds,
      )
      .setReconnectionDelayMax(
        AppConfig.notificationSocketReconnectDelayMax.inMilliseconds,
      )
      .setReconnectionAttempts(AppConfig.notificationSocketReconnectAttempts)
      .build());

    // A function, not the literal map `setAuth` takes: it is re-evaluated on
    // every connect attempt, so a reconnect after the token was refreshed
    // presents the current one. With the map, the token captured here was
    // replayed forever, and once it expired every reconnect was refused — so
    // new-message alerts and unread badges stopped arriving until a restart.
    _socket?.auth = (callback) => callback({
      'token': TokenStorage.cachedToken ?? token,
    });

    _socket?.connect();

    _socket?.onConnect((_) {
      // The personal alert room is joined server-side from the authenticated
      // handshake; emitting a client-chosen userId is no longer honoured.
      if (_isDisposed) return;
      state = state.copyWith(isOffline: false);

      // Nothing queues notifications raised while the socket was down, so a
      // reconnect has to go back to the server for them. Silent: the list is
      // already on screen and must not blank into a spinner.
      if (_hasConnected) {
        fetchNotifications(refresh: true, silent: true);
      }
      _hasConnected = true;
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
      if (data == null || _isDisposed) return;

      // socket.io hands over Map<dynamic, dynamic>, and on Flutter Web the
      // values are JS-backed. The parser tests `is Map<String, dynamic>` for
      // the populated sender, which is false for both, so without converting
      // the tree first the sender is silently read as empty.
      final json = _asJsonMap(data);
      if (json == null) return;

      final incoming = NotificationModel.fromJson(json);

      // The same notification can arrive twice — once live, once in the
      // refetch that follows a reconnect — and used to be appended both times.
      if (state.notifications.any((n) => n.id == incoming.id)) return;

      state = state.copyWith(
        notifications: [incoming, ...state.notifications],
        unreadCount: incoming.isRead ? state.unreadCount : state.unreadCount + 1,
      );
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  /// Loads a page of notifications.
  ///
  /// [silent] keeps the current list on screen while a refresh is in flight,
  /// for background reconciles (a reconnect, returning to the screen) where a
  /// spinner over correct data is a regression rather than feedback.
  Future<void> fetchNotifications({bool refresh = false, bool silent = false}) async {
    if (userId == null) return;
    if (refresh) {
      if (!_isDisposed) {
        state = state.copyWith(
          isLoading: !silent,
          page: 1,
          hasMore: true,
          errorMessage: null,
        );
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
          // A failed background reconcile must not replace a good list with an
          // error screen; the data on screen is still the best we have.
          errorMessage: silent ? null : "Failed to load notifications",
        );
      }
    } catch (e) {
      if (_isDisposed) return;
      state = state.copyWith(
        isLoading: false,
        isLoadMore: false,
        errorMessage: silent ? null : "Network error occurred",
      );
    }
  }

  /// Normalises a socket payload into plain Dart JSON, recursively.
  static Map<String, dynamic>? _asJsonMap(dynamic data) {
    final converted = _convert(data);
    return converted is Map<String, dynamic> ? converted : null;
  }

  static dynamic _convert(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _convert(entry.value),
      };
    }
    if (value is Iterable) return value.map(_convert).toList();
    return value;
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
