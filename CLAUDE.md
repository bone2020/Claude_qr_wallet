# CLAUDE.md — QR Wallet

## Project Overview

QR Wallet is a production-grade fintech mobile application enabling cashless transactions via QR codes, built for African markets. It is a **Flutter app** (iOS + Android) backed by **Firebase** services and **Cloud Functions** (Node.js).

**Firebase Project:** `qr-wallet-1993` | **Region:** `africa-south1`

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile framework | Flutter 3.x / Dart >=3.2.0 |
| State management | Riverpod 2.x (with code generation) |
| Local storage | Hive 2.x (with code generation) |
| Routing | GoRouter 13.x |
| Backend | Firebase (Auth, Firestore, Storage, App Check, Cloud Functions) |
| Cloud Functions | Node.js 20, firebase-functions 4.5, firebase-admin 11.11 |
| Payments | Paystack, Flutterwave, MTN Mobile Money |
| KYC | SmileID (facial recognition, document verification) |
| Networking | Dio 5.x |
| QR codes | qr_flutter (generation), mobile_scanner (scanning) |

---

## Project Structure

```
/
├── lib/                          # Flutter app source
│   ├── main.dart                 # Entry point (Firebase init, App Check, SmileID, Hive)
│   ├── firebase_options.dart     # Generated Firebase config
│   ├── core/
│   │   ├── constants/            # Colors, strings, dimensions, text styles, error codes, country data
│   │   ├── router/app_router.dart  # GoRouter route definitions (~19KB)
│   │   ├── services/             # 16 service classes (auth, payments, wallet, KYC, etc.)
│   │   ├── theme/app_theme.dart  # Light & dark theme definitions
│   │   ├── utils/                # error_handler.dart, network_retry.dart
│   │   └── widgets/              # screenshot_protected_screen.dart
│   ├── features/                 # Feature modules (vertical slices)
│   │   ├── auth/                 # Signup, login, OTP, KYC screens & widgets
│   │   ├── home/                 # Dashboard with balance, quick actions
│   │   ├── wallet/               # Balance management, add/withdraw money
│   │   ├── send/                 # Send money via QR scan or manual entry
│   │   ├── receive/              # Display QR code for receiving payments
│   │   ├── transactions/         # Transaction history and detail views
│   │   ├── profile/              # User profile, edit, change password/PIN
│   │   ├── settings/             # Theme toggle, notifications, help
│   │   ├── notifications/        # Notification list
│   │   └── splash/               # Splash/loading screen
│   ├── models/                   # Data models (User, Wallet, Transaction, Notification)
│   │   └── *.g.dart              # Generated Hive adapters — do NOT hand-edit
│   └── providers/                # Riverpod providers (auth, wallet, currency, theme)
├── functions/                    # Firebase Cloud Functions (Node.js)
│   ├── index.js                  # All 32 cloud functions (~4,559 lines)
│   ├── package.json              # Node.js deps
│   └── MOMO_SETUP.md             # MTN MoMo integration guide
├── test/                         # Flutter tests (minimal — 1 smoke test)
├── android/                      # Android native config (Gradle/Kotlin DSL)
├── ios/                          # iOS native config (CocoaPods, Xcode)
├── assets/                       # Images and icons
│   ├── images/
│   └── icons/
├── public/                       # Firebase Hosting assets
├── firestore.rules               # Firestore security rules (139 lines)
├── storage.rules                 # Cloud Storage security rules
├── firestore.indexes.json        # Firestore composite indexes
├── firebase.json                 # Firebase project configuration
├── .firebaserc                   # Firebase project alias
├── pubspec.yaml                  # Flutter dependencies
└── analysis_options.yaml         # Dart linting (flutter_lints)
```

---

## Build & Run Commands

### Flutter App

```bash
# Install dependencies
flutter pub get

# Run code generation (Hive adapters + Riverpod providers)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app (debug)
flutter run

# Static analysis
flutter analyze

# Run tests
flutter test
```

### Cloud Functions

```bash
cd functions/

# Install dependencies
npm install

# Local emulator
npm run serve              # or: firebase emulators:start --only functions

# Deploy to Firebase
npm run deploy             # or: firebase deploy --only functions

# View logs
npm run logs
```

