// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get app_title => 'जीनीलॉ';

  @override
  String get settings => 'सेटिंग्स';

  @override
  String get language => 'भाषा (Language)';

  @override
  String get choose_language => 'अपनी पसंदीदा भाषा चुनें';

  @override
  String get change_password => 'पासवर्ड बदलें';

  @override
  String get change_password_subtitle =>
      'अपने खाते का पासवर्ड सुरक्षित रूप से अपडेट करें';

  @override
  String get delete_account => 'खाता हटाएं (Delete Account)';

  @override
  String get delete_account_subtitle =>
      'अपनी प्रोफ़ाइल और सभी डेटा को स्थायी रूप से हटाएँ';

  @override
  String get current_password => 'वर्तमान पासवर्ड';

  @override
  String get new_password => 'नया पासवर्ड';

  @override
  String get confirm_new_password => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get save_password => 'नया पासवर्ड सहेजें';

  @override
  String get password_changed_success => 'पासवर्ड सफलतापूर्वक बदल दिया गया!';

  @override
  String get password_match_error => 'पासवर्ड मेल नहीं खाते हैं';

  @override
  String get password_requirements => 'पासवर्ड आवश्यकताएं:';

  @override
  String get rule_min_chars => 'कम से कम 8 अक्षर';

  @override
  String get rule_uppercase => 'कम से कम 1 बड़ा अक्षर (A-Z)';

  @override
  String get rule_lowercase => 'कम से कम 1 छोटा अक्षर (a-z)';

  @override
  String get rule_number => 'कम से कम 1 अंक (0-9)';

  @override
  String get rule_special => 'कम से कम 1 विशेष वर्ण (@#\$%^&*)';

  @override
  String get delete_account_dialog_title => 'खाता हटाएं';

  @override
  String get delete_account_dialog_msg =>
      'क्या आप वाकई अपना खाता स्थायी रूप से हटाना चाहते हैं?\n\nइस क्रिया को पूर्ववत नहीं किया जा सकता है।\n\nअपना खाता हटाने से आपकी प्रोफ़ाइल, मामले, अपॉइंटमेंट, चैट, अपलोड किए गए दस्तावेज़, AI इतिहास और सभी संबंधित डेटा स्थायी रूप से हटा दिए जाएंगे।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get enter_password_to_confirm =>
      'हटाने की पुष्टि के लिए अपना वर्तमान पासवर्ड दर्ज करें:';

  @override
  String get account_deleted_success => 'खाता स्थायी रूप से हटा दिया गया।';

  @override
  String get nav_workspace => 'वर्कस्पेस';

  @override
  String get nav_dashboard => 'डैशबोर्ड';

  @override
  String get nav_leads => 'लीड्स';

  @override
  String get nav_clients => 'क्लाइंट';

  @override
  String get nav_calendar => 'कैलेंडर';

  @override
  String get nav_profile => 'प्रोफ़ाइल';

  @override
  String get my_profile => 'मेरी प्रोफ़ाइल';

  @override
  String get advocate_prefix => 'एडवोकेट';

  @override
  String get advocate_fallback => 'अधिवक्ता';

  @override
  String get legal_practitioner => 'विधि व्यवसायी';

  @override
  String get reviews => 'समीक्षाएं';

  @override
  String get premium_plan => 'प्रीमियम प्लान';

  @override
  String get premium_plan_desc =>
      'प्राथमिकता वाली केस मैचिंग, AI विधि टूल्स, प्रीमियम विज़िबिलिटी और विशेष पेशेवर सुविधाएं अनलॉक करें।';

  @override
  String get view_plan => 'प्लान देखें';

  @override
  String get todays_overview => 'आज का अवलोकन';

  @override
  String get new_case_requests => 'नए केस अनुरोध';

  @override
  String get awaiting_response => 'प्रतिक्रिया की प्रतीक्षा में';

  @override
  String get unread_messages => 'अपठित संदेश';

  @override
  String get from_active_clients => 'सक्रिय क्लाइंट से';

  @override
  String get pending_document_reviews => 'लंबित दस्तावेज़ समीक्षाएं';

  @override
  String get docs_waiting_review => 'समीक्षा की प्रतीक्षा में दस्तावेज़';

  @override
  String get pending_client_responses => 'लंबित क्लाइंट प्रतिक्रियाएं';

  @override
  String get waiting_lawyer_action => 'वकील की कार्रवाई की प्रतीक्षा में';

  @override
  String welcome_name(String name) {
    return 'स्वागत है, $name';
  }

  @override
  String reviews_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count समीक्षाएं',
      one: '1 समीक्षा',
      zero: 'कोई समीक्षा नहीं',
    );
    return '$_temp0';
  }

  @override
  String get notifications => 'सूचनाएं';

  @override
  String get mark_all_read => 'सभी को पढ़ा हुआ चिन्हित करें';

  @override
  String get no_notifications => 'कोई सूचना नहीं मिली';

  @override
  String get filter_all => 'सभी';

  @override
  String get filter_unread => 'अपठित';

  @override
  String get active_leads => 'सक्रिय लीड्स';

  @override
  String get active_clients => 'सक्रिय क्लाइंट';

  @override
  String get in_progress_cases => 'प्रगति पर';

  @override
  String get completed_cases => 'पूर्ण';

  @override
  String get search_placeholder => 'खोजें...';

  @override
  String get save_changes => 'परिवर्तन सहेजें';

  @override
  String get edit_profile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get professional_details => 'व्यावसायिक विवरण';

  @override
  String get consultation_settings => 'परामर्श सेटिंग्स';

  @override
  String get documents => 'दस्तावेज़';

  @override
  String get subscription => 'सदस्यता';

  @override
  String get logout => 'लॉग आउट';

  @override
  String get confirm_logout => 'क्या आप वाकई लॉग आउट करना चाहते हैं?';

  @override
  String get confirm => 'पुष्टि करें';

  @override
  String get back => 'वापस';

  @override
  String get error_occurred => 'एक त्रुटि हुई';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get no_data_available => 'कोई डेटा उपलब्ध नहीं है';
}
