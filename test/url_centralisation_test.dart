import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:law/core/config/app_config.dart';

/// Every URL for a stored file comes from one resolver.
///
/// Screens used to build these themselves, and each got it wrong differently:
/// the lawyer dashboard joined `AppConfig.baseUrl` — which ends in `/api` — to
/// a stored `/uploads/...` path and asked the server for `/api/uploads/...`,
/// which matches no route; the admin lists and the matched-advocates list
/// handed the raw stored value to `NetworkImage`, so a relative path was never
/// a URL at all.
///
/// The unit cases below pin the resolver's behaviour. The source scan is the
/// part that keeps it true: a resolver is only central while nothing works
/// around it.

/// Dart sources under `lib/`, excluding the resolver and its config.
Iterable<File> appSources() sync* {
  const exempt = <String>[
    // Owns the rules these tests describe.
    'lib/core/config/app_config.dart',
    'lib/core/config/fallback_config.dart',
    'lib/core/widgets/user_avatar.dart',
  ];

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalised = entity.path.replaceAll(r'\', '/');
    if (exempt.any(normalised.endsWith)) continue;
    yield entity;
  }
}

/// Strips `//` comments so a line explaining a past bug is not read as one.
String withoutComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('getAttachmentUrl', () {
    test('a relative path is hosted on the file server, not the API', () {
      final url = AppConfig.getAttachmentUrl('/uploads/cases/order.pdf');

      expect(url, contains('/uploads/cases/order.pdf'));
      // The exact production failure: `/api` in front of `/uploads`.
      expect(url, isNot(contains('/api/uploads')));
    });

    test('an absolute URL is not prefixed a second time', () {
      final url = AppConfig.getAttachmentUrl(
        '${AppConfig.socketBaseUrl}/uploads/cases/order.pdf',
      );

      expect(RegExp('https?://').allMatches(url).length, 1,
          reason: 'doubled URL: $url');
    });

    test('a null or empty value yields an empty string, not a bad URL', () {
      expect(AppConfig.getAttachmentUrl(null), '');
      expect(AppConfig.getAttachmentUrl(''), '');
    });

    test('a stale token on a stored URL is replaced, never duplicated', () {
      // Express parses `?token=A&token=B` as a LIST, which jwt.verify rejects
      // with "jwt must be a string" — reported to the user as an expired
      // session it had nothing to do with.
      final url = AppConfig.getAttachmentUrl(
        '${AppConfig.socketBaseUrl}/uploads/cases/x.pdf?token=STALE',
      );

      expect('token='.allMatches(url).length, lessThanOrEqualTo(1));
      expect(url, isNot(contains('STALE')));
    });

    test('a query string that is not a token is preserved', () {
      final url = AppConfig.getAttachmentUrl('/uploads/cases/x.pdf?page=3');
      expect(url, contains('page=3'));
    });
  });

  group('No screen builds its own file URL', () {
    test('nothing joins the API base to an uploads path', () {
      final offenders = <String>[];

      for (final file in appSources()) {
        final source = withoutComments(file.readAsStringSync());
        // `${AppConfig.baseUrl}` immediately followed by a stored path.
        if (RegExp(r'\$\{?AppConfig\.baseUrl\}?\$?\{?\w*(doc|file|url|path)',
                caseSensitive: false)
            .hasMatch(source)) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'use AppConfig.getAttachmentUrl instead of joining baseUrl');
    });

    test('no screen hardcodes a host', () {
      final offenders = <String>[];

      for (final file in appSources()) {
        final source = withoutComments(file.readAsStringSync());
        if (RegExp(r'''["']https?://(localhost|127\.0\.0\.1|10\.0\.2\.2|\d+\.\d+\.\d+\.\d+)''')
            .hasMatch(source)) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'hosts belong in .env, read through AppConfig');
    });

    test('no screen writes an uploads path literal', () {
      // Folder names are the server's business; screens pass through whatever
      // the API stored.
      final offenders = <String>[];

      for (final file in appSources()) {
        final source = withoutComments(file.readAsStringSync());
        if (RegExp(r'''["']/uploads/''').hasMatch(source)) {
          offenders.add(file.path);
        }
      }

      expect(offenders, isEmpty);
    });
  });
}
