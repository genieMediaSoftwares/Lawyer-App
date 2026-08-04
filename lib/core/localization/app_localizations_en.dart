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

  @override
  String get guest_user => 'Guest User';

  @override
  String get sign_out => 'Sign Out';

  @override
  String get my_cases => 'My Cases';

  @override
  String get advocates => 'Advocates';

  @override
  String get messages => 'Messages';

  @override
  String get my_documents => 'My Documents';

  @override
  String get favorite_lawyers => 'Favorite Lawyers';

  @override
  String get legal_articles => 'Legal Articles';

  @override
  String get subscription_plans => 'Subscription Plans';

  @override
  String get personal_info => 'Personal Information';

  @override
  String get terms_conditions => 'Terms & Conditions';

  @override
  String get privacy_policy => 'Privacy Policy';

  @override
  String get about_us => 'About Us';

  @override
  String get help_center => 'Help Center';

  @override
  String get contact_support => 'Contact Support';

  @override
  String get recent_activity => 'Recent Activity';

  @override
  String get choose_subscription_plan_subtitle =>
      'Choose the plan that\'s right for your practice';

  @override
  String get most_popular => 'Most Popular';

  @override
  String get continue_button => 'Continue';

  @override
  String get new_leads_tab => 'New Leads';

  @override
  String get accepted_tab => 'Accepted';

  @override
  String get search_new_leads_hint => 'Search new leads...';

  @override
  String get search_accepted_hint => 'Search accepted...';

  @override
  String get accept_case_dialog_title => 'Accept Case?';

  @override
  String get accept_case_dialog_body => 'Accept this case request?';

  @override
  String get accept_button => 'Accept';

  @override
  String get reject_lead_dialog_title => 'Reject Lead?';

  @override
  String get reject_lead_dialog_body => 'Reject this case lead?';

  @override
  String get reject_button => 'Reject';

  @override
  String get complete_case_dialog_title => 'Complete Case?';

  @override
  String get complete_case_dialog_body => 'Mark this case as completed?';

  @override
  String get complete_button => 'Complete';

  @override
  String get view_details => 'View Details';

  @override
  String get view_case => 'View Case';

  @override
  String get accept_case => 'Accept Case';

  @override
  String get reject_lead => 'Reject Lead';

  @override
  String get mark_completed => 'Mark Completed';

  @override
  String get failed_to_load_leads => 'Failed to load leads.';

  @override
  String get no_new_leads_empty => 'No new case leads.\nCheck back later!';

  @override
  String get no_accepted_cases_empty => 'No accepted cases yet.';

  @override
  String posted_on(String date) {
    return 'Posted on: $date';
  }

  @override
  String accepted_on(String date) {
    return 'Accepted on: $date';
  }

  @override
  String urgency_label(String urgency) {
    return 'Urgency: $urgency';
  }

  @override
  String docs_uploaded_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count docs uploaded',
      one: '1 doc uploaded',
    );
    return '$_temp0';
  }

  @override
  String match_percentage(num percent) {
    return '$percent% Match';
  }

  @override
  String get close_button => 'Close';

  @override
  String get failed_to_load_profile => 'Failed to load profile details.';

  @override
  String get account_professional_details_header =>
      'ACCOUNT & PROFESSIONAL DETAILS';

  @override
  String get profile_photo_subtitle => 'Photo, name, location, contacts';

  @override
  String get professional_info_subtitle =>
      'Specialization, education, Bar Council details';

  @override
  String get documents_subtitle => 'Your credentials and case records';

  @override
  String get settings_subtitle => 'Language, calendar, support and legal';

  @override
  String get verified_advocate => 'Verified Advocate';

  @override
  String get verification_pending => 'Verification Pending';

  @override
  String get profile_completion => 'Profile Completion';

  @override
  String get profile_complete_tip =>
      '🎉 Your profile is 100% complete! This increases visibility and builds client trust.';

  @override
  String get profile_incomplete_tip =>
      '💡 Tip: Complete your professional and bank settings to receive inquiries and consultation bookings.';

  @override
  String get cases_handled => 'Cases Handled';

  @override
  String get win_rate => 'Win Rate';

  @override
  String get rating => 'Rating';

  @override
  String get profile_image_updated_success =>
      'Profile image updated successfully!';

  @override
  String get profile_image_updated_failure => 'Failed to upload profile image.';

  @override
  String error_selecting_image(String error) {
    return 'Error selecting image: $error';
  }

  @override
  String get email_address => 'Email Address';

  @override
  String get phone_number => 'Phone Number';

  @override
  String get location => 'Location';

  @override
  String get location_not_set => 'Location not set';

  @override
  String get edit_profile_details => 'Edit Profile Details';

  @override
  String get edit_personal_info => 'Edit Personal Information';

  @override
  String get full_name => 'Full Name';

  @override
  String get name_is_required => 'Name is required';

  @override
  String get phone_is_required => 'Phone number is required';

  @override
  String get location_is_required => 'Location is required';

  @override
  String get personal_details_saved_success =>
      'Personal details saved successfully!';

  @override
  String get personal_details_saved_failure =>
      'Failed to update profile details.';

  @override
  String get professional_details_updated_success =>
      'Professional details updated successfully!';

  @override
  String get professional_details_updated_failure =>
      'Failed to update details.';

  @override
  String get professional_details_subtitle =>
      'Update your professional details to attract more client consultation bookings.';

  @override
  String get specialization_label =>
      'Specialization (e.g. Family Law, Criminal Defense)';

  @override
  String get specialization_required => 'Specialization is required';

  @override
  String get years_experience_label => 'Years of Experience';

  @override
  String get experience_required => 'Experience is required';

  @override
  String get valid_number_required => 'Please enter a valid number';

  @override
  String get education_label =>
      'Education / Qualifications (e.g. LL.B., Harvard Law)';

  @override
  String get education_required => 'Education is required';

  @override
  String get bar_registration_label => 'Bar Council Registration Number';

  @override
  String get registration_required => 'Registration number is required';

  @override
  String get bio_label => 'About Me / Professional Bio';

  @override
  String get bio_required => 'Bio summary is required';

  @override
  String get consultation_settings_updated_success =>
      'Consultation settings updated successfully!';

  @override
  String get consultation_settings_updated_failure =>
      'Failed to update settings.';

  @override
  String get consultation_settings_subtitle =>
      'Set up your consultation fees, working hours, and banking details to automate payouts and booking confirmations.';

  @override
  String get consultation_fee_label => 'Consultation Fee (₹ per slot)';

  @override
  String get consultation_fee_required => 'Consultation fee is required';

  @override
  String get working_hours_label => 'Working Hours (e.g. 9:00 AM - 6:00 PM)';

  @override
  String get working_hours_required => 'Working hours is required';

  @override
  String get office_address_label => 'Office Address / Chamber Location';

  @override
  String get office_address_required => 'Office address is required';

  @override
  String get upi_id_label => 'UPI ID (for direct client payouts)';

  @override
  String get upi_id_required => 'UPI ID is required';

  @override
  String get bank_settlement_header => 'BANK SETTLEMENT DETAILS';

  @override
  String get account_holder_label => 'Account Holder Name';

  @override
  String get account_holder_required => 'Account holder name is required';

  @override
  String get bank_name_label => 'Bank Name';

  @override
  String get bank_name_required => 'Bank name is required';

  @override
  String get account_number_label => 'Bank Account Number';

  @override
  String get account_number_required => 'Account number is required';

  @override
  String get ifsc_code_label => 'IFSC Code';

  @override
  String get ifsc_code_required => 'IFSC Code is required';

  @override
  String get doc_uploaded_success => 'Document uploaded successfully!';

  @override
  String get doc_upload_failed =>
      'Upload failed. Unsupported type or size limit.';

  @override
  String get doc_upload_error => 'Upload error occurred.';

  @override
  String get uploading => 'Uploading...';

  @override
  String get upload_document => 'Upload Document';

  @override
  String get no_documents_found => 'No Documents Found';

  @override
  String get upload_documents_tip =>
      'Upload credentials, bar registration certificates, or identity verifications.';

  @override
  String get delete_document => 'Delete Document';

  @override
  String get confirm_delete_document =>
      'Are you sure you want to permanently delete this document?';

  @override
  String get doc_deleted_success => 'Document deleted successfully.';

  @override
  String get reviews_and_feedback => 'Reviews & Feedback';

  @override
  String based_on_reviews_count(num count) {
    return 'Based on $count reviews';
  }

  @override
  String client_feedbacks_header(num count) {
    return 'CLIENT FEEDBACKS ($count)';
  }

  @override
  String get no_reviews_yet => 'No Reviews Yet';

  @override
  String get no_reviews_tip =>
      'Client reviews will appear here once your cases or consultations are resolved.';

  @override
  String get photo_name_contact_subtitle =>
      'View and update your profile information.';

  @override
  String get dob_gender_address_subtitle => 'DOB, gender, address, languages.';

  @override
  String get timeline_activity_subtitle =>
      'View your recent actions and account activity.';

  @override
  String get support_help_subtitle => 'Help center, privacy, terms, support';

  @override
  String get legal_desk_header => 'LEGAL DESK & SERVICES';

  @override
  String get your_legal_docs_subtitle =>
      'View and manage your uploaded documents.';

  @override
  String get account_app_settings_subtitle =>
      'Manage your account, language, notifications, privacy, and preferences.';

  @override
  String get verified_client => 'Verified Client';

  @override
  String get date_of_birth => 'Date of Birth';

  @override
  String get dob_required => 'Date of Birth is required';

  @override
  String get select_valid_date => 'Please select a valid date';

  @override
  String get dob_future_error => 'Date of Birth cannot be in the future';

  @override
  String get select_gender => 'Select Gender';

  @override
  String get gender => 'Gender';

  @override
  String get gender_male => 'Male';

  @override
  String get gender_female => 'Female';

  @override
  String get gender_other => 'Other';

  @override
  String get gender_prefer_not_say => 'Prefer Not To Say';

  @override
  String get gender_required => 'Gender is required';

  @override
  String get languages_comma_separated => 'Languages (comma separated)';

  @override
  String get address_location => 'Address / Location';

  @override
  String get personal_info_updated_success =>
      'Personal information updated successfully!';

  @override
  String get personal_info_subtitle =>
      'Verify and update your personal details below to keep your legal records up to date.';

  @override
  String get languages_example_hint =>
      'Languages (e.g. English, Hindi, Spanish)';

  @override
  String get languages_required => 'Languages are required';

  @override
  String get no_favorites_added_yet => 'No Favorites Added Yet';

  @override
  String get no_favorites_tip =>
      'Select the heart icon on any lawyer\'s profile page to save them here.';

  @override
  String get book_button => 'Book';

  @override
  String get book_now_button => 'Book Now';

  @override
  String get removed_from_favorites => 'Removed from favorite lawyers.';

  @override
  String all_cases_tab_header(num count) {
    return 'All Cases ($count)';
  }

  @override
  String in_progress_tab_header(num count) {
    return 'In Progress ($count)';
  }

  @override
  String closed_tab_header(num count) {
    return 'Closed ($count)';
  }

  @override
  String get no_cases_posted_empty => 'No cases posted yet.';

  @override
  String get no_cases_in_progress_empty =>
      'No cases are currently in progress.';

  @override
  String get no_completed_cases_empty => 'No completed cases yet.';

  @override
  String get lawyers_responded_header => 'Lawyers Responded';

  @override
  String get no_proposals_received_empty => 'No proposals received yet.';

  @override
  String proposals_received_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Proposals Received',
      one: '1 Proposal Received',
    );
    return '$_temp0';
  }

  @override
  String get view_profile_button => 'View Profile';

  @override
  String consultation_fee_amount(num amount) {
    return '₹$amount Consultation Fee';
  }

  @override
  String get case_details_header => 'Case Details';

  @override
  String get no_case_details_found => 'No case details found.';

  @override
  String get case_progress_tracker => 'Case Progress Tracker';

  @override
  String get next_consultation => 'Next Consultation';

  @override
  String get supporting_documents => 'Supporting Documents';

  @override
  String get description => 'Description';

  @override
  String get completed_status => 'Completed';

  @override
  String get pending_status => 'Pending';

  @override
  String get awaiting_counsel_assignment => 'Awaiting counsel assignment...';

  @override
  String get welcome_advocate => 'Welcome, Advocate';

  @override
  String get workspace_welcome_desc =>
      'Manage client cases, review legal inquiries, respond to consultation requests, and organize your schedule—all from one secure workspace.';

  @override
  String get workspace_tools => 'Workspace Tools';

  @override
  String new_leads_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count New Leads',
      one: '1 New Lead',
    );
    return '$_temp0';
  }

  @override
  String get waiting_for_response => 'Waiting for your response';

  @override
  String clients_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clients',
      one: '1 Client',
    );
    return '$_temp0';
  }

  @override
  String get accepted_in_progress_closed => 'Accepted, In Progress, Closed';

  @override
  String get todays_schedule => 'Today\'s Schedule';

  @override
  String get no_events_today => 'No Events Today';

  @override
  String events_today_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Events Today',
      one: '1 Event Today',
    );
    return '$_temp0';
  }

  @override
  String unread_chats_count(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Unread Chats',
      one: '1 Unread Chat',
    );
    return '$_temp0';
  }

  @override
  String get all_caught_up => 'You\'re all caught up';

  @override
  String get active_tab => 'Active';

  @override
  String get in_progress_tab => 'In Progress';

  @override
  String get completed_tab => 'Completed';

  @override
  String category_label(String category) {
    return 'Category: $category';
  }

  @override
  String title_label(String title) {
    return 'Title: $title';
  }

  @override
  String location_label(String location) {
    return 'Location: $location';
  }

  @override
  String court_label(String court) {
    return 'Court: $court';
  }

  @override
  String accepted_date_label(String date) {
    return 'Accepted: $date';
  }

  @override
  String get any_court => 'Any Court';

  @override
  String get accepted_status => 'Accepted';

  @override
  String get view_client_button => 'View Client';

  @override
  String get start_case_button => 'Start Case';

  @override
  String get case_work_started => 'Case work started!';

  @override
  String get preferences_header => 'Preferences';

  @override
  String get support_legal_header => 'Support & Legal';

  @override
  String get account_header => 'Account';

  @override
  String get google_calendar_title => 'Google Calendar';

  @override
  String get google_calendar_subtitle =>
      'Sync your appointments with Google Calendar';

  @override
  String google_calendar_connected(String email) {
    return 'Connected: $email';
  }

  @override
  String get connect_button => 'Connect';

  @override
  String get disconnect_button => 'Disconnect';

  @override
  String get contact_support_subtitle =>
      'Reach out to our dedicated support team';

  @override
  String get about_us_subtitle => 'Who we are and what GenieLaw does';

  @override
  String get privacy_policy_subtitle => 'How your data is collected and used';

  @override
  String get terms_conditions_subtitle =>
      'The agreement governing your use of GenieLaw';

  @override
  String get delete_account_permanently => 'Delete Account Permanently';

  @override
  String get need_assistance_heading => 'Need Assistance?';

  @override
  String get need_assistance_desc =>
      'If you are experiencing technical issues, account-related problems, have bug reports, or require general assistance, our dedicated support team is ready to help.';

  @override
  String get email_support_title => 'Email Support';

  @override
  String get send_email_button => 'Send Email';

  @override
  String get response_time_heading => 'Response Time';

  @override
  String get response_time_desc =>
      'We typically respond within 24–48 business hours.';

  @override
  String get app_info_title => 'App Information';

  @override
  String app_version_label(String version) {
    return 'Version: $version';
  }

  @override
  String build_number_label(String build) {
    return 'Build: $build';
  }

  @override
  String could_not_launch_email(String email) {
    return 'Could not open your email application. Please email directly to $email';
  }

  @override
  String get password_required_to_confirm => 'Password is required to confirm.';

  @override
  String get incorrect_password => 'Incorrect password.';

  @override
  String get notifications_subtitle =>
      'Manage how and when GenieLaw notifies you';

  @override
  String get google_calendar_lawyer_only =>
      'Calendar sync is available to advocates only';

  @override
  String get account_header_client => 'Account';

  @override
  String get google_calendar_disconnected => 'Google Calendar disconnected.';

  @override
  String get google_calendar_connect_failed =>
      'Could not connect Google Calendar. Please try again.';

  @override
  String get enter_valid_email => 'Please enter a valid email address.';
}