### Firebase Rules & Indexes

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage

# Deploy indexes
firebase deploy --only firestore:indexes
```

---

## Architecture & Patterns

### Flutter Client

- **Clean Architecture (modified):** `core/` for shared infrastructure, `features/` for vertical feature slices each containing `screens/` and `widgets/` subdirectories.
- **State Management:** Riverpod with annotations. Providers live in `lib/providers/`. Some use code generation (`riverpod_generator` + `build_runner`).
- **Routing:** GoRouter with `routerProvider` defined in `core/router/app_router.dart`. Deep links handled via `DeepLinkWrapper` in `main.dart`.
- **Services:** Singleton-style service classes in `core/services/` handle all external integrations (Firebase, payment APIs, biometrics, KYC).
- **Models:** Dart classes in `lib/models/` with Hive type adapters. Files ending in `.g.dart` are auto-generated — never edit them manually.
- **Theme:** `AppTheme.lightTheme` and `AppTheme.darkTheme` defined in `core/theme/app_theme.dart`, toggled via `themeNotifierProvider`.

### Cloud Functions (functions/index.js)

- **Single file:** All 32 functions are in `index.js`. They are plain JavaScript (no TypeScript).
- **Error framework:** Standardized error codes with HTTP status mapping.
- **Structured logging:** JSON logging with severity levels and automatic PII masking (phone, email, account numbers, IDs).
- **Financial safety:** Idempotency keys prevent duplicate transactions, QR nonces prevent replay attacks, rate limiting per user, fraud detection flagging, defensive arithmetic.
- **Timing-safe comparisons** used for cryptographic operations.

### Security Model

- **Client writes are restricted.** Wallets, transactions, payments, and most subcollections are write-protected in Firestore rules — only Cloud Functions (Admin SDK) can write.
- **kycStatus** is a server-only field. Firestore rules enforce that clients cannot modify it; only Cloud Functions can set it.
- **Firebase App Check** is enabled (Play Integrity on Android, DeviceCheck on iOS; debug providers in development).
- **Screenshot prevention** via `no_screenshot` package.
- **Biometric auth** via `local_auth`.

---

## Key Firestore Collections

| Collection | Client Access | Purpose |
|------------|---------------|---------|
| `users/{userId}` | Owner R/W (kycStatus protected) | User profile data |
| `users/{userId}/transactions` | Owner R | Transaction history |
| `users/{userId}/notifications` | Owner R/Update | Push notifications |
| `users/{userId}/kyc` | Owner R/W | KYC documents |
| `users/{userId}/linkedAccounts` | Owner R | External accounts |
| `users/{userId}/bankAccounts` | Owner R | Bank references |
| `users/{userId}/cards` | Owner R | Card references |
| `wallets/{walletId}` | Owner R, Create only | Wallet balance |
| `exchange_rates/{rateId}` | Authenticated R | Currency rates |
| `app_config/{doc}` | Authenticated R | App settings |
| `transactions/{txId}` | CF only | Transaction records |
| `payments/{paymentId}` | CF only | Payment tracking |
| `idempotency_keys/{keyId}` | CF only | Duplicate prevention |
| `momo_transactions/{txId}` | CF only | MoMo records |
| `withdrawals/{id}` | CF only | Withdrawal records |
| `qr_nonces/{nonceId}` | CF only | QR replay protection |
| `flagged_transactions/{txId}` | CF only | Fraud review |
| `rate_limits/{userId}` | CF only | Rate limiting |
| `audit_logs/{logId}` | CF only | Audit trail |

**CF = Cloud Functions (Admin SDK only, no client access)**

---

## Cloud Functions Overview (32 functions)

**Payment Processing:** `verifyPayment`, `paystackWebhook`, `initiateWithdrawal`, `finalizeTransfer`, `getBanks`, `verifyBankAccount`, `signQrPayload`, `verifyQrSignature`

**Mobile Money (MTN MoMo):** `chargeMobileMoney`, `momoRequestToPay`, `momoCheckStatus`, `momoTransfer`, `momoGetBalance`, `momoWebhook`, `getOrCreateVirtualAccount`

**Transactions:** `initializeTransaction`, `sendMoney`, `lookupWallet`

**KYC/Verification:** `updateKycStatus`, `completeKycVerification`, `markUserAlreadyEnrolled`, `verifyPhoneNumber`, `checkPhoneVerificationSupport`

**Exchange Rates:** `updateExchangeRatesDaily` (scheduled), `updateExchangeRatesNow`

**Data Management:** `exportUserData`, `deleteUserData`

**Scheduled Cleanup:** `cleanupIdempotencyKeys`, `cleanupExpiredQrNonces`, `resetDailySpendingLimits`, `resetMonthlySpendingLimits`, `cleanupExpiredData`

---

## Development Conventions

### Dart/Flutter

- Linting follows `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`).
- Run `flutter analyze` before committing to catch lint issues.
- Feature modules follow the pattern: `lib/features/<feature>/screens/` and `lib/features/<feature>/widgets/`.
- All data models with Hive annotations require running `build_runner` after changes.
- Constants (colors, strings, dimensions, text styles) are centralized in `lib/core/constants/`.
- Use `ConsumerWidget` / `ConsumerStatefulWidget` for widgets that need Riverpod state.

### Cloud Functions (JavaScript)

- All functions live in `functions/index.js` — there is no multi-file split.
- Follow the existing error framework and structured logging patterns.
- Financial operations must use idempotency keys.
- Always mask PII in log output.
- Use the existing `safeAdd` / `safeSubtract` helper functions for monetary arithmetic.

### Git Conventions

- Commit messages use conventional format: `fix:`, `feat:`, `docs:`, `refactor:`, etc.
- Branch from `master` for new features.

---

## Important Files to Know

| File | Why It Matters |
|------|---------------|
| `lib/main.dart` | App entry point — Firebase, App Check, SmileID, Hive init |
| `lib/core/router/app_router.dart` | All route definitions and navigation guards |
| `lib/core/services/auth_service.dart` | Firebase Auth, phone verification, biometric login |
| `lib/core/services/wallet_service.dart` | Wallet operations and balance management |
| `lib/core/services/payment_service.dart` | Paystack & Flutterwave integration |
| `lib/core/services/momo_service.dart` | MTN Mobile Money integration |
| `lib/core/services/smile_id_service.dart` | SmileID KYC facial verification |
| `lib/core/services/qr_signing_service.dart` | Cryptographic QR code signing |
| `lib/providers/wallet_provider.dart` | Wallet state management (~15KB) |
| `lib/providers/auth_provider.dart` | Auth state management (~9KB) |
| `functions/index.js` | All 32 Cloud Functions (~4,559 lines) |
| `firestore.rules` | Firestore security rules (critical for access control) |
| `storage.rules` | Cloud Storage security rules |

---

## Testing

Testing coverage is minimal. There is one smoke test in `test/widget_test.dart` that verifies the app loads with a splash screen.

```bash
flutter test
```

When adding new features, consider adding widget tests in `test/` following the existing pattern of wrapping with `ProviderScope`.

---

## Common Pitfalls

1. **Never hand-edit `.g.dart` files.** These are generated by `build_runner` for Hive adapters and Riverpod. Run `flutter pub run build_runner build --delete-conflicting-outputs` to regenerate.
2. **kycStatus is server-only.** Never attempt to write `kycStatus` from the Flutter client — Firestore rules will reject it. Use Cloud Functions (`updateKycStatus`, `completeKycVerification`, `markUserAlreadyEnrolled`).
3. **Wallet writes are server-only.** Wallet balances can only be modified via Cloud Functions. The client can only read and create (during signup).
4. **Financial arithmetic.** Use the `safeAdd`/`safeSubtract` helpers in Cloud Functions to avoid floating-point errors with currency amounts.
5. **App Check.** Debug providers are used in `kDebugMode`; production uses Play Integrity (Android) and DeviceCheck (iOS).
6. **SmileID is initialized in sandbox mode** (`useSandbox: true` in `main.dart`). Switch to production before release.
