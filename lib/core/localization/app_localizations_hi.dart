// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get app_title => 'जीनीला';

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
      'सुरक्षित रूप से अपना खाता पासवर्ड अपडेट करें';

  @override
  String get delete_account => 'खाता हटाएं (Delete Account)';

  @override
  String get delete_account_subtitle =>
      'अपनी प्रोफ़ाइल और डेटा को स्थायी रूप से हटाएं';

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
  String get password_match_error => 'पासवर्ड मेल नहीं खाते';

  @override
  String get password_requirements => 'पासवर्ड की आवश्यकताएं:';

  @override
  String get rule_min_chars => 'कम से कम 8 अक्षर';

  @override
  String get rule_uppercase => 'कम से कम 1 बड़ा अक्षर (A-Z)';

  @override
  String get rule_lowercase => 'कम से कम 1 छोटा अक्षर (a-z)';

  @override
  String get rule_number => 'कम से कम 1 संख्या (0-9)';

  @override
  String get rule_special => 'कम से कम 1 विशेष वर्ण (@#\$%^&*)';

  @override
  String get delete_account_dialog_title => 'खाता हटाएं';

  @override
  String get delete_account_dialog_msg =>
      'क्या आप निश्चित रूप से अपना खाता स्थायी रूप से हटाना चाहते हैं?\n\nइस क्रिया को पूर्ववत नहीं किया जा सकता है।\n\nअपना खाता हटाने से आपकी प्रोफ़ाइल, मामले, अपॉइंटमेंट, चैट, अपलोड किए गए दस्तावेज़, AI इतिहास और सभी संबंधित डेटा स्थायी रूप से हट जाएंगे।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get enter_password_to_confirm =>
      'खाता हटाने की पुष्टि के लिए अपना वर्तमान पासवर्ड दर्ज करें:';

  @override
  String get account_deleted_success => 'खाता स्थायी रूप से हटा दिया गया।';

  @override
  String get nav_workspace => 'वर्कस्पेस';

  @override
  String get nav_dashboard => 'डैशबोर्ड';

  @override
  String get nav_leads => 'लीड्स';

  @override
  String get nav_clients => 'क्लाइंट्स';

  @override
  String get nav_calendar => 'कैलेंडर';

  @override
  String get nav_profile => 'प्रोफ़ाइल';

  @override
  String get my_profile => 'मेरी प्रोफ़ाइल';

  @override
  String get advocate_prefix => 'एडव.';

  @override
  String get advocate_fallback => 'अधिवक्ता';

  @override
  String get legal_practitioner => 'कानूनी पेशेवर';

  @override
  String get reviews => 'समीक्षाएं';

  @override
  String get premium_plan => 'प्रीमियम प्लान';

  @override
  String get premium_plan_desc =>
      'प्राथमिकता केस मैचिंग, AI कानूनी उपकरण, प्रीमियम दृश्यता और विशेष पेशेवर सुविधाओं को अनलॉक करें।';

  @override
  String get view_plan => 'प्लाँ देखें';

  @override
  String get todays_overview => 'आज का अवलोकन';

  @override
  String get new_case_requests => 'नए केस अनुरोध';

  @override
  String get awaiting_response => 'प्रतिक्रिया की प्रतीक्षा है';

  @override
  String get unread_messages => 'अपठित संदेश';

  @override
  String get from_active_clients => 'सक्रिय क्लाइंट्स से';

  @override
  String get pending_document_reviews => 'लंबित दस्तावेज़ समीक्षाएं';

  @override
  String get docs_waiting_review => 'समीक्षा की प्रतीक्षा में दस्तावेज़';

  @override
  String get pending_client_responses => 'लंबित क्लाइंट प्रतिक्रियाएं';

  @override
  String get waiting_lawyer_action => 'वकील की कार्रवाई की प्रतीक्षा है';

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
  String get mark_all_read => 'सभी को पढ़ा हुआ चिह्नित करें';

  @override
  String get no_notifications => 'कोई सूचना नहीं मिली';

  @override
  String get filter_all => 'सभी';

  @override
  String get filter_unread => 'अपठित';

  @override
  String get active_leads => 'सक्रिय लीड्स';

  @override
  String get active_clients => 'सक्रिय क्लाइंट्स';

  @override
  String get in_progress_cases => 'प्रगति में';

  @override
  String get completed_cases => 'पूरा हुआ';

  @override
  String get search_placeholder => 'खोजें...';

  @override
  String get save_changes => 'बदलाव सहेजें';

  @override
  String get edit_profile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get professional_details => 'पेशेवर विवरण';

  @override
  String get consultation_settings => 'परामर्श सेटिंग्स';

  @override
  String get documents => 'दस्तावेज़';

  @override
  String get subscription => 'सदस्यता (Subscription)';

  @override
  String get logout => 'लॉगआउट';

  @override
  String get confirm_logout => 'क्या आप निश्चित रूप से लॉगआउट करना चाहते हैं?';

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

  @override
  String get guest_user => 'अतिथि उपयोगकर्ता';

  @override
  String get sign_out => 'साइन आउट';

  @override
  String get my_cases => 'मेरे मामले';

  @override
  String get advocates => 'अधिवक्ता';

  @override
  String get messages => 'संदेश';

  @override
  String get my_documents => 'मेरे दस्तावेज़';

  @override
  String get favorite_lawyers => 'पसंदीदा वकील';

  @override
  String get subscription_plans => 'सदस्यता योजनाएं';

  @override
  String get personal_info => 'व्यक्तिगत जानकारी';

  @override
  String get terms_conditions => 'नियम और शर्तें';

  @override
  String get privacy_policy => 'गोपनीयता नीति';

  @override
  String get about_us => 'हमारे बारे में';

  @override
  String get help_center => 'सहायता केंद्र';

  @override
  String get contact_support => 'सहायता से संपर्क करें';

  @override
  String get recent_activity => 'हाल की गतिविधि';

  @override
  String get choose_subscription_plan_subtitle =>
      'अपनी प्रैक्टिस के लिए सही प्लान चुनें';

  @override
  String get most_popular => 'सबसे लोकप्रिय';

  @override
  String get continue_button => 'जारी रखें';

  @override
  String get new_leads_tab => 'नई लीड्स';

  @override
  String get accepted_tab => 'स्वीकृत';

  @override
  String get search_new_leads_hint => 'नई लीड्स खोजें...';

  @override
  String get search_accepted_hint => 'स्वीकृत मामलों को खोजें...';

  @override
  String get accept_case_dialog_title => 'केस स्वीकार करें?';

  @override
  String get accept_case_dialog_body => 'इस केस अनुरोध को स्वीकार करें?';

  @override
  String get accept_button => 'स्वीकार करें';

  @override
  String get reject_lead_dialog_title => 'लीड अस्वीकार करें?';

  @override
  String get reject_lead_dialog_body => 'इस केस लीड को अस्वीकार करें?';

  @override
  String get reject_button => 'अस्वीकार करें';

  @override
  String get complete_case_dialog_title => 'केस पूरा करें?';

  @override
  String get complete_case_dialog_body =>
      'इस केस को पूर्ण के रूप में चिह्नित करें?';

  @override
  String get complete_button => 'पूरा करें';

  @override
  String get view_details => 'विवरण देखें';

  @override
  String get view_case => 'केस देखें';

  @override
  String get accept_case => 'केस स्वीकार करें';

  @override
  String get reject_lead => 'लीड अस्वीकार करें';

  @override
  String get mark_completed => 'पूर्ण चिह्नित करें';

  @override
  String get failed_to_load_leads => 'लीड्स लोड करने में विफल।';

  @override
  String get no_new_leads_empty =>
      'कोई नई केस लीड नहीं है।\nबाद में पुनः जांचें!';

  @override
  String get no_accepted_cases_empty => 'अभी तक कोई स्वीकृत मामला नहीं है।';

  @override
  String posted_on(String date) {
    return 'पोस्ट की तारीख: $date';
  }

  @override
  String accepted_on(String date) {
    return 'स्वीकृत तारीख: $date';
  }

  @override
  String urgency_label(String urgency) {
    return 'अतिआवश्यकता: $urgency';
  }

  @override
  String docs_uploaded_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दस्तावेज़ अपलोड किए गए',
      one: '1 दस्तावेज़ अपलोड किया गया',
      zero: 'कोई दस्तावेज़ नहीं',
    );
    return '$_temp0';
  }

  @override
  String match_percentage(num percent) {
    return '$percent% मैच';
  }

  @override
  String get close_button => 'बंद करें';

  @override
  String get failed_to_load_profile => 'प्रोफ़ाइल विवरण लोड करने में विफल।';

  @override
  String get account_professional_details_header => 'खाता और पेशेवर विवरण';

  @override
  String get profile_photo_subtitle => 'फ़ोटो, नाम, स्थान, संपर्क';

  @override
  String get professional_info_subtitle =>
      'विशेषज्ञता, शिक्षा, बार काउंसिल विवरण';

  @override
  String get documents_subtitle => 'आपके क्रेडेंशियल और केस रिकॉर्ड';

  @override
  String get settings_subtitle => 'भाषा, कैलेंडर, सहायता और कानूनी';

  @override
  String get verified_advocate => 'सत्यापित अधिवक्ता';

  @override
  String get verification_pending => 'सत्यापन लंबित';

  @override
  String get profile_completion => 'प्रोफ़ाइल पूर्णता';

  @override
  String get profile_complete_tip =>
      '🎉 आपकी प्रोफ़ाइल 100% पूर्ण है! यह दृश्यता बढ़ाती है और क्लाइंट का विश्वास बनाती है।';

  @override
  String get profile_incomplete_tip =>
      '💡 सुझाव: पूछताछ और परामर्श बुकिंग प्राप्त करने के लिए अपनी पेशेवर और बैंक सेटिंग्स को पूरा करें।';

  @override
  String get cases_handled => 'संभाले गए मामले';

  @override
  String get win_rate => 'जीत दर';

  @override
  String get rating => 'रेटिंग';

  @override
  String get profile_image_updated_success =>
      'प्रोफ़ाइल चित्र सफलतापूर्वक अपडेट किया गया!';

  @override
  String get profile_image_updated_failure =>
      'प्रोफ़ाइल चित्र अपलोड करने में विफल।';

  @override
  String error_selecting_image(String error) {
    return 'चित्र चुनने में त्रुटि: $error';
  }

  @override
  String get email_address => 'ईमेल पता';

  @override
  String get phone_number => 'फ़ोन नंबर';

  @override
  String get location => 'स्थान (Location)';

  @override
  String get location_not_set => 'स्थान सेट नहीं है';

  @override
  String get edit_profile_details => 'प्रोफ़ाइल विवरण संपादित करें';

  @override
  String get edit_personal_info => 'व्यक्तिगत जानकारी संपादित करें';

  @override
  String get full_name => 'पूरा नाम';

  @override
  String get name_is_required => 'नाम आवश्यक है';

  @override
  String get phone_is_required => 'फ़ोन नंबर आवश्यक है';

  @override
  String get location_is_required => 'स्थान आवश्यक है';

  @override
  String get personal_details_saved_success =>
      'व्यक्तिगत विवरण सफलतापूर्वक सहेजे गए!';

  @override
  String get personal_details_saved_failure =>
      'प्रोफ़ाइल विवरण अपडेट करने में विफल।';

  @override
  String get professional_details_updated_success =>
      'पेशेवर विवरण सफलतापूर्वक अपडेट किए गए!';

  @override
  String get professional_details_updated_failure =>
      'विवरण अपडेट करने में विफल।';

  @override
  String get professional_details_subtitle =>
      'अधिक क्लाइंट परामर्श बुकिंग आकर्षित करने के लिए अपने पेशेवर विवरण अपडेट करें।';

  @override
  String get specialization_label =>
      'विशेषज्ञता (उदा. पारिवारिक कानून, आपराधिक बचाव)';

  @override
  String get specialization_required => 'विशेषज्ञता आवश्यक है';

  @override
  String get years_experience_label => 'अनुभव के वर्ष';

  @override
  String get experience_required => 'अनुभव आवश्यक है';

  @override
  String get valid_number_required => 'कृपया एक मान्य संख्या दर्ज करें';

  @override
  String get education_label => 'शिक्षा / योग्यता (उदा. LL.B., हार्वर्ड लॉ)';

  @override
  String get education_required => 'शिक्षा आवश्यक है';

  @override
  String get bar_registration_label => 'बार काउंसिल पंजीकरण संख्या';

  @override
  String get registration_required => 'पंजीकरण संख्या आवश्यक है';

  @override
  String get bio_label => 'मेरे बारे में / पेशेवर बायो';

  @override
  String get bio_required => 'बायो सारांश आवश्यक है';

  @override
  String get consultation_settings_updated_success =>
      'परामर्श सेटिंग्स सफलतापूर्वक अपडेट की गईं!';

  @override
  String get consultation_settings_updated_failure =>
      'सेटिंग्स अपडेट करने में विफल।';

  @override
  String get consultation_settings_subtitle =>
      'भुगतान और बुकिंग पुष्टियों को स्वचालित करने के लिए अपनी परामर्श शुल्क, कार्य समय और बैंक विवरण सेट करें।';

  @override
  String get consultation_fee_label => 'परामर्श शुल्क (प्रति स्लाॉट ₹)';

  @override
  String get consultation_fee_required => 'परामर्श शुल्क आवश्यक है';

  @override
  String get working_hours_label => 'कार्य का समय (उदा. सुबह 9:00 - शाम 6:00)';

  @override
  String get working_hours_required => 'कार्य का समय आवश्यक है';

  @override
  String get office_address_label => 'कार्यालय का पता / चैंबर स्थान';

  @override
  String get office_address_required => 'कार्यालय का पता आवश्यक है';

  @override
  String get upi_id_label => 'UPI ID (प्रत्यक्ष क्लाइंट भुगतान के लिए)';

  @override
  String get upi_id_required => 'UPI ID आवश्यक है';

  @override
  String get bank_settlement_header => 'बैंक निपटान विवरण';

  @override
  String get account_holder_label => 'खाताधारक का नाम';

  @override
  String get account_holder_required => 'खाताधारक का नाम आवश्यक है';

  @override
  String get bank_name_label => 'बैंक का नाम';

  @override
  String get bank_name_required => 'बैंक का नाम आवश्यक है';

  @override
  String get account_number_label => 'बैंक खाता संख्या';

  @override
  String get account_number_required => 'खाता संख्या आवश्यक है';

  @override
  String get ifsc_code_label => 'IFSC कोड';

  @override
  String get ifsc_code_required => 'IFSC कोड आवश्यक है';

  @override
  String get doc_uploaded_success => 'दस्तावेज़ सफलतापूर्वक अपलोड किया गया!';

  @override
  String get doc_upload_failed => 'अपलोड विफल। अमान्य प्रकार या आकार सीमा।';

  @override
  String get doc_upload_error => 'अपलोड त्रुटि हुई।';

  @override
  String get uploading => 'अपलोड हो रहा है...';

  @override
  String get upload_document => 'दस्तावेज़ अपलोड करें';

  @override
  String get no_documents_found => 'कोई दस्तावेज़ नहीं मिला';

  @override
  String get upload_documents_tip =>
      'अपनी साख, बार पंजीकरण प्रमाण पत्र या पहचान सत्यापन अपलोड करें।';

  @override
  String get delete_document => 'दस्तावेज़ हटाएं';

  @override
  String get confirm_delete_document =>
      'क्या आप निश्चित रूप से इस दस्तावेज़ को स्थायी रूप से हटाना चाहते हैं?';

  @override
  String get doc_deleted_success => 'दस्तावेज़ सफलतापूर्वक हटा दिया गया।';

  @override
  String get reviews_and_feedback => 'समीक्षाएं और प्रतिक्रिया';

  @override
  String based_on_reviews_count(num count) {
    return '$count समीक्षाओं के आधार पर';
  }

  @override
  String client_feedbacks_header(num count) {
    return 'क्लाइंट प्रतिक्रियाएं ($count)';
  }

  @override
  String get no_reviews_yet => 'अभी तक कोई समीक्षा नहीं';

  @override
  String get no_reviews_tip =>
      'आपके मामले या परामर्श हल होने के बाद क्लाइंट समीक्षाएं यहां दिखाई देंगी।';

  @override
  String get photo_name_contact_subtitle =>
      'अपनी प्रोफ़ाइल जानकारी देखें और अपडेट करें।';

  @override
  String get dob_gender_address_subtitle => 'जन्मतिथि, लिंग, पता, भाषाएं।';

  @override
  String get timeline_activity_subtitle =>
      'अपनी हाल की गतिविधियां और खाता गतिविधि देखें।';

  @override
  String get support_help_subtitle => 'सहायता केंद्र, गोपनीयता, शर्तें, सहायता';

  @override
  String get legal_desk_header => 'कानूनी डेस्क और सेवाएं';

  @override
  String get your_legal_docs_subtitle =>
      'अपने अपलोड किए गए दस्तावेज़ देखें और प्रबंधित करें।';

  @override
  String get account_app_settings_subtitle =>
      'अपना खाता, भाषा, सूचनाएं, गोपनीयता और प्राथमिकताएं प्रबंधित करें।';

  @override
  String get verified_client => 'सत्यापित क्लाइंट';

  @override
  String get date_of_birth => 'जन्म तिथि';

  @override
  String get dob_required => 'जन्म तिथि आवश्यक है';

  @override
  String get select_valid_date => 'कृपया एक मान्य तिथि चुनें';

  @override
  String get dob_future_error => 'जन्म तिथि भविष्य में नहीं हो सकती';

  @override
  String get select_gender => 'लिंग चुनें';

  @override
  String get gender => 'लिंग';

  @override
  String get gender_male => 'पुरुष';

  @override
  String get gender_female => 'महिला';

  @override
  String get gender_other => 'अन्य';

  @override
  String get gender_prefer_not_say => 'बताना नहीं चाहते';

  @override
  String get gender_required => 'लिंग आवश्यक है';

  @override
  String get languages_comma_separated => 'भाषाएं (कॉमा से अलग की हुई)';

  @override
  String get address_location => 'पता / स्थान';

  @override
  String get personal_info_updated_success =>
      'व्यक्तिगत जानकारी सफलतापूर्वक अपडेट की गई!';

  @override
  String get personal_info_subtitle =>
      'अपने कानूनी रिकॉर्ड को अद्यतन रखने के लिए नीचे अपने व्यक्तिगत विवरण सत्यापित और अपडेट करें।';

  @override
  String get languages_example_hint => 'भाषाएं (उदा. अंग्रेजी, हिंदी, तेलुगु)';

  @override
  String get languages_required => 'भाषाएं आवश्यक हैं';

  @override
  String get no_favorites_added_yet => 'अभी तक कोई पसंदीदा नहीं जोड़ा गया';

  @override
  String get no_favorites_tip =>
      'उन्हें यहां सहेजने के लिए किसी भी वकील के प्रोफ़ाइल पृष्ठ पर दिल के आइकन पर टैप करें।';

  @override
  String get book_button => 'बुकिंग';

  @override
  String get book_now_button => 'अभी बुक करें';

  @override
  String get removed_from_favorites => 'पसंदीदा वकीलों से हटा दिया गया।';

  @override
  String all_cases_tab_header(num count) {
    return 'सभी मामले ($count)';
  }

  @override
  String in_progress_tab_header(num count) {
    return 'प्रगति में ($count)';
  }

  @override
  String closed_tab_header(num count) {
    return 'पूर्ण हुए ($count)';
  }

  @override
  String get no_cases_posted_empty => 'अभी तक कोई केस पोस्ट नहीं किया गया।';

  @override
  String get no_cases_in_progress_empty =>
      'वर्तमान में कोई केस प्रगति में नहीं है।';

  @override
  String get no_completed_cases_empty => 'अभी तक कोई पूर्ण केस नहीं है।';

  @override
  String get lawyers_responded_header => 'वकीलों ने जवाब दिया';

  @override
  String get no_proposals_received_empty =>
      'अभी तक कोई प्रस्ताव प्राप्त नहीं हुआ।';

  @override
  String proposals_received_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रस्ताव प्राप्त हुए',
      one: '1 प्रस्ताव प्राप्त हुआ',
      zero: 'कोई प्रस्ताव नहीं',
    );
    return '$_temp0';
  }

  @override
  String get view_profile_button => 'प्रोफ़ाइल देखें';

  @override
  String consultation_fee_amount(num amount) {
    return '₹$amount परामर्श शुल्क';
  }

  @override
  String get case_details_header => 'केस विवरण';

  @override
  String get no_case_details_found => 'कोई केस विवरण नहीं मिला।';

  @override
  String get case_progress_tracker => 'केस प्रगति ट्रैकर';

  @override
  String get next_consultation => 'अगला परामर्श';

  @override
  String get supporting_documents => 'सहायक दस्तावेज़';

  @override
  String get description => 'विवरण';

  @override
  String get completed_status => 'पूर्ण';

  @override
  String get pending_status => 'लंबित';

  @override
  String get awaiting_counsel_assignment => 'वकील आवंटन की प्रतीक्षा है...';

  @override
  String get welcome_advocate => 'स्वागत है, अधिवक्ता';

  @override
  String get workspace_welcome_desc =>
      'क्लाइंट मामलों का प्रबंधन करें, कानूनी पूछताछ की समीक्षा करें, परामर्श अनुरोधों का उत्तर दें और अपने शेड्यूल को व्यवस्थित करें—सब कुछ एक सुरक्षित वर्कस्पेस से।';

  @override
  String get workspace_tools => 'वर्कस्पेस उपकरण';

  @override
  String new_leads_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नई लीड्स',
      one: '1 नई लीड',
      zero: 'कोई लीड नहीं',
    );
    return '$_temp0';
  }

  @override
  String get waiting_for_response => 'आपकी प्रतिक्रिया की प्रतीक्षा है';

  @override
  String clients_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count क्लाइंट्स',
      one: '1 क्लाइंट',
      zero: 'कोई क्लाइंट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get accepted_in_progress_closed => 'स्वीकृत, प्रगति में, पूर्ण';

  @override
  String get todays_schedule => 'आज का शेड्यूल';

  @override
  String get no_events_today => 'आज कोई ईवेंट नहीं है';

  @override
  String events_today_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ईवेंट आज',
      one: '1 ईवेंट आज',
      zero: 'कोई ईवेंट नहीं',
    );
    return '$_temp0';
  }

  @override
  String unread_chats_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अपठित चैट',
      one: '1 अपठित चैट',
      zero: 'कोई अपठित चैट नहीं',
    );
    return '$_temp0';
  }

  @override
  String get all_caught_up => 'सभी संदेश पढ़े जा चुके हैं';

  @override
  String get active_tab => 'सक्रिय';

  @override
  String get in_progress_tab => 'प्रगति में';

  @override
  String get completed_tab => 'पूर्ण हुए';

  @override
  String category_label(String category) {
    return 'श्रेणी: $category';
  }

  @override
  String title_label(String title) {
    return 'शीर्षक: $title';
  }

  @override
  String location_label(String location) {
    return 'स्थान: $location';
  }

  @override
  String court_label(String court) {
    return 'कोर्ट: $court';
  }

  @override
  String accepted_date_label(String date) {
    return 'स्वीकृत तारीख: $date';
  }

  @override
  String get any_court => 'कोई भी कोर्ट';

  @override
  String get accepted_status => 'स्वीकृत';

  @override
  String get view_client_button => 'क्लाइंट देखें';

  @override
  String get start_case_button => 'केस शुरू करें';

  @override
  String get case_work_started => 'केस का काम शुरू हो गया!';

  @override
  String get preferences_header => 'प्राथमिकताएं';

  @override
  String get support_legal_header => 'सहायता और कानूनी';

  @override
  String get account_header => 'खाता';

  @override
  String get google_calendar_title => 'गूगल कैलेंडर';

  @override
  String get google_calendar_subtitle =>
      'गूगल कैलेंडर के साथ अपने अपॉइंटमेंट सिंक करें';

  @override
  String google_calendar_connected(String email) {
    return 'कनेक्ट किया गया: $email';
  }

  @override
  String get connect_button => 'कनेक्ट करें';

  @override
  String get disconnect_button => 'डिस्कनेक्ट करें';

  @override
  String get contact_support_subtitle =>
      'हमारी समर्पित सहायता टीम से संपर्क करें';

  @override
  String get about_us_subtitle => 'हम कौन हैं और जीनीला क्या करता है';

  @override
  String get privacy_policy_subtitle =>
      'आपका डेटा कैसे एकत्र और उपयोग किया जाता है';

  @override
  String get terms_conditions_subtitle =>
      'जीनीला के आपके उपयोग को नियंत्रित करने वाला समझौता';

  @override
  String get delete_account_permanently => 'खाता स्थायी रूप से हटाएं';

  @override
  String get need_assistance_heading => 'सहायता की आवश्यकता है?';

  @override
  String get need_assistance_desc =>
      'यदि आप तकनीकी समस्याओं, खाते से संबंधित समस्याओं का सामना कर रहे हैं या सामान्य सहायता चाहते हैं, तो हमारी सहायता टीम आपकी सहायता के लिए तैयार है।';

  @override
  String get email_support_title => 'ईमेल सहायता';

  @override
  String get send_email_button => 'ईमेल भेजें';

  @override
  String get response_time_heading => 'प्रतिक्रिया समय';

  @override
  String get response_time_desc =>
      'हम आमतौर पर 24–48 कार्य घंटों के भीतर जवाब देते हैं।';

  @override
  String get app_info_title => 'ऐप जानकारी';

  @override
  String app_version_label(String version) {
    return 'संस्करण: $version';
  }

  @override
  String build_number_label(String build) {
    return 'बिल्ड: $build';
  }

  @override
  String could_not_launch_email(String email) {
    return 'ईमेल ऐप नहीं खोला जा सका। कृपया सीधे $email पर ईमेल भेजें';
  }

  @override
  String get password_required_to_confirm => 'पुष्टि के लिए पासवर्ड आवश्यक है।';

  @override
  String get incorrect_password => 'गलत पासवर्ड।';

  @override
  String get notifications_subtitle =>
      'जीनीलॉ आपको कब और कैसे सूचित करे, यह प्रबंधित करें';

  @override
  String get google_calendar_lawyer_only =>
      'कैलेंडर सिंक केवल अधिवक्ताओं के लिए उपलब्ध है';

  @override
  String get account_header_client => 'खाता';

  @override
  String get google_calendar_disconnected =>
      'गूगल कैलेंडर डिस्कनेक्ट कर दिया गया।';

  @override
  String get google_calendar_connect_failed =>
      'गूगल कैलेंडर कनेक्ट नहीं हो सका। कृपया पुनः प्रयास करें।';

  @override
  String get enter_valid_email => 'कृपया एक वैध ईमेल पता दर्ज करें।';
}
