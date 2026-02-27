# CLAUDE.md - QR Wallet Codebase Guide

## Project Overview

QR Wallet is a cross-platform mobile wallet app built with **Flutter** for iOS and Android. It enables cashless transactions via QR codes across multiple African countries (Nigeria, Ghana, Kenya, Sierra Leone, Uganda, etc.). The backend uses **Firebase** (Auth, Firestore, Cloud Functions, Storage) with **Paystack** for card/bank payments and **MTN MoMo** for direct mobile money integration.

## Tech Stack

- **Framework**: Flutter 3.x (Dart SDK >=3.2.0 <4.0.0)
- **State Management**: Riverpod (`flutter_riverpod`, `StateNotifier` pattern)
- **Routing**: GoRouter with auth/KYC route guards
- **Backend**: Firebase (Auth, Cloud Firestore, Cloud Functions, Storage, App Check)
- **Local Storage**: Hive (with generated adapters) + `flutter_secure_storage`
- **Payments**: Paystack (card/bank), MTN MoMo (direct API via Cloud Functions)
- **KYC**: SmileID (`smile_id` package)
- **QR Codes**: `qr_flutter` (generation), `mobile_scanner` (scanning)
- **Network**: Dio for HTTP, Cloud Functions callable for server operations
- **Cloud Functions**: Node.js 20 (`functions/index.js`)

## Project Structure

```
lib/
├── main.dart                          # App entry point (Firebase init, SmileID, Hive)
├── firebase_options.dart              # Firebase config (auto-generated)
├── core/
│   ├── constants/
│   │   ├── african_countries.dart     # Country data (dial codes, currencies, flags)
│   │   ├── app_colors.dart            # Color constants
│   │   ├── app_dimensions.dart        # Spacing/sizing constants
│   │   ├── app_strings.dart           # String constants
│   │   ├── app_text_styles.dart       # Typography
│   │   ├── constants.dart             # Barrel export
│   │   └── error_codes.dart           # Error code constants
│   ├── models/
│   │   └── currency_model.dart        # Currency data model
│   ├── router/
│   │   └── app_router.dart            # GoRouter config with auth/KYC guards
│   ├── services/
│   │   ├── services.dart              # Barrel export for all services
│   │   ├── auth_service.dart          # Firebase Auth operations
│   │   ├── wallet_service.dart        # Wallet CRUD, send money, transactions
│   │   ├── payment_service.dart       # Paystack + MoMo payment orchestration
│   │   ├── momo_service.dart          # MTN MoMo direct API (via Cloud Functions)
│   │   ├── user_service.dart          # User profile operations
│   │   ├── currency_service.dart      # Currency config and formatting
│   │   ├── exchange_rate_service.dart  # FX rate lookups
│   │   ├── biometric_service.dart     # Fingerprint/Face ID
│   │   ├── local_storage_service.dart # Hive-based caching
│   │   ├── secure_storage_service.dart # flutter_secure_storage wrapper
│   │   ├── qr_signing_service.dart    # QR code signing/verification
│   │   ├── deep_link_service.dart     # qrwallet:// deep link handling
│   │   ├── smile_id_service.dart      # SmileID KYC integration
│   │   ├── screenshot_prevention_service.dart # Screenshot blocking
│   │   └── firebase_config.dart       # Firebase instance access
│   ├── theme/
│   │   └── app_theme.dart             # Light/dark theme definitions
│   ├── utils/
│   │   ├── error_handler.dart         # Centralized error handling + MoMo errors
│   │   └── network_retry.dart         # Retry logic with exponential backoff
│   └── widgets/
│       └── screenshot_protected_screen.dart  # Widget wrapper for sensitive screens
├── features/
│   ├── auth/
│   │   ├── screens/                   # Login, SignUp, OTP, KYC, ForgotPassword
│   │   │   └── kyc/                   # Country-specific KYC: NIN, BVN, Passport, etc.
│   │   └── widgets/                   # Reusable auth widgets
│   ├── home/
│   │   ├── screens/                   # HomeScreen, MainNavigationScreen (bottom nav)
│   │   └── widgets/                   # BalanceCard, QuickActionButton, TransactionTile
│   ├── send/screens/                  # SendMoney, ScanQR, ConfirmSend
│   ├── receive/screens/               # ReceiveMoney, RequestPayment (merchant QR)
│   ├── wallet/screens/                # AddMoney, Withdraw, PaymentResult
│   ├── transactions/screens/          # TransactionsList, TransactionDetails
│   ├── profile/
│   │   ├── screens/                   # Profile, EditProfile, Settings, etc.
│   │   └── widgets/                   # BusinessLogoSection
│   ├── settings/screens/              # CurrencySelector
│   ├── notifications/screens/         # NotificationsScreen
│   └── splash/                        # SplashScreen
├── models/
│   ├── models.dart                    # Barrel export
│   ├── user_model.dart                # UserModel (with .g.dart Hive adapter)
│   ├── wallet_model.dart              # WalletModel (with .g.dart Hive adapter)
│   ├── transaction_model.dart         # TransactionModel (with .g.dart Hive adapter)
│   └── notification_model.dart        # NotificationModel
└── providers/
    ├── providers.dart                 # Barrel export
    ├── auth_provider.dart             # Auth state + current user provider
    ├── wallet_provider.dart           # Wallet, Transactions, SendMoney state
    ├── currency_provider.dart         # Currency selection state
    └── theme_provider.dart            # Theme mode state

functions/                             # Firebase Cloud Functions (Node.js 20)
├── index.js                           # All cloud functions (payments, MoMo, KYC, etc.)
├── package.json                       # Node dependencies
├── MOMO_SETUP.md                      # MTN MoMo API setup guide
└── scripts/                           # Utility scripts

firestore.rules                        # Firestore security rules
storage.rules                          # Firebase Storage security rules
firebase.json                          # Firebase project config (africa-south1)
```

