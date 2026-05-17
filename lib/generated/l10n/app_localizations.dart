import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// App name shown in title bars and splash
  ///
  /// In en, this message translates to:
  /// **'QR Wallet'**
  String get appName;

  /// Tagline shown on splash screen
  ///
  /// In en, this message translates to:
  /// **'Seamless payments, anywhere'**
  String get appTagline;

  /// Button on splash screen to begin onboarding
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Sign up button label and screen title
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// Subtitle shown on the sign up screen
  ///
  /// In en, this message translates to:
  /// **'Sign up and begin your journey to the next level'**
  String get signUpSubtitle;

  /// Log in button label and screen title
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// Subtitle shown on the log in screen
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Sign in to continue'**
  String get logInSubtitle;

  /// Button on sign up screen to submit the form
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// Prompt before the Log in link on the sign up screen
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Prompt before the Sign up link on the log in screen
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// Divider text above social sign up options
  ///
  /// In en, this message translates to:
  /// **'Or sign up with'**
  String get orSignUpWith;

  /// Divider text above social log in options
  ///
  /// In en, this message translates to:
  /// **'Or log in with'**
  String get orLogInWith;

  /// Link to password reset on the log in screen
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// Title on the password reset screen
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Button to email the password reset link
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Link returning the user to the log in screen
  ///
  /// In en, this message translates to:
  /// **'Back to Login'**
  String get backToLogin;

  /// Label for the full name input field
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// Placeholder text inside the full name field
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get fullNameHint;

  /// Label for the email input field
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get email;

  /// Placeholder text inside the email field
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get emailHint;

  /// Label for the phone number input field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Placeholder text inside the phone number field
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneNumberHint;

  /// Label for the password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Placeholder text inside the password field
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Label for the confirm password input field
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Placeholder inside the confirm password field
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get confirmPasswordHint;

  /// Prefix before the Terms and Privacy link on sign up
  ///
  /// In en, this message translates to:
  /// **'I agree with'**
  String get termsAgreement;

  /// Link to the terms and privacy policy
  ///
  /// In en, this message translates to:
  /// **'Terms and Privacy'**
  String get termsAndPrivacy;

  /// Title shown when verifying a phone number via OTP
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// Title shown when verifying an email address
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmail;

  /// Prompt above the OTP input field
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// Confirmation text above the masked email or phone
  ///
  /// In en, this message translates to:
  /// **'We sent a verification code to'**
  String get otpSentTo;

  /// Button to request a new OTP
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// Prefix shown next to the OTP resend countdown timer
  ///
  /// In en, this message translates to:
  /// **'Resend in'**
  String get resendIn;

  /// Button to submit an OTP for verification
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// Prompt before the resend code link
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive code?'**
  String get didntReceiveCode;

  /// Title on the KYC completion screen
  ///
  /// In en, this message translates to:
  /// **'Complete Profile'**
  String get completeProfile;

  /// Subtitle on the KYC completion screen
  ///
  /// In en, this message translates to:
  /// **'We need a few more details to secure your account'**
  String get completeProfileSubtitle;

  /// Section header for government ID upload during KYC
  ///
  /// In en, this message translates to:
  /// **'Government ID'**
  String get governmentId;

  /// Prompt to choose an ID document type during KYC
  ///
  /// In en, this message translates to:
  /// **'Select ID type'**
  String get selectIdType;

  /// ID type option: national identity card
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get nationalId;

  /// ID type option: driver's license
  ///
  /// In en, this message translates to:
  /// **'Driver\'s License'**
  String get driversLicense;

  /// ID type option: passport
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get passport;

  /// Button to upload the front of an ID card
  ///
  /// In en, this message translates to:
  /// **'Upload Front'**
  String get uploadFront;

  /// Button to upload the back of an ID card
  ///
  /// In en, this message translates to:
  /// **'Upload Back'**
  String get uploadBack;

  /// Button to upload the main page of a passport
  ///
  /// In en, this message translates to:
  /// **'Upload Main Page'**
  String get uploadMainPage;

  /// Label for the date of birth input field
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// Placeholder for an unselected date field
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get selectDate;

  /// Title for the face scan KYC step
  ///
  /// In en, this message translates to:
  /// **'Face Scan'**
  String get faceScan;

  /// Instructions shown during face scan
  ///
  /// In en, this message translates to:
  /// **'Position your face within the frame'**
  String get faceScanInstructions;

  /// Button to begin the face scan
  ///
  /// In en, this message translates to:
  /// **'Start Scan'**
  String get startScan;

  /// Label for the profile photo upload section
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhoto;

  /// Button to choose an existing photo from gallery
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// Button to take a new photo with the camera
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Generic continue/next button
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// Button to skip the current optional step
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skip;

  /// Bottom navigation tab label for the home screen
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Label above the total wallet balance figure
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// Label above the available (spendable) balance figure
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalance;

  /// Action to obscure the displayed wallet balance
  ///
  /// In en, this message translates to:
  /// **'Hide Balance'**
  String get hideBalance;

  /// Action to reveal the obscured wallet balance
  ///
  /// In en, this message translates to:
  /// **'Show Balance'**
  String get showBalance;

  /// Action: send money to another wallet
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Action: receive money via QR or wallet ID
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// Action: top up the wallet
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get addMoney;

  /// Action: withdraw funds from the wallet
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdraw;

  /// Section header on home screen above the latest transactions
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// Link to navigate to the full transactions list
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// Empty state message when no transactions exist
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// Subtitle in the empty transactions state
  ///
  /// In en, this message translates to:
  /// **'Your transaction history will appear here'**
  String get noTransactionsSubtitle;

  /// Title of the send money flow
  ///
  /// In en, this message translates to:
  /// **'Send Money'**
  String get sendMoney;

  /// Action to open the camera and scan a QR code
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// Action to manually type a recipient wallet ID
  ///
  /// In en, this message translates to:
  /// **'Enter Wallet ID'**
  String get enterWalletId;

  /// Label for a wallet ID field or display
  ///
  /// In en, this message translates to:
  /// **'Wallet ID'**
  String get walletId;

  /// Placeholder text in the recipient wallet ID field
  ///
  /// In en, this message translates to:
  /// **'Enter recipient wallet ID'**
  String get walletIdHint;

  /// Label for an amount input field
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// Placeholder text inside the amount field
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get amountHint;

  /// Label for the optional transaction note field
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get note;

  /// Placeholder inside the optional transaction note field
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get noteHint;

  /// Button to advance from amount to confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// Button on the confirmation screen to dispatch the send
  ///
  /// In en, this message translates to:
  /// **'Confirm & Send'**
  String get confirmSend;

  /// Label above the recipient name on the confirmation screen
  ///
  /// In en, this message translates to:
  /// **'Sending to'**
  String get sendingTo;

  /// Label for the displayed transaction fee
  ///
  /// In en, this message translates to:
  /// **'Transaction Fee'**
  String get transactionFee;

  /// Label for the total to be sent including fees
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// Title of the receive money screen
  ///
  /// In en, this message translates to:
  /// **'Receive Money'**
  String get receiveMoney;

  /// Section header above the user's QR code
  ///
  /// In en, this message translates to:
  /// **'My QR Code'**
  String get myQrCode;

  /// Action to share the QR code via system share sheet
  ///
  /// In en, this message translates to:
  /// **'Share QR Code'**
  String get shareQrCode;

  /// Action to save the QR code as an image
  ///
  /// In en, this message translates to:
  /// **'Download QR Code'**
  String get downloadQrCode;

  /// Confirmation snackbar after copying the wallet ID
  ///
  /// In en, this message translates to:
  /// **'Wallet ID copied!'**
  String get walletIdCopied;

  /// Hint shown next to a copyable wallet ID
  ///
  /// In en, this message translates to:
  /// **'Tap to copy'**
  String get tapToCopy;

  /// Title of the add money screen (separate from action button)
  ///
  /// In en, this message translates to:
  /// **'Add Money'**
  String get addMoneyTitle;

  /// Action to choose a linked bank for funding
  ///
  /// In en, this message translates to:
  /// **'Select Bank'**
  String get selectBank;

  /// Section header listing the user's linked bank accounts
  ///
  /// In en, this message translates to:
  /// **'Linked Banks'**
  String get linkedBanks;

  /// Action to link a new bank account
  ///
  /// In en, this message translates to:
  /// **'Add New Bank'**
  String get addNewBank;

  /// Label for a bank name field
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankName;

  /// Label for an account number field
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get accountNumber;

  /// Label for the displayed account holder name
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountName;

  /// Button to confirm linking a bank account
  ///
  /// In en, this message translates to:
  /// **'Link Bank'**
  String get linkBank;

  /// Label preceding the chosen funding source
  ///
  /// In en, this message translates to:
  /// **'Transfer from'**
  String get transferFrom;

  /// Bottom navigation label and screen title for the transactions list
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// Filter chip showing all transactions
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTransactions;

  /// Filter chip and status label for sent transactions
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// Filter chip and status label for received transactions
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// Status label for pending transactions
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Status label for completed transactions
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// Status label for failed transactions
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// Title of the single transaction detail screen
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// Label for the transaction's unique identifier
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// Label for a transaction date field
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Label for a transaction time field
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// Label for a transaction status field
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Label for the sender of a transaction
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// Label for the recipient of a transaction
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// Bottom navigation label and screen title for the user's profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Action to open the profile editor
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Section header for account-related settings
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// Section header for security-related settings
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// Section header and screen title for notification settings
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Profile row leading to linked accounts management
  ///
  /// In en, this message translates to:
  /// **'Linked Accounts'**
  String get linkedAccounts;

  /// Profile row leading to help and support
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// Profile row leading to the user's dispute list
  ///
  /// In en, this message translates to:
  /// **'My Disputes'**
  String get myDisputes;

  /// Profile row leading to the about screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// Action to sign the user out
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// Toggle label for dark theme
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Toggle label for biometric authentication
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get biometricLogin;

  /// Profile row to change the account password
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// Profile row to change the wallet PIN
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// Fallback error message when the cause is unknown
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// Error shown when offline or network is unreachable
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check your network.'**
  String get errorNetwork;

  /// Validation error when an email field's content is malformed
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get errorInvalidEmail;

  /// Validation error when a phone field's content is malformed
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get errorInvalidPhone;

  /// Validation error when password and confirm password differ
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get errorPasswordMismatch;

  /// Validation error when the password is too short
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get errorPasswordWeak;

  /// Validation error for an empty required field
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errorFieldRequired;

  /// Error shown when wallet has too little to complete a send
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get errorInsufficientBalance;

  /// Validation error when amount is missing or zero/negative
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get errorInvalidAmount;

  /// Error shown when the entered OTP code is wrong
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get errorInvalidOtp;

  /// Error shown when the entered email/phone has no account
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get errorUserNotFound;

  /// Error shown when the password is incorrect on log in
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get errorWrongPassword;

  /// Success message after sign up completes
  ///
  /// In en, this message translates to:
  /// **'Account created successfully!'**
  String get successAccountCreated;

  /// Success message after a successful log in
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get successLoggedIn;

  /// Success message after a transaction is dispatched
  ///
  /// In en, this message translates to:
  /// **'Money sent successfully!'**
  String get successMoneySent;

  /// Success message after a successful top up
  ///
  /// In en, this message translates to:
  /// **'Money added successfully!'**
  String get successMoneyAdded;

  /// Success message after editing the profile
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get successProfileUpdated;

  /// Success message after a password reset email is sent
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent!'**
  String get successPasswordReset;

  /// Confirmation button: acknowledge
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Action to abort the current flow
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirmation button: proceed
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Action to persist edits
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Action to close the current step as complete
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Action to advance to the next step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Action to return to the previous step
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Action to attempt the failed operation again
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Action to dismiss a dialog or modal
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Title of the KYC method selection screen
  ///
  /// In en, this message translates to:
  /// **'Select Verification Method'**
  String get selectVerificationMethod;

  /// Subtitle on the KYC method selection screen
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred ID type to verify your identity'**
  String get selectVerificationMethodSubtitle;

  /// KYC option title for passport verification
  ///
  /// In en, this message translates to:
  /// **'Verify Passport'**
  String get verifyPassport;

  /// KYC option title for Nigerian National Identification Number verification
  ///
  /// In en, this message translates to:
  /// **'Verify NIN'**
  String get verifyNin;

  /// KYC option title for Bank Verification Number verification
  ///
  /// In en, this message translates to:
  /// **'Verify BVN'**
  String get verifyBvn;

  /// KYC option title for driver's license verification
  ///
  /// In en, this message translates to:
  /// **'Verify Driver\'s License'**
  String get verifyDriversLicense;

  /// KYC option title for voter's card verification
  ///
  /// In en, this message translates to:
  /// **'Verify Voter\'s Card'**
  String get verifyVotersCard;

  /// KYC option title for national ID verification
  ///
  /// In en, this message translates to:
  /// **'Verify National ID'**
  String get verifyNationalId;

  /// KYC option title for Ghanaian SSNIT verification
  ///
  /// In en, this message translates to:
  /// **'Verify SSNIT'**
  String get verifySsnit;

  /// Helper text under the passport KYC option
  ///
  /// In en, this message translates to:
  /// **'International passport verification'**
  String get passportDescription;

  /// Helper text under the NIN KYC option
  ///
  /// In en, this message translates to:
  /// **'National Identification Number (11 digits)'**
  String get ninDescription;

  /// Helper text under the BVN KYC option
  ///
  /// In en, this message translates to:
  /// **'Bank Verification Number (11 digits)'**
  String get bvnDescription;

  /// Helper text under the driver's license KYC option
  ///
  /// In en, this message translates to:
  /// **'Driver\'s license verification'**
  String get driversLicenseDescription;

  /// Helper text under the voter's card KYC option
  ///
  /// In en, this message translates to:
  /// **'Voter\'s card verification'**
  String get votersCardDescription;

  /// Helper text under the national ID KYC option
  ///
  /// In en, this message translates to:
  /// **'National ID card verification'**
  String get nationalIdDescription;

  /// Helper text under the SSNIT KYC option
  ///
  /// In en, this message translates to:
  /// **'SSNIT number (1 letter + 12 digits)'**
  String get ssnitDescription;

  /// Button to begin the KYC verification flow
  ///
  /// In en, this message translates to:
  /// **'Start Verification'**
  String get startVerification;

  /// Explanatory text shown before starting KYC verification
  ///
  /// In en, this message translates to:
  /// **'We will capture your document and take a selfie to verify your identity'**
  String get verificationDescription;

  /// Prompt to enter an ID number during KYC
  ///
  /// In en, this message translates to:
  /// **'Enter ID Number'**
  String get enterIdNumber;

  /// Validation error for empty ID number field
  ///
  /// In en, this message translates to:
  /// **'ID number is required for verification'**
  String get idNumberRequired;

  /// Success message after KYC completes
  ///
  /// In en, this message translates to:
  /// **'Verification completed successfully!'**
  String get verificationSuccessful;

  /// Error message when KYC fails
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get verificationFailed;

  /// Profile row label leading to the language settings screen (Phase 6 NEW)
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Title shown at the top of the language settings screen (Phase 6 NEW)
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Subtitle shown on the language settings screen (Phase 6 NEW)
  ///
  /// In en, this message translates to:
  /// **'Choose the language you\'d like to use throughout the app and in notifications.'**
  String get languageDescription;

  /// Prompt shown on the first-launch language picker (Phase 6 NEW). Note: this string is shown alongside the same prompt in French and Arabic since the user hasn't picked yet.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get firstLaunchLanguagePrompt;

  /// Label for the English language option (always in English regardless of locale)
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Label for the French language option in English locale; in fr.arb this stays Français, in ar.arb stays Français
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// Label for the Arabic language option in English locale; native form العربية shown in fr/ar
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// Snackbar shown after a successful language change (Phase 6 NEW)
  ///
  /// In en, this message translates to:
  /// **'Language changed'**
  String get languageChanged;

  /// Currency code followed by amount with a space, e.g. 'USD 12.34'. Used in balance card.
  ///
  /// In en, this message translates to:
  /// **'{currency} {amount}'**
  String currencyAmount(String currency, String amount);

  /// Currency symbol concatenated with amount, e.g. '$12.34'. Used in transaction details and confirm send.
  ///
  /// In en, this message translates to:
  /// **'{symbol}{amount}'**
  String symbolAmount(String symbol, String amount);

  /// Sign prefix (+/- or empty) followed by currency code and amount. Used in transaction tile.
  ///
  /// In en, this message translates to:
  /// **'{prefix}{currency}{amount}'**
  String signedCurrencyAmount(String prefix, String currency, String amount);

  /// Exchange rate display line, e.g. '1 USD = 0.85 EUR'.
  ///
  /// In en, this message translates to:
  /// **'1 {fromCurrency} = {rate} {toCurrency}'**
  String exchangeRateLine(String fromCurrency, String rate, String toCurrency);

  /// Currency symbol with code in parentheses, e.g. '$ (USD)'.
  ///
  /// In en, this message translates to:
  /// **'{symbol} ({code})'**
  String currencyCodeWithSymbol(String symbol, String code);

  /// Router 404 fallback message.
  ///
  /// In en, this message translates to:
  /// **'Page not found: {uri}'**
  String pageNotFound(String uri);

  /// Banner shown when device is offline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get youAreOffline;

  /// Home screen greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {userName} 👋'**
  String helloUser(String userName);

  /// Home screen subtitle below the greeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// Label above the available balance amount on the balance card.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableBalanceLabel;

  /// Label above the held/escrow balance on the balance card.
  ///
  /// In en, this message translates to:
  /// **'On Hold'**
  String get onHoldBalanceLabel;

  /// Status badge for pending transactions in the list.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transactionStatusPending;

  /// Status badge for failed transactions in the list.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transactionStatusFailed;

  /// AppBar title on the notifications screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsScreenTitle;

  /// Menu action on notifications screen.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsRead;

  /// Error state when notifications fail to load.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications'**
  String get failedToLoadNotifications;

  /// Empty state heading on notifications screen.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get noNotifications;

  /// Empty state subtext on notifications screen.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get youreAllCaughtUp;

  /// AppBar title on currency selector screen.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get selectCurrencyTitle;

  /// Body description on currency selector screen.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred currency for displaying balances and transactions.'**
  String get currencySelectorDescription;

  /// Snackbar shown after successful currency change.
  ///
  /// In en, this message translates to:
  /// **'Currency changed to {currencyName}'**
  String currencyChangedTo(String currencyName);

  /// Snackbar shown when currency change fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to change currency'**
  String get failedToChangeCurrency;

  /// Pagination button at the bottom of transactions list.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// Snackbar after copying a value to clipboard. {label} is the field name.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String copiedToClipboard(String label);

  /// Empty state when transaction can't be loaded on details screen.
  ///
  /// In en, this message translates to:
  /// **'Transaction not found'**
  String get transactionNotFound;

  /// Outlined button on transaction details for sent transactions within 7 days.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get reportIssue;

  /// Section header on transaction details for cross-currency transactions.
  ///
  /// In en, this message translates to:
  /// **'Currency Conversion'**
  String get currencyConversion;

  /// Label for sender-side amount in currency conversion section.
  ///
  /// In en, this message translates to:
  /// **'Original Amount'**
  String get originalAmount;

  /// Label for receiver-side amount in currency conversion section.
  ///
  /// In en, this message translates to:
  /// **'Converted Amount'**
  String get convertedAmount;

  /// Label for the exchange rate row on transaction details.
  ///
  /// In en, this message translates to:
  /// **'Exchange Rate'**
  String get exchangeRateLabel;

  /// Label above the list of items in a payment-request transaction.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get transactionItemsLabel;

  /// Instruction overlay on QR scanner screen.
  ///
  /// In en, this message translates to:
  /// **'Position QR code within the frame'**
  String get positionQrCodeInFrame;

  /// Validation snackbar on send money screen.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid wallet ID'**
  String get pleaseEnterValidWalletId;

  /// Loading state when resolving a wallet ID on send money screen.
  ///
  /// In en, this message translates to:
  /// **'Looking up wallet...'**
  String get lookingUpWallet;

  /// Helper text under the wallet ID field on send money screen.
  ///
  /// In en, this message translates to:
  /// **'Scan recipient\'s QR code to send money'**
  String get scanRecipientQrToSend;

  /// Title of PIN entry dialog on confirm send screen.
  ///
  /// In en, this message translates to:
  /// **'Transaction PIN'**
  String get transactionPin;

  /// Subtitle in PIN entry dialog on confirm send screen.
  ///
  /// In en, this message translates to:
  /// **'Enter your 6-digit PIN to confirm this transfer'**
  String get enterPinToConfirm;

  /// Validation snackbar on confirm send screen.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get pleaseEnterAmount;

  /// Success message after sending money.
  ///
  /// In en, this message translates to:
  /// **'{currency}{amount} sent to {recipient}'**
  String amountSentTo(String currency, String amount, String recipient);

  /// Badge on confirm send when paying a payment request rather than free-form send.
  ///
  /// In en, this message translates to:
  /// **'Payment Request'**
  String get paymentRequestLabel;

  /// Caption when fee preview fails on confirm send.
  ///
  /// In en, this message translates to:
  /// **'Fee is approximate — {error}'**
  String feeApproximateError(String error);

  /// Error caption on confirm send when balance check fails.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance for this transfer'**
  String get insufficientBalance;

  /// Label preceding the seller's requested amount on confirm send (cross-currency).
  ///
  /// In en, this message translates to:
  /// **'Seller requested:'**
  String get sellerRequestedLabel;

  /// Label preceding the converted amount on confirm send (cross-currency).
  ///
  /// In en, this message translates to:
  /// **'Recipient receives:'**
  String get recipientReceivesLabel;

  /// Send button label on confirm send including amount, e.g. 'Send USD12.34'.
  ///
  /// In en, this message translates to:
  /// **'Send {currency}{amount}'**
  String sendButtonAmount(String currency, String amount);

  /// Generic error snackbar prefix with the underlying error message.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// Title of the country picker bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Select Country'**
  String get selectCountryTitle;

  /// Search field hint in the country picker bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get searchCountryHint;

  /// Phone number text field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumberHint;

  /// Snackbar after triggering an SMS OTP send.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to your phone'**
  String get otpSentToPhone;

  /// Snackbar after a successful phone OTP verification.
  ///
  /// In en, this message translates to:
  /// **'Phone verified successfully!'**
  String get phoneVerifiedSuccessfully;

  /// Generic Verify submit button label.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// Generic Try Again button label after a failure.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainButton;

  /// App lock screen heading. Distinct from welcomeBack home subtitle (different capitalization).
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBackTitle;

  /// App lock screen subtitle when password mode is selected.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to unlock'**
  String get enterPasswordToUnlock;

  /// App lock screen subtitle when PIN mode is selected.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to unlock'**
  String get enterPinToUnlock;

  /// Password text field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPasswordHint;

  /// App lock screen unlock button.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockButton;

  /// App lock screen biometric authentication shortcut label.
  ///
  /// In en, this message translates to:
  /// **'Use Biometric'**
  String get useBiometric;

  /// AppBar title on the forgot password screen.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// Heading shown after a password reset email is sent successfully.
  ///
  /// In en, this message translates to:
  /// **'Email Sent!'**
  String get emailSentTitle;

  /// Body text after a password reset email send. Email appears on its own line.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a password reset link to:\n{email}'**
  String emailResetLinkSent(String email);

  /// Sub-instruction below the reset email confirmation.
  ///
  /// In en, this message translates to:
  /// **'Please check your email and follow the instructions to reset your password.'**
  String get checkEmailForInstructions;

  /// Tertiary action below Back to Login on forgot password screen.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive email? Try again'**
  String get didntReceiveEmailTryAgain;

  /// Display heading on the forgot password form.
  ///
  /// In en, this message translates to:
  /// **'Reset Your Password'**
  String get resetYourPasswordTitle;

  /// Body text under the heading on forgot password form.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get enterEmailForResetLink;

  /// Email text field hint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmailHint;

  /// Snackbar after successful email verification.
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully!'**
  String get emailVerifiedSuccessfully;

  /// Snackbar after triggering a verification email resend.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent!'**
  String get verificationEmailSent;

  /// Display heading on the email OTP verification screen.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyYourEmailTitle;

  /// Body text above the user's email on the OTP verification screen.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a verification link to:'**
  String get weveSentVerificationLinkTo;

  /// Status text shown while polling for email verification completion.
  ///
  /// In en, this message translates to:
  /// **'Checking automatically...'**
  String get checkingAutomatically;

  /// Section heading above resend/check-now actions on email OTP screen.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the email?'**
  String get didntReceiveTheEmail;

  /// Manual recheck button on email OTP screen.
  ///
  /// In en, this message translates to:
  /// **'Check Now'**
  String get checkNowButton;

  /// AppBar title on the phone OTP screen.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhoneTitle;

  /// Display heading on the phone OTP screen.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Phone'**
  String get verifyYourPhone;

  /// Body text above the user's phone number on the phone OTP screen.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to'**
  String get weSent6DigitCode;

  /// Validation snackbar on signup when the terms checkbox is unchecked.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Terms and Privacy Policy'**
  String get pleaseAgreeToTerms;

  /// Success snackbar after signup completes.
  ///
  /// In en, this message translates to:
  /// **'Account created! Please verify your email.'**
  String get accountCreatedVerifyEmail;

  /// Snackbar when user taps Apple sign-in button (not yet implemented).
  ///
  /// In en, this message translates to:
  /// **'Apple Sign In coming soon'**
  String get appleSignInComingSoon;

  /// Subtitle in the country picker list, e.g. '+1 • $ USD'.
  ///
  /// In en, this message translates to:
  /// **'{dialCode} • {symbol} {code}'**
  String countryDisplayFormat(String dialCode, String symbol, String code);

  /// Snackbar shown when an identity verification call fails. Used across all KYC verification screens.
  ///
  /// In en, this message translates to:
  /// **'Verification failed: {error}'**
  String verificationFailedWithError(String error);

  /// Display heading on BVN (Bank Verification Number) verification screen, Nigeria.
  ///
  /// In en, this message translates to:
  /// **'BVN Verification'**
  String get bvnVerificationTitle;

  /// Display heading on driver's license verification screen.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s License Verification'**
  String get driversLicenseVerificationTitle;

  /// Display heading on NIN (National Identification Number) verification screen, Nigeria.
  ///
  /// In en, this message translates to:
  /// **'NIN Verification'**
  String get ninVerificationTitle;

  /// Display heading on passport verification screen.
  ///
  /// In en, this message translates to:
  /// **'Passport Verification'**
  String get passportVerificationTitle;

  /// Display heading on SSNIT verification screen, Ghana.
  ///
  /// In en, this message translates to:
  /// **'SSNIT Verification'**
  String get ssnitVerificationTitle;

  /// Display heading on voter's card verification screen.
  ///
  /// In en, this message translates to:
  /// **'Voter\'s Card Verification'**
  String get votersCardVerificationTitle;

  /// Display heading on the generic national ID verification screen — countryName is dynamic.
  ///
  /// In en, this message translates to:
  /// **'{countryName} Verification'**
  String nationalIdVerificationTitleWithCountry(String countryName);

  /// AppBar title on the Uganda NIN verification screen.
  ///
  /// In en, this message translates to:
  /// **'Uganda National ID'**
  String get ugandaNationalIdAppBarTitle;

  /// Body heading on the Uganda NIN verification screen, below the AppBar.
  ///
  /// In en, this message translates to:
  /// **'National ID Verification'**
  String get ugandaNationalIdHeading;

  /// Body description on the Uganda NIN verification screen.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity using your Uganda National Identification Number (NIN) and card number.'**
  String get ugandaNationalIdDescription;

  /// Helper text under the BVN input field.
  ///
  /// In en, this message translates to:
  /// **'Your Bank Verification Number linked to your bank accounts'**
  String get bvnHelperText;

  /// Helper text under the NIN input field.
  ///
  /// In en, this message translates to:
  /// **'Your National Identification Number as shown on your NIN slip'**
  String get ninHelperText;

  /// Helper text under the SSNIT input field explaining the format.
  ///
  /// In en, this message translates to:
  /// **'Your SSNIT number: 1 letter followed by 12 digits'**
  String get ssnitHelperText;

  /// Helper text under the Uganda NIN input field explaining the format.
  ///
  /// In en, this message translates to:
  /// **'Your NIN is 14 alphanumeric characters'**
  String get ugandaNinHelperText;

  /// Helper text under the Uganda card-number input field.
  ///
  /// In en, this message translates to:
  /// **'The number printed on your physical ID card'**
  String get ugandaNinCardNumberHelperText;

  /// AppBar title on the KYC phone verification screen. Distinct from verifyPhoneTitle ('Verify Phone') used in standalone phone_otp_screen.
  ///
  /// In en, this message translates to:
  /// **'Phone Verification'**
  String get phoneVerificationAppBarTitle;

  /// Submit button label on the OTP code entry view of phone verification.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyCodeButton;

  /// Countdown caption shown while resend is locked, e.g. 'Resend code in 30s'.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {seconds}s'**
  String resendCodeIn(String seconds);

  /// Tappable resend OTP button (active after countdown).
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCodeButton;

  /// Initial send-OTP button before any code has been sent.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Code'**
  String get sendVerificationCodeButton;

  /// Title of the failure dialog on the verification pending screen.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get verificationFailedTitle;

  /// Body of the failure dialog on the verification pending screen.
  ///
  /// In en, this message translates to:
  /// **'Your identity verification did not pass. This may be due to a face mismatch or document issue. Please try again.'**
  String get verificationFailedMessage;

  /// Heading shown while waiting for KYC verification to complete.
  ///
  /// In en, this message translates to:
  /// **'Verification In Progress'**
  String get verificationInProgressTitle;

  /// Body text below the verification in-progress heading.
  ///
  /// In en, this message translates to:
  /// **'Your identity documents are being verified. This usually takes a few seconds but may take up to a few minutes.'**
  String get verificationInProgressMessage;

  /// Generic loading/wait caption.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;

  /// Reassurance message at bottom of verification pending screen.
  ///
  /// In en, this message translates to:
  /// **'You will be automatically redirected once verification is complete. Do not close the app.'**
  String get verificationDoNotCloseApp;

  /// Loading caption shown while a download is in progress. Clears Step 8 deferral #1 (receive_money_screen.dart line ~322 ternary).
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// Snackbar when device storage permission is needed but not granted.
  ///
  /// In en, this message translates to:
  /// **'Storage permission required to save QR code'**
  String get storagePermissionRequired;

  /// Success snackbar after saving QR code image to device gallery.
  ///
  /// In en, this message translates to:
  /// **'QR code saved to gallery!'**
  String get qrCodeSavedToGallery;

  /// Snackbar when saving QR code to gallery fails.
  ///
  /// In en, this message translates to:
  /// **'Error saving QR code: {error}'**
  String errorSavingQrCode(String error);

  /// Snackbar when user tries to add more than 20 items to a payment request.
  ///
  /// In en, this message translates to:
  /// **'Maximum 20 items allowed'**
  String get maximum20ItemsAllowed;

  /// Validation snackbar when amount is non-numeric or zero. Distinct from pleaseEnterAmount which fires when the field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// Snackbar when QR code generation fails on payment request screen.
  ///
  /// In en, this message translates to:
  /// **'Error generating QR: {error}'**
  String errorGeneratingQr(String error);

  /// Snackbar when QR code sharing (system share sheet) fails.
  ///
  /// In en, this message translates to:
  /// **'Error sharing QR: {error}'**
  String errorSharingQr(String error);

  /// AppBar title on the payment request screen.
  ///
  /// In en, this message translates to:
  /// **'Request Payment'**
  String get requestPaymentTitle;

  /// Tooltip on the refresh icon button that resets the payment request form.
  ///
  /// In en, this message translates to:
  /// **'New Request'**
  String get newRequestTooltip;

  /// Heading on the payment request form's create view.
  ///
  /// In en, this message translates to:
  /// **'Create Payment Request'**
  String get createPaymentRequestTitle;

  /// Body description below the create heading on payment request screen.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount and add items. Customers can scan the QR code to pay you instantly.'**
  String get createPaymentRequestDescription;

  /// Label above the amount input field on payment request screen.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// Label above the items list section, indicating items are optional.
  ///
  /// In en, this message translates to:
  /// **'Items (optional)'**
  String get itemsOptional;

  /// Placeholder text in the items input field showing example item names.
  ///
  /// In en, this message translates to:
  /// **'e.g., Jollof Rice, Chicken, Drinks'**
  String get itemsHint;

  /// Pluralized item count. Renders '1 item' for count=1 and '{count} items' otherwise.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// Submit button on the payment request form.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get generateQrCode;

  /// Recipient label on the generated QR code preview, e.g. 'Pay to: Eric'.
  ///
  /// In en, this message translates to:
  /// **'Pay to: {userName}'**
  String payToUser(String userName);

  /// Generic Share button label (used in payment request QR preview).
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareButton;

  /// Info caption below the generated QR code on payment request screen. Two lines (line break in middle).
  ///
  /// In en, this message translates to:
  /// **'Show this QR code to the customer.\nThey scan it, confirm the amount, and pay instantly!'**
  String get qrCodeInfoForCustomer;

  /// Outlined button to reset and create another payment request after a QR is generated.
  ///
  /// In en, this message translates to:
  /// **'Create New Request'**
  String get createNewRequest;

  /// Generic Download button label (used in payment request QR preview, alongside Share).
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadButton;

  /// Subject line when sharing wallet ID via system share sheet (receive_money_screen Share.share call).
  ///
  /// In en, this message translates to:
  /// **'My QR Wallet ID'**
  String get shareWalletIdSubject;

  /// Generic fallback display name shown when the authenticated user has no displayName set on their account.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get defaultUserName;

  /// Generic loading caption shown while content is being fetched (e.g. wallet ID resolving).
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingPlaceholder;

  /// Body text in system share sheet when sharing a payment request, e.g. 'Pay $5.00 to Eric'.
  ///
  /// In en, this message translates to:
  /// **'Pay {symbol}{amount} to {userName}'**
  String payRequestShareText(String symbol, String amount, String userName);

  /// Title of the dialog asking the user to approve a pending MTN MoMo payment on their phone.
  ///
  /// In en, this message translates to:
  /// **'Approve Payment'**
  String get approvePaymentTitle;

  /// Body of the MTN MoMo approval dialog showing the amount to approve.
  ///
  /// In en, this message translates to:
  /// **'Please approve the payment of {symbol}{amount} on your MTN MoMo phone.'**
  String mtnMomoApprovePromptBody(String symbol, String amount);

  /// Caption beneath the MTN MoMo approval dialog body.
  ///
  /// In en, this message translates to:
  /// **'Check your phone for the approval prompt.'**
  String get checkPhoneForApprovalPrompt;

  /// Button label confirming the user has approved the payment on their MoMo phone.
  ///
  /// In en, this message translates to:
  /// **'I\'ve Approved'**
  String get iveApproved;

  /// Snackbar shown when the user copies a value (e.g. account number) to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String labelCopiedToClipboard(String label);

  /// Title of the post-payment success dialog inside the add-money flow (no exclamation, used in dialog title).
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccessful;

  /// Hero title on the dedicated payment result screen (with celebratory exclamation).
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessfulHero;

  /// Hero title on the payment result screen when the payment failed (capitalized as a title).
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// Inline labeled amount, e.g. 'Amount: $5.00'.
  ///
  /// In en, this message translates to:
  /// **'Amount: {symbol}{amount}'**
  String amountWithCurrency(String symbol, String amount);

  /// Inline labeled transaction reference, e.g. 'Reference: ABC-123'.
  ///
  /// In en, this message translates to:
  /// **'Reference: {reference}'**
  String referenceWithValue(String reference);

  /// Generic Done button label used to dismiss a result dialog/screen.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneButton;

  /// Title shown when mobile money is not supported in the user's region (shared between add-money and withdraw).
  ///
  /// In en, this message translates to:
  /// **'Mobile Money Not Available'**
  String get mobileMoneyNotAvailableTitle;

  /// Body text for the mobile-money-unavailable empty state on the add-money screen (suggesting Card/Bank Transfer alternatives).
  ///
  /// In en, this message translates to:
  /// **'Mobile money payments are not available in your region. Please use Card or Bank Transfer.'**
  String get mobileMoneyNotAvailablePaymentsBody;

  /// Label above the amount input on the add-money screen.
  ///
  /// In en, this message translates to:
  /// **'Enter Amount'**
  String get enterAmountLabel;

  /// Label above the row of preset amount chips on the add-money screen.
  ///
  /// In en, this message translates to:
  /// **'Quick Select'**
  String get quickSelectLabel;

  /// Heading label above the Paystack security note.
  ///
  /// In en, this message translates to:
  /// **'Secure Payment'**
  String get securePaymentLabel;

  /// Reassurance caption shown below the Secure Payment heading on add-money screen.
  ///
  /// In en, this message translates to:
  /// **'Powered by Paystack. Your payment details are secure.'**
  String get paystackSecurityNote;

  /// Label above the mobile money provider dropdown (shared between add-money and withdraw).
  ///
  /// In en, this message translates to:
  /// **'Mobile Money Provider'**
  String get mobileMoneyProviderLabel;

  /// Label above the phone number input field (shared between add-money and withdraw).
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumberLabel;

  /// Caption shown while the virtual bank account details are being generated/fetched.
  ///
  /// In en, this message translates to:
  /// **'Loading account details...'**
  String get loadingAccountDetails;

  /// Title for the virtual account empty state (before account is generated).
  ///
  /// In en, this message translates to:
  /// **'Virtual Account'**
  String get virtualAccountTitle;

  /// Caption inviting the user to tap the button below to generate a virtual bank account.
  ///
  /// In en, this message translates to:
  /// **'Tap to generate your dedicated account number'**
  String get tapToGenerateAccountPrompt;

  /// Button to generate the user's virtual bank account.
  ///
  /// In en, this message translates to:
  /// **'Generate Account'**
  String get generateAccountButton;

  /// Heading on the populated virtual account card.
  ///
  /// In en, this message translates to:
  /// **'Your Virtual Account'**
  String get yourVirtualAccountLabel;

  /// Label for the bank name field on the virtual account card.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankNameLabel;

  /// Label for the account number field (shared between add-money virtual account card and withdraw screen).
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get accountNumberLabel;

  /// Label for the account holder name field (shared between add-money virtual account card and withdraw screen).
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountNameLabel;

  /// Heading above the explanatory bullet points on the virtual account screen.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get howItWorksLabel;

  /// Explanatory body text on the virtual account info card.
  ///
  /// In en, this message translates to:
  /// **'This account is unique to you. Any transfer to this account credits your wallet automatically.'**
  String get virtualAccountInfoBody;

  /// Fallback error snackbar message when an MTN MoMo payment fails and the API didn't return a specific error.
  ///
  /// In en, this message translates to:
  /// **'MTN MoMo payment failed'**
  String get mtnMomoPaymentFailedError;

  /// Fallback error snackbar when a payment fails or is rejected by the user/processor.
  ///
  /// In en, this message translates to:
  /// **'Payment failed or was rejected'**
  String get paymentFailedOrRejectedError;

  /// Generic fallback error snackbar for payment failures (lowercase 'failed' — distinct from the title-cased paymentFailed used as a hero title).
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailedError;

  /// Tab label for the card payment method on add-money screen.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get cardTabLabel;

  /// Tab label for the mobile money payment method (shared between add-money and withdraw).
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get mobileMoneyTabLabel;

  /// Tab label for the bank transfer payment method (shared between add-money and withdraw).
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransferTabLabel;

  /// Submit button label on the card payment tab (proceeds to Paystack flow).
  ///
  /// In en, this message translates to:
  /// **'Continue to Payment'**
  String get continueToPaymentButton;

  /// Submit button label on the mobile money tab.
  ///
  /// In en, this message translates to:
  /// **'Pay with Mobile Money'**
  String get payWithMobileMoneyButton;

  /// Title shown on the payment result screen while the verification request is in flight.
  ///
  /// In en, this message translates to:
  /// **'Verifying payment...'**
  String get verifyingPaymentTitle;

  /// Body caption shown beneath the verifying payment title.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we confirm your payment'**
  String get verifyingPaymentBody;

  /// Inline label 'Reference: ' (with trailing colon and space) used as a prefix before a separately-rendered reference value widget.
  ///
  /// In en, this message translates to:
  /// **'Reference: '**
  String get referenceColon;

  /// Standalone Reference label (no colon) used in the post-payment summary block.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get referenceLabel;

  /// Caption beneath the credited amount on the payment success screen.
  ///
  /// In en, this message translates to:
  /// **'has been added to your wallet'**
  String get hasBeenAddedToWallet;

  /// Label for the updated wallet balance row on the payment success screen.
  ///
  /// In en, this message translates to:
  /// **'New Balance'**
  String get newBalanceLabel;

  /// Generic error fallback shown on the payment failed screen when no specific error message is available.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrongTryAgain;

  /// Button label on the failed payment result screen (returns to previous screen).
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBackButton;

  /// Title of the dialog asking the user to enter the OTP for completing a withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtpTitle;

  /// Body of the OTP dialog showing the withdrawal amount, e.g. 'Please enter the OTP sent to your registered phone/email to complete the withdrawal of $50.00'.
  ///
  /// In en, this message translates to:
  /// **'Please enter the OTP sent to your registered phone/email to complete the withdrawal of {symbol}{amount}'**
  String enterOtpBody(String symbol, String amount);

  /// Title of the dialog asking the user to confirm withdrawal details before submitting.
  ///
  /// In en, this message translates to:
  /// **'Confirm Withdrawal'**
  String get confirmWithdrawalTitle;

  /// Warning caption inside the confirm-withdrawal dialog asking the user to double-check the entered details.
  ///
  /// In en, this message translates to:
  /// **'Please verify the details are correct'**
  String get pleaseVerifyDetailsCorrect;

  /// Generic Confirm button label (paired with Cancel inside the confirm-withdrawal dialog).
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// Success title shown after a withdrawal request is successfully submitted.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal Initiated'**
  String get withdrawalInitiatedTitle;

  /// Caption beneath the withdrawal-initiated title showing the amount being processed.
  ///
  /// In en, this message translates to:
  /// **'{symbol}{amount} is being processed'**
  String withdrawalBeingProcessed(String symbol, String amount);

  /// Compact reference line shown after a withdrawal, e.g. 'Ref: ABC-123'. Distinct from referenceWithValue which uses the full word 'Reference'.
  ///
  /// In en, this message translates to:
  /// **'Ref: {reference}'**
  String refLine(String reference);

  /// Withdraw label, used both as AppBar title and as the primary action button label on the withdraw screen.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get withdrawAction;

  /// Body text for the mobile-money-unavailable empty state on the withdraw screen. Distinct from mobileMoneyNotAvailablePaymentsBody.
  ///
  /// In en, this message translates to:
  /// **'Mobile money withdrawals are not available in your region. Please use bank transfer.'**
  String get mobileMoneyNotAvailableWithdrawalsBody;

  /// Full 'Available Balance' phrase used as a label above the user's withdrawable balance on the withdraw screen. Distinct from the existing availableBalanceLabel which is the shorter 'Available' used elsewhere.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get availableBalanceFull;

  /// Label above the amount input on the withdraw screen.
  ///
  /// In en, this message translates to:
  /// **'Amount to Withdraw'**
  String get amountToWithdrawLabel;

  /// Label above the bank selection dropdown on the withdraw screen.
  ///
  /// In en, this message translates to:
  /// **'Select Bank'**
  String get selectBankLabel;

  /// Placeholder/hint shown inside the bank selection dropdown when no bank is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a bank'**
  String get selectABankHint;

  /// Placeholder text in the account number input field.
  ///
  /// In en, this message translates to:
  /// **'Enter account number'**
  String get enterAccountNumberHint;

  /// Validation caption shown when the user has typed too few digits to trigger account verification.
  ///
  /// In en, this message translates to:
  /// **'Enter at least {count} digits to verify'**
  String enterAtLeastDigitsToVerify(int count);

  /// Success caption shown after a bank account number has been successfully verified.
  ///
  /// In en, this message translates to:
  /// **'Account Verified'**
  String get accountVerifiedLabel;

  /// Placeholder text in the account holder name input field for mobile money withdrawals.
  ///
  /// In en, this message translates to:
  /// **'Enter account holder name'**
  String get enterAccountHolderNameHint;

  /// Fallback error snackbar when the bank account verification API call fails.
  ///
  /// In en, this message translates to:
  /// **'Could not verify account'**
  String get couldNotVerifyAccountError;

  /// Fallback error snackbar when a withdrawal submission fails.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal failed'**
  String get withdrawalFailedError;

  /// Fallback error snackbar when OTP verification during a withdrawal fails.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed'**
  String get otpVerificationFailedError;

  /// AppBar title on the About screen.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// App name shown prominently on the About screen. Brand name.
  ///
  /// In en, this message translates to:
  /// **'QR Wallet'**
  String get qrWalletAppName;

  /// Version and build number display on About screen, e.g. 'Version 1.2.3 (Build 456)'.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (Build {buildNumber})'**
  String versionAndBuild(String version, String buildNumber);

  /// Marketing description paragraph on About screen describing the app.
  ///
  /// In en, this message translates to:
  /// **'QR Wallet is a secure and easy-to-use digital wallet that allows you to send, receive, and manage money with just a scan. Experience the future of payments today.'**
  String get aboutAppDescription;

  /// About screen link item that opens the Terms of Service URL.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceLink;

  /// About screen link item that opens the Privacy Policy URL.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLink;

  /// About screen link item that prompts the user to rate the app.
  ///
  /// In en, this message translates to:
  /// **'Rate Us'**
  String get rateUsLink;

  /// Snackbar shown when the user taps the Rate Us link.
  ///
  /// In en, this message translates to:
  /// **'Rate us on the App Store!'**
  String get rateUsToast;

  /// About screen link item to share the app with others.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareAppLink;

  /// Snackbar shown when the user taps Share App.
  ///
  /// In en, this message translates to:
  /// **'Share feature coming soon!'**
  String get shareComingSoonToast;

  /// Copyright footer on the About screen.
  ///
  /// In en, this message translates to:
  /// **'© 2024 QR Wallet. All rights reserved.'**
  String get copyrightLine;

  /// Pride-of-place footer on the About screen.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ in Ghana'**
  String get madeInGhanaLine;

  /// Snackbar shown when saving profile changes fails.
  ///
  /// In en, this message translates to:
  /// **'Error updating profile: {error}'**
  String errorUpdatingProfile(String error);

  /// Caption explaining why the name field is locked on the edit profile screen.
  ///
  /// In en, this message translates to:
  /// **'Name verified via KYC — cannot be changed'**
  String get nameVerifiedKycCannotChange;

  /// Button label on the edit profile screen for changing the avatar photo.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get changePhotoButton;

  /// Generic 'Block Account' label — shared across dialog title, dialog action button, and menu item label.
  ///
  /// In en, this message translates to:
  /// **'Block Account'**
  String get blockAccountLabel;

  /// Body text inside the Block Account confirmation dialog. Multi-line with bullet list.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block your account?\n\nThis will prevent all transactions including:\n• Sending money\n• Withdrawing funds\n• Adding money\n\nYou can unblock anytime with your PIN.'**
  String get blockAccountConfirmBody;

  /// Snackbar shown after the user successfully blocks their own account.
  ///
  /// In en, this message translates to:
  /// **'Account blocked successfully. All transactions are disabled.'**
  String get accountBlockedSuccessToast;

  /// Title of the modal dialog shown when the user's account has been blocked by customer support.
  ///
  /// In en, this message translates to:
  /// **'Account Blocked by Support'**
  String get accountBlockedBySupportTitle;

  /// Body of the support-blocked dialog explaining the situation.
  ///
  /// In en, this message translates to:
  /// **'Your account was blocked by customer support for security reasons.\n\nPlease contact our support team to verify your identity and unblock your account.'**
  String get accountBlockedBySupportBody;

  /// Snackbar shown after the user successfully unblocks their account.
  ///
  /// In en, this message translates to:
  /// **'Account unblocked successfully. All transactions are now enabled.'**
  String get accountUnblockedSuccessToast;

  /// Body text inside the Log Out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmBody;

  /// Section heading on the profile screen for business-account-related items.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get businessLabel;

  /// Snackbar shown when the user tries to enable biometric login but no biometrics are enrolled.
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled on this device. Please set up fingerprint or Face ID in device settings.'**
  String get noBiometricsEnrolledToast;

  /// Section heading on the profile screen for user preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// Menu item label that opens the theme/appearance settings screen.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceMenuItem;

  /// Section heading on the profile screen for account safety options.
  ///
  /// In en, this message translates to:
  /// **'Account Safety'**
  String get accountSafetySection;

  /// Section heading on the profile screen for support items.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportSection;

  /// Label for the currency selection menu item on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyLabel;

  /// Compact currency display showing both name and symbol, e.g. 'US Dollar (US$)'.
  ///
  /// In en, this message translates to:
  /// **'{name} ({symbol})'**
  String currencyNameAndSymbol(String name, String symbol);

  /// Menu item label shown when the account is currently blocked.
  ///
  /// In en, this message translates to:
  /// **'Unblock Account'**
  String get unblockAccountLabel;

  /// Compact subtitle on the block-account menu item shown when blocked by support.
  ///
  /// In en, this message translates to:
  /// **'Blocked by support — contact us to unblock'**
  String get blockedBySupportSubtitle;

  /// Subtitle on the block-account menu item shown when the user has self-blocked.
  ///
  /// In en, this message translates to:
  /// **'Your account is currently blocked'**
  String get accountBlockedSubtitle;

  /// Subtitle on the block-account menu item explaining what blocking does.
  ///
  /// In en, this message translates to:
  /// **'Temporarily disable all transactions'**
  String get temporarilyDisableSubtitle;

  /// Brief snackbar shown when notification settings are successfully saved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSavedToast;

  /// Snackbar shown when saving notification settings fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSaveError(String error);

  /// AppBar title on the notification settings screen.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettingsTitle;

  /// Section heading on the notification settings screen for general delivery channel toggles.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSection;

  /// Toggle label for enabling push notifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotificationsLabel;

  /// Subtitle below the Push Notifications toggle.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications on your device'**
  String get pushNotificationsSubtitle;

  /// Toggle label for enabling email notifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotificationsLabel;

  /// Subtitle below the Email Notifications toggle.
  ///
  /// In en, this message translates to:
  /// **'Receive updates via email'**
  String get emailNotificationsSubtitle;

  /// Section heading on the notification settings screen for transaction-related notifications.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactionsSection;

  /// Toggle label for enabling transaction alert notifications.
  ///
  /// In en, this message translates to:
  /// **'Transaction Alerts'**
  String get transactionAlertsLabel;

  /// Subtitle below the Transaction Alerts toggle.
  ///
  /// In en, this message translates to:
  /// **'Get notified for all transactions'**
  String get transactionAlertsSubtitle;

  /// Toggle label for enabling payment reminder notifications.
  ///
  /// In en, this message translates to:
  /// **'Payment Reminders'**
  String get paymentRemindersLabel;

  /// Subtitle below the Payment Reminders toggle.
  ///
  /// In en, this message translates to:
  /// **'Reminders for pending payments'**
  String get paymentRemindersSubtitle;

  /// Section heading for security alerts and promotional updates on the notification settings screen.
  ///
  /// In en, this message translates to:
  /// **'Security & Updates'**
  String get securityAndUpdatesSection;

  /// Toggle label for security alert notifications. This toggle is locked-on.
  ///
  /// In en, this message translates to:
  /// **'Security Alerts'**
  String get securityAlertsLabel;

  /// Subtitle below the Security Alerts toggle.
  ///
  /// In en, this message translates to:
  /// **'Important security notifications'**
  String get securityAlertsSubtitle;

  /// Toggle label for marketing/promotional notifications.
  ///
  /// In en, this message translates to:
  /// **'Promotional Updates'**
  String get promotionalUpdatesLabel;

  /// Subtitle below the Promotional Updates toggle.
  ///
  /// In en, this message translates to:
  /// **'Offers, news, and promotions'**
  String get promotionalUpdatesSubtitle;

  /// Info note shown beneath the security alerts toggle explaining why it can't be turned off.
  ///
  /// In en, this message translates to:
  /// **'Security alerts cannot be disabled for your protection.'**
  String get securityAlertsCannotBeDisabledNote;

  /// Section heading on the theme settings screen above the light/dark/system options.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// Theme option label for the light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightThemeLabel;

  /// Subtitle describing the Light theme option.
  ///
  /// In en, this message translates to:
  /// **'Light background with dark text'**
  String get lightThemeSubtitle;

  /// Theme option label for the dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkThemeLabel;

  /// Subtitle describing the Dark theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark background with light text'**
  String get darkThemeSubtitle;

  /// Theme option label for following the system theme.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemThemeLabel;

  /// Subtitle describing the System theme option.
  ///
  /// In en, this message translates to:
  /// **'Follow system settings'**
  String get systemThemeSubtitle;

  /// Heading above the theme preview section on the theme settings screen.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// Hero title shown on the password changed success screen.
  ///
  /// In en, this message translates to:
  /// **'Password Changed!'**
  String get passwordChangedTitle;

  /// Body text shown beneath the password changed title.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated successfully.'**
  String get passwordChangedBody;

  /// Change Password label, used both as AppBar title and as the primary action button on the change password screen.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordAction;

  /// Subtitle below the AppBar on the change password screen.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get createNewPasswordSubtitle;

  /// Floating label on the current password input field.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPasswordLabel;

  /// Placeholder text in the current password input field.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get enterCurrentPasswordHint;

  /// Floating label on the new password input field.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// Placeholder text in the new password input field.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get enterNewPasswordHint;

  /// Floating label on the confirm-new-password input field.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPasswordLabel;

  /// Placeholder text in the confirm-new-password input field.
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get reenterNewPasswordHint;

  /// Label above the password requirements checklist.
  ///
  /// In en, this message translates to:
  /// **'Password must contain:'**
  String get passwordMustContainLabel;

  /// Hero title shown on the PIN changed success screen.
  ///
  /// In en, this message translates to:
  /// **'PIN Changed!'**
  String get pinChangedTitle;

  /// Body text shown beneath the PIN changed title.
  ///
  /// In en, this message translates to:
  /// **'Your transaction PIN has been updated successfully.'**
  String get pinChangedBody;

  /// AppBar title on the change PIN screen.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePinAction;

  /// Text button on the change PIN screen that navigates to the reset PIN flow.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get forgotPinLink;

  /// Reassurance caption on the change PIN screen.
  ///
  /// In en, this message translates to:
  /// **'Your PIN is securely encrypted and used to authorize transactions.'**
  String get pinSecurityNote;

  /// Hero title shown on the PIN reset success screen.
  ///
  /// In en, this message translates to:
  /// **'PIN Reset!'**
  String get pinResetTitle;

  /// Body text shown beneath the PIN reset title.
  ///
  /// In en, this message translates to:
  /// **'Your transaction PIN has been reset successfully.'**
  String get pinResetBody;

  /// AppBar title on the reset PIN screen.
  ///
  /// In en, this message translates to:
  /// **'Reset PIN'**
  String get resetPinAction;

  /// Step title in the reset PIN flow when entering the new PIN.
  ///
  /// In en, this message translates to:
  /// **'Enter New PIN'**
  String get enterNewPinStepTitle;

  /// Subtitle below the Enter New PIN step heading.
  ///
  /// In en, this message translates to:
  /// **'Create a new 6-digit transaction PIN'**
  String get createNewPinSubtitle;

  /// Step title in the reset PIN flow when confirming the new PIN.
  ///
  /// In en, this message translates to:
  /// **'Confirm New PIN'**
  String get confirmNewPinStepTitle;

  /// Subtitle below the Confirm New PIN step heading.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your new PIN to confirm'**
  String get reenterNewPinSubtitle;

  /// Heading on the reset PIN method selection step.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Identity'**
  String get verifyYourIdentityTitle;

  /// Body text below the Verify Your Identity heading.
  ///
  /// In en, this message translates to:
  /// **'To reset your PIN, please verify your identity using one of the options below.'**
  String get resetPinVerifyIdentityBody;

  /// Method card title for verifying identity via email and password.
  ///
  /// In en, this message translates to:
  /// **'Email & Password'**
  String get emailAndPasswordMethod;

  /// Method card subtitle for the email and password verification option.
  ///
  /// In en, this message translates to:
  /// **'Verify using your login credentials'**
  String get emailAndPasswordSubtitle;

  /// Security reassurance caption on the reset PIN method selection step.
  ///
  /// In en, this message translates to:
  /// **'This verification ensures only you can reset your PIN.'**
  String get resetPinSecurityAssurance;

  /// Step title when verifying via email and password during PIN reset.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Password'**
  String get enterYourPasswordTitle;

  /// Body text below the Enter Your Password step heading.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity by entering your login credentials.'**
  String get verifyByCredentialsBody;

  /// Floating label on the email input field. Generic label that may be reused.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Floating label on the password input field. Generic label that may be reused.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Placeholder text in the password input field on the PIN reset email-verification step.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPasswordHint;

  /// Body text on the OTP entry step during PIN reset.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {phone}'**
  String enter6DigitCodePhone(String phone);

  /// Error message shown when OTP send attempts have been rate-limited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get tooManyAttemptsError;

  /// Generic fallback error when OTP send fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Please try again.'**
  String get failedToSendOtpError;

  /// Error message shown when the user enters an incorrect OTP.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Please try again.'**
  String get incorrectCodeError;

  /// Generic fallback error when OTP verification fails.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Please try again.'**
  String get verificationFailedAgainError;

  /// Method card subtitle for the phone OTP verification option.
  ///
  /// In en, this message translates to:
  /// **'Verify via OTP sent to your phone'**
  String get verifyOtpToPhoneSubtitle;

  /// Method card subtitle when no phone number is on file.
  ///
  /// In en, this message translates to:
  /// **'No phone number linked to your account'**
  String get noPhoneNumberLinkedSubtitle;

  /// Snackbar shown when the email app cannot be opened from the help screen.
  ///
  /// In en, this message translates to:
  /// **'Could not open email app. Please email us at qrwallet.support@bongroups.co'**
  String get couldNotOpenEmailToast;

  /// Snackbar shown when WhatsApp cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp. Please make sure WhatsApp is installed.'**
  String get couldNotOpenWhatsAppToast;

  /// Title of the dialog showing the WhatsApp QR code.
  ///
  /// In en, this message translates to:
  /// **'Chat on WhatsApp'**
  String get chatOnWhatsAppDialogTitle;

  /// Two-line caption inside the WhatsApp QR dialog.
  ///
  /// In en, this message translates to:
  /// **'Scan with another phone\nor tap \"Open WhatsApp\" below'**
  String get scanWithAnotherPhoneCaption;

  /// Button label inside the WhatsApp QR dialog that opens the WhatsApp app.
  ///
  /// In en, this message translates to:
  /// **'Open WhatsApp'**
  String get openWhatsAppButton;

  /// Generic Close button label.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// AppBar title on the help and support screen.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupportTitle;

  /// Section heading for contact methods (email, WhatsApp).
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUsSection;

  /// Menu item label for contacting support via email.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get emailSupportLabel;

  /// Menu item label for contacting support via WhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Support'**
  String get whatsappSupportLabel;

  /// Subtitle for the WhatsApp Support menu item.
  ///
  /// In en, this message translates to:
  /// **'Chat with us on WhatsApp'**
  String get whatsappSupportSubtitle;

  /// Section heading for the FAQ list.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faqSection;

  /// Section heading for social media follow links.
  ///
  /// In en, this message translates to:
  /// **'Follow Us'**
  String get followUsSection;

  /// Pre-filled email subject for support emails.
  ///
  /// In en, this message translates to:
  /// **'QR Wallet Support Request'**
  String get emailSupportSubject;

  /// FAQ question about adding money.
  ///
  /// In en, this message translates to:
  /// **'How do I add money to my wallet?'**
  String get faqAddMoneyQuestion;

  /// FAQ answer for adding money. Contains the Unicode arrow character.
  ///
  /// In en, this message translates to:
  /// **'You can add money via Card, Mobile Money, or Bank Transfer. Go to Home → Add Money and choose your preferred method.'**
  String get faqAddMoneyAnswer;

  /// FAQ question about sending money.
  ///
  /// In en, this message translates to:
  /// **'How do I send money to someone?'**
  String get faqSendMoneyQuestion;

  /// FAQ answer for sending money. Contains double quotes and apostrophe.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Send\" on the home screen, enter the recipient\'s wallet ID or scan their QR code, enter the amount, and confirm.'**
  String get faqSendMoneyAnswer;

  /// FAQ question about withdrawal timing.
  ///
  /// In en, this message translates to:
  /// **'How long do withdrawals take?'**
  String get faqWithdrawalTimeQuestion;

  /// FAQ answer about withdrawal timing.
  ///
  /// In en, this message translates to:
  /// **'Bank transfers typically take 1-3 business days. Mobile Money withdrawals are usually instant.'**
  String get faqWithdrawalTimeAnswer;

  /// FAQ question about security.
  ///
  /// In en, this message translates to:
  /// **'Is my money safe?'**
  String get faqMoneySafeQuestion;

  /// FAQ answer about security and encryption.
  ///
  /// In en, this message translates to:
  /// **'Yes! We use bank-level encryption and secure payment processors. Your funds are protected at all times.'**
  String get faqMoneySafeAnswer;

  /// FAQ question about changing PIN.
  ///
  /// In en, this message translates to:
  /// **'How do I change my PIN?'**
  String get faqChangePinQuestion;

  /// FAQ answer for changing PIN. Contains the Unicode arrow character.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile → Change PIN. Enter your current PIN, then create and confirm your new PIN.'**
  String get faqChangePinAnswer;

  /// FAQ question about forgotten password.
  ///
  /// In en, this message translates to:
  /// **'What if I forget my password?'**
  String get faqForgotPasswordQuestion;

  /// FAQ answer for forgotten password. Contains double quotes and apostrophe.
  ///
  /// In en, this message translates to:
  /// **'On the login screen, tap \"Forgot Password?\" and enter your email. We\'ll send you a reset link.'**
  String get faqForgotPasswordAnswer;

  /// Title of the confirmation dialog when removing a linked bank account.
  ///
  /// In en, this message translates to:
  /// **'Remove Account?'**
  String get removeAccountConfirmTitle;

  /// Body of the remove-account confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this bank account?'**
  String get removeAccountConfirmBody;

  /// Snackbar shown after a bank account is removed.
  ///
  /// In en, this message translates to:
  /// **'Account removed'**
  String get accountRemovedToast;

  /// Snackbar shown when removing a bank account fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove: {error}'**
  String failedToRemoveError(String error);

  /// AppBar title on the linked bank accounts screen.
  ///
  /// In en, this message translates to:
  /// **'Linked Bank Accounts'**
  String get linkedBankAccountsTitle;

  /// Empty-state title when no bank accounts are linked.
  ///
  /// In en, this message translates to:
  /// **'No Bank Accounts'**
  String get noBankAccountsEmptyTitle;

  /// Empty-state subtitle on the linked bank accounts screen.
  ///
  /// In en, this message translates to:
  /// **'Add a bank account to make withdrawals easier'**
  String get noBankAccountsEmptySubtitle;

  /// Action label for adding a bank account. Used in 3 places: empty-state CTA, bottom-sheet title, submit button.
  ///
  /// In en, this message translates to:
  /// **'Add Bank Account'**
  String get addBankAccountAction;

  /// Generic fallback shown when a linked bank account has no bank name on file.
  ///
  /// In en, this message translates to:
  /// **'Bank Account'**
  String get bankAccountFallback;

  /// Placeholder text in the bank name input field.
  ///
  /// In en, this message translates to:
  /// **'e.g. GCB Bank'**
  String get bankNameHint;

  /// Placeholder text in the account holder name input field.
  ///
  /// In en, this message translates to:
  /// **'Name on account'**
  String get nameOnAccountHint;

  /// Title of the upload-logo bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Upload Business Logo'**
  String get uploadBusinessLogoTitle;

  /// Caption inside the upload-logo bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'This logo will appear in your payment QR codes'**
  String get logoAppearInQrCaption;

  /// Bottom-sheet option to take a photo with the camera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhotoOption;

  /// Bottom-sheet option to pick from the gallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGalleryOption;

  /// Snackbar shown after a business logo is uploaded.
  ///
  /// In en, this message translates to:
  /// **'Business logo uploaded successfully'**
  String get businessLogoUploadedToast;

  /// Snackbar shown when business logo upload fails.
  ///
  /// In en, this message translates to:
  /// **'Error uploading logo: {error}'**
  String errorUploadingLogo(String error);

  /// Title of the remove-logo confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove Logo'**
  String get removeLogoTitle;

  /// Body of the remove-logo confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove your business logo?'**
  String get removeLogoConfirmBody;

  /// Generic Remove button label. Shared between linked accounts and business logo dialogs/cards.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// Snackbar shown after a business logo is removed.
  ///
  /// In en, this message translates to:
  /// **'Business logo removed'**
  String get businessLogoRemovedToast;

  /// Snackbar shown when business logo removal fails.
  ///
  /// In en, this message translates to:
  /// **'Error removing logo: {error}'**
  String errorRemovingLogo(String error);

  /// Label on the business logo card.
  ///
  /// In en, this message translates to:
  /// **'Business Logo'**
  String get businessLogoLabel;

  /// Caption on the business logo card. Distinct from logoAppearInQrCaption.
  ///
  /// In en, this message translates to:
  /// **'This logo will be embedded in your payment QR codes'**
  String get logoEmbeddedInQrCaption;

  /// Business logo card subtitle when a logo is uploaded.
  ///
  /// In en, this message translates to:
  /// **'Logo uploaded'**
  String get logoUploadedSubtitle;

  /// Business logo card subtitle when no logo exists yet.
  ///
  /// In en, this message translates to:
  /// **'Add your business logo'**
  String get addBusinessLogoSubtitle;

  /// Button label on business logo card when a logo exists (paired with uploadButton).
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeButton;

  /// Button label on business logo card when no logo exists (paired with changeButton).
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get uploadButton;

  /// Empty-state message on the dispute detail screen when the requested dispute cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Dispute not found'**
  String get disputeNotFoundError;

  /// Section label above the dispute description text on the dispute detail screen.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// Section label above the recipient's response text on the dispute detail screen (shown only when a response exists).
  ///
  /// In en, this message translates to:
  /// **'Recipient Response'**
  String get recipientResponseLabel;

  /// AppBar title on the my-disputes screen.
  ///
  /// In en, this message translates to:
  /// **'My Disputes'**
  String get myDisputesTitle;

  /// Outer tab label on the my-disputes screen showing disputes the user filed.
  ///
  /// In en, this message translates to:
  /// **'Filed by Me'**
  String get filedByMeTab;

  /// Outer tab label on the my-disputes screen showing disputes filed against the user.
  ///
  /// In en, this message translates to:
  /// **'Against Me'**
  String get againstMeTab;

  /// Empty-state message in the Filed by Me / Active subtab when the user has filed no active disputes.
  ///
  /// In en, this message translates to:
  /// **'No active disputes filed.'**
  String get noActiveDisputesFiled;

  /// Empty-state message in the Against Me / Active subtab.
  ///
  /// In en, this message translates to:
  /// **'No active disputes against you.'**
  String get noActiveDisputesAgainstYou;

  /// Empty-state message in the Resolved subtab. Shared between Filed by Me and Against Me outer tabs.
  ///
  /// In en, this message translates to:
  /// **'No resolved disputes.'**
  String get noResolvedDisputes;

  /// Inner tab label showing the number of active disputes.
  ///
  /// In en, this message translates to:
  /// **'Active ({count})'**
  String activeTabWithCount(int count);

  /// Inner tab label showing the number of resolved disputes.
  ///
  /// In en, this message translates to:
  /// **'Resolved ({count})'**
  String resolvedTabWithCount(int count);

  /// Informational banner shown when the dispute list has hit the 50-row cap.
  ///
  /// In en, this message translates to:
  /// **'Showing latest 50 disputes. Older entries may not appear.'**
  String get disputesCappedNotice;

  /// Description shown on the KYC ID-type selection screen for Uganda NIN. Returned by _getDescriptionForIdType switch case 'UGANDA_NIN'.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with your Uganda National Identification Number'**
  String get ugandaNinDescription;

  /// Description shown on the KYC ID-type selection screen for Zambian Taxpayer PIN. Returned by _getDescriptionForIdType switch case 'TPIN'.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity with your Zambian Taxpayer PIN'**
  String get tpinDescription;

  /// Default description shown on the KYC ID-type selection screen when the ID type is not recognized. Returned by _getDescriptionForIdType switch default.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get verifyIdentityDefaultDescription;

  /// User-visible name for the Zambian Taxpayer PIN document, returned by _countryName for ZM.
  ///
  /// In en, this message translates to:
  /// **'Taxpayer PIN (TPIN)'**
  String get taxpayerPinLabel;

  /// Generic fallback shown when ID number validation fails and the validation result has no specific error message.
  ///
  /// In en, this message translates to:
  /// **'Invalid ID number'**
  String get invalidIdNumberFallback;

  /// Form field label for the Zambian TPIN input (when countryCode == 'ZM').
  ///
  /// In en, this message translates to:
  /// **'TPIN'**
  String get tpinLabel;

  /// Form field label for the ID number input (when countryCode != 'ZM').
  ///
  /// In en, this message translates to:
  /// **'ID Number'**
  String get idNumberLabel;

  /// Form field hint for the Zambian TPIN input.
  ///
  /// In en, this message translates to:
  /// **'Enter your 10-digit TPIN'**
  String get enterTpinHint;

  /// Form field hint for the South African ID number input.
  ///
  /// In en, this message translates to:
  /// **'Enter your 13-digit ID number'**
  String get enterIdNumberHint;

  /// Helper text below the TPIN input field for Zambian users.
  ///
  /// In en, this message translates to:
  /// **'Your Zambian Taxpayer Identification Number'**
  String get zambianTaxpayerHelperText;

  /// Helper text below the ID number input field for South African users.
  ///
  /// In en, this message translates to:
  /// **'Your South African ID number'**
  String get southAfricanIdHelperText;

  /// Title shown on the KYC verification card after the user has captured their ID document.
  ///
  /// In en, this message translates to:
  /// **'Document Captured'**
  String get documentCapturedTitle;

  /// Title shown on the KYC verification card before document capture. {documentType} is the localized country-specific document name.
  ///
  /// In en, this message translates to:
  /// **'Verify Your {documentType}'**
  String verifyYourDocumentTitle(String documentType);

  /// Body text shown on the KYC verification card after document capture, telling the user verification is about to start.
  ///
  /// In en, this message translates to:
  /// **'Your {documentType} has been captured. Verification will begin when you continue.'**
  String documentCapturedBody(String documentType);

  /// Body text shown on the KYC verification card before capture, when verification mode is photo-only (ID number entry + selfie). Used when _isPhotoCapture is true.
  ///
  /// In en, this message translates to:
  /// **'We will verify your ID number and take a selfie for confirmation'**
  String get idAndSelfieVerificationDescription;

  /// Body text shown on the KYC verification card before capture, when verification mode is full document capture. Used when _isPhotoCapture is false.
  ///
  /// In en, this message translates to:
  /// **'We will capture both sides of your ID and take a selfie'**
  String get documentBothSidesAndSelfieDescription;

  /// Validation error shown when the user enters a NIN that is not exactly 11 digits.
  ///
  /// In en, this message translates to:
  /// **'NIN must be exactly 11 digits'**
  String get ninLengthError;

  /// Validation error shown when the user enters a BVN that is not exactly 11 digits.
  ///
  /// In en, this message translates to:
  /// **'BVN must be exactly 11 digits'**
  String get bvnLengthError;

  /// Validation error shown when the user's SSNIT does not match the format: one letter followed by twelve digits.
  ///
  /// In en, this message translates to:
  /// **'SSNIT must be 1 letter followed by 12 digits'**
  String get ssnitFormatError;

  /// Validation error shown when the user's South African National ID is not exactly 13 digits.
  ///
  /// In en, this message translates to:
  /// **'South African ID must be exactly 13 digits'**
  String get southAfricanIdLengthError;

  /// Validation error shown when the user's Uganda NIN does not match the expected 14 alphanumeric characters.
  ///
  /// In en, this message translates to:
  /// **'Uganda NIN must be exactly 14 alphanumeric characters'**
  String get ugandaNinFormatError;

  /// Validation error shown when the user's Zambian TPIN is not exactly 10 digits.
  ///
  /// In en, this message translates to:
  /// **'TPIN must be exactly 10 digits'**
  String get tpinLengthError;

  /// User-facing error shown when the app cannot parse the verification result returned by the Smile ID widget. Technical detail is logged separately.
  ///
  /// In en, this message translates to:
  /// **'Could not read verification result. Please try again.'**
  String get smileIdParseError;

  /// Label for the 'Voter's ID' option in the KYC ID-type picker dropdown.
  ///
  /// In en, this message translates to:
  /// **'Voter\'s ID'**
  String get votersIdLabel;

  /// Label for the 'International Passport' option in the KYC ID-type picker dropdown.
  ///
  /// In en, this message translates to:
  /// **'International Passport'**
  String get internationalPassportLabel;

  /// Label for the 'Alien ID' option in the KYC ID-type picker dropdown (Kenya only).
  ///
  /// In en, this message translates to:
  /// **'Alien ID'**
  String get alienIdLabel;

  /// Label for the long-form NIN option in the KYC ID-type picker dropdown (Nigeria; pending SmileID entitlement activation).
  ///
  /// In en, this message translates to:
  /// **'National Identification Number (NIN)'**
  String get ninFullLabel;

  /// Label for the long-form BVN option in the KYC ID-type picker dropdown (Nigeria; pending SmileID entitlement activation).
  ///
  /// In en, this message translates to:
  /// **'Bank Verification Number (BVN)'**
  String get bvnFullLabel;

  /// Label for the SSNIT option in the KYC ID-type picker dropdown (Ghana; pending SmileID entitlement activation).
  ///
  /// In en, this message translates to:
  /// **'SSNIT'**
  String get ssnitLabel;

  /// Label for the Uganda National ID option in the KYC ID-type picker dropdown (pending SmileID entitlement activation).
  ///
  /// In en, this message translates to:
  /// **'National ID (NIN)'**
  String get ugandaNationalIdLabel;

  /// Label for the long-form Zambian TPIN option in the KYC ID-type picker dropdown (pending SmileID entitlement activation).
  ///
  /// In en, this message translates to:
  /// **'Taxpayer PIN (TPIN)'**
  String get tpinFullLabel;

  /// Shown when a user tries to use Mobile Money but the service is not yet configured.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money is coming soon! This feature is not yet available. Please use Card or Bank Transfer instead.'**
  String get momoErrorNotConfigured;

  /// Shown when a Mobile Money payment is rejected or declined by the provider.
  ///
  /// In en, this message translates to:
  /// **'Payment was declined. Please check your Mobile Money balance and try again.'**
  String get momoErrorPaymentDeclined;

  /// Shown when the user's Mobile Money account does not have enough balance for the transaction.
  ///
  /// In en, this message translates to:
  /// **'Insufficient funds in your Mobile Money account.'**
  String get momoErrorInsufficientFunds;

  /// Shown when the phone number provided for Mobile Money is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number. Please check and try again.'**
  String get momoErrorInvalidPhone;

  /// Shown when a Mobile Money payment request times out before user approval.
  ///
  /// In en, this message translates to:
  /// **'Payment request timed out. Please check your phone for approval prompt and try again.'**
  String get momoErrorPaymentTimeout;

  /// Shown when a network error prevents an operation from completing.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Please check your internet connection and try again.'**
  String get genericErrorNetwork;

  /// Shown when camera permission is denied during a verification flow.
  ///
  /// In en, this message translates to:
  /// **'Camera access is required for verification. Please enable camera permissions in your device settings.'**
  String get genericErrorCameraPermission;

  /// Shown when the user cancels a verification flow.
  ///
  /// In en, this message translates to:
  /// **'Verification was cancelled. You can try again when ready.'**
  String get genericErrorUserCancelled;

  /// Shown when the camera cannot detect the user's face during verification.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t detect your face clearly. Please ensure good lighting and position your face within the frame.'**
  String get genericErrorFaceDetection;

  /// Shown when the user's selfie does not match the photo on their ID document.
  ///
  /// In en, this message translates to:
  /// **'Face verification failed. The selfie doesn\'t match the ID photo. Please ensure you\'re using your own ID document.'**
  String get genericErrorFaceMismatch;

  /// Shown when ID verification fails for unknown reasons.
  ///
  /// In en, this message translates to:
  /// **'ID verification failed. Please ensure your ID is valid, not expired, and the information entered is correct.'**
  String get genericErrorIdVerification;

  /// Shown when an uploaded document cannot be read by the verification system.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read your document clearly. Please ensure the document is well-lit, flat, and all text is visible.'**
  String get genericErrorDocument;

  /// Shown when the verification backend returns a server error.
  ///
  /// In en, this message translates to:
  /// **'Our verification service is temporarily unavailable. Please try again in a few minutes.'**
  String get genericErrorServer;

  /// Shown when a request times out.
  ///
  /// In en, this message translates to:
  /// **'The request took too long. Please check your connection and try again.'**
  String get genericErrorTimeout;

  /// Shown when the user's authentication session has expired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again to continue.'**
  String get genericErrorAuth;

  /// Generic last-resort error message when no more specific classification applies.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again or contact support if the problem persists.'**
  String get genericErrorFallback;

  /// Shown when a Smile ID verification completes successfully (result code 0810).
  ///
  /// In en, this message translates to:
  /// **'Verification successful!'**
  String get smileIdResultVerified;

  /// Smile ID result code 0811 — selfie/ID photo mismatch.
  ///
  /// In en, this message translates to:
  /// **'Face verification failed. The selfie doesn\'t match the ID photo.'**
  String get smileIdResultFaceMatchFailed;

  /// Smile ID result code 0812 — ID document failed verification.
  ///
  /// In en, this message translates to:
  /// **'ID document could not be verified. Please try with a different document.'**
  String get smileIdResultIdDocFailed;

  /// Smile ID result code 0813 — liveness check failed.
  ///
  /// In en, this message translates to:
  /// **'Liveness check failed. Please follow the on-screen instructions carefully.'**
  String get smileIdResultLivenessFailed;

  /// Smile ID result code 0814 — document is expired.
  ///
  /// In en, this message translates to:
  /// **'Document is expired. Please use a valid, non-expired ID.'**
  String get smileIdResultExpiredDoc;

  /// Smile ID result code 0815 — information on ID does not match what user entered.
  ///
  /// In en, this message translates to:
  /// **'ID information mismatch. Please ensure you entered the correct details.'**
  String get smileIdResultInfoMismatch;

  /// Smile ID result code 0816 — document type not supported.
  ///
  /// In en, this message translates to:
  /// **'Document not supported. Please try with a different ID type.'**
  String get smileIdResultUnsupportedDoc;

  /// Smile ID result code 0820 — no face detected in selfie.
  ///
  /// In en, this message translates to:
  /// **'Face not detected. Please ensure your face is clearly visible and well-lit.'**
  String get smileIdResultFaceNotDetected;

  /// Smile ID result code 0821 — more than one face in selfie.
  ///
  /// In en, this message translates to:
  /// **'Multiple faces detected. Please ensure only your face is in the frame.'**
  String get smileIdResultMultipleFacesDetected;

  /// Smile ID result code 0822 — image quality too low for verification.
  ///
  /// In en, this message translates to:
  /// **'Poor image quality. Please ensure good lighting and a clear photo.'**
  String get smileIdResultPoorImageQuality;

  /// Smile ID fallback when result code is unknown or no error info available.
  ///
  /// In en, this message translates to:
  /// **'Verification could not be completed. Please try again.'**
  String get smileIdResultCouldNotComplete;

  /// Shown when document upload fails due to a network issue.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload document. Please check your connection and try again.'**
  String get kycErrorDocumentUploadNetwork;

  /// Shown when an uploaded document image is too large.
  ///
  /// In en, this message translates to:
  /// **'Image file is too large. Please use a smaller image.'**
  String get kycErrorImageTooLarge;

  /// Generic fallback when document upload fails for unspecified reason.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload document. Please try again.'**
  String get kycErrorDocumentUploadGeneric;

  /// Firebase auth error: network request failed.
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Please check your internet connection.'**
  String get firebaseAuthErrorNetwork;

  /// Firebase auth error: too many requests, throttled.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a few minutes and try again.'**
  String get firebaseAuthErrorTooManyRequests;

  /// Firebase auth error: account does not exist.
  ///
  /// In en, this message translates to:
  /// **'Account not found. Please check your credentials or sign up.'**
  String get firebaseAuthErrorUserNotFound;

  /// Firebase auth error: wrong password supplied.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get firebaseAuthErrorWrongPassword;

  /// Firebase auth error: email already used by another account.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Please sign in instead.'**
  String get firebaseAuthErrorEmailAlreadyInUse;

  /// Firebase auth error: email format invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get firebaseAuthErrorInvalidEmail;

  /// Firebase auth error: password does not meet strength requirement.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Please use at least 6 characters.'**
  String get firebaseAuthErrorWeakPassword;

  /// Firebase auth error: phone number invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number.'**
  String get firebaseAuthErrorInvalidPhone;

  /// Firebase auth error: SMS or email verification code is invalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code. Please check and try again.'**
  String get firebaseAuthErrorInvalidVerificationCode;

  /// Firebase auth error: backend service unavailable.
  ///
  /// In en, this message translates to:
  /// **'Service temporarily unavailable. Please try again later.'**
  String get firebaseAuthErrorServiceUnavailable;

  /// Firebase auth error: operation not allowed for current user.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to perform this action.'**
  String get firebaseAuthErrorOperationNotAllowed;

  /// Firebase auth fallback when no more specific code applies.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get firebaseAuthErrorFallback;

  /// Shown when account creation fails after Firebase auth succeeds (e.g. Firestore write fails).
  ///
  /// In en, this message translates to:
  /// **'Failed to create user'**
  String get authErrorFailedToCreateUser;

  /// Shown when sign-in completes without throwing but returns a null user.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in'**
  String get authErrorFailedToSignIn;

  /// Shown when Firebase auth succeeds but the user's Firestore document is missing.
  ///
  /// In en, this message translates to:
  /// **'User data not found'**
  String get authErrorUserDataNotFound;

  /// Shown when the user cancels the Google sign-in flow.
  ///
  /// In en, this message translates to:
  /// **'Google sign in cancelled'**
  String get authErrorGoogleSignInCancelled;

  /// Shown when Google sign-in fails for an unspecified reason.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in with Google'**
  String get authErrorFailedToSignInWithGoogle;

  /// Shown when Apple sign-in fails for an unspecified reason.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in with Apple'**
  String get authErrorFailedToSignInWithApple;

  /// Shown when the user cancels the Apple sign-in flow.
  ///
  /// In en, this message translates to:
  /// **'Apple sign in cancelled'**
  String get authErrorAppleSignInCancelled;

  /// Shown when Apple sign-in throws a SignInWithAppleException. Technical detail is logged separately.
  ///
  /// In en, this message translates to:
  /// **'Apple sign in failed'**
  String get authErrorAppleSignInFailed;

  /// Shown when OTP verification completes without throwing but returns a null user.
  ///
  /// In en, this message translates to:
  /// **'Failed to verify OTP'**
  String get authErrorFailedToVerifyOtp;

  /// Shown when an authenticated user's Firestore document cannot be found during a post-auth lookup.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get authErrorUserNotFound;

  /// Shown when an operation requires a logged-in user but no current user is found.
  ///
  /// In en, this message translates to:
  /// **'No user logged in'**
  String get authErrorNoUserLoggedIn;

  /// Shown when phone OTP verification is attempted without a stored verification ID.
  ///
  /// In en, this message translates to:
  /// **'No verification ID. Please request OTP again.'**
  String get authErrorNoVerificationId;

  /// Firebase auth code 'user-not-found': no account exists for the given email.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email'**
  String get authErrorFirebaseAccountNotFound;

  /// Firebase auth code 'wrong-password': supplied password is incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get authErrorFirebaseWrongPassword;

  /// Firebase auth code 'email-already-in-use': email already registered.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email'**
  String get authErrorFirebaseEmailAlreadyInUse;

  /// Firebase auth code 'invalid-email': email format invalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get authErrorFirebaseInvalidEmail;

  /// Firebase auth code 'weak-password': password too short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authErrorFirebaseWeakPassword;

  /// Firebase auth code 'too-many-requests': throttled.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later'**
  String get authErrorFirebaseTooManyRequests;

  /// Firebase auth code 'invalid-verification-code': OTP code rejected.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP code. Please try again'**
  String get authErrorFirebaseInvalidVerificationCode;

  /// Firebase auth code 'invalid-verification-id': verification session expired.
  ///
  /// In en, this message translates to:
  /// **'Verification session expired. Please request a new code'**
  String get authErrorFirebaseInvalidVerificationId;

  /// Firebase auth code 'credential-already-in-use': phone number already linked elsewhere.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already linked to another account'**
  String get authErrorFirebaseCredentialAlreadyInUse;

  /// Firebase auth code 'network-request-failed': network unreachable.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection'**
  String get authErrorFirebaseNetworkRequestFailed;

  /// Generic auth fallback when no specific Firebase code or service-layer case applies.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again'**
  String get authErrorFallback;

  /// Shown when an action requires authentication but the user is not signed in.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get userErrorUserNotAuthenticated;

  /// Shown when an updateProfile call is made with no fields to update.
  ///
  /// In en, this message translates to:
  /// **'No updates provided'**
  String get userErrorNoUpdatesProvided;

  /// Shown when KYC document upload is missing the required ID front image.
  ///
  /// In en, this message translates to:
  /// **'ID front image is required'**
  String get userErrorIdFrontImageRequired;

  /// Generic UserResult fallback when no specific case applies.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the action. Please try again.'**
  String get userErrorFallback;

  /// Shown across KYC screens when the Smile ID flow has not been completed yet.
  ///
  /// In en, this message translates to:
  /// **'Please complete verification with Smile ID'**
  String get kycErrorPleaseCompleteSmileId;

  /// Shown across KYC screens when the user attempts to submit without selecting a DOB.
  ///
  /// In en, this message translates to:
  /// **'Please select your date of birth'**
  String get kycErrorPleaseSelectDateOfBirth;

  /// Shown specifically in the NIN flow when the user tries to take the selfie before entering their DOB.
  ///
  /// In en, this message translates to:
  /// **'Please select your date of birth before taking the selfie'**
  String get kycErrorPleaseSelectDateOfBirthBeforeSelfie;

  /// Shown specifically in the Uganda NIN flow when the user attempts to submit without entering a card number.
  ///
  /// In en, this message translates to:
  /// **'Please enter your card number'**
  String get kycErrorPleaseEnterCardNumber;

  /// Shown specifically in the NIN flow when the auth session is missing.
  ///
  /// In en, this message translates to:
  /// **'You are not signed in. Please sign in and try again.'**
  String get kycErrorNotSignedIn;

  /// Shown specifically in the NIN flow when the verification session has timed out.
  ///
  /// In en, this message translates to:
  /// **'Verification session expired. Please retake your selfie.'**
  String get kycErrorVerificationSessionExpired;

  /// Generic NIN-flow fallback when verification fails for an unspecified reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get kycErrorSomethingWentWrong;

  /// Shown in the phone verification flow when the user's account has no phone number on file.
  ///
  /// In en, this message translates to:
  /// **'No phone number found on your account. Please go back and re-enter it.'**
  String get kycErrorPhoneVerificationNoPhoneNumber;

  /// Shown in the phone verification flow when the user submits without entering the OTP.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code'**
  String get kycErrorPhoneVerificationEnter6DigitCode;

  /// Shown when a transaction is attempted but the user is not signed in.
  ///
  /// In en, this message translates to:
  /// **'User not authenticated'**
  String get transactionErrorUserNotAuthenticated;

  /// Shown when sendMoney's Cloud Function returns an 'unauthenticated' error code.
  ///
  /// In en, this message translates to:
  /// **'Please log in to send money'**
  String get transactionErrorPleaseLogInToSendMoney;

  /// Shown when sendMoney's Cloud Function returns a 'not-found' error code.
  ///
  /// In en, this message translates to:
  /// **'Recipient wallet not found'**
  String get transactionErrorRecipientWalletNotFound;

  /// Shown when sendMoney's Cloud Function returns a 'failed-precondition' error code, indicating not enough wallet balance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get transactionErrorInsufficientBalance;

  /// Shown when sendMoney's Cloud Function returns an 'invalid-argument' error code without a more specific server message.
  ///
  /// In en, this message translates to:
  /// **'Invalid request'**
  String get transactionErrorInvalidRequest;

  /// Generic transaction-failure message - used when the server returns no specific error or the error code is not specifically classified.
  ///
  /// In en, this message translates to:
  /// **'Transaction failed'**
  String get transactionErrorTransactionFailed;

  /// Shown when addMoney detects that the payment has already been credited (idempotency check).
  ///
  /// In en, this message translates to:
  /// **'Payment already processed'**
  String get transactionErrorPaymentAlreadyProcessed;

  /// Shown when addMoney's verification step fails or returns no specific error message.
  ///
  /// In en, this message translates to:
  /// **'Payment verification failed'**
  String get transactionErrorPaymentVerificationFailed;

  /// Shown when addMoney throws a generic exception. Technical detail is logged separately via debugPrint.
  ///
  /// In en, this message translates to:
  /// **'Deposit failed'**
  String get transactionErrorDepositFailed;

  /// Generic TransactionResult fallback when no specific case applies.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t complete the transaction. Please try again.'**
  String get transactionErrorFallback;

  /// Biometric authentication unavailable on this device (PlatformException 'NotAvailable').
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available'**
  String get biometricErrorNotAvailable;

  /// No biometrics enrolled (PlatformException 'NotEnrolled').
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled. Please set up fingerprint or face in device settings'**
  String get biometricErrorNotEnrolled;

  /// Biometric locked out due to repeated failures (PlatformException 'LockedOut').
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again later'**
  String get biometricErrorLockedOut;

  /// Biometric permanently locked (PlatformException 'PermanentlyLockedOut').
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is locked. Please unlock your device first'**
  String get biometricErrorPermanentlyLockedOut;

  /// Device passcode not set (PlatformException 'PasscodeNotSet').
  ///
  /// In en, this message translates to:
  /// **'Please set up a device passcode to use biometric authentication'**
  String get biometricErrorPasscodeNotSet;

  /// OS does not support biometric (PlatformException 'OtherOperatingSystem').
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not supported on this device'**
  String get biometricErrorOtherOperatingSystem;

  /// Generic biometric authentication failure - also default for unknown PlatformException codes.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get biometricErrorAuthenticationFailed;

  /// Shown when canCheckBiometrics returns false (early-return path before authenticate()).
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication not supported'**
  String get biometricErrorNotSupported;

  /// Shown when getAvailableBiometrics returns empty (different code path from PlatformException NotEnrolled).
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled on this device'**
  String get biometricErrorNoBiometricsEnrolled;

  /// Generic BiometricResult fallback when no specific case applies.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t authenticate. Please try again.'**
  String get biometricErrorFallback;

  /// Reason text shown in OS biometric prompt during app login.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to access your QR Wallet'**
  String get biometricReasonAuthenticate;

  /// Reason text shown in OS biometric prompt when changing security settings.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to change security settings'**
  String get biometricReasonChangeSecurity;

  /// Wallet lookup throttled (Cloud Functions resource-exhausted).
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get walletErrorTooManyRequests;

  /// Wallet lookup failed for reasons other than throttling. Technical detail logged via debugPrint.
  ///
  /// In en, this message translates to:
  /// **'Failed to look up wallet'**
  String get walletErrorFailedToLookupWallet;

  /// Transaction fetch failed. Technical detail logged via debugPrint.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch transaction'**
  String get walletErrorFailedToFetchTransaction;

  /// Generic WalletException fallback when no specific case applies.
  ///
  /// In en, this message translates to:
  /// **'Wallet operation failed. Please try again.'**
  String get walletErrorFallback;

  /// Exchange rate request for an unrecognized currency.
  ///
  /// In en, this message translates to:
  /// **'Unsupported currency'**
  String get exchangeRateErrorUnsupportedCurrency;

  /// Shown when add_money_screen detects no current user.
  ///
  /// In en, this message translates to:
  /// **'User not found. Please log in again.'**
  String get walletUiErrorUserNotFound;

  /// Validation message shown in add_money/withdraw screens.
  ///
  /// In en, this message translates to:
  /// **'Please select a mobile money provider'**
  String get walletUiErrorPleaseSelectMomoProvider;

  /// Shown when momo polling times out without resolution.
  ///
  /// In en, this message translates to:
  /// **'Payment still pending. Please check your phone and try again.'**
  String get walletUiErrorPaymentStillPending;

  /// Validation message shown in withdraw screen.
  ///
  /// In en, this message translates to:
  /// **'Please select a bank'**
  String get walletUiErrorPleaseSelectBank;

  /// Withdraw flow validation: account verification step required.
  ///
  /// In en, this message translates to:
  /// **'Please verify your account first'**
  String get walletUiErrorPleaseVerifyAccount;

  /// Validation message shown in withdraw screen.
  ///
  /// In en, this message translates to:
  /// **'Please enter account name'**
  String get walletUiErrorPleaseEnterAccountName;

  /// Shown when a withdrawal fails after balance was deducted; the refund is automatic.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal failed. Your balance has been refunded.'**
  String get walletUiErrorWithdrawalFailedRefunded;

  /// OTP input validation in withdraw flow.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 6-digit OTP'**
  String get walletUiErrorPleaseEnter6DigitOtp;

  /// Shown when scan_qr fails to verify the recipient wallet.
  ///
  /// In en, this message translates to:
  /// **'Could not verify recipient wallet'**
  String get sendUiErrorCouldNotVerifyRecipientWallet;

  /// Shown when QR scanning fails.
  ///
  /// In en, this message translates to:
  /// **'Could not read QR code'**
  String get sendUiErrorCouldNotReadQrCode;

  /// Shown when send-preview fetch exceeds its timeout in confirm_send_screen.
  ///
  /// In en, this message translates to:
  /// **'Preview timed out'**
  String get sendUiErrorPreviewTimedOut;

  /// Shown when sendMoney exceeds its 30-second timeout in confirm_send_screen.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Please check your connection and try again.'**
  String get sendUiErrorRequestTimedOut;

  /// Reason text shown in OS biometric prompt when confirming a payment.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment of {currencySymbol}{amount} to {recipient}'**
  String biometricReasonConfirmPayment(
      String currencySymbol, String amount, String recipient);

  /// Withdraw flow validation: account number too short.
  ///
  /// In en, this message translates to:
  /// **'Account number must be at least {minDigits} digits'**
  String walletUiErrorAccountNumberTooShort(int minDigits);

  /// Exchange rate conversion involves at least one unrecognized currency.
  ///
  /// In en, this message translates to:
  /// **'Unsupported currency: {from} or {to}'**
  String exchangeRateErrorUnsupportedCurrencyPair(String from, String to);

  /// AppBar title on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get fileDisputeTitle;

  /// Body label showing the ID of the transaction being disputed.
  ///
  /// In en, this message translates to:
  /// **'Transaction: {transactionId}'**
  String fileDisputeTransactionLabel(String transactionId);

  /// Body label showing the recipient of the transaction being disputed.
  ///
  /// In en, this message translates to:
  /// **'To: {recipientName}'**
  String fileDisputeRecipientLabel(String recipientName);

  /// Section label above the issue-type dropdown on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Issue Type'**
  String get fileDisputeIssueTypeLabel;

  /// Dropdown option for issue type 'money_sent_not_received' on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Money sent but not received'**
  String get fileDisputeIssueTypeMoneySentNotReceived;

  /// Dropdown option for issue type 'service_not_delivered' on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Service not delivered'**
  String get fileDisputeIssueTypeServiceNotDelivered;

  /// Dropdown option for issue type 'item_not_delivered' on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Item not delivered'**
  String get fileDisputeIssueTypeItemNotDelivered;

  /// Dropdown option for issue type 'other' on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fileDisputeIssueTypeOther;

  /// Section label above the amount field on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Amount in Dispute ({currency})'**
  String fileDisputeAmountLabel(String currency);

  /// Hint text inside the amount field showing the maximum allowable dispute amount.
  ///
  /// In en, this message translates to:
  /// **'Max: {maxAmount}'**
  String fileDisputeAmountHint(String maxAmount);

  /// Section label above the description text area on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fileDisputeDescriptionLabel;

  /// Hint text inside the description text area on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Describe what happened (min 10 characters)...'**
  String get fileDisputeDescriptionHint;

  /// Checkbox label confirming the user accepts the dispute filing fee.
  ///
  /// In en, this message translates to:
  /// **'I understand a dispute fee will be charged. It will be refunded if the dispute is upheld.'**
  String get fileDisputeFeeAcknowledgement;

  /// Submit button label on the file-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Submit Dispute'**
  String get fileDisputeSubmitButton;

  /// Validation error shown when the description is shorter than 10 characters.
  ///
  /// In en, this message translates to:
  /// **'Description must be at least 10 characters.'**
  String get fileDisputeErrorDescriptionTooShort;

  /// Validation error shown when the dispute amount is not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount.'**
  String get fileDisputeErrorInvalidAmount;

  /// Validation error shown when the dispute amount exceeds the original transaction amount.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot exceed {maxAmount}.'**
  String fileDisputeErrorAmountExceedsMax(String maxAmount);

  /// Validation error shown when the user has not checked the dispute fee acknowledgement.
  ///
  /// In en, this message translates to:
  /// **'Please acknowledge the dispute fee.'**
  String get fileDisputeErrorFeeNotAcknowledged;

  /// SnackBar shown after a dispute is successfully filed, showing the generated dispute ID.
  ///
  /// In en, this message translates to:
  /// **'Dispute filed: {disputeId}'**
  String fileDisputeSuccessSnackbar(String disputeId);

  /// AppBar title on the respond-to-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Respond to Dispute'**
  String get respondToDisputeTitle;

  /// Body label showing the ID of the dispute being responded to.
  ///
  /// In en, this message translates to:
  /// **'Dispute: {disputeId}'**
  String respondToDisputeIdLabel(String disputeId);

  /// Section label above the response text area on the respond-to-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Your Response'**
  String get respondToDisputeResponseLabel;

  /// Hint text inside the response text area on the respond-to-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Explain your side of the story (min 10 characters)...'**
  String get respondToDisputeResponseHint;

  /// Submit button label on the respond-to-dispute screen.
  ///
  /// In en, this message translates to:
  /// **'Submit Response'**
  String get respondToDisputeSubmitButton;

  /// Validation error shown when the response is shorter than 10 characters.
  ///
  /// In en, this message translates to:
  /// **'Response must be at least 10 characters.'**
  String get respondToDisputeErrorTooShort;

  /// SnackBar shown after a dispute response is successfully submitted.
  ///
  /// In en, this message translates to:
  /// **'Response submitted'**
  String get respondToDisputeSuccessSnackbar;

  /// Step title in the change PIN flow when entering the current PIN.
  ///
  /// In en, this message translates to:
  /// **'Enter Current PIN'**
  String get enterCurrentPinStepTitle;

  /// Subtitle below the Enter Current PIN step heading.
  ///
  /// In en, this message translates to:
  /// **'Enter your current 6-digit transaction PIN'**
  String get enterCurrentPinSubtitle;

  /// Validation error shown when the user enters a PIN that doesn't match the stored one.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get pinErrorIncorrectPin;

  /// Generic error shown when PIN verification fails due to an unexpected error. Does not include developer diagnostic text.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get pinErrorWrapperGeneric;

  /// User-facing error shown when the changePin Cloud Function call fails. Does not include developer diagnostic text.
  ///
  /// In en, this message translates to:
  /// **'Failed to update PIN. Please try again.'**
  String get changePinErrorFailedToUpdate;

  /// Validation error shown when the confirmation PIN doesn't match the newly chosen PIN. Used in both change-pin and reset-pin flows.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinsDoNotMatchError;

  /// Validation error on the reset PIN email-verification step when email or password is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password'**
  String get resetPinErrorEmailPasswordRequired;

  /// Error shown on the reset PIN email-verification step when the password is wrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get resetPinErrorIncorrectPassword;

  /// Error shown when the user tries to use phone verification but no phone number is on their account.
  ///
  /// In en, this message translates to:
  /// **'No phone number linked to your account. Please use email verification.'**
  String get resetPinErrorNoPhoneLinked;

  /// Error shown when SMS auto-retrieval fails during reset PIN phone verification.
  ///
  /// In en, this message translates to:
  /// **'Auto-verification failed. Please enter the OTP manually.'**
  String get resetPinErrorAutoVerificationFailed;

  /// Validation error when the user submits an OTP shorter than 6 digits during reset PIN phone verification.
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code'**
  String get resetPinErrorEnter6DigitCode;

  /// Error shown when the OTP verification window has expired during reset PIN.
  ///
  /// In en, this message translates to:
  /// **'Verification expired. Please request a new code.'**
  String get resetPinErrorVerificationExpired;

  /// Generic error shown when the resetPin Cloud Function call fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to reset PIN. Please try again.'**
  String get resetPinErrorFailedToReset;

  /// Validation error shown when sendMoney is invoked without a recipient.
  ///
  /// In en, this message translates to:
  /// **'No recipient selected'**
  String get transactionErrorNoRecipientSelected;

  /// Validation error shown when sendMoney is invoked with amount <= 0.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get transactionErrorInvalidAmount;

  /// Label for the button that opens the response form on the dispute detail screen, shown to the dispute recipient before they have submitted any response.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get respondButton;

  /// Label for the button on the dispute detail screen after the recipient has already submitted one response. Tapping it lets them submit a second response.
  ///
  /// In en, this message translates to:
  /// **'Update Response'**
  String get updateResponseButton;

  /// Label for the disabled button on the dispute detail screen after the recipient has submitted the maximum number of responses (2).
  ///
  /// In en, this message translates to:
  /// **'Responded'**
  String get respondedLabel;

  /// Section heading on the dispute detail screen above the first response submitted by the recipient.
  ///
  /// In en, this message translates to:
  /// **'First Response'**
  String get firstResponseLabel;

  /// Section heading on the dispute detail screen above the second response submitted by the recipient.
  ///
  /// In en, this message translates to:
  /// **'Second Response'**
  String get secondResponseLabel;
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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
