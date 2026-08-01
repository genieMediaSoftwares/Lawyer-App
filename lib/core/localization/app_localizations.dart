import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'GenieLaw',
      'settings': 'Settings',
      'language': 'Language',
      'choose_language': 'Choose your preferred language',
      'change_password': 'Change Password',
      'change_password_subtitle': 'Update your account password securely',
      'delete_account': 'Delete Account',
      'delete_account_subtitle': 'Permanently delete your profile and all data',
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_new_password': 'Confirm New Password',
      'save_password': 'Save New Password',
      'password_changed_success': 'Password changed successfully!',
      'password_match_error': 'Passwords do not match',
      'password_requirements': 'Password Requirements:',
      'rule_min_chars': 'At least 8 characters',
      'rule_uppercase': 'At least 1 uppercase letter (A-Z)',
      'rule_lowercase': 'At least 1 lowercase letter (a-z)',
      'rule_number': 'At least 1 number (0-9)',
      'rule_special': 'At least 1 special character (@#\$%^&*)',
      'delete_account_dialog_title': 'Delete Account',
      'delete_account_dialog_msg':
          'Are you sure you want to permanently delete your account?\n\nThis action cannot be undone.\n\nDeleting your account will permanently remove your profile, cases, appointments, chats, uploaded documents, AI history, and all associated data.',
      'cancel': 'Cancel',
      'enter_password_to_confirm':
          'Enter your current password to confirm deletion:',
      'account_deleted_success': 'Account permanently deleted.',
    },
    'te': {
      'app_title': 'జీనీలా',
      'settings': 'సెట్టింగ్‌లు',
      'language': 'భాష (Language)',
      'choose_language': 'మీకు కావలసిన భాషను ఎంచుకోండి',
      'change_password': 'పాస్‌వర్డ్ మార్చండి',
      'change_password_subtitle':
          'మీ ఖాతా పాస్‌వర్డ్‌ను భద్రంగా అప్‌డేట్ చేయండి',
      'delete_account': 'ఖాతాను తొలగించండి (Delete Account)',
      'delete_account_subtitle':
          'మీ ప్రొఫైల్ మరియు డేటాను శాశ్వతంగా తొలగించండి',
      'current_password': 'ప్రస్తుత పాస్‌వర్డ్',
      'new_password': 'కొత్త పాస్‌వర్డ్',
      'confirm_new_password': 'కొత్త పాస్‌వర్డ్‌ను నిర్ధారించండి',
      'save_password': 'కొత్త పాస్‌వర్డ్‌ను సేవ్ చేయండి',
      'password_changed_success': 'పాస్‌వర్డ్ విజయవంతంగా మార్చబడింది!',
      'password_match_error': 'పాస్‌వర్డ్‌లు సరిపోలడం లేదు',
      'password_requirements': 'పాస్‌వర్డ్ నిబంధనలు:',
      'rule_min_chars': 'కనీసం 8 అక్షరాలు ఉండాలి',
      'rule_uppercase': 'కనీసం 1 పెద్ద అక్షరం (A-Z)',
      'rule_lowercase': 'కనీసం 1 చిన్న అక్షరం (a-z)',
      'rule_number': 'కనీసం 1 సంఖ్య (0-9)',
      'rule_special': 'కనీసం 1 ప్రత్యేక చిహ్నం (@#\$%^&*)',
      'delete_account_dialog_title': 'ఖాతాను తొలగించు',
      'delete_account_dialog_msg':
          'మీరు మీ ఖాతాను శాశ్వతంగా తొలగించాలనుకుంటున్నారా?\n\nఈ చర్యను రద్దు చేయలేము.\n\nమీ ఖాతాను తొలగించడం వల్ల మీ ప్రొఫైల్, కేసులు, అపాయింట్‌మెంట్‌లు, చాట్‌లు, అప్‌లోడ్ చేసిన పత్రాలు, AI చరిత్ర మరియు అనుబంధిత డేటా శాశ్వతంగా తొలగించబడతాయి.',
      'cancel': 'రద్దు చేయి',
      'enter_password_to_confirm':
          'ఖాతా తొలగింపును నిర్ధారించడానికి మీ ప్రస్తుత పాస్‌వర్డ్‌ను నమోదు చేయండి:',
      'account_deleted_success': 'ఖాతా శాశ్వతంగా తొలగించబడింది.',
    },
    'hi': {
      'app_title': 'जीनीलॉ',
      'settings': 'सेटिंग्स',
      'language': 'भाषा (Language)',
      'choose_language': 'अपनी पसंदीदा भाषा चुनें',
      'change_password': 'पासवर्ड बदलें',
      'change_password_subtitle':
          'अपने खाते का पासवर्ड सुरक्षित रूप से अपडेट करें',
      'delete_account': 'खाता हटाएं (Delete Account)',
      'delete_account_subtitle':
          'अपनी प्रोफ़ाइल और सभी डेटा को स्थायी रूप से हटाएँ',
      'current_password': 'वर्तमान पासवर्ड',
      'new_password': 'नया पासवर्ड',
      'confirm_new_password': 'नए पासवर्ड की पुष्टि करें',
      'save_password': 'नया पासवर्ड सहेजें',
      'password_changed_success': 'पासवर्ड सफलतापूर्वक बदल दिया गया!',
      'password_match_error': 'पासवर्ड मेल नहीं खाते हैं',
      'password_requirements': 'पासवर्ड आवश्यकताएं:',
      'rule_min_chars': 'कम से कम 8 अक्षर',
      'rule_uppercase': 'कम से कम 1 बड़ा अक्षर (A-Z)',
      'rule_lowercase': 'कम से कम 1 छोटा अक्षर (a-z)',
      'rule_number': 'कम से कम 1 अंक (0-9)',
      'rule_special': 'कम से कम 1 विशेष वर्ण (@#\$%^&*)',
      'delete_account_dialog_title': 'खाता हटाएं',
      'delete_account_dialog_msg':
          'क्या आप वाकई अपना खाता स्थायी रूप से हटाना चाहते हैं?\n\nइस क्रिया को पूर्ववत नहीं किया जा सकता है।\n\nअपना खाता हटाने से आपकी प्रोफ़ाइल, मामले, अपॉइंटमेंट, चैट, अपलोड किए गए दस्तावेज़, AI इतिहास और सभी संबंधित डेटा स्थायी रूप से हटा दिए जाएंगे।',
      'cancel': 'रद्द करें',
      'enter_password_to_confirm':
          'हटाने की पुष्टि के लिए अपना वर्तमान पासवर्ड दर्ज करें:',
      'account_deleted_success': 'खाता स्थायी रूप से हटा दिया गया।',
    },
  };

  String translate(String key) {
    final langCode = locale.languageCode;
    return _localizedValues[langCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'te', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
