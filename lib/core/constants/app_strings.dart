// /// AppStrings — Genie Law App
// /// Centralised string constants for all UI copy.
// /// Zero runtime cost — all `static const`.
// /// Organised by feature, then by screen/widget.
//
// abstract final class AppStrings {
//   // ─────────────────────────────────────────────
//   // APP META
//   // ─────────────────────────────────────────────
//
//   static const String appName = 'Genie Law';
//   static const String appTagline = 'Expert Legal Advice, On Demand';
//   static const String appDescription =
//       'Connect with verified lawyers instantly for consultations, case management, and legal advice.';
//   static const String appVersion = '1.0.0';
//   static const String packageName = 'com.kkdigitalgrowth.genie_law';
//
//   // ─────────────────────────────────────────────
//   // GENERIC / SHARED
//   // ─────────────────────────────────────────────
//
//   static const String ok = 'OK';
//   static const String cancel = 'Cancel';
//   static const String confirm = 'Confirm';
//   static const String save = 'Save';
//   static const String edit = 'Edit';
//   static const String delete = 'Delete';
//   static const String submit = 'Submit';
//   static const String next = 'Next';
//   static const String back = 'Back';
//   static const String done = 'Done';
//   static const String close = 'Close';
//   static const String retry = 'Retry';
//   static const String continueText = 'Continue';
//   static const String skip = 'Skip';
//   static const String search = 'Search';
//   static const String filter = 'Filter';
//   static const String sortBy = 'Sort by';
//   static const String apply = 'Apply';
//   static const String reset = 'Reset';
//   static const String viewAll = 'View All';
//   static const String seeMore = 'See More';
//   static const String loading = 'Loading…';
//   static const String pleaseWait = 'Please wait…';
//   static const String noData = 'Nothing here yet.';
//   static const String noResults = 'No results found.';
//   static const String somethingWentWrong = 'Something went wrong. Please try again.';
//   static const String networkError =
//       'Unable to connect. Check your internet and try again.';
//   static const String sessionExpired = 'Session expired. Please log in again.';
//   static const String required = 'This field is required.';
//   static const String optional = 'Optional';
//   static const String comingSoon = 'Coming Soon';
//   static const String betaLabel = 'Beta';
//   static const String newLabel = 'New';
//   static const String premiumLabel = 'Premium';
//
//   // ─────────────────────────────────────────────
//   // AUTHENTICATION
//   // ─────────────────────────────────────────────
//
//   static const String welcomeBack = 'Welcome Back';
//   static const String loginSubtitle = 'Log in to access your legal workspace.';
//   static const String signUp = 'Sign Up';
//   static const String logIn = 'Log In';
//   static const String logOut = 'Log Out';
//   static const String logOutConfirm = 'Are you sure you want to log out?';
//
//   // Phone OTP
//   static const String enterMobile = 'Enter Mobile Number';
//   static const String mobileHint = '+91 98765 43210';
//   static const String mobileLabel = 'Mobile Number';
//   static const String sendOtp = 'Send OTP';
//   static const String resendOtp = 'Resend OTP';
//   static const String resendOtpIn = 'Resend in ';
//   static const String otpSent = 'OTP sent to ';
//   static const String verifyOtp = 'Verify OTP';
//   static const String enterOtp = 'Enter the 6-digit code';
//   static const String otpLabel = 'OTP';
//   static const String otpExpired = 'OTP expired. Request a new one.';
//   static const String otpInvalid = 'Invalid OTP. Please check and try again.';
//   static const String otpVerified = 'Mobile number verified!';
//   static const String changeNumber = 'Change Number';
//
//   // Google Login
//   static const String continueWithGoogle = 'Continue with Google';
//   static const String googleSignInFailed =
//       'Google sign-in failed. Please try again.';
//
//   // Registration
//   static const String createAccount = 'Create Account';
//   static const String alreadyHaveAccount = 'Already have an account? ';
//   static const String dontHaveAccount = "Don't have an account? ";
//   static const String fullName = 'Full Name';
//   static const String fullNameHint = 'e.g. Priya Sharma';
//   static const String emailAddress = 'Email Address';
//   static const String emailHint = 'priya@example.com';
//   static const String password = 'Password';
//   static const String passwordHint = 'Min. 8 characters';
//   static const String confirmPassword = 'Confirm Password';
//   static const String passwordMismatch = 'Passwords do not match.';
//   static const String weakPassword =
//       'Password must be at least 8 characters with a number and special character.';
//   static const String invalidEmail = 'Enter a valid email address.';
//   static const String invalidMobile = 'Enter a valid 10-digit mobile number.';
//   static const String iAmA = 'I am a…';
//   static const String roleClient = 'Client';
//   static const String roleLawyer = 'Lawyer';
//   static const String termsAgree = 'I agree to the ';
//   static const String termsOfService = 'Terms of Service';
//   static const String andText = ' and ';
//   static const String privacyPolicy = 'Privacy Policy';
//   static const String mustAgreeTerms = 'You must agree to continue.';
//
//   // Forgot Password
//   static const String forgotPassword = 'Forgot Password?';
//   static const String resetPassword = 'Reset Password';
//   static const String resetPasswordSubtitle =
//       'Enter your registered email to receive a reset link.';
//   static const String resetLinkSent =
//       'Reset link sent! Check your inbox.';
//
//   // KYC / Lawyer Registration
//   static const String kycTitle = 'Identity Verification';
//   static const String kycSubtitle =
//       'Upload documents to verify your identity and start practising on Genie Law.';
//   static const String barCouncilNumber = 'Bar Council Registration Number';
//   static const String barCouncilHint = 'e.g. BAR/AP/2018/12345';
//   static const String uploadAadhaar = 'Upload Aadhaar Card';
//   static const String uploadBarCertificate = 'Upload Bar Certificate';
//   static const String uploadPhoto = 'Upload Profile Photo';
//   static const String kycPending = 'Verification Pending';
//   static const String kycPendingDetail =
//       'Your documents are under review. We'll notify you within 24–48 hours.';
//   static const String kycApproved = 'Verified Lawyer';
//   static const String kycRejected = 'Verification Failed';
//   static const String kycRejectedDetail =
//       'Your submission was rejected. Please re-upload valid documents.';
//
//   // ─────────────────────────────────────────────
//   // NAVIGATION / TABS
//   // ─────────────────────────────────────────────
//
//   static const String tabHome = 'Home';
//   static const String tabSearch = 'Search';
//   static const String tabAppointments = 'Appointments';
//   static const String tabChat = 'Messages';
//   static const String tabProfile = 'Profile';
//
//   // Lawyer nav
//   static const String tabDashboard = 'Dashboard';
//   static const String tabClients = 'Clients';
//   static const String tabCalendar = 'Calendar';
//   static const String tabEarnings = 'Earnings';
//
//   // ─────────────────────────────────────────────
//   // CLIENT — DASHBOARD
//   // ─────────────────────────────────────────────
//
//   static const String goodMorning = 'Good morning, ';
//   static const String goodAfternoon = 'Good afternoon, ';
//   static const String goodEvening = 'Good evening, ';
//   static const String dashboardSubtitle = 'How can we help you today?';
//   static const String findLawyer = 'Find a Lawyer';
//   static const String upcomingConsultations = 'Upcoming Consultations';
//   static const String recentCases = 'Recent Cases';
//   static const String recommendedLawyers = 'Recommended for You';
//   static const String quickActions = 'Quick Actions';
//   static const String bookConsultation = 'Book Consultation';
//   static const String myDocuments = 'My Documents';
//   static const String myPayments = 'Payments';
//
//   // ─────────────────────────────────────────────
//   // LAWYER SEARCH
//   // ─────────────────────────────────────────────
//
//   static const String searchLawyers = 'Search Lawyers';
//   static const String searchHint = 'Name, specialisation, or location…';
//   static const String filterByPractice = 'Practice Area';
//   static const String filterByCity = 'City';
//   static const String filterByRating = 'Rating';
//   static const String filterByFee = 'Consultation Fee';
//   static const String filterByLanguage = 'Language';
//   static const String filterByExperience = 'Experience';
//   static const String sortByRelevance = 'Relevance';
//   static const String sortByRating = 'Highest Rated';
//   static const String sortByFeeAsc = 'Fee: Low to High';
//   static const String sortByFeeDesc = 'Fee: High to Low';
//   static const String sortByExperience = 'Most Experienced';
//   static const String noLawyersFound =
//       'No lawyers match your filters. Try adjusting your search.';
//   static const String lawyersNearYou = 'Lawyers Near You';
//   static const String topRatedLawyers = 'Top Rated';
//   static const String availableNow = 'Available Now';
//
//   // ─────────────────────────────────────────────
//   // LAWYER PROFILE
//   // ─────────────────────────────────────────────
//
//   static const String aboutLawyer = 'About';
//   static const String practiceAreas = 'Practice Areas';
//   static const String experience = 'Experience';
//   static const String yearsExperience = 'yrs experience';
//   static const String consultationFee = 'Consultation Fee';
//   static const String perSession = '/ session';
//   static const String languages = 'Languages';
//   static const String education = 'Education';
//   static const String courts = 'Courts Practised In';
//   static const String reviewsAndRatings = 'Reviews & Ratings';
//   static const String verifiedLawyer = 'Verified Lawyer';
//   static const String notVerified = 'Pending Verification';
//   static const String bookNow = 'Book Now';
//   static const String sendMessage = 'Send Message';
//   static const String availability = 'Availability';
//   static const String noSlotsAvailable =
//       'No slots available for the selected date. Try another day.';
//   static const String selectDate = 'Select Date';
//   static const String selectTimeSlot = 'Select Time Slot';
//
//   // ─────────────────────────────────────────────
//   // APPOINTMENT BOOKING
//   // ─────────────────────────────────────────────
//
//   static const String bookAppointment = 'Book Appointment';
//   static const String selectConsultationType = 'Consultation Type';
//   static const String typeVideo = 'Video Call';
//   static const String typeAudio = 'Audio Call';
//   static const String typeChat = 'Chat';
//   static const String typeInPerson = 'In-Person';
//   static const String appointmentSummary = 'Appointment Summary';
//   static const String lawyerName = 'Lawyer';
//   static const String dateAndTime = 'Date & Time';
//   static const String duration = 'Duration';
//   static const String minutes = 'min';
//   static const String totalFee = 'Total Fee';
//   static const String platformFee = 'Platform Fee';
//   static const String grandTotal = 'Grand Total';
//   static const String proceedToPayment = 'Proceed to Payment';
//   static const String appointmentConfirmed = 'Appointment Confirmed!';
//   static const String appointmentConfirmedDetail =
//       'Your consultation has been booked. You\'ll receive a reminder before the session.';
//   static const String appointmentCancelled = 'Appointment Cancelled';
//   static const String cancelAppointment = 'Cancel Appointment';
//   static const String cancelReason = 'Reason for cancellation';
//   static const String reschedule = 'Reschedule';
//   static const String joinCall = 'Join Call';
//   static const String callStartsIn = 'Starts in ';
//
//   // Status labels
//   static const String statusPending = 'Pending';
//   static const String statusConfirmed = 'Confirmed';
//   static const String statusCompleted = 'Completed';
//   static const String statusCancelled = 'Cancelled';
//   static const String statusInProgress = 'In Progress';
//   static const String statusExpired = 'Expired';
//   static const String statusRefunded = 'Refunded';
//
//   // ─────────────────────────────────────────────
//   // CHAT
//   // ─────────────────────────────────────────────
//
//   static const String messages = 'Messages';
//   static const String typeMessage = 'Type a message…';
//   static const String send = 'Send';
//   static const String attach = 'Attach';
//   static const String noMessages = 'No messages yet. Say hello!';
//   static const String online = 'Online';
//   static const String offline = 'Offline';
//   static const String lastSeen = 'Last seen ';
//   static const String delivered = 'Delivered';
//   static const String read = 'Read';
//   static const String sending = 'Sending…';
//   static const String messageFailed = 'Failed to send. Tap to retry.';
//   static const String deleteMessage = 'Delete Message';
//   static const String deleteMessageConfirm =
//       'This message will be deleted for everyone.';
//   static const String attachPhoto = 'Photo';
//   static const String attachDocument = 'Document';
//   static const String viewDocument = 'View Document';
//
//   // ─────────────────────────────────────────────
//   // PAYMENTS
//   // ─────────────────────────────────────────────
//
//   static const String payments = 'Payments';
//   static const String paymentHistory = 'Payment History';
//   static const String payNow = 'Pay Now';
//   static const String paymentSuccessful = 'Payment Successful';
//   static const String paymentFailed = 'Payment Failed';
//   static const String paymentPending = 'Payment Pending';
//   static const String paymentRefunded = 'Refunded';
//   static const String amount = 'Amount';
//   static const String transactionId = 'Transaction ID';
//   static const String paymentMethod = 'Payment Method';
//   static const String invoice = 'Invoice';
//   static const String downloadInvoice = 'Download Invoice';
//   static const String razorpayUpi = 'UPI';
//   static const String razorpayCard = 'Card';
//   static const String razorpayNetBanking = 'Net Banking';
//   static const String razorpayWallet = 'Wallet';
//   static const String noPayments = 'No payment history yet.';
//
//   // ─────────────────────────────────────────────
//   // CASE TRACKING
//   // ─────────────────────────────────────────────
//
//   static const String myCases = 'My Cases';
//   static const String caseDetails = 'Case Details';
//   static const String caseTitle = 'Case Title';
//   static const String caseType = 'Case Type';
//   static const String caseStatus = 'Status';
//   static const String filedOn = 'Filed On';
//   static const String hearingDate = 'Next Hearing';
//   static const String caseDocuments = 'Documents';
//   static const String caseTimeline = 'Timeline';
//   static const String addNote = 'Add Note';
//   static const String noCases = 'No active cases. Book a consultation to get started.';
//
//   // ─────────────────────────────────────────────
//   // DOCUMENTS
//   // ─────────────────────────────────────────────
//
//   static const String documents = 'Documents';
//   static const String uploadDocument = 'Upload Document';
//   static const String documentName = 'Document Name';
//   static const String documentType = 'Document Type';
//   static const String uploadedOn = 'Uploaded on ';
//   static const String downloadDocument = 'Download';
//   static const String previewDocument = 'Preview';
//   static const String deleteDocument = 'Delete Document';
//   static const String deleteDocumentConfirm =
//       'This document will be permanently deleted.';
//   static const String noDocuments = 'No documents uploaded yet.';
//   static const String maxFileSize = 'Max file size: 10 MB';
//   static const String supportedFormats = 'Supported: PDF, JPG, PNG, DOCX';
//   static const String uploading = 'Uploading…';
//   static const String uploadComplete = 'Upload complete.';
//   static const String uploadFailed = 'Upload failed. Please try again.';
//
//   // ─────────────────────────────────────────────
//   // REVIEWS & RATINGS
//   // ─────────────────────────────────────────────
//
//   static const String writeReview = 'Write a Review';
//   static const String yourRating = 'Your Rating';
//   static const String yourReview = 'Your Experience';
//   static const String reviewHint = 'Tell others about your consultation…';
//   static const String reviewMinLength = 'Please write at least 20 characters.';
//   static const String submitReview = 'Submit Review';
//   static const String reviewSubmitted = 'Review submitted. Thank you!';
//   static const String editReview = 'Edit Review';
//   static const String noReviews = 'No reviews yet. Be the first!';
//   static const String verifiedClient = 'Verified Client';
//
//   // ─────────────────────────────────────────────
//   // NOTIFICATIONS
//   // ─────────────────────────────────────────────
//
//   static const String notifications = 'Notifications';
//   static const String markAllRead = 'Mark all as read';
//   static const String noNotifications = 'You're all caught up!';
//   static const String notificationAppointment = 'Appointment Update';
//   static const String notificationPayment = 'Payment';
//   static const String notificationCase = 'Case Update';
//   static const String notificationSystem = 'System';
//
//   // ─────────────────────────────────────────────
//   // LAWYER — DASHBOARD
//   // ─────────────────────────────────────────────
//
//   static const String lawyerDashboard = 'Dashboard';
//   static const String todaysAppointments = 'Today\'s Appointments';
//   static const String totalEarnings = 'Total Earnings';
//   static const String thisMonth = 'This Month';
//   static const String totalClients = 'Total Clients';
//   static const String pendingRequests = 'Pending Requests';
//   static const String acceptRequest = 'Accept';
//   static const String declineRequest = 'Decline';
//   static const String noAppointmentsToday = 'No appointments today. ';
//
//   // ─────────────────────────────────────────────
//   // LAWYER — PROFILE / SETTINGS
//   // ─────────────────────────────────────────────
//
//   static const String myProfile = 'My Profile';
//   static const String editProfile = 'Edit Profile';
//   static const String profileUpdated = 'Profile updated successfully.';
//   static const String profilePhoto = 'Profile Photo';
//   static const String changePhoto = 'Change Photo';
//   static const String bio = 'Bio';
//   static const String bioHint = 'Tell clients about yourself and your expertise…';
//   static const String officeAddress = 'Office Address';
//   static const String city = 'City';
//   static const String state = 'State';
//   static const String pincode = 'Pincode';
//   static const String setConsultationFee = 'Set Consultation Fee (₹)';
//   static const String setAvailability = 'Set Availability';
//   static const String addPracticeArea = 'Add Practice Area';
//   static const String addEducation = 'Add Education';
//   static const String addLanguage = 'Add Language';
//
//   // ─────────────────────────────────────────────
//   // SUBSCRIPTIONS
//   // ─────────────────────────────────────────────
//
//   static const String subscriptions = 'Subscription Plans';
//   static const String currentPlan = 'Current Plan';
//   static const String freePlan = 'Free';
//   static const String basicPlan = 'Basic';
//   static const String proPlan = 'Pro';
//   static const String enterprisePlan = 'Enterprise';
//   static const String upgradeNow = 'Upgrade Now';
//   static const String renewNow = 'Renew Now';
//   static const String planExpires = 'Expires on ';
//   static const String planExpired = 'Plan Expired';
//   static const String mostPopular = 'Most Popular';
//   static const String bestValue = 'Best Value';
//   static const String perMonth = '/ month';
//   static const String perYear = '/ year';
//
//   // ─────────────────────────────────────────────
//   // SETTINGS
//   // ─────────────────────────────────────────────
//
//   static const String settings = 'Settings';
//   static const String account = 'Account';
//   static const String security = 'Security';
//   static const String changePassword = 'Change Password';
//   static const String changeLanguage = 'Language';
//   static const String appearance = 'Appearance';
//   static const String themeDark = 'Dark';
//   static const String themeLight = 'Light';
//   static const String themeSystem = 'System Default';
//   static const String pushNotifications = 'Push Notifications';
//   static const String emailNotifications = 'Email Notifications';
//   static const String helpAndSupport = 'Help & Support';
//   static const String contactSupport = 'Contact Support';
//   static const String reportIssue = 'Report an Issue';
//   static const String faq = 'FAQs';
//   static const String aboutApp = 'About Genie Law';
//   static const String rateApp = 'Rate the App';
//   static const String deleteAccount = 'Delete Account';
//   static const String deleteAccountConfirm =
//       'Deleting your account is permanent and cannot be undone. All your data will be lost.';
//
//   // ─────────────────────────────────────────────
//   // ADMIN
//   // ─────────────────────────────────────────────
//
//   static const String adminPanel = 'Admin Panel';
//   static const String manageUsers = 'Manage Users';
//   static const String manageLawyers = 'Manage Lawyers';
//   static const String manageComplaints = 'Complaints';
//   static const String manageBlogs = 'Blogs & FAQs';
//   static const String revenueAnalytics = 'Revenue & Analytics';
//   static const String approveKyc = 'Approve KYC';
//   static const String verifyLawyer = 'Verify Lawyer';
//   static const String suspendUser = 'Suspend User';
//   static const String unsuspendUser = 'Unsuspend User';
//
//   // ─────────────────────────────────────────────
//   // VALIDATION MESSAGES
//   // ─────────────────────────────────────────────
//
//   static const String fieldRequired = 'This field cannot be empty.';
//   static const String nameTooShort = 'Name must be at least 2 characters.';
//   static const String nameTooLong = 'Name cannot exceed 60 characters.';
//   static const String emailInvalid = 'Enter a valid email address.';
//   static const String phoneInvalid = 'Enter a valid 10-digit mobile number.';
//   static const String pincodeInvalid = 'Enter a valid 6-digit pincode.';
//   static const String feeInvalid = 'Enter a valid consultation fee.';
//   static const String bioTooLong = 'Bio cannot exceed 500 characters.';
//
//   // ─────────────────────────────────────────────
//   // EMPTY STATES
//   // ─────────────────────────────────────────────
//
//   static const String emptyAppointments =
//       'No appointments yet.\nBook your first consultation now.';
//   static const String emptyChats =
//       'No conversations yet.\nConnect with a lawyer to get started.';
//   static const String emptyDocuments =
//       'No documents uploaded.\nUpload case files to keep everything in one place.';
//   static const String emptyPayments =
//       'No payment records found.';
//   static const String emptyNotifications =
//       'You're all caught up!\nCheck back later for updates.';
//   static const String emptyReviews =
//       'No reviews yet.\nBe the first to share your experience.';
//   static const String emptyCases =
//       'No active cases.\nStart a consultation to open your first case.';
//
//   // ─────────────────────────────────────────────
//   // PRACTICE AREAS
//   // ─────────────────────────────────────────────
//
//   static const String criminalLaw = 'Criminal Law';
//   static const String familyLaw = 'Family Law';
//   static const String corporateLaw = 'Corporate Law';
//   static const String civilLaw = 'Civil Law';
//   static const String propertyLaw = 'Property Law';
//   static const String taxLaw = 'Tax Law';
//   static const String ipLaw = 'Intellectual Property';
//   static const String labourLaw = 'Labour Law';
//   static const String consumerLaw = 'Consumer Law';
//   static const String constitutionalLaw = 'Constitutional Law';
//   static const String immigrationLaw = 'Immigration Law';
//   static const String cyberlawLaw = 'Cyber Law';
//   static const String divorceAndMatrimonial = 'Divorce & Matrimonial';
//   static const String bankingAndFinance = 'Banking & Finance';
//
//   // ─────────────────────────────────────────────
//   // ONBOARDING
//   // ─────────────────────────────────────────────
//
//   static const String onboard1Title = 'Find the Right Lawyer';
//   static const String onboard1Body =
//       'Search from thousands of verified lawyers across all practice areas — fast, transparent, and trusted.';
//   static const String onboard2Title = 'Consult in Minutes';
//   static const String onboard2Body =
//       'Book a consultation via chat, call, or video at a time that suits you.';
//   static const String onboard3Title = 'Manage Your Cases';
//   static const String onboard3Body =
//       'Track hearings, share documents, and stay informed — all in one secure place.';
//   static const String getStarted = 'Get Started';
// }

