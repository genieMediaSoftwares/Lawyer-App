import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env.dart';
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
  void connect() {
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }

    final socket = io.io(
      '${Environment.baseSocketUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          // Retry indefinitely. A capped count means a device that spends a
          // while on a dead network never reconnects at all, and chat silently
          // stops working until the app is restarted.
          //
          // 2^30 rather than 2^31: bitwise operators are 32-bit and signed on
          // the web, so `1 << 31` is -2147483648 there. A negative attempt
          // count meant the browser build gave up reconnecting immediately —
          // the exact opposite of what this line intends. 2^30 attempts is
          // still indefinite in practice and evaluates the same everywhere.
          .setReconnectionAttempts(1 << 30)
          .build(),
    );

    // A function, not a literal map: it is re-evaluated on every connect
    // attempt, so a reconnect after the token was refreshed presents the
    // current token instead of the one captured at startup.
    socket.auth = (callback) => callback({
      'token': TokenStorage.cachedToken ?? '',
    });

    socket.onConnect((_) {
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

    socket.onConnectError(
      (data) => debugPrint('🔌 [ChatSocket] connect error: $data'),
    );
    socket.onError((data) => debugPrint('🔌 [ChatSocket] error: $data'));
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
    _rooms.clear();
    _hasConnected = false;
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
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
  /// come back as JS-backed collections. Model parsers test
  /// `is Map<String, dynamic>`, which is false for both, so a nested object such as
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
