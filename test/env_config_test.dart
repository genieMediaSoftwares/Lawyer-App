import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// The base URL is read from a bundled `.env` asset, which has twice now been
/// the cause of "the app cannot reach the server". A typo, a stray character or
/// a commented-out line produces no error at all: `Environment.baseUrl` simply
/// falls back to localhost and every request fails with a connection error that
/// looks like a server problem.
///
/// This parses the real file the app ships and asserts what comes out of it.
void main() {
  setUp(() {
    dotenv.clean();
    dotenv.loadFromString(envString: File('.env').readAsStringSync());
  });

  test('.env defines a usable BASE_URL', () {
    final url = dotenv.env['BASE_URL'];

    expect(url, isNotNull, reason: 'BASE_URL missing or commented out in .env');
    expect(url, isNotEmpty);
    expect(
      url,
      anyOf(startsWith('http://'), startsWith('https://')),
      reason: 'BASE_URL must be an absolute URL',
    );
    expect(
      url,
      endsWith('/api'),
      reason: 'the socket URL is derived by stripping /api from this',
    );
  });

  test('the configured URL survives the web-specific rewrite', () {
    // Mirrors the kIsWeb branch of Environment.baseUrl, which silently
    // substitutes localhost for any LAN address. A device-only URL left in
    // .env therefore breaks the web build with no diagnostic.
    final url = dotenv.env['BASE_URL']!;
    final rewrittenOnWeb =
        url.contains('192.168.') || url.contains('10.0.2.2');

    expect(
      rewrittenOnWeb,
      isFalse,
      reason: 'BASE_URL is a LAN address; the web build will silently use '
          'http://localhost:5000/api instead',
    );
  });
}
