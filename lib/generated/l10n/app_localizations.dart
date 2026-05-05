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
