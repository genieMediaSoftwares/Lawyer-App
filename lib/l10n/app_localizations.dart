import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'GenieLaw'**
  String get app_title;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @choose_language.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get choose_language;

  /// No description provided for @change_password.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get change_password;

  /// No description provided for @change_password_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your account password securely'**
  String get change_password_subtitle;

  /// No description provided for @delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account;

  /// No description provided for @delete_account_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your profile and all data'**
  String get delete_account_subtitle;

  /// No description provided for @current_password.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get current_password;

  /// No description provided for @new_password.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get new_password;

  /// No description provided for @confirm_new_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirm_new_password;

  /// No description provided for @save_password.
  ///
  /// In en, this message translates to:
  /// **'Save New Password'**
  String get save_password;

  /// No description provided for @password_changed_success.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully!'**
  String get password_changed_success;

  /// No description provided for @password_match_error.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get password_match_error;

  /// No description provided for @password_requirements.
  ///
  /// In en, this message translates to:
  /// **'Password Requirements:'**
  String get password_requirements;

  /// No description provided for @rule_min_chars.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get rule_min_chars;

  /// No description provided for @rule_uppercase.
  ///
  /// In en, this message translates to:
  /// **'At least 1 uppercase letter (A-Z)'**
  String get rule_uppercase;

  /// No description provided for @rule_lowercase.
  ///
  /// In en, this message translates to:
  /// **'At least 1 lowercase letter (a-z)'**
  String get rule_lowercase;

  /// No description provided for @rule_number.
  ///
  /// In en, this message translates to:
  /// **'At least 1 number (0-9)'**
  String get rule_number;

  /// No description provided for @rule_special.
  ///
  /// In en, this message translates to:
  /// **'At least 1 special character (@#\$%^&*)'**
  String get rule_special;

  /// No description provided for @delete_account_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account_dialog_title;

  /// No description provided for @delete_account_dialog_msg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account?\n\nThis action cannot be undone.\n\nDeleting your account will permanently remove your profile, cases, appointments, chats, uploaded documents, AI history, and all associated data.'**
  String get delete_account_dialog_msg;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @enter_password_to_confirm.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password to confirm deletion:'**
  String get enter_password_to_confirm;

  /// No description provided for @account_deleted_success.
  ///
  /// In en, this message translates to:
  /// **'Account permanently deleted.'**
  String get account_deleted_success;

  /// No description provided for @nav_workspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get nav_workspace;

  /// No description provided for @nav_dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get nav_dashboard;

  /// No description provided for @nav_leads.
  ///
  /// In en, this message translates to:
  /// **'Leads'**
  String get nav_leads;

  /// No description provided for @nav_clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get nav_clients;

  /// No description provided for @nav_calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get nav_calendar;

  /// No description provided for @nav_profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nav_profile;

  /// No description provided for @my_profile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get my_profile;

  /// No description provided for @advocate_prefix.
  ///
  /// In en, this message translates to:
  /// **'Adv.'**
  String get advocate_prefix;

  /// No description provided for @advocate_fallback.
  ///
  /// In en, this message translates to:
  /// **'Advocate'**
  String get advocate_fallback;

  /// No description provided for @legal_practitioner.
  ///
  /// In en, this message translates to:
  /// **'Legal Practitioner'**
  String get legal_practitioner;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @premium_plan.
  ///
  /// In en, this message translates to:
  /// **'Premium Plan'**
  String get premium_plan;

  /// No description provided for @premium_plan_desc.
  ///
  /// In en, this message translates to:
  /// **'Unlock priority case matching, AI legal tools, premium visibility, and exclusive professional features.'**
  String get premium_plan_desc;

  /// No description provided for @view_plan.
  ///
  /// In en, this message translates to:
  /// **'View Plan'**
  String get view_plan;

  /// No description provided for @todays_overview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get todays_overview;

  /// No description provided for @new_case_requests.
  ///
  /// In en, this message translates to:
  /// **'New Case Requests'**
  String get new_case_requests;

  /// No description provided for @awaiting_response.
  ///
  /// In en, this message translates to:
  /// **'Awaiting response'**
  String get awaiting_response;

  /// No description provided for @unread_messages.
  ///
  /// In en, this message translates to:
  /// **'Unread Messages'**
  String get unread_messages;

  /// No description provided for @from_active_clients.
  ///
  /// In en, this message translates to:
  /// **'From active clients'**
  String get from_active_clients;

  /// No description provided for @pending_document_reviews.
  ///
  /// In en, this message translates to:
  /// **'Pending Document Reviews'**
  String get pending_document_reviews;

  /// No description provided for @docs_waiting_review.
  ///
  /// In en, this message translates to:
  /// **'Docs waiting for review'**
  String get docs_waiting_review;

  /// No description provided for @pending_client_responses.
  ///
  /// In en, this message translates to:
  /// **'Pending Client Responses'**
  String get pending_client_responses;

  /// No description provided for @waiting_lawyer_action.
  ///
  /// In en, this message translates to:
  /// **'Waiting for lawyer action'**
  String get waiting_lawyer_action;

  /// Greeting message with name placeholder
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcome_name(String name);

  /// Pluralized review count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reviews} =1{1 review} other{{count} reviews}}'**
  String reviews_count(num count);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @mark_all_read.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get mark_all_read;

  /// No description provided for @no_notifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications found'**
  String get no_notifications;

  /// No description provided for @filter_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filter_all;

  /// No description provided for @filter_unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get filter_unread;

  /// No description provided for @active_leads.
  ///
  /// In en, this message translates to:
  /// **'Active Leads'**
  String get active_leads;

  /// No description provided for @active_clients.
  ///
  /// In en, this message translates to:
  /// **'Active Clients'**
  String get active_clients;

  /// No description provided for @in_progress_cases.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get in_progress_cases;

  /// No description provided for @completed_cases.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed_cases;

  /// No description provided for @search_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search_placeholder;

  /// No description provided for @save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get save_changes;

  /// No description provided for @edit_profile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profile;

  /// No description provided for @professional_details.
  ///
  /// In en, this message translates to:
  /// **'Professional Details'**
  String get professional_details;

  /// No description provided for @consultation_settings.
  ///
  /// In en, this message translates to:
  /// **'Consultation Settings'**
  String get consultation_settings;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @confirm_logout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get confirm_logout;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @error_occurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error_occurred;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @no_data_available.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get no_data_available;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
