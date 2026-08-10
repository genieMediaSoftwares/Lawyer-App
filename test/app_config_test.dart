import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:law/core/config/app_config.dart';
import 'package:law/core/config/fallback_config.dart';

/// Guards the configuration system's four rules:
///
///  1. every configurable value comes from `.env`, through [AppConfig];
///  2. [FallbackConfig] covers whatever `.env` does not, so a half-written or
///     missing `.env` degrades to a working app rather than an error screen;
///  3. a *malformed* value is still fatal — that is a typo to fix, not a gap;
///  4. no secret ever reaches a log, an error message or the error screen.
///
/// These cases build their own environment rather than patching the project's
/// `.env`. `.env` is gitignored and routinely edited — commented out while
/// someone works against a local server, for instance — and a suite that
/// depended on its exact text would fail for reasons that have nothing to do
/// with the code.
void main() {
  /// Installs an environment containing exactly [values].
  void loadEnv(Map<String, String> values) {
    dotenv.loadFromString(
      envString: values.entries.map((e) => '${e.key}=${e.value}').join('\n'),
      isOptional: true,
    );
  }

  /// A complete, valid environment, optionally altered.
  ///
  /// [overrides] adds or replaces entries; [remove] drops them, standing in for
  /// a key that was never written or has been commented out.
  Map<String, String> completeEnv({
    Map<String, String> overrides = const {},
    List<String> remove = const [],
  }) {
    final values = Map<String, String>.from(FallbackConfig.values)
      ..addAll(overrides);
    for (final key in remove) {
      values.remove(key);
    }
    return values;
  }

  Set<String> keysInFile(String path) => File(path)
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .map((line) => line.split('=').first.trim())
      .toSet();

  /// Leaves a complete environment behind, so a case that installed a broken
  /// one cannot affect whatever runs next.
  tearDown(() => loadEnv(completeEnv()));

  group('AppConfig.validate', () {
    test('accepts a complete environment', () {
      loadEnv(completeEnv());
      expect(AppConfig.validate, returnsNormally);
    });

    test('rejects a malformed value in every mode', () {
      // A gap is recoverable; a typo is not. This must fail whether or not the
      // fallback is available, or a bad .env would be silently overridden and
      // nobody would ever fix it.
      loadEnv(completeEnv(overrides: {'HTTP_MAX_RETRIES': 'three'}));

      final error = _configErrorFrom(AppConfig.validate);
      expect(error.problems.single, contains('must be an integer'));
    });

    test('rejects a base URL that is not absolute', () {
      loadEnv(completeEnv(overrides: {'BASE_URL': '/api'}));

      final error = _configErrorFrom(AppConfig.validate);
      expect(error.problems.single, contains('absolute URL'));
    });

    test('rejects a picker extension the upload filter would reject', () {
      loadEnv(completeEnv(overrides: {'AI_UPLOAD_PICKER_EXTENSIONS': 'pdf,doc'}));

      final error = _configErrorFrom(AppConfig.validate);
      expect(error.problems.single, contains('doc'));
    });

    test('rejects a run timeout below the hard timeout', () {
      loadEnv(completeEnv(overrides: {
        'AI_HARD_TIMEOUT_MINUTES': '10',
        'AI_RUN_TIMEOUT_MINUTES': '5',
      }));

      final error = _configErrorFrom(AppConfig.validate);
      expect(error.problems.single, contains('AI_RUN_TIMEOUT_MINUTES'));
    });

    test('the project .env holds no malformed value', () {
      // The one case that reads the real file. Missing keys are fine — the
      // fallback covers them — but a typo in a key that *is* set is a real bug
      // and this is what catches it.
      final envFile = File('.env');
      if (!envFile.existsSync()) return;

      dotenv.loadFromString(
        envString: envFile.readAsStringSync(),
        isOptional: true,
      );

      try {
        AppConfig.validate();
      } on AppConfigError catch (error) {
        for (final problem in error.problems) {
          expect(
            problem,
            contains('is missing or empty'),
            reason: 'A value that is present in .env is malformed: $problem',
          );
        }
      }
    });
  });

  group('fallback mode', () {
    test('is on unless the build opted out', () {
      // The behaviour this file exists to guarantee: an ordinary build covers
      // gaps in .env rather than refusing to start. Only a run given
      // --dart-define=STRICT_ENV_CONFIG=true sees the other branch.
      expect(
        AppConfig.strictConfig,
        const bool.fromEnvironment('STRICT_ENV_CONFIG'),
      );
      expect(AppConfig.fallbackEnabled, !AppConfig.strictConfig);
    });

    test('covers every key AppConfig reads', () {
      // A key AppConfig reads but the fallback does not answer for means
      // fallback mode still dies on that key — the moment it should have
      // helped. Proven by validating against the fallback alone.
      loadEnv(FallbackConfig.values);
      expect(AppConfig.validate, returnsNormally);
    });

    test('carries the app when the endpoints are commented out', () {
      // Exactly the reported situation: the URLs are commented out of .env.
      // A default build must come up on the fallback endpoints.
      loadEnv(completeEnv(remove: ['BASE_URL', 'SOCKET_BASE_URL']));

      if (AppConfig.strictConfig) {
        // Both keys are reported. SOCKET_BASE_URL also fails the four socket
        // URLs derived from it, so the count is higher than two.
        final problems = _configErrorFrom(AppConfig.validate).problems;
        expect(problems.any((p) => p.contains('BASE_URL')), isTrue);
        expect(problems.any((p) => p.contains('SOCKET_BASE_URL')), isTrue);
        return;
      }

      expect(AppConfig.validate, returnsNormally);
      expect(AppConfig.baseUrl, FallbackConfig.values['BASE_URL']);
      expect(AppConfig.socketBaseUrl, FallbackConfig.values['SOCKET_BASE_URL']);
      expect(
        AppConfig.keysServedByFallback,
        containsAll(<String>['BASE_URL', 'SOCKET_BASE_URL']),
      );
    });

    test('carries the app when .env is empty entirely', () {
      loadEnv(const {});

      if (AppConfig.strictConfig) {
        expect(_configErrorFrom(AppConfig.validate).problems, isNotEmpty);
        return;
      }

      expect(AppConfig.validate, returnsNormally);
      expect(
        AppConfig.keysServedByFallback,
        hasLength(FallbackConfig.values.length),
      );
    });

    test('treats a blank value exactly like an absent one', () {
      // `KEY=` with nothing after it must trigger the fallback, not be passed
      // through as a valid empty string — the original bug behind this work.
      loadEnv(completeEnv(overrides: {'SUPPORT_EMAIL': ''}));

      if (AppConfig.strictConfig) {
        expect(
          _configErrorFrom(AppConfig.validate).problems.single,
          contains('SUPPORT_EMAIL'),
        );
        return;
      }

      expect(AppConfig.supportEmail, FallbackConfig.values['SUPPORT_EMAIL']);
      expect(AppConfig.keysServedByFallback, contains('SUPPORT_EMAIL'));
    });

    test('prefers .env over the fallback wherever .env has a value', () {
      loadEnv(completeEnv(overrides: {
        'HTTP_MAX_RETRIES': '7',
        'BASE_URL': 'https://staging.example.test/api',
      }));

      expect(AppConfig.httpMaxRetries, 7);
      expect(AppConfig.baseUrl, 'https://staging.example.test/api');

      // validate() reads every key, which is what makes the tally complete —
      // see the note on keysServedByFallback. Without it the set still holds
      // whatever an earlier read recorded.
      AppConfig.validate();
      expect(AppConfig.keysServedByFallback, isEmpty);
    });
  });

  group('secret hygiene', () {
    test('recognises the names a secret is likely to be given', () {
      for (final key in const [
        'JWT_SECRET',
        'API_KEY',
        'GEMINI_API_KEY',
        'ACCESS_TOKEN',
        'DB_PASSWORD',
        'SERVICE_CREDENTIAL',
        'SIGNING_CERT',
        'PRIVATE_PEM',
        'KEY_MATERIAL',
      ]) {
        expect(AppConfig.isSensitive(key), isTrue, reason: '$key must redact');
      }

      for (final key in const [
        'BASE_URL',
        'HTTP_MAX_RETRIES',
        'SUPPORT_EMAIL',
        'AI_MAX_FILE_COUNT',
        'PUBLIC_UPLOAD_FOLDERS',
      ]) {
        expect(
          AppConfig.isSensitive(key),
          isFalse,
          reason: '$key is not a secret; redacting it hides real errors',
        );
      }
    });

    test('no client-side config key is secret-shaped at all', () {
      // Redaction is the safety net. The actual rule is that secrets never
      // reach the client: they live in backend/.env and stay server-side.
      final offenders = FallbackConfig.values.keys
          .where(AppConfig.isSensitive)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'FallbackConfig is compiled into the binary and .env ships as '
            'an app asset — both are readable by anyone with the APK. These '
            'belong in backend/.env:\n${offenders.join('\n')}',
      );
    });

    test('a malformed value is quoted back for an ordinary key', () {
      // The counterpart to redaction: for a non-secret the offending value is
      // shown, because that is what makes the error diagnosable.
      loadEnv(completeEnv(overrides: {'HTTP_MAX_RETRIES': 'three'}));

      final error = _configErrorFrom(AppConfig.validate);
      expect(error.problems.single, contains('"three"'));
    });

    test('the fallback is reachable and holds no credential', () {
      // Because the fallback is the safety net for real builds, its endpoints
      // must work. A localhost or example.com placeholder would start the app
      // and then fail every request — worse than failing loudly.
      for (final key in const ['BASE_URL', 'SOCKET_BASE_URL']) {
        final uri = Uri.parse(FallbackConfig.values[key]!);
        expect(uri.hasScheme && uri.hasAuthority, isTrue,
            reason: '$key must be an absolute URL');
        expect(
          uri.host,
          isNot(anyOf(
            'localhost',
            '127.0.0.1',
            '10.0.2.2',
            contains('example.'),
            contains('your-host'),
          )),
          reason: '$key must name a backend a shipped build can actually '
              'reach, not a placeholder.',
        );
      }

      expect(
        FallbackConfig.values['HTTP_LOG_REQUESTS'],
        'false',
        reason: 'The request logger prints Authorization headers.',
      );

      // A leaked credential looks like a long opaque run of characters with no
      // structure. Every legitimate value here has some — a scheme, a dot, a
      // comma, a slash, an @ — or is far shorter than this.
      final opaque = RegExp(r'^[A-Za-z0-9_\-]{24,}$');
      final secretShaped = FallbackConfig.values.entries
          .where((entry) => opaque.hasMatch(entry.value))
          .map((entry) => entry.key)
          .toList();
      expect(
        secretShaped,
        isEmpty,
        reason: 'These values look like credentials:\n'
            '${secretShaped.join('\n')}',
      );
    });
  });

  group('source hygiene', () {
    /// Everything is funnelled through one class so there is no second path by
    /// which an unvalidated key or an in-code default can appear.
    test('only app_config.dart reads dotenv or the fallback', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final normalised = entity.path.replaceAll(r'\', '/');
        if (normalised.endsWith('lib/core/config/app_config.dart') ||
            normalised.endsWith('lib/core/config/fallback_config.dart')) {
          continue;
        }

        // Comments may name them; code may not.
        final lines = entity.readAsLinesSync().where(
              (line) =>
                  !line.trimLeft().startsWith('//') &&
                  (line.contains('dotenv') || line.contains('FallbackConfig')),
            );
        if (lines.isNotEmpty) offenders.add(normalised);
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Read configuration through AppConfig:\n'
            '${offenders.join('\n')}',
      );
    });

    test('no source file hardcodes an http(s) or ws(s) endpoint', () {
      // Namespaced URIs (xmlns, SVG) are not endpoints the app calls.
      final endpoint = RegExp(r'''['"](?:https?|wss?)://''');
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // The one file whose entire job is to hold literal values. It has its
        // own, stricter guards in the "secret hygiene" group above.
        if (entity.path
            .replaceAll(r'\', '/')
            .endsWith('lib/core/config/fallback_config.dart')) {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!endpoint.hasMatch(line)) continue;
          // `startsWith('http')` style scheme checks are not endpoints either.
          if (line.contains('startsWith(') || line.contains('xmlns')) continue;

          offenders.add(
            '${entity.path.replaceAll(r'\', '/')}:${i + 1}  ${line.trim()}',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Endpoints belong in .env, behind AppConfig:\n'
            '${offenders.join('\n')}',
      );
    });

    test('.env.example stays in step with the config, when it exists', () {
      // Not required to exist. FallbackConfig is the authoritative record of
      // what the app reads — it is code, so it cannot silently drift or be
      // deleted without the rest of this file failing. `.env.example` is a
      // convenience on top of that, and it is untracked, so routine git
      // operations remove it. Checked only when it is present.
      final example = File('.env.example');
      if (!example.existsSync()) return;

      expect(
        keysInFile('.env.example'),
        FallbackConfig.values.keys.toSet(),
        reason: 'A key added to the config must appear in .env.example too.',
      );
    });

    test('.env is gitignored', () {
      final ignored = File('.gitignore')
          .readAsLinesSync()
          .map((line) => line.trim())
          .toSet();

      expect(
        ignored,
        contains('.env'),
        reason: '.env holds per-deployment values and must never be committed.',
      );
    });
  });
}

AppConfigError _configErrorFrom(void Function() action) {
  try {
    action();
  } on AppConfigError catch (error) {
    return error;
  }
  fail('expected an AppConfigError');
}
