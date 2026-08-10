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
/// import 'localization/app_localizations.dart';
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

  /// No description provided for @guest_user.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get guest_user;

  /// No description provided for @sign_out.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get sign_out;

  /// No description provided for @my_cases.
  ///
  /// In en, this message translates to:
  /// **'My Cases'**
  String get my_cases;

  /// No description provided for @advocates.
  ///
  /// In en, this message translates to:
  /// **'Advocates'**
  String get advocates;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @my_documents.
  ///
  /// In en, this message translates to:
  /// **'My Documents'**
  String get my_documents;

  /// No description provided for @favorite_lawyers.
  ///
  /// In en, this message translates to:
  /// **'Favorite Lawyers'**
  String get favorite_lawyers;

  /// No description provided for @subscription_plans.
  ///
  /// In en, this message translates to:
  /// **'Subscription Plans'**
  String get subscription_plans;

  /// No description provided for @personal_info.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personal_info;

  /// No description provided for @terms_conditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get terms_conditions;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @about_us.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get about_us;

  /// No description provided for @help_center.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get help_center;

  /// No description provided for @contact_support.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contact_support;

  /// No description provided for @recent_activity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recent_activity;

  /// No description provided for @choose_subscription_plan_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the plan that\'s right for your practice'**
  String get choose_subscription_plan_subtitle;

  /// No description provided for @most_popular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get most_popular;

  /// No description provided for @continue_button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_button;

  /// No description provided for @new_leads_tab.
  ///
  /// In en, this message translates to:
  /// **'New Leads'**
  String get new_leads_tab;

  /// No description provided for @accepted_tab.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted_tab;

  /// No description provided for @search_new_leads_hint.
  ///
  /// In en, this message translates to:
  /// **'Search new leads...'**
  String get search_new_leads_hint;

  /// No description provided for @search_accepted_hint.
  ///
  /// In en, this message translates to:
  /// **'Search accepted...'**
  String get search_accepted_hint;

  /// No description provided for @accept_case_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Accept Case?'**
  String get accept_case_dialog_title;

  /// No description provided for @accept_case_dialog_body.
  ///
  /// In en, this message translates to:
  /// **'Accept this case request?'**
  String get accept_case_dialog_body;

  /// No description provided for @accept_button.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept_button;

  /// No description provided for @reject_lead_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Reject Lead?'**
  String get reject_lead_dialog_title;

  /// No description provided for @reject_lead_dialog_body.
  ///
  /// In en, this message translates to:
  /// **'Reject this case lead?'**
  String get reject_lead_dialog_body;

  /// No description provided for @reject_button.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject_button;

  /// No description provided for @complete_case_dialog_title.
  ///
  /// In en, this message translates to:
  /// **'Complete Case?'**
  String get complete_case_dialog_title;

  /// No description provided for @complete_case_dialog_body.
  ///
  /// In en, this message translates to:
  /// **'Mark this case as completed?'**
  String get complete_case_dialog_body;

  /// No description provided for @complete_button.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete_button;

  /// No description provided for @view_details.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get view_details;

  /// No description provided for @view_case.
  ///
  /// In en, this message translates to:
  /// **'View Case'**
  String get view_case;

  /// No description provided for @accept_case.
  ///
  /// In en, this message translates to:
  /// **'Accept Case'**
  String get accept_case;

  /// No description provided for @reject_lead.
  ///
  /// In en, this message translates to:
  /// **'Reject Lead'**
  String get reject_lead;

  /// No description provided for @mark_completed.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get mark_completed;

  /// No description provided for @failed_to_load_leads.
  ///
  /// In en, this message translates to:
  /// **'Failed to load leads.'**
  String get failed_to_load_leads;

  /// No description provided for @no_new_leads_empty.
  ///
  /// In en, this message translates to:
  /// **'No new case leads.\nCheck back later!'**
  String get no_new_leads_empty;

  /// No description provided for @no_accepted_cases_empty.
  ///
  /// In en, this message translates to:
  /// **'No accepted cases yet.'**
  String get no_accepted_cases_empty;

  /// No description provided for @posted_on.
  ///
  /// In en, this message translates to:
  /// **'Posted on: {date}'**
  String posted_on(String date);

  /// No description provided for @accepted_on.
  ///
  /// In en, this message translates to:
  /// **'Accepted on: {date}'**
  String accepted_on(String date);

  /// No description provided for @urgency_label.
  ///
  /// In en, this message translates to:
  /// **'Urgency: {urgency}'**
  String urgency_label(String urgency);

  /// No description provided for @docs_uploaded_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 doc uploaded} other{{count} docs uploaded}}'**
  String docs_uploaded_count(num count);

  /// No description provided for @match_percentage.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Match'**
  String match_percentage(num percent);

  /// No description provided for @close_button.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close_button;

  /// No description provided for @failed_to_load_profile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile details.'**
  String get failed_to_load_profile;

  /// No description provided for @account_professional_details_header.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT & PROFESSIONAL DETAILS'**
  String get account_professional_details_header;

  /// No description provided for @profile_photo_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Photo, name, location, contacts'**
  String get profile_photo_subtitle;

  /// No description provided for @professional_info_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Specialization, education, Bar Council details'**
  String get professional_info_subtitle;

  /// No description provided for @documents_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your credentials and case records'**
  String get documents_subtitle;

  /// No description provided for @settings_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, calendar, support and legal'**
  String get settings_subtitle;

  /// No description provided for @verified_advocate.
  ///
  /// In en, this message translates to:
  /// **'Verified Advocate'**
  String get verified_advocate;

  /// No description provided for @verification_pending.
  ///
  /// In en, this message translates to:
  /// **'Verification Pending'**
  String get verification_pending;

  /// No description provided for @profile_completion.
  ///
  /// In en, this message translates to:
  /// **'Profile Completion'**
  String get profile_completion;

  /// No description provided for @profile_complete_tip.
  ///
  /// In en, this message translates to:
  /// **'🎉 Your profile is 100% complete! This increases visibility and builds client trust.'**
  String get profile_complete_tip;

  /// No description provided for @profile_incomplete_tip.
  ///
  /// In en, this message translates to:
  /// **'💡 Tip: Complete your professional and bank settings to receive inquiries and consultation bookings.'**
  String get profile_incomplete_tip;

  /// No description provided for @cases_handled.
  ///
  /// In en, this message translates to:
  /// **'Cases Handled'**
  String get cases_handled;

  /// No description provided for @win_rate.
  ///
  /// In en, this message translates to:
  /// **'Win Rate'**
  String get win_rate;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @profile_image_updated_success.
  ///
  /// In en, this message translates to:
  /// **'Profile image updated successfully!'**
  String get profile_image_updated_success;

  /// No description provided for @profile_image_updated_failure.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload profile image.'**
  String get profile_image_updated_failure;

  /// No description provided for @error_selecting_image.
  ///
  /// In en, this message translates to:
  /// **'Error selecting image: {error}'**
  String error_selecting_image(String error);

  /// No description provided for @email_address.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get email_address;

  /// No description provided for @phone_number.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone_number;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @location_not_set.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get location_not_set;

  /// No description provided for @edit_profile_details.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile Details'**
  String get edit_profile_details;

  /// No description provided for @edit_personal_info.
  ///
  /// In en, this message translates to:
  /// **'Edit Personal Information'**
  String get edit_personal_info;

  /// No description provided for @full_name.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get full_name;

  /// No description provided for @name_is_required.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get name_is_required;

  /// No description provided for @phone_is_required.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phone_is_required;

  /// No description provided for @location_is_required.
  ///
  /// In en, this message translates to:
  /// **'Location is required'**
  String get location_is_required;

  /// No description provided for @personal_details_saved_success.
  ///
  /// In en, this message translates to:
  /// **'Personal details saved successfully!'**
  String get personal_details_saved_success;

  /// No description provided for @personal_details_saved_failure.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile details.'**
  String get personal_details_saved_failure;

  /// No description provided for @professional_details_updated_success.
  ///
  /// In en, this message translates to:
  /// **'Professional details updated successfully!'**
  String get professional_details_updated_success;

  /// No description provided for @professional_details_updated_failure.
  ///
  /// In en, this message translates to:
  /// **'Failed to update details.'**
  String get professional_details_updated_failure;

  /// No description provided for @professional_details_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your professional details to attract more client consultation bookings.'**
  String get professional_details_subtitle;

  /// No description provided for @specialization_label.
  ///
  /// In en, this message translates to:
  /// **'Specialization (e.g. Family Law, Criminal Defense)'**
  String get specialization_label;

  /// No description provided for @specialization_required.
  ///
  /// In en, this message translates to:
  /// **'Specialization is required'**
  String get specialization_required;

  /// No description provided for @years_experience_label.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get years_experience_label;

  /// No description provided for @experience_required.
  ///
  /// In en, this message translates to:
  /// **'Experience is required'**
  String get experience_required;

  /// No description provided for @valid_number_required.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get valid_number_required;

  /// No description provided for @education_label.
  ///
  /// In en, this message translates to:
  /// **'Education / Qualifications (e.g. LL.B., Harvard Law)'**
  String get education_label;

  /// No description provided for @education_required.
  ///
  /// In en, this message translates to:
  /// **'Education is required'**
  String get education_required;

  /// No description provided for @bar_registration_label.
  ///
  /// In en, this message translates to:
  /// **'Bar Council Registration Number'**
  String get bar_registration_label;

  /// No description provided for @registration_required.
  ///
  /// In en, this message translates to:
  /// **'Registration number is required'**
  String get registration_required;

  /// No description provided for @bio_label.
  ///
  /// In en, this message translates to:
  /// **'About Me / Professional Bio'**
  String get bio_label;

  /// No description provided for @bio_required.
  ///
  /// In en, this message translates to:
  /// **'Bio summary is required'**
  String get bio_required;

  /// No description provided for @consultation_settings_updated_success.
  ///
  /// In en, this message translates to:
  /// **'Consultation settings updated successfully!'**
  String get consultation_settings_updated_success;

  /// No description provided for @consultation_settings_updated_failure.
  ///
  /// In en, this message translates to:
  /// **'Failed to update settings.'**
  String get consultation_settings_updated_failure;

  /// No description provided for @consultation_settings_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your consultation fees, working hours, and banking details to automate payouts and booking confirmations.'**
  String get consultation_settings_subtitle;

  /// No description provided for @consultation_fee_label.
  ///
  /// In en, this message translates to:
  /// **'Consultation Fee (₹ per slot)'**
  String get consultation_fee_label;

  /// No description provided for @consultation_fee_required.
  ///
  /// In en, this message translates to:
  /// **'Consultation fee is required'**
  String get consultation_fee_required;

  /// No description provided for @working_hours_label.
  ///
  /// In en, this message translates to:
  /// **'Working Hours (e.g. 9:00 AM - 6:00 PM)'**
  String get working_hours_label;

  /// No description provided for @working_hours_required.
  ///
  /// In en, this message translates to:
  /// **'Working hours is required'**
  String get working_hours_required;

  /// No description provided for @office_address_label.
  ///
  /// In en, this message translates to:
  /// **'Office Address / Chamber Location'**
  String get office_address_label;

  /// No description provided for @office_address_required.
  ///
  /// In en, this message translates to:
  /// **'Office address is required'**
  String get office_address_required;

  /// No description provided for @upi_id_label.
  ///
  /// In en, this message translates to:
  /// **'UPI ID (for direct client payouts)'**
  String get upi_id_label;

  /// No description provided for @upi_id_required.
  ///
  /// In en, this message translates to:
  /// **'UPI ID is required'**
  String get upi_id_required;

  /// No description provided for @bank_settlement_header.
  ///
  /// In en, this message translates to:
  /// **'BANK SETTLEMENT DETAILS'**
  String get bank_settlement_header;

  /// No description provided for @account_holder_label.
  ///
  /// In en, this message translates to:
  /// **'Account Holder Name'**
  String get account_holder_label;

  /// No description provided for @account_holder_required.
  ///
  /// In en, this message translates to:
  /// **'Account holder name is required'**
  String get account_holder_required;

  /// No description provided for @bank_name_label.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bank_name_label;

  /// No description provided for @bank_name_required.
  ///
  /// In en, this message translates to:
  /// **'Bank name is required'**
  String get bank_name_required;

  /// No description provided for @account_number_label.
  ///
  /// In en, this message translates to:
  /// **'Bank Account Number'**
  String get account_number_label;

  /// No description provided for @account_number_required.
  ///
  /// In en, this message translates to:
  /// **'Account number is required'**
  String get account_number_required;

  /// No description provided for @ifsc_code_label.
  ///
  /// In en, this message translates to:
  /// **'IFSC Code'**
  String get ifsc_code_label;

  /// No description provided for @ifsc_code_required.
  ///
  /// In en, this message translates to:
  /// **'IFSC Code is required'**
  String get ifsc_code_required;

  /// No description provided for @doc_uploaded_success.
  ///
  /// In en, this message translates to:
  /// **'Document uploaded successfully!'**
  String get doc_uploaded_success;

  /// No description provided for @doc_upload_failed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Unsupported type or size limit.'**
  String get doc_upload_failed;

  /// No description provided for @doc_upload_error.
  ///
  /// In en, this message translates to:
  /// **'Upload error occurred.'**
  String get doc_upload_error;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @upload_document.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get upload_document;

  /// No description provided for @no_documents_found.
  ///
  /// In en, this message translates to:
  /// **'No Documents Found'**
  String get no_documents_found;

  /// No description provided for @upload_documents_tip.
  ///
  /// In en, this message translates to:
  /// **'Upload credentials, bar registration certificates, or identity verifications.'**
  String get upload_documents_tip;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @delete_document.
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get delete_document;

  /// No description provided for @confirm_delete_document.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete this document?'**
  String get confirm_delete_document;

  /// No description provided for @doc_deleted_success.
  ///
  /// In en, this message translates to:
  /// **'Document deleted successfully.'**
  String get doc_deleted_success;

  /// No description provided for @reviews_and_feedback.
  ///
  /// In en, this message translates to:
  /// **'Reviews & Feedback'**
  String get reviews_and_feedback;

  /// No description provided for @based_on_reviews_count.
  ///
  /// In en, this message translates to:
  /// **'Based on {count} reviews'**
  String based_on_reviews_count(num count);

  /// No description provided for @client_feedbacks_header.
  ///
  /// In en, this message translates to:
  /// **'CLIENT FEEDBACKS ({count})'**
  String client_feedbacks_header(num count);

  /// No description provided for @no_reviews_yet.
  ///
  /// In en, this message translates to:
  /// **'No Reviews Yet'**
  String get no_reviews_yet;

  /// No description provided for @no_reviews_tip.
  ///
  /// In en, this message translates to:
  /// **'Client reviews will appear here once your cases or consultations are resolved.'**
  String get no_reviews_tip;

  /// No description provided for @photo_name_contact_subtitle.
  ///
  /// In en, this message translates to:
  /// **'View and update your profile information.'**
  String get photo_name_contact_subtitle;

  /// No description provided for @dob_gender_address_subtitle.
  ///
  /// In en, this message translates to:
  /// **'DOB, gender, address, languages.'**
  String get dob_gender_address_subtitle;

  /// No description provided for @timeline_activity_subtitle.
  ///
  /// In en, this message translates to:
  /// **'View your recent actions and account activity.'**
  String get timeline_activity_subtitle;

  /// No description provided for @support_help_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Help center, privacy, terms, support'**
  String get support_help_subtitle;

  /// No description provided for @legal_desk_header.
  ///
  /// In en, this message translates to:
  /// **'LEGAL DESK & SERVICES'**
  String get legal_desk_header;

  /// No description provided for @your_legal_docs_subtitle.
  ///
  /// In en, this message translates to:
  /// **'View and manage your uploaded documents.'**
  String get your_legal_docs_subtitle;

  /// No description provided for @account_app_settings_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your account, language, notifications, privacy, and preferences.'**
  String get account_app_settings_subtitle;

  /// No description provided for @verified_client.
  ///
  /// In en, this message translates to:
  /// **'Verified Client'**
  String get verified_client;

  /// No description provided for @date_of_birth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get date_of_birth;

  /// No description provided for @dob_required.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth is required'**
  String get dob_required;

  /// No description provided for @select_valid_date.
  ///
  /// In en, this message translates to:
  /// **'Please select a valid date'**
  String get select_valid_date;

  /// No description provided for @dob_future_error.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth cannot be in the future'**
  String get dob_future_error;

  /// No description provided for @select_gender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get select_gender;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @gender_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get gender_male;

  /// No description provided for @gender_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get gender_female;

  /// No description provided for @gender_other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get gender_other;

  /// No description provided for @gender_prefer_not_say.
  ///
  /// In en, this message translates to:
  /// **'Prefer Not To Say'**
  String get gender_prefer_not_say;

  /// No description provided for @gender_required.
  ///
  /// In en, this message translates to:
  /// **'Gender is required'**
  String get gender_required;

  /// No description provided for @languages_comma_separated.
  ///
  /// In en, this message translates to:
  /// **'Languages (comma separated)'**
  String get languages_comma_separated;

  /// No description provided for @address_location.
  ///
  /// In en, this message translates to:
  /// **'Address / Location'**
  String get address_location;

  /// No description provided for @personal_info_updated_success.
  ///
  /// In en, this message translates to:
  /// **'Personal information updated successfully!'**
  String get personal_info_updated_success;

  /// No description provided for @personal_info_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify and update your personal details below to keep your legal records up to date.'**
  String get personal_info_subtitle;

  /// No description provided for @languages_example_hint.
  ///
  /// In en, this message translates to:
  /// **'Languages (e.g. English, Hindi, Spanish)'**
  String get languages_example_hint;

  /// No description provided for @languages_required.
  ///
  /// In en, this message translates to:
  /// **'Languages are required'**
  String get languages_required;

  /// No description provided for @no_favorites_added_yet.
  ///
  /// In en, this message translates to:
  /// **'No Favorites Added Yet'**
  String get no_favorites_added_yet;

  /// No description provided for @no_favorites_tip.
  ///
  /// In en, this message translates to:
  /// **'Select the heart icon on any lawyer\'s profile page to save them here.'**
  String get no_favorites_tip;

  /// No description provided for @book_button.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book_button;

  /// No description provided for @book_now_button.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get book_now_button;

  /// No description provided for @removed_from_favorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorite lawyers.'**
  String get removed_from_favorites;

  /// No description provided for @all_cases_tab_header.
  ///
  /// In en, this message translates to:
  /// **'All Cases ({count})'**
  String all_cases_tab_header(num count);

  /// No description provided for @in_progress_tab_header.
  ///
  /// In en, this message translates to:
  /// **'In Progress ({count})'**
  String in_progress_tab_header(num count);

  /// No description provided for @closed_tab_header.
  ///
  /// In en, this message translates to:
  /// **'Closed ({count})'**
  String closed_tab_header(num count);

  /// No description provided for @no_cases_posted_empty.
  ///
  /// In en, this message translates to:
  /// **'No cases posted yet.'**
  String get no_cases_posted_empty;

  /// No description provided for @no_cases_in_progress_empty.
  ///
  /// In en, this message translates to:
  /// **'No cases are currently in progress.'**
  String get no_cases_in_progress_empty;

  /// No description provided for @no_completed_cases_empty.
  ///
  /// In en, this message translates to:
  /// **'No completed cases yet.'**
  String get no_completed_cases_empty;

  /// No description provided for @lawyers_responded_header.
  ///
  /// In en, this message translates to:
  /// **'Lawyers Responded'**
  String get lawyers_responded_header;

  /// No description provided for @no_proposals_received_empty.
  ///
  /// In en, this message translates to:
  /// **'No proposals received yet.'**
  String get no_proposals_received_empty;

  /// No description provided for @proposals_received_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Proposal Received} other{{count} Proposals Received}}'**
  String proposals_received_count(num count);

  /// No description provided for @view_profile_button.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get view_profile_button;

  /// No description provided for @consultation_fee_amount.
  ///
  /// In en, this message translates to:
  /// **'₹{amount} Consultation Fee'**
  String consultation_fee_amount(num amount);

  /// No description provided for @case_details_header.
  ///
  /// In en, this message translates to:
  /// **'Case Details'**
  String get case_details_header;

  /// No description provided for @no_case_details_found.
  ///
  /// In en, this message translates to:
  /// **'No case details found.'**
  String get no_case_details_found;

  /// No description provided for @case_progress_tracker.
  ///
  /// In en, this message translates to:
  /// **'Case Progress Tracker'**
  String get case_progress_tracker;

  /// No description provided for @next_consultation.
  ///
  /// In en, this message translates to:
  /// **'Next Consultation'**
  String get next_consultation;

  /// No description provided for @supporting_documents.
  ///
  /// In en, this message translates to:
  /// **'Supporting Documents'**
  String get supporting_documents;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @completed_status.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed_status;

  /// No description provided for @pending_status.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending_status;

  /// No description provided for @awaiting_counsel_assignment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting counsel assignment...'**
  String get awaiting_counsel_assignment;

  /// No description provided for @welcome_advocate.
  ///
  /// In en, this message translates to:
  /// **'Welcome, Advocate'**
  String get welcome_advocate;

  /// No description provided for @workspace_welcome_desc.
  ///
  /// In en, this message translates to:
  /// **'Manage client cases, review legal inquiries, respond to consultation requests, and organize your schedule—all from one secure workspace.'**
  String get workspace_welcome_desc;

  /// No description provided for @workspace_tools.
  ///
  /// In en, this message translates to:
  /// **'Workspace Tools'**
  String get workspace_tools;

  /// No description provided for @new_leads_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 New Lead} other{{count} New Leads}}'**
  String new_leads_count(num count);

  /// No description provided for @waiting_for_response.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your response'**
  String get waiting_for_response;

  /// No description provided for @clients_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Client} other{{count} Clients}}'**
  String clients_count(num count);

  /// No description provided for @accepted_in_progress_closed.
  ///
  /// In en, this message translates to:
  /// **'Accepted, In Progress, Closed'**
  String get accepted_in_progress_closed;

  /// No description provided for @todays_schedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Schedule'**
  String get todays_schedule;

  /// No description provided for @no_events_today.
  ///
  /// In en, this message translates to:
  /// **'No Events Today'**
  String get no_events_today;

  /// No description provided for @events_today_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Event Today} other{{count} Events Today}}'**
  String events_today_count(num count);

  /// No description provided for @unread_chats_count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Unread Chat} other{{count} Unread Chats}}'**
  String unread_chats_count(num count);

  /// No description provided for @all_caught_up.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get all_caught_up;

  /// No description provided for @active_tab.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active_tab;

  /// No description provided for @in_progress_tab.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get in_progress_tab;

  /// No description provided for @completed_tab.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed_tab;

  /// No description provided for @category_label.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String category_label(String category);

  /// No description provided for @title_label.
  ///
  /// In en, this message translates to:
  /// **'Title: {title}'**
  String title_label(String title);

  /// No description provided for @location_label.
  ///
  /// In en, this message translates to:
  /// **'Location: {location}'**
  String location_label(String location);

  /// No description provided for @court_label.
  ///
  /// In en, this message translates to:
  /// **'Court: {court}'**
  String court_label(String court);

  /// No description provided for @accepted_date_label.
  ///
  /// In en, this message translates to:
  /// **'Accepted: {date}'**
  String accepted_date_label(String date);

  /// No description provided for @any_court.
  ///
  /// In en, this message translates to:
  /// **'Any Court'**
  String get any_court;

  /// No description provided for @accepted_status.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted_status;

  /// No description provided for @view_client_button.
  ///
  /// In en, this message translates to:
  /// **'View Client'**
  String get view_client_button;

  /// No description provided for @start_case_button.
  ///
  /// In en, this message translates to:
  /// **'Start Case'**
  String get start_case_button;

  /// No description provided for @case_work_started.
  ///
  /// In en, this message translates to:
  /// **'Case work started!'**
  String get case_work_started;

  /// No description provided for @preferences_header.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences_header;

  /// No description provided for @support_legal_header.
  ///
  /// In en, this message translates to:
  /// **'Support & Legal'**
  String get support_legal_header;

  /// No description provided for @account_header.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account_header;

  /// No description provided for @google_calendar_title.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar'**
  String get google_calendar_title;

  /// No description provided for @google_calendar_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your appointments with Google Calendar'**
  String get google_calendar_subtitle;

  /// No description provided for @google_calendar_connected.
  ///
  /// In en, this message translates to:
  /// **'Connected: {email}'**
  String google_calendar_connected(String email);

  /// No description provided for @connect_button.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect_button;

  /// No description provided for @disconnect_button.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect_button;

  /// No description provided for @contact_support_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Reach out to our dedicated support team'**
  String get contact_support_subtitle;

  /// No description provided for @about_us_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Who we are and what GenieLaw does'**
  String get about_us_subtitle;

  /// No description provided for @privacy_policy_subtitle.
  ///
  /// In en, this message translates to:
  /// **'How your data is collected and used'**
  String get privacy_policy_subtitle;

  /// No description provided for @terms_conditions_subtitle.
  ///
  /// In en, this message translates to:
  /// **'The agreement governing your use of GenieLaw'**
  String get terms_conditions_subtitle;

  /// No description provided for @delete_account_permanently.
  ///
  /// In en, this message translates to:
  /// **'Delete Account Permanently'**
  String get delete_account_permanently;

  /// No description provided for @need_assistance_heading.
  ///
  /// In en, this message translates to:
  /// **'Need Assistance?'**
  String get need_assistance_heading;

  /// No description provided for @need_assistance_desc.
  ///
  /// In en, this message translates to:
  /// **'If you are experiencing technical issues, account-related problems, have bug reports, or require general assistance, our dedicated support team is ready to help.'**
  String get need_assistance_desc;

  /// No description provided for @email_support_title.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get email_support_title;

  /// No description provided for @send_email_button.
  ///
  /// In en, this message translates to:
  /// **'Send Email'**
  String get send_email_button;

  /// No description provided for @response_time_heading.
  ///
  /// In en, this message translates to:
  /// **'Response Time'**
  String get response_time_heading;

  /// No description provided for @response_time_desc.
  ///
  /// In en, this message translates to:
  /// **'We typically respond within 24–48 business hours.'**
  String get response_time_desc;

  /// No description provided for @app_info_title.
  ///
  /// In en, this message translates to:
  /// **'App Information'**
  String get app_info_title;

  /// No description provided for @app_version_label.
  ///
  /// In en, this message translates to:
  /// **'Version: {version}'**
  String app_version_label(String version);

  /// No description provided for @build_number_label.
  ///
  /// In en, this message translates to:
  /// **'Build: {build}'**
  String build_number_label(String build);

  /// No description provided for @could_not_launch_email.
  ///
  /// In en, this message translates to:
  /// **'Could not open your email application. Please email directly to {email}'**
  String could_not_launch_email(String email);

  /// No description provided for @password_required_to_confirm.
  ///
  /// In en, this message translates to:
  /// **'Password is required to confirm.'**
  String get password_required_to_confirm;

  /// No description provided for @incorrect_password.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get incorrect_password;

  /// No description provided for @notifications_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage how and when GenieLaw notifies you'**
  String get notifications_subtitle;

  /// No description provided for @google_calendar_lawyer_only.
  ///
  /// In en, this message translates to:
  /// **'Calendar sync is available to advocates only'**
  String get google_calendar_lawyer_only;

  /// No description provided for @account_header_client.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account_header_client;

  /// No description provided for @google_calendar_disconnected.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar disconnected.'**
  String get google_calendar_disconnected;

  /// No description provided for @google_calendar_connect_failed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect Google Calendar. Please try again.'**
  String get google_calendar_connect_failed;

  /// No description provided for @enter_valid_email.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get enter_valid_email;
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
