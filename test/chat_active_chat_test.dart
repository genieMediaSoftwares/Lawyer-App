import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/providers/chat_provider.dart';

/// The chat screen records which conversation is on screen so an arriving
/// message can be marked read, and can be kept out of the unread badge,
/// without a frame's delay.
///
/// It has to do that from `initState` and `dispose`. Riverpod rejects writing
/// to provider *state* in either ("Tried to modify a provider while the widget
/// tree was building"), which is why [ActiveChatTracker] is a plain mutable
/// object behind a `Provider` rather than a `StateProvider`.
///
/// These are not vacuous: written against the first version of the fix, they
/// failed with "Cannot use ref after the widget was disposed", because that
/// version still called `ref.read` from `dispose`. Hence [_activeChat] being
/// resolved in `initState` and held.
///
/// A control case — a `ConsumerWidget` watching a `StateProvider` with a child
/// writing it from `initState` — was also confirmed by hand to throw "Tried to
/// modify a provider while the widget tree was building". It is not kept here
/// because flutter_test reports that failure through a channel
/// `tester.takeException()` cannot clear, so it can only ever be a red test.
void main() {
  group('ActiveChatTracker', () {
    testWidgets(
      'claiming the open conversation from initState does not throw',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const _ChatScreenLifecycle('chat-a'),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(container.read(activeChatProvider).chatId, 'chat-a');
      },
    );

    testWidgets('releasing from dispose does not throw', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _ChatScreenLifecycle('chat-a'),
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(container.read(activeChatProvider).chatId, isNull);
    });

    test('a disposing screen cannot release a conversation it no longer owns', () {
      // Pushing chat B runs B's initState first, then disposes A. An
      // unconditional clear in A's dispose would blank the id while B is open,
      // so every message arriving in B would raise an unread badge.
      final tracker = ActiveChatTracker();

      tracker.chatId = 'chat-a';
      tracker.chatId = 'chat-b';
      tracker.release('chat-a');

      expect(tracker.chatId, 'chat-b');
      expect(tracker.isOnScreen('chat-b'), isTrue);
      expect(tracker.isOnScreen('chat-a'), isFalse);
    });

    test('releasing the conversation it does own clears it', () {
      final tracker = ActiveChatTracker();

      tracker.chatId = 'chat-a';
      tracker.release('chat-a');

      expect(tracker.chatId, isNull);
      expect(tracker.isOnScreen('chat-a'), isFalse);
    });

  });
}

/// Mirrors what ChatScreen does around [activeChatProvider].
class _ChatScreenLifecycle extends ConsumerStatefulWidget {
  final String chatId;
  const _ChatScreenLifecycle(this.chatId);

  @override
  ConsumerState<_ChatScreenLifecycle> createState() =>
      _ChatScreenLifecycleState();
}

class _ChatScreenLifecycleState extends ConsumerState<_ChatScreenLifecycle> {
  // Resolved while ref is still usable: dispose cannot call ref.read.
  late final ActiveChatTracker _activeChat;

  @override
  void initState() {
    super.initState();
    _activeChat = ref.read(activeChatProvider);
    _activeChat.chatId = widget.chatId;
  }

  @override
  void dispose() {
    _activeChat.release(widget.chatId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

