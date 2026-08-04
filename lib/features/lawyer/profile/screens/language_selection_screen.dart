import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/language_provider.dart';

/// Language picker for the app's three supported locales.
///
/// Selection is applied immediately: [LanguageNotifier.setLanguage] updates
/// [languageProvider] and persists the code to SharedPreferences, and `MyApp`
/// watches that provider and feeds it straight to `MaterialApp.locale`. The
/// whole tree therefore rebuilds in the new language on tap — there is no
/// "Apply" button and no restart, by construction rather than by extra wiring.
///
/// Role-neutral despite living under `lawyer/`: it reads and writes nothing but
/// the locale. The client Settings screen still uses its own inline dropdown;
/// pointing it here would remove that duplicate.
class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  /// Kept in the same order as [AppLocalizations.supportedLocales]. The native
  /// label is shown alongside the English one so a user who has landed in a
  /// language they cannot read can still find their way back.
  static const List<({String code, String english, String native})> _languages =
      [
    (code: 'en', english: 'English', native: 'English'),
    (code: 'te', english: 'Telugu', native: 'తెలుగు'),
    (code: 'hi', english: 'Hindi', native: 'हिंदी'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final currentCode = ref.watch(languageProvider).languageCode;

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          loc!.language,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              loc.choose_language,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _languages.length; i++) ...[
                    if (i > 0)
                      const Divider(color: AppColors.border, height: 1),
                    _LanguageTile(
                      language: _languages[i],
                      isSelected: _languages[i].code == currentCode,
                      onTap: () => ref
                          .read(languageProvider.notifier)
                          .setLanguage(_languages[i].code),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.isSelected,
    required this.onTap,
  });

  final ({String code, String english, String native}) language;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Hand-rolled rather than RadioListTile: the Material radio's
    // groupValue/onChanged pair is deprecated in favour of a RadioGroup
    // ancestor on this Flutter version, and the analyzer currently reports
    // zero issues on this project — worth keeping it that way.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaryGold : AppColors.mutedText,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.native,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primaryGold
                          : AppColors.primaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                  if (language.native != language.english) ...[
                    const SizedBox(height: 2),
                    Text(
                      language.english,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primaryGold, size: 20),
          ],
        ),
      ),
    );
  }
}
