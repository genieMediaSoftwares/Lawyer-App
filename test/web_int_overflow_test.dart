import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against 32-bit shift overflow on the web.
///
/// Dart's bitwise operators are 64-bit on the VM but **32-bit and signed** when
/// compiled to JavaScript. So in a browser build:
///
///   * `1 << 31` is `-2147483648`, not `2147483648`
///   * `1 << 32` is `0`, not `4294967296`
///
/// Both shipped here and neither was visible in a VM test:
///
///   * `Random().nextInt(1 << 32)` in `chat_provider` threw
///     "max must be in range 0 < max <= 2^32, was 0" on every message send,
///     making chat unusable in the browser.
///   * `setReconnectionAttempts(1 << 31)` in `chat_socket` passed a *negative*
///     attempt count, so the web build stopped reconnecting immediately —
///     precisely the opposite of the "retry indefinitely" it was written to do.
///
/// A shift of 31 or more is essentially always this bug. Anything up to
/// `1 << 30` evaluates identically on both platforms, so that is the ceiling.
void main() {
  test('no source file shifts by 31 or more', () {
    // `x << 31`, `1<<32`, etc. The operand is captured so the failure message
    // can name it.
    final shift = RegExp(r'<<\s*(\d+)');

    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip the comments that explain this very rule.
        if (line.trimLeft().startsWith('//') ||
            line.trimLeft().startsWith('///')) {
          continue;
        }
        for (final match in shift.allMatches(line)) {
          final amount = int.parse(match.group(1)!);
          if (amount >= 31) {
            offenders.add(
              '${entity.path.replaceAll(r'\', '/')}:${i + 1}  '
              '<< $amount  ->  ${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Shifting by 31+ overflows in JavaScript, so these are correct '
          'on Android/iOS and wrong in the browser. Use 1 << 30 or lower:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the safe ceiling really is safe in 32-bit signed arithmetic', () {
    // Reproduces what JS does: truncate to 32 bits, then interpret as signed.
    int asJsShift(int bits) {
      final truncated = (1 << bits) & 0xFFFFFFFF;
      return truncated >= 0x80000000 ? truncated - 0x100000000 : truncated;
    }

    // The ceiling this project standardises on.
    expect(asJsShift(30), 1 << 30);
    expect(asJsShift(30), greaterThan(0));

    // The two values that actually broke, shown failing the same check.
    expect(asJsShift(31), isNegative);
    expect(asJsShift(32), 0);
  });
}