class AppStrings {
  AppStrings._();

  // App
  static const String appName = "LawConnect";
  static const String appTagline = "Professional Legal Assistance";

  // Authentication
  static const String login = "Login";
  static const String signup = "Sign Up";
  static const String continueText = "Continue";
  static const String verifyOtp = "Verify OTP";
  static const String enterMobile = "Enter Mobile Number";
  static const String googleSignIn = "Continue with Google";
  static const String resendOtp = "Resend OTP";

  // Dashboard
  static const String welcome = "Welcome";
  static const String searchLawyer = "Search Lawyers";
  static const String topRatedLawyers = "Top Rated Lawyers";
  static const String upcomingAppointments =
      "Upcoming Appointments";

  // Lawyer Profile
  static const String experience = "Experience";
  static const String specialization = "Specialization";
  static const String reviews = "Reviews";
  static const String availability = "Availability";

  // Appointment
  static const String bookAppointment = "Book Appointment";
  static const String appointmentDetails =
      "Appointment Details";

  // Chat
  static const String chat = "Chat";
  static const String typeMessage = "Type your message";

  // Documents
  static const String uploadDocument = "Upload Document";
  static const String legalDocuments = "Legal Documents";

  // Payments
  static const String payment = "Payment";
  static const String payNow = "Pay Now";

  // Common
  static const String cancel = "Cancel";
  static const String save = "Save";
  static const String update = "Update";
  static const String delete = "Delete";
  static const String retry = "Retry";
  static const String loading = "Loading...";
  static const String noDataFound = "No Data Found";

  // Validation
  static const String mobileRequired =
      "Mobile number is required";

  static const String invalidMobile =
      "Enter valid mobile number";

  static const String otpRequired =
      "Please enter OTP";

  static const String somethingWentWrong =
      "Something went wrong";
}