import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/kyc_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/main_navigation_screen.dart';
import '../../features/send/screens/send_money_screen.dart';
import '../../features/send/screens/scan_qr_screen.dart';
import '../../features/send/screens/confirm_send_screen.dart';
import '../../features/receive/screens/receive_money_screen.dart';
import '../../features/receive/screens/request_payment_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../../features/transactions/screens/transaction_details_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/wallet/screens/add_money_screen.dart';
import '../../features/wallet/screens/withdraw_screen.dart';
import '../../features/wallet/screens/payment_result_screen.dart';
import '../../features/settings/screens/currency_selector_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';

/// Route names
class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String signUp = '/sign-up';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String otpVerification = '/otp-verification';
  static const String kyc = '/kyc';
  static const String main = '/main';
  static const String home = '/home';
  static const String sendMoney = '/send-money';
  static const String scanQr = '/scan-qr';
  static const String confirmSend = '/confirm-send';
  static const String receiveMoney = '/receive-money';
  static const String requestPayment = '/request-payment';
  static const String addMoney = '/add-money';
  static const String withdraw = '/withdraw';
  static const String paymentResult = '/payment-result';
  static const String currencySelector = '/currency-selector';
  static const String transactions = '/transactions';
  static const String transactionDetails = '/transaction-details';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String notifications = '/notifications';
}

/// Router provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Intercept qrwallet:// deep links - let DeepLinkService handle them
      if (state.uri.scheme == 'qrwallet') {
        return '/main'; // Redirect to main, DeepLinkService handles actual navigation
      }
      return null;
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Welcome Screen
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),

      // Sign Up Screen
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        builder: (context, state) => const SignUpScreen(),
      ),

      // Login Screen
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Forgot Password Screen
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // OTP/Email Verification Screen
      GoRoute(
        path: AppRoutes.otpVerification,
        name: 'otpVerification',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return OtpVerificationScreen(
            email: extras?['email'] ?? '',
            phoneNumber: extras?['phoneNumber'],
            isEmailVerification: extras?['isEmailVerification'] ?? true,
          );
        },
      ),

      // KYC Screen
      GoRoute(
        path: AppRoutes.kyc,
        name: 'kyc',
        builder: (context, state) => const KycScreen(),
      ),

      // Main Navigation (contains bottom nav)
      GoRoute(
        path: AppRoutes.main,
        name: 'main',
        builder: (context, state) => const MainNavigationScreen(),
      ),

      // Send Money Screen
      GoRoute(
        path: AppRoutes.sendMoney,
        name: 'sendMoney',
        builder: (context, state) => const SendMoneyScreen(),
      ),

      // Scan QR Screen
      GoRoute(
        path: AppRoutes.scanQr,
        name: 'scanQr',
        builder: (context, state) => const ScanQrScreen(),
      ),

      // Confirm Send Screen
      GoRoute(
        path: AppRoutes.confirmSend,
        name: 'confirmSend',
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>?;
          return ConfirmSendScreen(
            recipientWalletId: extras?['recipientWalletId'] ?? '',
            recipientName: extras?['recipientName'] ?? '',
            amount: extras?['amount'] ?? 0.0,
            note: extras?['note'],
            fromScan: extras?['fromScan'] ?? false,
            amountLocked: extras?['amountLocked'] ?? false,
            recipientCurrency: extras?['recipientCurrency'],
            recipientCurrencySymbol: extras?['recipientCurrencySymbol'],
          );
        },
      ),

      // Receive Money Screen
      GoRoute(
        path: AppRoutes.receiveMoney,
        name: 'receiveMoney',
        builder: (context, state) => const ReceiveMoneyScreen(),
      ),

      // Request Payment Screen (Merchant QR)
      GoRoute(
        path: AppRoutes.requestPayment,
        name: 'requestPayment',
        builder: (context, state) => const RequestPaymentScreen(),
      ),

      // Add Money Screen
      GoRoute(
        path: AppRoutes.addMoney,
        name: 'addMoney',
        builder: (context, state) => const AddMoneyScreen(),
      ),

      // Withdraw Screen
      GoRoute(
        path: AppRoutes.withdraw,
        name: 'withdraw',
        builder: (context, state) => const WithdrawScreen(),
      ),

      // Payment Result Screen (Deep Link Callback)
      GoRoute(
        path: AppRoutes.paymentResult,
        name: 'paymentResult',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PaymentResultScreen(
            reference: extra?['reference'] ?? '',
            status: extra?['status'],
          );
        },
      ),

      // Currency Selector Screen
      GoRoute(
        path: AppRoutes.currencySelector,
        name: 'currencySelector',
        builder: (context, state) => const CurrencySelectorScreen(),
      ),

      // Transactions Screen (View All)
      GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionsScreen(),
      ),

      // Transaction Details Screen
      GoRoute(
        path: AppRoutes.transactionDetails,
        name: 'transactionDetails',
        builder: (context, state) {
          final transactionId = state.extra as String?;
          return TransactionDetailsScreen(transactionId: transactionId ?? '');
        },
      ),

      // Edit Profile Screen
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'editProfile',
        builder: (context, state) => const EditProfileScreen(),
      ),

      // Notifications Screen
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
