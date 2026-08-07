import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Owns the single `/chat` socket and broadcasts its events as streams.
///
/// Everything that needs live chat data listens here rather than holding a
/// socket of its own. That matters for more than tidiness: the conversation
/// list used to own the socket and the open-conversation notifier borrowed it,
/// so a conversation opened before the list had finished loading found `null`,
/// gave up, and stayed dead for as long as that screen was on screen — the
/// "messages only arrive after I restart the app" case.
///
/// Rooms requested through [joinChat] are remembered and re-joined on every
/// connect, so a conversation opened while the socket is still connecting, or
/// one that outlives a dropped connection, ends up subscribed either way.
class ChatSocketService {
  io.Socket? _socket;

  /// Conversation rooms this client wants to be in, replayed on each connect.
  final Set<String> _rooms = <String>{};

  /// Distinguishes the first connect from a reconnect: only the latter means
  /// events were missed and callers need to resync.
  bool _hasConnected = false;

  /// Guards against two overlapping [connect] calls building two sockets.
  /// [connect] reads the token before constructing one, so there is an await
  /// between the null check and the assignment.
  bool _connecting = false;

  bool _disposed = false;

  /// Retry for a handshake the *server* rejected — see [_scheduleAuthRetry].
  Timer? _authRetryTimer;
  Duration? _authRetryDelay;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _chatUpdates = StreamController<Map<String, dynamic>>.broadcast();
  final _chatReads = StreamController<Map<String, dynamic>>.broadcast();
  final _chatCreated = StreamController<Map<String, dynamic>>.broadcast();
  final _typing = StreamController<Map<String, dynamic>>.broadcast();
  final _resync = StreamController<void>.broadcast();

  /// A new message in some conversation. Payload is a full message document.
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// A conversation's last message / timestamp changed.
  Stream<Map<String, dynamic>> get chatUpdates => _chatUpdates.stream;

  /// This user read a conversation (possibly on another device).
  Stream<Map<String, dynamic>> get chatReads => _chatReads.stream;

  /// Someone started a conversation with this user.
  Stream<Map<String, dynamic>> get chatCreated => _chatCreated.stream;

  /// Typing indicator. Always carries `chatId`.
  Stream<Map<String, dynamic>> get typing => _typing.stream;

  /// Fires after a reconnect. Anything derived from server state should be
  /// re-fetched: events that occurred while the socket was down were not
  /// queued anywhere and are simply gone.
  Stream<void> get resyncRequired => _resync.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects, or does nothing if a live socket already exists.
  ///
  /// Returns as soon as the socket has been created; callers do not need to
  /// await it, and the existing fire-and-forget call sites still work.
  Future<void> connect() async {
    if (_disposed) return;

    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }
    if (_connecting) return;
    _connecting = true;