## Key Commands

```bash
# Install Flutter dependencies
flutter pub get

# Generate Hive adapters (required after model changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze

# Deploy Cloud Functions
cd functions && firebase deploy --only functions

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage

# Run Cloud Functions locally
cd functions && firebase emulators:start --only functions
```

## Architecture & Patterns

### State Management
- **Riverpod** with `StateNotifier` + `StateNotifierProvider` pattern
- Providers are in `lib/providers/` with barrel export via `providers.dart`
- Services are instantiated in providers (not dependency injected)
- Wallet state uses real-time Firestore streams (`watchWallet()`, `watchTransactions()`)
- Offline-first: Hive caches wallet/transactions locally; fresh data fetched on init

### Routing
- **GoRouter** configured in `lib/core/router/app_router.dart`
- Route names defined in `AppRoutes` class as static constants
- Global redirect handles auth guards:
  - Unauthenticated users -> welcome/login
  - Unverified email -> OTP screen
  - KYC not completed -> KYC screen
  - Deep links (`qrwallet://`) require auth
- Screen data passed via `state.extra` as `Map<String, dynamic>`

### Security Model
- **Firestore rules** enforce server-side access control
- `kycStatus` is a **server-only field** -- clients cannot modify it (enforced in rules)
- Financial writes (transactions, withdrawals, payments) go through **Cloud Functions only**
- Clients have read-only access to transactions, bank accounts, linked accounts
- Idempotency keys prevent duplicate financial operations
- QR nonces prevent replay attacks
- `FirebaseAppCheck` enabled (debug mode in dev, PlayIntegrity/DeviceCheck in prod)
- Sensitive screens wrapped with `ScreenshotProtectedScreen`

### Multi-Country Support
- Countries defined in `lib/core/constants/african_countries.dart` (`AfricanCountries.all`)
- Each country has: name, ISO code, dial code, flag emoji, currency code/symbol/name
- Currency determines available payment methods and MoMo providers
- Exchange rates handled by `ExchangeRateService` for cross-currency sends

### Payment Flow
1. **Card payments**: Paystack via Cloud Function (`initializeTransaction` -> browser checkout)
2. **Mobile Money (Paystack)**: Cloud Function `chargeMobileMoney` for supported regions
3. **MTN MoMo Direct**: `MomoService` -> Cloud Functions (`momoRequestToPay`, `momoTransfer`, `momoCheckStatus`)
4. **Bank Transfer**: Virtual account via `getOrCreateVirtualAccount` Cloud Function
5. **Bank Withdrawal**: `initiateWithdrawal` -> optional OTP -> `finalizeTransfer`

### MoMo Provider Configuration
- `MobileMoneyProvider.getProviders(country)` in `payment_service.dart` returns available providers per country
- `MomoService.isAvailable(country)` checks if MTN MoMo direct API is available
- Currency-to-country mapping in `_loadMomoProviders()` (in `add_money_screen.dart` and `withdraw_screen.dart`)

## Known Issues & Gotchas

- **MoMo provider mapping**: When adding new country support, you must update THREE places:
  1. `MobileMoneyProvider.getProviders()` in `payment_service.dart` (provider list)
  2. `_loadMomoProviders()` in `add_money_screen.dart` (currency-to-country mapping)
  3. `_loadMomoProviders()` in `withdraw_screen.dart` (same currency-to-country mapping)
- The default country fallback in `_loadMomoProviders()` is `'nigeria'` but `'nigeria'` has no providers in `getProviders()`, causing the "Mobile Money Not Available" message for unmapped currencies
- SmileID is initialized in **sandbox mode** (`useSandbox: true`) in `main.dart`
- MoMo sandbox uses EUR currency by default
- Hive adapters (`.g.dart` files) must be regenerated with `build_runner` after model changes

## Coding Conventions

- **File naming**: `snake_case.dart` for all files
- **Class naming**: `PascalCase`
- **Feature structure**: `features/<name>/screens/` and `features/<name>/widgets/`
- **Service pattern**: Plain Dart classes with Firebase/API calls, no DI framework
- **Barrel exports**: `services.dart`, `providers.dart`, `models.dart`, `constants.dart`
- **Constants**: Dedicated files per type (`app_colors.dart`, `app_strings.dart`, etc.)
- **Route extras**: Pass data between screens via `GoRouter`'s `extra` parameter as `Map<String, dynamic>`
- **Error handling**: Centralized in `ErrorHandler` class with user-friendly message mapping
- **Linting**: `package:flutter_lints/flutter.yaml` (standard Flutter lint rules)

## Firebase Configuration

- **Project**: `qr-wallet-1993`
- **Firestore location**: `africa-south1`
- **Cloud Functions runtime**: Node.js 20
- **Platforms**: Android + iOS
- **Auth providers**: Email/Password, Phone, Google Sign-In, Apple Sign-In

## Development Notes

- The app uses portrait-only orientation (set in `main.dart`)
- Deep links use `qrwallet://` scheme via `app_links` package
- Theme supports light and dark modes via `ThemeNotifier`
- Transaction fees: 1% of amount, clamped between 10-100 (in sender's currency)
- Wallet IDs match Firebase Auth UIDs
- The `flutter_paystack_plus` package is included but payments primarily use the browser checkout flow via Cloud Functions
