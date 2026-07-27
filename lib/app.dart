import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/localization/app_localizations.dart';
import 'core/network/test_api.dart';
import 'core/theme/app_theme.dart';
import 'providers/language_provider.dart';
import 'routes/app_router.dart';

class MyApp extends ConsumerWidget {
  final ThemeData? customTheme;
  const MyApp({super.key, this.customTheme});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final router = ref.watch(routerProvider);
    final languageState = ref.watch(languageProvider);

    TestApi.test();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GenieLaw',

      locale: languageState.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],

      theme: customTheme ?? AppTheme.luxuryTheme,
      darkTheme: customTheme ?? AppTheme.luxuryTheme,

      routerConfig: router,
    );
  }
}