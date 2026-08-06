import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../core/network/chat_socket.dart';
import '../core/network/dio_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

import 'auth_provider.dart';
import 'notification_provider.dart';

/// The one `/chat` socket for the whole app.
final chatSocketProvider = Provider<ChatSocketService>((ref) {
  final service = ChatSocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Tracks which conversation is on screen.
///
/// Drives two decisions: whether an arriving message should be marked read
/// immediately, and whether it should raise the unread badge.
///
/// Deliberately a plain mutable object rather than a `StateProvider`. Nothing
/// rebuilds from this value — only the notifiers read it, imperatively — and
/// the chat screen has to set it from `initState`/`dispose`, where modifying
/// a provider's state throws "Tried to modify a provider while the widget tree
/// was building". Mutating a field on an object handed out by a `Provider` is
/// not a provider modification, so this is legal from any lifecycle and can
/// stay synchronous.
class ActiveChatTracker {
  String? chatId;

  bool isOnScreen(String id) => chatId == id;

  /// Releases [id] only if it is still the one on screen. Pushing chat B
  /// disposes chat A *afterwards*, so an unconditional clear would blank the
  /// id while B is open.
  void release(String id) {
    if (chatId == id) chatId = null;
  }
}

final activeChatProvider = Provider<ActiveChatTracker>(
  (ref) => ActiveChatTracker(),
);

/// Name of whoever is typing in a conversation, or null.
final chatTypingProvider = StateProvider.family<String?, String>(
  (ref, chatId) => null,
);

final _random = Random();

/// Upper bound for the random half of a client id.
///
/// 2^30, *not* 2^32. Dart's bitwise operators are 32-bit on the web, so
/// `1 << 32` evaluates to 0 there — and `Random.nextInt(0)` throws
/// "max must be in range 0 < max <= 2^32". The literal worked on the VM, where
/// ints are 64-bit, so the crash only ever appeared in the browser. Anything up
/// to 2^30 is identical on both platforms.
const int _clientIdRandomMax = 1 << 30;

/// Ids for optimistic messages. Unique per device without pulling in a uuid
/// dependency; the server only ever compares them within one conversation, and
/// the microsecond timestamp already separates ids a billion-value random
/// suffix might not.
String _newClientId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(_clientIdRandomMax)}';

// ────────────────────────────────────────────────────────────────────────────
// chatsProvider — the conversation list
// ────────────────────────────────────────────────────────────────────────────
final chatsProvider =
    StateNotifierProvider<ChatsNotifier, AsyncValue<List<ChatModel>>>((ref) {
      final isLoggedIn = ref.watch(authProvider.select((s) => s.isLoggedIn));
      return ChatsNotifier(ref, isLoggedIn: isLoggedIn);
    });

class ChatsNotifier extends StateNotifier<AsyncValue<List<ChatModel>>> {
  final Ref _ref;

  /// Held rather than looked up on demand: `dispose` runs while the owning
  /// provider is being torn down, and `ref.read` is no longer legal by then.
  final ChatSocketService _socket;

  final List<StreamSubscription<dynamic>> _subs = [];

  ChatsNotifier(Ref ref, {required bool isLoggedIn})
    : _ref = ref,
      _socket = ref.read(chatSocketProvider),
      super(isLoggedIn ? const AsyncValue.loading() : const AsyncValue.data([])) {
    if (!isLoggedIn) {
      // Signing out must tear the socket down, or the previous session's
      // token keeps a live connection and its events land in the next one.
      _socket.disconnect();
      return;
    }

    // Connect before the first fetch. The socket no longer depends on the list
    // having loaded, so a conversation opened immediately after login is live
    // from the start.
    _socket.connect();

    _subs.addAll([
      _socket.chatUpdates.listen(_onChatUpdated),
      _socket.chatReads.listen(_onChatRead),
      _socket.chatCreated.listen((_) => fetchChats(silent: true)),
      _socket.resyncRequired.listen((_) => fetchChats(silent: true)),
      _socket.messages.listen((_) => fetchChats(silent: true)),
    ]);

    fetchChats();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  /// Loads the conversation list.
  ///
  /// [silent] leaves the current list on screen while the request is in
  /// flight. Every background refresh uses it — a socket event or a return
  /// from a chat should not blank the list into a shimmer.
  Future<void> fetchChats({bool silent = false}) async {
    try {
      if (!silent) state = const AsyncValue.loading();

      final response = await DioClient.dio.get("/chats");
      if (response.data != null && response.data['success'] == true) {
        final raw = response.data['data'];
        final list = raw is List ? raw : const [];
        final chats = list
            .map(
              (item) =>
                  ChatModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
        _setChats(chats);
      } else if (!silent) {
        state = AsyncValue.error("Failed to load chats", StackTrace.current);
      }
    } catch (e, stack) {
      if (!silent) state = AsyncValue.error(e, stack);
      debugPrint('💬 [ChatsNotifier] fetchChats error: $e');
    }
  }

  void _setChats(List<ChatModel> chats) {
    if (!mounted) return;
    final sorted = _sortedByRecency(chats);
    state = AsyncValue.data(sorted);

    // Joining is idempotent server-side, so replaying it for the whole list
    // costs nothing and covers conversations created since the last connect.
    for (final chat in sorted) {
      _socket.joinChat(chat.id);
    }
  }

  static List<ChatModel> _sortedByRecency(List<ChatModel> chats) {
    final copy = [...chats];
    copy.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return copy;
  }

  void _updateChat(String chatId, ChatModel Function(ChatModel) update) {
    if (!mounted) return;
    final chats = state.valueOrNull;
    if (chats == null) return;
    if (!chats.any((c) => c.id == chatId)) return;

    state = AsyncValue.data(
      _sortedByRecency([
        for (final c in chats) c.id == chatId ? update(c) : c,
      ]),
    );
  }

  void _onChatUpdated(Map<String, dynamic> data) {
    if (!mounted) return;

    final chatId = (data['chatId'] ?? '').toString();
    if (chatId.isEmpty) return;

    final chats = state.valueOrNull;
    if (chats == null) {
      fetchChats(silent: true);
      return;
    }

    if (!chats.any((c) => c.id == chatId)) {
      // First message of a conversation this device has never seen.
      fetchChats(silent: true);
      return;
    }

    final senderId = (data['senderId'] ?? '').toString();
    final currentUserId = _ref.read(authProvider).userId ?? '';
    final isMine = senderId == currentUserId;
    final isOpen = _ref.read(activeChatProvider).isOnScreen(chatId);

    final lastMessageAt =
        DateTime.tryParse((data['lastMessageAt'] ?? '').toString())?.toLocal() ??
        DateTime.now();

    _updateChat(
      chatId,
      (c) => c.copyWith(
        lastMessage: (data['lastMessage'] ?? '').toString(),
        lastMessageAt: lastMessageAt,
        lastMessageSender: senderId,
        // My own message, or one arriving in the conversation I am looking
        // at, is already accounted for.
        unreadCount: (isMine || isOpen) ? c.unreadCount : c.unreadCount + 1,
      ),
    );
  }

  void _onChatRead(Map<String, dynamic> data) {
    final chatId = (data['chatId'] ?? '').toString();
    if (chatId.isNotEmpty) markChatAsRead(chatId);
  }

  /// Clears the unread badge for a conversation.
  void markChatAsRead(String chatId) {
    _updateChat(chatId, (c) => c.copyWith(unreadCount: 0));
  }

  /// Moves a conversation to the top with a new preview, before the server
  /// has confirmed the message. The matching `chat_updated` arrives moments
  /// later and overwrites this with the authoritative values.
  void applyLocalPreview(String chatId, String lastMessage, DateTime at) {
    final currentUserId = _ref.read(authProvider).userId ?? '';
    _updateChat(
      chatId,
      (c) => c.copyWith(
        lastMessage: lastMessage,
        lastMessageAt: at,
        lastMessageSender: currentUserId,
      ),
    );
  }

  /// Returns the conversation with [otherUserId], creating it if needed.
  Future<ChatModel?> getOrCreateChat(String otherUserId) async {
    try {
      final response = await DioClient.dio.post(
        "/chats",
        data: {"otherUserId": otherUserId},
      );

      if (response.data != null && response.data['success'] == true) {
        final chat = ChatModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );

        _socket.joinChat(chat.id);

        // Show it straight away, then reconcile in the background. Awaiting a
        // full list fetch here delayed every "Chat Now" tap by a round trip.
        final chats = state.valueOrNull;
        if (mounted && chats != null && !chats.any((c) => c.id == chat.id)) {
          state = AsyncValue.data(_sortedByRecency([chat, ...chats]));
        }
        unawaited(fetchChats(silent: true));

        return chat;
      }
    } catch (e) {
      debugPrint('💬 [ChatsNotifier] getOrCreateChat error: $e');
    }
    return null;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// chatMessagesProvider — the messages of ONE conversation
// ────────────────────────────────────────────────────────────────────────────
final chatMessagesProvider =
    StateNotifierProvider.autoDispose
        .family<ChatMessagesNotifier, AsyncValue<List<MessageModel>>, String>((
          ref,
          chatId,
        ) {
          return ChatMessagesNotifier(chatId, ref);
        });

class ChatMessagesNotifier
    extends StateNotifier<AsyncValue<List<MessageModel>>> {
  final String chatId;
  final Ref _ref;

  /// See [ChatsNotifier._socket] — `dispose` cannot go through `ref`.
  final ChatSocketService _socket;

  final List<StreamSubscription<dynamic>> _subs = [];

  ChatMessagesNotifier(this.chatId, Ref ref)
    : _ref = ref,
      _socket = ref.read(chatSocketProvider),
      super(const AsyncValue.loading()) {
    // Connect if the conversation was opened before the list ever loaded, and
    // register interest in the room. Both are safe while still connecting: the
    // room is replayed once the connection is up.
    _socket.connect();
    _socket.joinChat(chatId);

    _subs.addAll([
      _socket.messages.listen(_onMessage),
      _socket.typing.listen(_onTyping),
      _socket.resyncRequired.listen((_) => fetchMessages(silent: true)),
    ]);

    fetchMessages();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _socket.leaveChat(chatId);
    super.dispose();
  }

  bool get _isOnScreen => _ref.read(activeChatProvider).isOnScreen(chatId);

  // ── Incoming ──────────────────────────────────────────────────────────────

  void _onMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    if ((data['chat'] ?? '').toString() != chatId) return;

    try {
      _mergeMessage(MessageModel.fromJson(data));

      // Only while the user is actually looking at the conversation. Marking
      // read from a notifier that merely happens to still be alive silently
      // cleared unread badges for messages nobody had seen.
      if (_isOnScreen) markAsRead();
    } catch (e) {
      debugPrint('💬 [ChatMessages:$chatId] parse error: $e');
    }
  }

  void _onTyping(Map<String, dynamic> data) {
    if (!mounted) return;
    // One socket carries every conversation, so without this check a lawyer
    // typing in one thread showed "typing…" on all of them.
    if ((data['chatId'] ?? '').toString() != chatId) return;

    final isTyping = data['isTyping'] == true;
    _ref.read(chatTypingProvider(chatId).notifier).state = isTyping
        ? (data['userName'] ?? '').toString()
        : null;
  }

  /// Inserts [incoming], replacing any local copy of the same message.
  ///
  /// A message the current user sent can reach here three ways — the
  /// optimistic bubble, the POST response and the socket broadcast — in any
  /// order. Matching on `clientId` first, then on the server id, collapses
  /// them into one entry regardless.
  void _mergeMessage(MessageModel incoming) {
    if (!mounted) return;
    final current = state.valueOrNull ?? const <MessageModel>[];

    final merged = <MessageModel>[];
    var replaced = false;
    for (final existing in current) {
      final matches =
          (incoming.clientId.isNotEmpty &&
              existing.clientId == incoming.clientId) ||
          existing.id == incoming.id;
      if (matches) {
        if (!replaced) {
          merged.add(incoming);
          replaced = true;
        }
        continue;
      }
      merged.add(existing);
    }
    if (!replaced) merged.add(incoming);

    state = AsyncValue.data(_sorted(merged));
  }

  /// Oldest first. Ties broken by id so the order can never flip between
  /// rebuilds — messages sent in the same millisecond used to swap places.
  static List<MessageModel> _sorted(List<MessageModel> messages) {
    final copy = [...messages];
    copy.sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return copy;
  }

  Future<void> fetchMessages({bool silent = false}) async {
    try {
      if (!silent && mounted) state = const AsyncValue.loading();

      final response = await DioClient.dio.get("/chats/$chatId/messages");
      if (!mounted) return;

      if (response.data != null && response.data['success'] == true) {
        final raw = response.data['data'];
        final list = raw is List ? raw : const [];
        final fetched = list
            .map(
              (item) =>
                  MessageModel.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();

        // Keep anything still in flight or failed: the server does not know
        // about those yet, and a refresh must not throw them away.
        final pending = (state.valueOrNull ?? const <MessageModel>[])
            .where((m) => m.isPending)
            .where(
              (p) => !fetched.any(
                (f) => f.clientId.isNotEmpty && f.clientId == p.clientId,
              ),
            );

        state = AsyncValue.data(_sorted([...fetched, ...pending]));
        markAsRead();
      } else if (!silent) {
        state = AsyncValue.error("Failed to load messages", StackTrace.current);
      }
    } catch (e, stack) {
      if (!mounted) return;
      if (!silent) state = AsyncValue.error(e, stack);
      debugPrint('💬 [ChatMessages:$chatId] fetch error: $e');
    }
  }

  /// Marks the conversation read on the server and clears its badge locally.
  Future<void> markAsRead() async {
    try {
      await DioClient.dio.put("/chats/$chatId/read");
      if (!mounted) return;
      _ref.read(chatsProvider.notifier).markChatAsRead(chatId);

      final notificationsNotifier = _ref.read(notificationsProvider.notifier);
      final related = _ref
          .read(notificationsProvider)
          .notifications
          .where(
            (n) =>
                n.referenceId == chatId &&
                n.type == 'chat_message' &&
                !n.isRead,
          )
          .toList();
      for (final n in related) {
        notificationsNotifier.markAsRead(n.id);
      }
    } catch (e) {
      // Non-critical: the next open re-runs it.
      debugPrint('💬 [ChatMessages:$chatId] markAsRead error: $e');
    }
  }

  // ── Outgoing ──────────────────────────────────────────────────────────────

  void emitTyping(String userName, bool isTyping) {
    _socket.emitTyping(
      chatId: chatId,
      userName: userName,
      isTyping: isTyping,
    );
  }

  /// Sends a message, showing it immediately.
  ///
  /// The bubble appears before the request leaves, and settles into [sent] or
  /// [failed] when the server answers. A failure leaves the message on screen
  /// so it can be retried rather than disappearing with the typed text lost.
  Future<bool> sendMessage(
    String content, {
    List<MessageAttachmentModel> attachments = const [],
  }) async {
    final optimistic = MessageModel.pending(
      clientId: _newClientId(),
      chatId: chatId,
      senderId: _ref.read(authProvider).userId ?? '',
      content: content,
      attachments: attachments,
    );

    _mergeMessage(optimistic);

    final preview = content.isNotEmpty
        ? content
        : (attachments.isNotEmpty ? "Sent an attachment" : "");
    _ref
        .read(chatsProvider.notifier)
        .applyLocalPreview(chatId, preview, optimistic.createdAt);

    return _deliver(optimistic);
  }

  /// Re-sends a message that previously failed, reusing its client id so the
  /// server recognises it as the same message and cannot store it twice.
  Future<bool> retryMessage(MessageModel message) async {
    if (!mounted) return false;
    _mergeMessage(message.copyWith(status: MessageStatus.sending));
    return _deliver(message);
  }

  Future<bool> _deliver(MessageModel optimistic) async {
    try {
      final response = await DioClient.dio.post(
        "/chats/$chatId/messages",
        data: {
          "content": optimistic.content,
          "clientId": optimistic.clientId,
          "attachments": optimistic.attachments
              .map((a) => a.toJson())
              .toList(),
        },
      );

      if (response.data != null && response.data['success'] == true) {
        _mergeMessage(
          MessageModel.fromJson(
            Map<String, dynamic>.from(response.data['data'] as Map),
          ),
        );
        return true;
      }
      _markFailed(optimistic);
    } on DioException catch (e) {
      debugPrint('💬 [ChatMessages:$chatId] send error: ${e.message}');
      _markFailed(optimistic);
    } catch (e) {
      debugPrint('💬 [ChatMessages:$chatId] send error: $e');
      _markFailed(optimistic);
    }
    return false;
  }

  void _markFailed(MessageModel optimistic) {
    _mergeMessage(optimistic.copyWith(status: MessageStatus.failed));
  }

  Future<MessageAttachmentModel?> uploadAttachment({
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    try {
      MultipartFile file;
      if (fileBytes != null) {
        file = MultipartFile.fromBytes(fileBytes, filename: fileName);
      } else if (filePath != null) {
        file = await MultipartFile.fromFile(filePath, filename: fileName);
      } else {
        return null;
      }

      final response = await DioClient.dio.post(
        "/chats/$chatId/attachments",
        data: FormData.fromMap({"file": file}),
      );

      if (response.data != null && response.data['success'] == true) {
        return MessageAttachmentModel.fromJson(
          Map<String, dynamic>.from(response.data['data'] as Map),
        );
      }
    } catch (e) {
      debugPrint('💬 [ChatMessages:$chatId] uploadAttachment error: $e');
    }
    return null;
  }
}
