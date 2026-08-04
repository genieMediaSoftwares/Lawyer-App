import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:law/core/localization/app_localizations.dart';
import 'package:law/features/lawyer/profile/screens/language_selection_screen.dart';
import 'package:law/providers/language_provider.dart';

/// Guards real-time language switching.
///
/// The app shipped `localizationsDelegates: [AppLocalizations.delegate]` only.
/// MaterialApp then falls back to DefaultMaterialLocalizations, whose delegate
/// reports `isSupported => locale.languageCode == 'en'`, so English resolved
/// and Telugu/Hindi resolved to *no* MaterialLocalizations at all. The next
/// Scaffold/AppBar to build after switching threw "No MaterialLocalizations
/// found" — which looked like a navigation or provider fault but was purely a
/// missing delegate.
///
/// These tests build against [AppLocalizations.localizationsDelegates], the
/// same list `MyApp` passes to MaterialApp, so dropping a delegate fails here.
void main() {
  /// Every locale the app offers, plus one it does not, to prove the
  /// supportedLocales fallback also lands somewhere that has localizations.
  const locales = <String, Locale>{
    'English': Locale('en'),
    'Telugu': Locale('te'),
    'Hindi': Locale('hi'),
    'unsupported (French)': Locale('fr'),
  };

  group('MaterialLocalizations resolve for', () {
    locales.forEach((name, locale) {
      testWidgets(name, (tester) async {
        late BuildContext captured;

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            // An AppBar is the widget that threw: it reads
            // MaterialLocalizations for the back button's tooltip.
            home: Builder(
              builder: (context) {
                captured = context;
                return Scaffold(
                  appBar: AppBar(title: const Text('Settings')),
                  body: const SizedBox.shrink(),
                );
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(Localizations.of<MaterialLocalizations>(
                captured, MaterialLocalizations)
            , isNotNull);
        expect(
          Localizations.of<WidgetsLocalizations>(captured, WidgetsLocalizations),
          isNotNull,
        );
      });
    });
  });

  testWidgets(
      'selecting each language rebuilds the app in that locale without error',
      (tester) async {
    // Mirrors MyApp: MaterialApp.locale is driven by languageProvider, so a
    // selection rebuilds the whole tree rather than a subtree.
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final language = ref.watch(languageProvider);
            return MaterialApp(
              locale: language.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const LanguageSelectionScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Telugu, then Hindi, then back to English. Going through all three in one
    // test is the point: the failure only appeared on the *second* build, once
    // the locale had actually moved off English.
    for (final native in ['తెలుగు', 'हिंदी', 'English']) {
      await tester.tap(find.text(native));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'selecting $native threw',
      );

      // The screen is still mounted and readable after the rebuild — i.e. the
      // AppBar survived the locale change.
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    }
  });

  testWidgets('the selected language is marked in the list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final language = ref.watch(languageProvider);
            return MaterialApp(
              locale: language.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const LanguageSelectionScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one row is checked at a time.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

    await tester.tap(find.text('తెలుగు'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