    try {
      // Read the token before handing the socket its auth callback.
      //
      // The callback below reads `TokenStorage.cachedToken`, which is only a
      // mirror: it is null until something has read the token at least once,
      // and a null there authenticates the handshake with an empty string,
      // which the server rejects outright. Priming it here means the very
      // first connect of a session presents a real token.
      await TokenStorage().getToken();
      if (_disposed || _socket != null) return;

      _createSocket();
    } finally {
      _connecting = false;
    }
  }

  void _createSocket() {
    final socket = io.io(
      AppConfig.chatSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(
            AppConfig.chatSocketReconnectDelay.inMilliseconds,
          )
          .setReconnectionDelayMax(
            AppConfig.chatSocketReconnectDelayMax.inMilliseconds,
          )
          // CHAT_SOCKET_RECONNECT_ATTEMPTS is set high enough to be indefinite.
          // A capped count means a device that spends a while on a dead network
          // never reconnects at all, and chat silently stops working until the
          // app is restarted.
          .setReconnectionAttempts(AppConfig.chatSocketReconnectAttempts)
          .build(),
    );

    // A function, not a literal map: it is re-evaluated on every connect
    // attempt, so a reconnect after the token was refreshed presents the
    // current token instead of the one captured at startup.
    socket.auth = (callback) => callback({
      'token': TokenStorage.cachedToken ?? '',
    });

    socket.onConnect((_) {
      // The handshake succeeded, so any pending auth retry is moot and the
      // backoff starts fresh next time.
      _authRetryTimer?.cancel();
      _authRetryTimer = null;
      _authRetryDelay = null;

      // Re-join before announcing: a listener that reacts to the resync by
      // fetching should already be in the rooms whose events it will receive.
      for (final chatId in _rooms) {
        socket.emit('join', {'chatId': chatId});
      }

      if (_hasConnected) {
        _resync.add(null);
      }
      _hasConnected = true;
    });

    // Transport-level failure. socket.io retries these itself.
    socket.onConnectError(
      (data) => debugPrint('🔌 [ChatSocket] connect error: $data'),
    );

    // A handshake the *server* refused — an expired token, or one that had not
    // been loaded yet. socket.io surfaces a namespace middleware rejection
    // here, not through `onConnectError`, and it calls `destroy()` first, so
    // the socket is torn down and its own reconnection loop will never run.
    //
    // Left alone, a single rejection killed live chat for the rest of the app
    // session: messages then only appeared after a manual refresh or a
    // restart, on both the client and the lawyer side.
    socket.onError((data) {
      debugPrint('🔌 [ChatSocket] error: $data');
      _scheduleAuthRetry();
    });
    socket.onDisconnect(
      (reason) => debugPrint('🔌 [ChatSocket] disconnected: $reason'),
    );

    socket.on('message', (data) => _emit(_messages, data));
    socket.on('chat_updated', (data) => _emit(_chatUpdates, data));
    socket.on('chat_read', (data) => _emit(_chatReads, data));
    socket.on('chat_created', (data) => _emit(_chatCreated, data));
    socket.on('typing', (data) => _emit(_typing, data));

    _socket = socket;
    socket.connect();
  }

  /// Rebuilds the socket after the server refused the handshake.
  ///
  /// Only for that case: socket.io destroys the socket on a middleware
  /// rejection, so [io.Socket.active] goes false and nothing else will bring
  /// it back. Every other failure is already being retried internally, and
  /// racing it here would open a second connection.
  ///
  /// Backoff runs between the same bounds as the built-in reconnection
  /// (CHAT_SOCKET_RECONNECT_DELAY_MS to CHAT_SOCKET_RECONNECT_DELAY_MAX_MS),
  /// so a token that stays invalid — a genuinely expired session — settles
  /// into a slow poll rather than hammering the server.
  void _scheduleAuthRetry() {
    if (_disposed) return;

    final socket = _socket;
    if (socket == null || socket.active) return;
    if (_authRetryTimer?.isActive ?? false) return;

    final maxDelay = AppConfig.chatSocketReconnectDelayMax;
    final delay = _authRetryDelay ?? AppConfig.chatSocketReconnectDelay;
    final doubled = delay * 2;
    _authRetryDelay = doubled > maxDelay ? maxDelay : doubled;

    debugPrint(
      '🔌 [ChatSocket] handshake rejected; retrying in ${delay.inMilliseconds}ms',
    );

    _authRetryTimer = Timer(delay, () {
      if (_disposed) return;

      // The old socket is dead and cannot be revived — drop it and build a new
      // one. `connect` re-reads the token first, which is the point: the retry
      // only helps if it presents a token the previous attempt did not have.
      _socket?.dispose();
      _socket = null;
      _hasConnected = false;
      connect();
    });
  }

  /// Subscribes to a conversation's room, now and after any future reconnect.
  void joinChat(String chatId) {
    if (chatId.isEmpty) return;
    _rooms.add(chatId);
    if (isConnected) {
      _socket!.emit('join', {'chatId': chatId});
    }
  }

  /// Stops following a conversation. Safe to call for a room never joined.
  void leaveChat(String chatId) {
    if (chatId.isEmpty) return;
    _rooms.remove(chatId);
    if (isConnected) {
      _socket!.emit('leave', {'chatId': chatId});
    }
  }

  void emitTyping({
    required String chatId,
    required String userName,
    required bool isTyping,
  }) {
    if (!isConnected) return;
    _socket!.emit('typing', {
      'chatId': chatId,
      'userName': userName,
      'isTyping': isTyping,
    });
  }

  /// Tears the connection down, e.g. on sign-out. [connect] can be called
  /// again afterwards to start a fresh session.
  void disconnect() {
    // Before dropping the socket: a pending retry would otherwise fire after
    // sign-out and reconnect the session that was just torn down.
    _authRetryTimer?.cancel();
    _authRetryTimer = null;
    _authRetryDelay = null;

    _rooms.clear();
    _hasConnected = false;
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _messages.close();
    _chatUpdates.close();
    _chatReads.close();
    _chatCreated.close();
    _typing.close();
    _resync.close();
  }

  void _emit(StreamController<Map<String, dynamic>> sink, dynamic data) {
    if (sink.isClosed) return;
    final map = _asJsonMap(data);
    if (map != null) sink.add(map);
  }

  /// Normalises a socket payload into plain Dart JSON.
  ///
  /// socket.io hands over maps keyed `dynamic`, and on Flutter Web the values
  /// come back as JS-backed collections. Model parsers test `is
  /// Map<String, dynamic>`, which is false for both, so a nested object such as
  /// a populated `sender` was silently read as empty — socket-delivered
  /// messages arrived with no sender id at all. Converting the whole tree once,
  /// here, keeps every parser downstream working on real JSON.
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
    if (value is Iterable) {
      return value.map(_convert).toList();
    }
    return value;
  }
}
