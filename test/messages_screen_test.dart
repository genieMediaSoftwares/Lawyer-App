import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/features/chat/presentation/screens/messages_screen.dart';
import 'package:law/models/chat_model.dart';
import 'package:law/providers/auth_provider.dart';
import 'package:law/providers/chat_provider.dart';

/// Covers the rules the Messages list has to keep: every conversation on
/// screen, nothing clipped, and each row showing who it is from, what was
/// said, when, and how many are unread.
///
/// The row used to be a [ListTile]. That widget sizes itself from a one- or
/// two-line model and constrains its `subtitle` to match, so the third stacked
/// line — the message preview — was laid out and then cut off. The text was
/// present in the tree the whole time, which is why it could not be found by
/// reading the code alone: only a height assertion shows it.
void main() {
  const currentUserId = 'me-1';

  ChatModel chat({
    required String id,
    required String otherName,
    required String lastMessage,
    required int unreadCount,
    DateTime? at,
    String otherRole = 'client',
    String? caseTitle,
  }) {
    return ChatModel(
      id: id,
      participants: [
        ChatParticipantModel(
          id: currentUserId,
          fullName: 'Me',
          profileImage: '',
          role: 'lawyer',
        ),
        ChatParticipantModel(
          id: '$id-other',
          fullName: otherName,
          profileImage: '',
          role: otherRole,
        ),
      ],
      lastMessage: lastMessage,
      lastMessageAt: at ?? DateTime.now(),
      unreadCount: unreadCount,
      caseInfo: caseTitle == null
          ? null
          : ChatCaseInfoModel(id: '$id-case', title: caseTitle),
    );
  }

  Future<void> pumpMessages(
    WidgetTester tester,
    List<ChatModel> chats, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _StubAuth(
              ref,
              const AuthState(
                isLoggedIn: true,
                role: UserRole.lawyer,
                onboardingCompleted: true,
                userId: currentUserId,
                userName: 'Me',
              ),
            ),
          ),
          chatsProvider.overrideWith((ref) => _StubChats(ref, chats)),
        ],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('every conversation is rendered, none dropped', (tester) async {
    final chats = List.generate(
      8,
      (i) => chat(
        id: 'c$i',
        otherName: 'Client $i',
        lastMessage: 'Message body number $i',
        unreadCount: i.isEven ? i + 1 : 0,
      ),
    );

    await pumpMessages(tester, chats);

    // Scroll through the whole list so off-screen rows are built too: the
    // requirement is that all eight exist, not just the visible ones.
    for (var i = 0; i < chats.length; i++) {
      await tester.scrollUntilVisible(
        find.text('Client $i'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Client $i'), findsOneWidget);
    }
  });

  testWidgets('name, preview and timestamp all show for a row', (tester) async {
    await pumpMessages(tester, [
      chat(
        id: 'c1',
        otherName: 'Ramesh J.',
        lastMessage: 'I wanted to discuss my property case.',
        unreadCount: 1,
        at: DateTime.now(),
        caseTitle: 'Property dispute',
      ),
    ]);

    expect(find.text('Ramesh J.'), findsOneWidget);
    expect(find.text('I wanted to discuss my property case.'), findsOneWidget);
    expect(find.text('Property dispute'), findsOneWidget);
    // Today's messages are stamped with a time, e.g. "09:31 AM".
    expect(find.textContaining(RegExp(r'\d{2}:\d{2} (AM|PM)')), findsOneWidget);
  });

  testWidgets('a long preview is not clipped out of the card', (tester) async {
    const longMessage =
        'Hi Advocate, I wanted to discuss my property case in detail. '
        'Please let me know when you are free to talk this week.';

    await pumpMessages(tester, [
      chat(
        id: 'c1',
        otherName: 'Ramesh J.',
        lastMessage: longMessage,
        unreadCount: 1,
      ),
    ]);

    final preview = find.text(longMessage);
    expect(preview, findsOneWidget);

    // The regression guard. Under ListTile this text painted at a height of a
    // single line even though two were requested, because the tile clipped it.
    final previewHeight = tester.getSize(preview).height;
    final oneLine = tester.renderObject<RenderBox>(
      find.text('Ramesh J.'),
    ).size.height;
    expect(
      previewHeight,
      greaterThan(oneLine),
      reason: 'the preview must be allowed to wrap onto its second line',
    );

    // And the row it sits in must be tall enough to actually contain it.
    final cardHeight = tester.getSize(find.byType(Card).first).height;
    final previewBottom = tester.getBottomLeft(preview).dy;
    final cardBottom = tester.getBottomLeft(find.byType(Card).first).dy;
    expect(
      previewBottom,
      lessThanOrEqualTo(cardBottom),
      reason: 'the preview must sit inside the card, not past its edge',
    );
    expect(cardHeight, greaterThan(previewHeight));
  });

  testWidgets('unread rows carry a red badge with the count', (tester) async {
    await pumpMessages(tester, [
      chat(id: 'c1', otherName: 'A', lastMessage: 'x', unreadCount: 3),
      chat(id: 'c2', otherName: 'B', lastMessage: 'y', unreadCount: 0),
    ]);

    expect(find.text('3'), findsOneWidget);

    // Red, not the gold used elsewhere in the row — an unread count has to be
    // distinguishable at a glance from the accent colour.
    final badge = tester.widget<Container>(
      find
          .ancestor(of: find.text('3'), matching: find.byType(Container))
          .first,
    );
    final decoration = badge.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFE53935));

    // The read conversation gets no badge.
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a count above 99 stays inside its badge', (tester) async {
    await pumpMessages(tester, [
      chat(id: 'c1', otherName: 'A', lastMessage: 'x', unreadCount: 1250),
    ]);

    expect(find.text('99+'), findsOneWidget);
    expect(find.text('1250'), findsNothing);
  });

  testWidgets('nothing overflows on a narrow screen', (tester) async {
    await pumpMessages(
      tester,
      [
        chat(
          id: 'c1',
          otherName: 'A client with a very long display name indeed',
          lastMessage:
              'A long message that would certainly wrap several times over '
              'on a narrow device screen without careful constraints.',
          unreadCount: 42,
          caseTitle: 'An unusually long case title for a property dispute',
        ),
      ],
      size: const Size(320, 700),
    );

    // A RenderFlex overflow is reported as a thrown exception in tests.
    expect(tester.takeException(), isNull);
  });
}

class _StubAuth extends AuthNotifier {
  _StubAuth(super.ref, AuthState value) {
    state = value;
  }

  /// The real one reads secure storage and would overwrite the fixed state.
  @override
  Future<void> initialize() async {}
}

/// A [ChatsNotifier] holding a fixed list.
///
/// Constructed with `isLoggedIn: false`, which is the branch that returns
/// before touching the socket or the network, then given the list directly.
class _StubChats extends ChatsNotifier {
  _StubChats(super.ref, List<ChatModel> chats) : super(isLoggedIn: false) {
    state = AsyncValue.data(chats);
  }

  /// The screen reconciles on first frame; there is no server here.
  @override
  Future<void> fetchChats({bool silent = false}) async {}
}
