// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'GenieLaw';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get choose_language => 'Choose your preferred language';

  @override
  String get change_password => 'Change Password';

  @override
  String get change_password_subtitle =>
      'Update your account password securely';

  @override
  String get delete_account => 'Delete Account';

  @override
  String get delete_account_subtitle =>
      'Permanently delete your profile and all data';

  @override
  String get current_password => 'Current Password';

  @override
  String get new_password => 'New Password';

  @override
  String get confirm_new_password => 'Confirm New Password';

  @override
  String get save_password => 'Save New Password';

  @override
  String get password_changed_success => 'Password changed successfully!';

  @override
  String get password_match_error => 'Passwords do not match';

  @override
  String get password_requirements => 'Password Requirements:';

  @override
  String get rule_min_chars => 'At least 8 characters';

  @override
  String get rule_uppercase => 'At least 1 uppercase letter (A-Z)';

  @override
  String get rule_lowercase => 'At least 1 lowercase letter (a-z)';

  @override
  String get rule_number => 'At least 1 number (0-9)';

  @override
  String get rule_special => 'At least 1 special character (@#\$%^&*)';

  @override
  String get delete_account_dialog_title => 'Delete Account';

  @override
  String get delete_account_dialog_msg =>
      'Are you sure you want to permanently delete your account?\n\nThis action cannot be undone.\n\nDeleting your account will permanently remove your profile, cases, appointments, chats, uploaded documents, AI history, and all associated data.';

  @override
  String get cancel => 'Cancel';

  @override
  String get enter_password_to_confirm =>
      'Enter your current password to confirm deletion:';

  @override
  String get account_deleted_success => 'Account permanently deleted.';

  @override
  String get nav_workspace => 'Workspace';

  @override
  String get nav_dashboard => 'Dashboard';

  @override
  String get nav_leads => 'Leads';

  @override
  String get nav_clients => 'Clients';

  @override
  String get nav_calendar => 'Calendar';

  @override
  String get nav_profile => 'Profile';

  @override
  String get my_profile => 'My Profile';

  @override
  String get advocate_prefix => 'Adv.';

  @override
  String get advocate_fallback => 'Advocate';

  @override
  String get legal_practitioner => 'Legal Practitioner';

  @override
  String get reviews => 'Reviews';

  @override
  String get premium_plan => 'Premium Plan';

  @override
  String get premium_plan_desc =>
      'Unlock priority case matching, AI legal tools, premium visibility, and exclusive professional features.';

  @override
  String get view_plan => 'View Plan';

  @override
  String get todays_overview => 'Today\'s Overview';

  @override
  String get new_case_requests => 'New Case Requests';

  @override
  String get awaiting_response => 'Awaiting response';

  @override
  String get unread_messages => 'Unread Messages';

  @override
  String get from_active_clients => 'From active clients';

  @override
  String get pending_document_reviews => 'Pending Document Reviews';

  @override
  String get docs_waiting_review => 'Docs waiting for review';

  @override
  String get pending_client_responses => 'Pending Client Responses';

  @override
  String get waiting_lawyer_action => 'Waiting for lawyer action';

  @override
  String welcome_name(String name) {
    return 'Welcome, $name';
  }

  @override
  String reviews_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get mark_all_read => 'Mark all as read';

  @override
  String get no_notifications => 'No notifications found';

  @override
  String get filter_all => 'All';

  @override
  String get filter_unread => 'Unread';

  @override
  String get active_leads => 'Active Leads';

  @override
  String get active_clients => 'Active Clients';

  @override
  String get in_progress_cases => 'In Progress';

  @override
  String get completed_cases => 'Completed';

  @override
  String get search_placeholder => 'Search...';

  @override
  String get save_changes => 'Save Changes';

  @override
  String get edit_profile => 'Edit Profile';

  @override
  String get professional_details => 'Professional Details';

  @override
  String get consultation_settings => 'Consultation Settings';

  @override
  String get documents => 'Documents';

  @override
  String get subscription => 'Subscription';

  @override
  String get logout => 'Logout';

  @override
  String get confirm_logout => 'Are you sure you want to logout?';

  @override
  String get confirm => 'Confirm';

  @override
  String get back => 'Back';

  @override
  String get error_occurred => 'An error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get no_data_available => 'No data available';
}
