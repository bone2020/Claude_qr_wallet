/// QR Wallet String Constants
/// All user-facing text in the app
class AppStrings {
  AppStrings._();

  // ============ APP ============
  static const String appName = 'QR Wallet';
  static const String appTagline = 'Seamless payments, anywhere';
  static const String currencySymbol = '₦'; // Default currency symbol (Nigerian Naira)

  // ============ SPLASH ============
  static const String getStarted = 'Get Started';

  // ============ AUTH ============
  static const String signUp = 'Sign up';
  static const String signUpSubtitle = 'Sign up and begin your journey to the next level';
  static const String logIn = 'Log in';
  static const String logInSubtitle = 'Welcome back! Sign in to continue';
  static const String createAccount = 'Create Account';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String orSignUpWith = 'Or sign up with';
  static const String orLogInWith = 'Or log in with';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String sendResetLink = 'Send Reset Link';
  static const String backToLogin = 'Back to Login';

  // ============ FORM FIELDS ============
  static const String fullName = 'Full name';
  static const String fullNameHint = 'Enter your full name';
  static const String email = 'Email address';
  static const String emailHint = 'Enter your email address';
  static const String phoneNumber = 'Phone Number';
  static const String phoneNumberHint = 'Enter your phone number';
  static const String password = 'Password';
  static const String passwordHint = 'Enter your password';
  static const String confirmPassword = 'Confirm Password';
  static const String confirmPasswordHint = 'Confirm your password';
  static const String termsAgreement = 'I agree with';
  static const String termsAndPrivacy = 'Terms and Privacy';

  // ============ VERIFICATION ============
  static const String verifyPhone = 'Verify Phone';
  static const String verifyEmail = 'Verify Email';
  static const String enterOtp = 'Enter OTP';
  static const String otpSentTo = 'We sent a verification code to';
  static const String resendCode = 'Resend Code';
  static const String resendIn = 'Resend in';
  static const String verify = 'Verify';
  static const String didntReceiveCode = "Didn't receive code?";

  // ============ KYC / BIOMETRIC ============
  static const String completeProfile = 'Complete Profile';
  static const String completeProfileSubtitle = 'We need a few more details to secure your account';
  static const String governmentId = 'Government ID';
  static const String selectIdType = 'Select ID type';
  static const String nationalId = 'National ID';
  static const String driversLicense = "Driver's License";
  static const String passport = 'Passport';
  static const String uploadFront = 'Upload Front';
  static const String uploadBack = 'Upload Back';
  static const String uploadMainPage = 'Upload Main Page';
  static const String dateOfBirth = 'Date of Birth';
  static const String selectDate = 'Select date';
  static const String faceScan = 'Face Scan';
  static const String faceScanInstructions = 'Position your face within the frame';
  static const String startScan = 'Start Scan';
  static const String profilePhoto = 'Profile Photo';
  static const String uploadPhoto = 'Upload Photo';
  static const String takePhoto = 'Take Photo';
  static const String continueText = 'Continue';
  static const String skip = 'Skip for now';

  // ============ HOME ============
  static const String home = 'Home';
  static const String totalBalance = 'Total Balance';
  static const String availableBalance = 'Available Balance';
  static const String hideBalance = 'Hide Balance';
  static const String showBalance = 'Show Balance';
  static const String send = 'Send';
  static const String receive = 'Receive';
  static const String addMoney = 'Add Money';
  static const String withdraw = 'Withdraw';
  static const String recentTransactions = 'Recent Transactions';
  static const String viewAll = 'View All';
  static const String noTransactions = 'No transactions yet';
  static const String noTransactionsSubtitle = 'Your transaction history will appear here';

  // ============ SEND MONEY ============
  static const String sendMoney = 'Send Money';
  static const String scanQrCode = 'Scan QR Code';
  static const String enterWalletId = 'Enter Wallet ID';
  static const String walletId = 'Wallet ID';
  static const String walletIdHint = 'Enter recipient wallet ID';
  static const String amount = 'Amount';
  static const String amountHint = 'Enter amount';
  static const String note = 'Note (optional)';
  static const String noteHint = 'Add a note';
  static const String review = 'Review';
  static const String confirmSend = 'Confirm & Send';
  static const String sendingTo = 'Sending to';
  static const String transactionFee = 'Transaction Fee';
  static const String totalAmount = 'Total Amount';

  // ============ RECEIVE MONEY ============
  static const String receiveMoney = 'Receive Money';
  static const String myQrCode = 'My QR Code';
  static const String shareQrCode = 'Share QR Code';
  static const String downloadQrCode = 'Download QR Code';
  static const String walletIdCopied = 'Wallet ID copied!';
  static const String tapToCopy = 'Tap to copy';

  // ============ ADD MONEY ============
  static const String addMoneyTitle = 'Add Money';
  static const String selectBank = 'Select Bank';
  static const String linkedBanks = 'Linked Banks';
  static const String addNewBank = 'Add New Bank';
  static const String bankName = 'Bank Name';
  static const String accountNumber = 'Account Number';
  static const String accountName = 'Account Name';
  static const String linkBank = 'Link Bank';
  static const String transferFrom = 'Transfer from';

  // ============ TRANSACTIONS ============
  static const String transactions = 'Transactions';
  static const String allTransactions = 'All';
  static const String sent = 'Sent';
  static const String received = 'Received';
  static const String pending = 'Pending';
  static const String completed = 'Completed';
  static const String failed = 'Failed';
  static const String transactionDetails = 'Transaction Details';
  static const String transactionId = 'Transaction ID';
  static const String date = 'Date';
  static const String time = 'Time';
  static const String status = 'Status';
  static const String from = 'From';
  static const String to = 'To';

  // ============ PROFILE ============
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String accountSettings = 'Account Settings';
  static const String security = 'Security';
  static const String notifications = 'Notifications';
  static const String linkedAccounts = 'Linked Accounts';
  static const String helpSupport = 'Help & Support';
  static const String about = 'About';
  static const String logOut = 'Log Out';
  static const String darkMode = 'Dark Mode';
  static const String biometricLogin = 'Biometric Login';
  static const String changePassword = 'Change Password';
  static const String changePin = 'Change PIN';

  // ============ ERRORS ============
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'No internet connection. Please check your network.';
  static const String errorInvalidEmail = 'Please enter a valid email address';
  static const String errorInvalidPhone = 'Please enter a valid phone number';
  static const String errorPasswordMismatch = 'Passwords do not match';
  static const String errorPasswordWeak = 'Password must be at least 8 characters';
  static const String errorFieldRequired = 'This field is required';
  static const String errorInsufficientBalance = 'Insufficient balance';
  static const String errorInvalidAmount = 'Please enter a valid amount';
  static const String errorInvalidOtp = 'Invalid OTP. Please try again.';
  static const String errorUserNotFound = 'User not found';
  static const String errorWrongPassword = 'Wrong password';

  // ============ SUCCESS ============
  static const String successAccountCreated = 'Account created successfully!';
  static const String successLoggedIn = 'Welcome back!';
  static const String successMoneySent = 'Money sent successfully!';
  static const String successMoneyAdded = 'Money added successfully!';
  static const String successProfileUpdated = 'Profile updated successfully!';
  static const String successPasswordReset = 'Password reset link sent!';

  // ============ BUTTONS ============
  static const String ok = 'OK';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String retry = 'Retry';
  static const String close = 'Close';
}
