import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law/core/config/app_config.dart';
import 'package:law/core/widgets/profile_image_viewer.dart';
import 'package:law/core/widgets/user_avatar.dart';

/// Profile pictures, everywhere they appear.
///
/// Roughly twenty screens each resolved their own image URL and built their own
/// CircleAvatar. Several handed the RAW stored value straight to NetworkImage —
/// the lawyer dashboard's client cards, the admin lists, the matched-advocates
/// list — so a profile recorded as a relative `/uploads/profiles/...` path, or
/// recorded on a developer's machine against localhost, could never load. And
/// because a bare CircleAvatar has no error builder, the failure showed as an
/// empty grey circle rather than the person's initials.
///
/// [UserAvatar] now owns resolution and the fallback, so these cases describe
/// the behaviour of every avatar in the app at once.

void main() {
  group('UserAvatar.resolve', () {
    test('a relative upload path is resolved against the backend', () {
      final url = UserAvatar.resolve('/uploads/profiles/abc.jpg');

      expect(url, isNotNull);
      expect(url, startsWith(AppConfig.socketBaseUrl));
      expect(url, contains('/uploads/profiles/abc.jpg'));
    });

    test('a path without a leading slash still resolves', () {
      final url = UserAvatar.resolve('uploads/profiles/abc.jpg');
      expect(url, contains('/uploads/profiles/abc.jpg'));
      // Never `...comuploads/...`.
      expect(url, isNot(contains('comuploads')));
    });

    test('an absolute URL on our own host is not prefixed twice', () {
      final stored = '${AppConfig.socketBaseUrl}/uploads/profiles/abc.jpg';
      final url = UserAvatar.resolve(stored)!;

      expect(RegExp('https?://').allMatches(url).length, 1,
          reason: 'produced a doubled URL: $url');
      expect(url, contains('/uploads/profiles/abc.jpg'));
    });

    test('a URL recorded against localhost is re-hosted, not discarded', () {
      // Records written during development keep the developer's host forever.
      // Left alone they are dead links on every real device.
      final url =
          UserAvatar.resolve('http://localhost:5000/uploads/profiles/a.jpg')!;

      expect(url, startsWith(AppConfig.socketBaseUrl));
      expect(url, isNot(contains('localhost')));
      expect(url, contains('/uploads/profiles/a.jpg'));
    });

    test('an emulator or LAN host is re-hosted too', () {
      for (final host in <String>[
        'http://10.0.2.2:5000',
        'http://192.168.1.14:5000',
        'http://127.0.0.1:5000',
      ]) {
        final url = UserAvatar.resolve('$host/uploads/profiles/a.jpg')!;
        expect(url, startsWith(AppConfig.socketBaseUrl), reason: host);
      }
    });

    test('a genuine CDN URL is left alone', () {
      // Re-hosting a third-party URL would point it at nothing.
      const cloudinary =
          'https://res.cloudinary.com/demo/image/upload/v1/avatar.jpg';
      expect(UserAvatar.resolve(cloudinary), cloudinary);
    });

    test('nothing-values resolve to null rather than a broken URL', () {
      for (final value in <String?>[null, '', '   ', 'null', 'undefined', '/']) {
        expect(UserAvatar.resolve(value), isNull, reason: 'value: $value');
      }
    });

    test('a profile URL carries no session token', () {
      // The profiles folder is public by design — advocates are browsed by
      // prospective clients before they sign in. Appending the JWT would put a
      // credential in every image request, and in any log that records them.
      final url = UserAvatar.resolve('/uploads/profiles/abc.jpg')!;
      expect(url, isNot(contains('token=')));
      expect(
          AppConfig.requiresSessionToken('/uploads/profiles/abc.jpg'), isFalse);
    });

    test('a case attachment still does require a token', () {
      // The counterpart: private material stays guarded.
      expect(AppConfig.requiresSessionToken('/uploads/cases/x.pdf'), isTrue);
    });
  });

  group('UserAvatar.initialsFrom', () {
    test('two words become two letters', () {
      expect(UserAvatar.initialsFrom('Ananya Rao'), 'AR');
    });

    test('one word becomes one letter', () {
      expect(UserAvatar.initialsFrom('Chaitanya'), 'C');
    });

    test('extra whitespace does not produce blank initials', () {
      expect(UserAvatar.initialsFrom('  Ravi   Kumar  '), 'RK');
    });

    test('no name yields no initials rather than a crash', () {
      expect(UserAvatar.initialsFrom(null), isNull);
      expect(UserAvatar.initialsFrom('   '), isNull);
    });

    test('a non-Latin name keeps its own first letter', () {
      expect(UserAvatar.initialsFrom('చైతన్య'), isNotNull);
    });
  });

  group('UserAvatar widget', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        home: Scaffold(body: Center(child: child)),
      ));
      await tester.pump();
    }

    testWidgets('shows initials when there is no picture', (tester) async {
      await pump(tester, const UserAvatar(imagePath: null, name: 'Ananya Rao'));

      // Not a broken-image icon, and not an empty circle.
      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('an empty string is treated as no picture', (tester) async {
      await pump(tester, const UserAvatar(imagePath: '', name: 'Ravi Kumar'));
      expect(find.text('RK'), findsOneWidget);
    });

    testWidgets('falls back to an icon when there is no name either',
        (tester) async {
      await pump(tester, const UserAvatar(imagePath: null));
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('is not tappable by default', (tester) async {
      // A list row usually wants its own tap; stealing it would break
      // navigation on every list in the app.
      await pump(tester, const UserAvatar(imagePath: null, name: 'A B'));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('opens the full-screen viewer when asked', (tester) async {
      await pump(
        tester,
        const UserAvatar(
          imagePath: '/uploads/profiles/a.jpg',
          name: 'Ananya Rao',
          subtitle: 'Advocate',
          openOnTap: true,
        ),
      );

      expect(find.byType(ProfileImageViewer), findsNothing);
      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileImageViewer), findsOneWidget);
      // The caption identifies whose picture this is.
      expect(find.text('Ananya Rao'), findsOneWidget);
    });

    testWidgets('the viewer closes on the Android back button', (tester) async {
      await pump(
        tester,
        const UserAvatar(
          imagePath: '/uploads/profiles/a.jpg',
          name: 'Ananya Rao',
          openOnTap: true,
        ),
      );

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileImageViewer), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileImageViewer), findsNothing);
    });

    testWidgets('an explicit onTap replaces the default behaviour',
        (tester) async {
      var taps = 0;
      await pump(
        tester,
        UserAvatar(
          imagePath: '/uploads/profiles/a.jpg',
          name: 'Ananya Rao',
          openOnTap: true,
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.byType(ProfileImageViewer), findsNothing);
    });

    testWidgets('a tappable avatar is announced to screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const UserAvatar(
          imagePath: '/uploads/profiles/a.jpg',
          name: 'Ananya Rao',
          openOnTap: true,
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r"View Ananya Rao.s profile picture")),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a tap target is large enough to hit', (tester) async {
      await pump(
        tester,
        const UserAvatar(
          imagePath: '/uploads/profiles/a.jpg',
          name: 'Ananya Rao',
          radius: 18,
          openOnTap: true,
        ),
      );

      final size = tester.getSize(find.byType(UserAvatar));
      expect(size.width, greaterThanOrEqualTo(36));
      expect(size.height, greaterThanOrEqualTo(36));
    });
  });

  group('ProfileImageViewer', () {
    testWidgets(
        'shows a fallback rather than a broken image when there is none',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ProfileImageViewer(imagePath: null, name: 'Ananya Rao'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ProfileImageViewer), findsOneWidget);
    });

    testWidgets('a malformed stored value does not crash the viewer',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ProfileImageViewer(imagePath: 'not a url at all', name: 'X'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
