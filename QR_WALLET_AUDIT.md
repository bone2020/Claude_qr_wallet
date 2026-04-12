# QR Wallet App — Full Audit Documentation

**Audited on:** 2026-04-12
**Auditor:** Claude Code Agent (read-only audit)
**Repository:** github.com:bone2020/Claude_qr_wallet (branch `main`)
**Commit at time of audit:** `1b72127dc42ef0d18cd099486f95e1aabbf6f91c` ("fix: add SmileIDSmartSelfieEnrollment subpath import (Step 7.1)")
**Local path at audit time:** `/home/user/Claude_qr_wallet` (note: requested macOS output path rewritten to actual Linux repo root for this environment)
**Firebase project:** `qr-wallet-1993`
**Cloud Functions region:** `us-central1` (no `.region()` overrides anywhere in `functions/index.js`)

This document describes what exists today. It is written to support the planning of a Shop Afrik e-commerce integration. Places that directly affect that integration are flagged with **⚠️ Relevant for Shop Afrik integration**.

---

## Section 1 — App Architecture Overview

### 1.1 Top-level repository structure

```
Claude_qr_wallet/
├── lib/                         Flutter mobile app source (Dart)
├── functions/                   Firebase Cloud Functions (Node.js)
│   ├── index.js                 ~295 KB single file, ~75 exported functions
│   ├── package.json             Node 22 runtime
│   └── MOMO_SETUP.md            MTN MoMo integration notes
├── admin-dashboard/             React + Vite SPA for platform admins (NOT in CLAUDE.md)
│   ├── src/pages/               Dashboard, Transactions, Users, Revenue, Reports, etc.
│   └── dist/                    Built assets
├── public/payment-callback.html Paystack browser redirect landing page
├── firestore.rules              Security rules for Cloud Firestore
├── storage.rules                Security rules for Firebase Storage
├── firestore.indexes.json       14 composite indexes
├── firebase.json                Firebase project config
├── android/, ios/               Native platform configs
├── assets/images/, assets/icons/ Static UI assets
├── test/widget_test.dart        Single smoke test (effectively no test coverage)
├── CLAUDE.md                    Project guide (mostly accurate; admin-dashboard is NOT documented there)
├── README.md
└── SECURITY_AUDIT_PHASE1.md     Prior security audit notes
```

The `admin-dashboard/` React SPA is NOT documented in `CLAUDE.md`. It is the platform operator UI and is important context for the Shop Afrik discussion in Section 10.

### 1.2 `lib/` structure

```
lib/
├── main.dart                          App entry point
├── firebase_options.dart              Generated Firebase config
├── core/
│   ├── constants/                     Colors, strings, dimensions, error codes, african_countries.dart
│   ├── models/currency_model.dart
│   ├── router/app_router.dart         GoRouter + auth/KYC guards
│   ├── services/                      Auth, wallet, payment, momo, smile_id, qr_signing, deep_link,
│   │                                  biometric, local_storage, secure_storage, screenshot_prevention,
│   │                                  currency, exchange_rate, user, push_notification, firebase_config
│   ├── theme/app_theme.dart
│   ├── utils/error_handler.dart, network_retry.dart
│   └── widgets/screenshot_protected_screen.dart, responsive_wrapper.dart
├── features/
│   ├── auth/                          screens/ (welcome, sign_up, login, otp, phone_otp, forgot_password,
│   │                                  kyc, app_lock, reset_pin) + screens/kyc/ (NIN, BVN, Passport,
│   │                                  drivers_license, voters_card, national_id, ssnit, uganda_nin,
│   │                                  phone_verification, verification_pending) + widgets/
│   ├── home/                          main_navigation_screen, home_screen + widgets
│   ├── send/screens/                  send_money, scan_qr, confirm_send
│   ├── receive/screens/               receive_money, request_payment (merchant QR)
│   ├── wallet/screens/                add_money, withdraw, payment_result
│   ├── transactions/screens/          transactions, transaction_details
│   ├── profile/                       screens/ (profile, edit_profile, change_password, change_pin,
│   │                                  reset_pin, help_support, about, notification_settings,
│   │                                  linked_accounts, theme_settings) + widgets/business_logo_section.dart
│   ├── settings/screens/currency_selector_screen.dart
│   ├── notifications/screens/notifications_screen.dart
│   └── splash/splash_screen.dart
├── models/                            user_model, wallet_model, transaction_model, notification_model
│                                      + Hive .g.dart adapters for user/wallet/transaction
└── providers/                         auth_provider, wallet_provider, currency_provider, theme_provider
                                       + barrel export providers.dart
```

### 1.3 State management

**Riverpod** (`flutter_riverpod` 2.4.9) using the `StateNotifier` + `StateNotifierProvider` pattern.

Top-level providers:
- `authNotifierProvider` (`StateNotifierProvider<AuthNotifier, AuthStateData>`)
- `authStateProvider` (`StreamProvider<User?>` — Firebase Auth stream)
- `currentUserProvider` (derived — `Provider<UserModel?>`)
- `walletNotifierProvider` / `transactionsNotifierProvider` / `sendMoneyNotifierProvider`
- `transactionsStreamProvider` (real-time Firestore stream variant)
- `recentTransactionsProvider` (first 5 transactions for home screen)
- `currencyNotifierProvider`
- `themeNotifierProvider`
- `routerProvider` (`Provider<GoRouter>`)
- `connectivityProvider` (online/offline banner)
- `biometricServiceProvider`, `localStorageServiceProvider`, `authServiceProvider` (service singletons)

Services are plain Dart classes instantiated inside providers — no DI framework.

Wallet and transactions state are **offline-first**: Hive cache hydrates the UI instantly on startup, then `WalletService.watchWallet()` / `watchTransactions()` subscribe to real-time Firestore snapshots which overwrite local state.

### 1.4 Routing

**GoRouter** (13.0.1) configured in `lib/core/router/app_router.dart`.

The provider is `routerProvider`. Route name constants live in `class AppRoutes`. Global `redirect` handler enforces four guards on every navigation:

1. Deep link scheme `qrwallet://` → require auth, then route to the authenticated destination.
2. Unauthenticated users → public routes only (`/`, `/welcome`, `/sign-up`, `/login`, `/forgot-password`). Everything else redirects to `/welcome`.
3. Authenticated but email not verified → forced to `/otp-verification`.
4. Authenticated, email verified, KYC pending → forced to `/kyc`. KYC status read from `users/{uid}.kycStatus` (`'pending_review'`, `'verified'`, `'failed'`, or null). For countries not in Smile ID list `['GH','NG','KE','ZA','CI','UG','ZM','ZW']`, the flow routes through `/phone-otp` if `phoneVerified` is false, otherwise to `/kyc`.

On error during the Firestore KYC lookup, the guard **fails open** (comment: "server-side enforcement is the primary guard for financial operations"). This is an explicit design decision — Cloud Functions call `enforceKyc()` on every financial operation.

Before allowing `/main`, the guard also verifies `wallets/{uid}` exists; if not, redirects back to `/kyc`.

The full list of route name constants (43 total) is documented in Section 16.4.

### 1.5 App initialization (`lib/main.dart`, step by step)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
3. Firebase Crashlytics: collection enabled only in release mode. `FlutterError.onError` and `PlatformDispatcher.instance.onError` wired to Crashlytics.
4. Firebase App Check: `AndroidProvider.debug` / `AppleProvider.debug` in debug mode; `playIntegrity` / `deviceCheck` in release. **⚠️ Note:** App Check is initialized on the client but, per the Cloud Functions audit in Section 12, **not enforced on any Cloud Function**.
5. `PushNotificationService().initialize()` — FCM permissions, background handler, foreground listener, token refresh listener, Android notification channel `qr_wallet_transactions`.
6. `SmileID.initialize(useSandbox: kDebugMode, enableCrashReporting: !kDebugMode)`.
7. `SmileID.setCallbackUrl(callbackUrl: Uri.parse('https://us-central1-qr-wallet-1993.cloudfunctions.net/smileIdWebhook'))`.
8. `LocalStorageService.initialize()` — Hive opens AES-encrypted boxes for user/wallet/transaction caches.
9. `SystemChrome.setPreferredOrientations(...)` — portrait only.
10. System UI overlay style set.
11. `runApp(ProviderScope(child: QRWalletApp()))`.

`QRWalletApp` builds `MaterialApp.router` with light/dark themes, watches `routerProvider` and `themeNotifierProvider`, caps text scale to 0.8–1.5x to prevent overflow, wraps in `ResponsiveWrapper` and `DeepLinkWrapper`, and displays an offline banner driven by `connectivityProvider`.

`DeepLinkWrapper` initializes `DeepLinkService` via a post-frame callback, keeps the router reference fresh on `didChangeDependencies`, and re-syncs on `AppLifecycleState.resumed`.

### 1.6 Firebase services used

- **Firebase Auth** (email/password, phone OTP, Google Sign-In, Apple Sign-In)
- **Cloud Firestore** (primary operational datastore — full collection list in Section 14)
- **Cloud Functions** (`cloud_functions: ^5.1.4` — all financial writes)
- **Firebase Storage** (profile photos, KYC documents, QR codes, receipts, business logos)
- **Firebase App Check** (client-activated; not enforced server-side — Section 12)
- **Firebase Messaging** (FCM push notifications — Section 11)
- **Firebase Crashlytics** (release-mode only)

Firebase Analytics is NOT imported anywhere in `lib/`.

### 1.7 Main third-party packages (from `pubspec.yaml`)

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | 2.4.9 | State management |
| `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_app_check`, `firebase_crashlytics`, `firebase_storage`, `firebase_messaging` | latest | Firebase BaaS |
| `google_sign_in`, `sign_in_with_apple` | — | Social auth |
| `flutter_local_notifications` 18.0.1 | — | Local notification display for foreground FCM |
| `hive`, `hive_flutter` | 2.2.3 / 1.1.0 | Local encrypted cache |
| `flutter_secure_storage` 9.2.2 | — | Keychain/EncryptedSharedPrefs for PIN hash, biometric toggle |
| `qr_flutter` 4.1.0 | — | QR code rendering |
| `mobile_scanner` 6.0.2 | — | QR code scanning (camera) |
| `local_auth` 2.1.8 | — | Biometric (Face ID / fingerprint) |
| `dio` 5.4.0 | — | HTTP client (sparsely used; most server ops go via callable functions) |
| `flutter_paystack_plus` 1.1.2 | — | Declared but production flow uses Paystack via Cloud Functions + browser checkout |
| `go_router` 13.0.1 | — | Routing |
| `app_links` 6.1.1 | — | Deep linking (`qrwallet://`) |
| `cloud_functions` 5.1.4 | — | Callable Cloud Functions client |
| `url_launcher` 6.3.2 | — | Opens Paystack checkout URL in browser |
| `no_screenshot` 0.3.1 | — | Screen protection on sensitive screens |
| `smile_id` 11.2.9 | — | SmileID KYC SDK |
| `crypto` 3.0.6 | — | SHA-256 for PIN hashing |
| `connectivity_plus`, `permission_handler`, `image_picker`, `share_plus`, `screenshot`, `path_provider`, `gal` | — | Utilities |
| `iconsax`, `flutter_svg`, `cached_network_image`, `shimmer`, `pinput`, `timeago`, `google_fonts`, `flutter_animate`, `intl` | — | UI utilities |
| `package_info_plus` 8.0.0 | — | App version display |

---

## Section 2 — Authentication and User Management

### 2.1 `AuthService` — `lib/core/services/auth_service.dart`

Sign-in methods supported: **email/password, Google, Apple, phone OTP**. Biometric is a device-unlock layer, not a Firebase Auth credential.

| Method | Purpose | Firestore writes |
|---|---|---|
| `signUpWithEmail(email, password, fullName, phoneNumber, countryCode, currencyCode)` | Creates FirebaseAuth user, sets `displayName`, writes new `UserModel` to `users/{uid}`. Wallet is NOT created here — deferred to a Cloud Function after KYC/phone verification. | `users/{uid}` — full `UserModel.toJson()` |
| `signInWithEmail` | Firebase Auth sign-in, reads `users/{uid}`, returns `UserModel`. | None |
| `signInWithGoogle` | Google OAuth, creates `users/{uid}` for new users. Returns `isNewUser: true` when applicable. | `users/{uid}` (new users only) |
| `signInWithApple` | Apple Sign-In with SHA-256 nonce. Apple may not return name on subsequent sign-ins — falls back to `user.displayName ?? 'User'`. | `users/{uid}` (new users only) |
| `sendOtp(phoneNumber, ...)` | `verifyPhoneNumber` with 60s timeout; delivers `verificationId`. | None |
| `verifyOtp(verificationId, otp)` | If user signed in, links phone credential; else signs in fresh. | `users/{uid}` — `isVerified: true` |
| `sendEmailVerification`, `checkEmailVerified`, `markEmailVerified` | Email verification helpers. | `users/{uid}` — `isVerified: true` |
| `sendPasswordResetEmail` | Firebase password reset link. | None |
| `updatePassword` | Re-authenticates via `EmailAuthProvider.credential` then `user.updatePassword`. | None |
| `signOut` | `googleSignIn.signOut()` + `auth.signOut()`. | None |

`_generateUniqueWalletId()` is defined in `AuthService` but never called — wallet creation is entirely server-side (via Cloud Function `createWalletForUser` or the KYC completion flow).

`AuthResult` wrapper: `AuthResult.success(UserModel?, {bool isNewUser})` / `AuthResult.failure(String error)`.

### 2.2 Riverpod auth providers — `lib/providers/auth_provider.dart`

| Provider | Type | Purpose |
|---|---|---|
| `authServiceProvider` | `Provider<AuthService>` | Singleton |
| `localStorageServiceProvider` | `Provider<LocalStorageService>` | Hive wrapper |
| `biometricServiceProvider` | `Provider<BiometricService>` | `local_auth` wrapper |
| `authStateProvider` | `StreamProvider<User?>` | Firebase Auth stream |
| `authNotifierProvider` | `StateNotifierProvider<AuthNotifier, AuthStateData>` | Main auth state machine |
| `currentUserProvider` | `Provider<UserModel?>` | Convenience accessor |
| `isAuthenticatedProvider` | `Provider<bool>` | Boolean flag |

`AuthStateData` holds `AuthState authState` (enum: `initial / unauthenticated / authenticated / loading`), `UserModel? user`, `String? error`.

`AuthNotifier` methods: `signUp`, `signIn`, `signInWithGoogle`, `signInWithApple`, `signOut`, `sendEmailVerification`, `checkEmailVerified`, `markEmailVerified`, `sendPhoneOtp`, `verifyPhoneOtp`, `refreshUser`, `updateUser`.

### 2.3 Session storage and logout

After any successful auth event, `_localStorage.saveUser(user)` persists the `UserModel` to Hive (AES-encrypted `user_box`, key `current_user`). On `signOut()`, both `SecureStorageService.clearAll()` and `_localStorage.clearAll()` are invoked. A `_isSigningUp` flag prevents a race where the `authStateChanges` stream fires before the Firestore document write completes.

Firebase Auth tokens are managed entirely by the Firebase SDK; `flutter_secure_storage` keys `auth_token` / `refresh_token` exist in `SecureStorageService` but have no callers — likely vestigial.

### 2.4 Auth screens (`lib/features/auth/screens/`)

- **`welcome_screen.dart`** — `WelcomeScreen`, a simple landing screen.
- **`sign_up_screen.dart`** — `SignUpScreen`. Collects `fullName`, `email`, `phoneNumber` (with country dial-code picker from `AfricanCountryCodes`), `password`, `confirmPassword`, terms checkbox. On success, fires `sendEmailVerification()` and pushes `/otp-verification` with `isEmailVerification: true`. Google sign-up path routes directly to `/kyc` (Smile ID countries) or `/phone-otp` (others). **Apple Sign-Up shows "Apple Sign In coming soon" and does nothing** — half-finished.
- **`login_screen.dart`** — `LoginScreen`. Email+password form plus Google/Apple handlers. `_buildSocialLogin()` is defined but never called in `build()` — the social login buttons on the login screen are effectively hidden dead code.
- **`otp_verification_screen.dart`** — `OtpVerificationScreen`. Named "OTP" but is actually an **email verification waiting screen** (no PIN entry). Polls `emailVerified` every 3 s via `_autoCheckTimer`. 60 s resend cooldown. On success, writes `isVerified: true`, then routes to `/kyc` (for `GH, NG, KE, ZA, CI, UG, ZM, ZW`) or `/phone-otp`.
- **`phone_otp_screen.dart`** — `PhoneOtpScreen`. Actual SMS OTP flow using Firebase Phone Auth + `pinput` (6 digits). On success writes `phoneVerified: true`, refreshes wallet, loads currency, saves FCM token, navigates to `/main`.
- **`forgot_password_screen.dart`** — calls `FirebaseAuth.instance.sendPasswordResetEmail` directly (bypassing `AuthService`).
- **`app_lock_screen.dart`** — `AppLockScreen`. Shown when a PIN is set. Supports: 6-digit PIN (SHA-256 hashed locally, compared to `SecureStorageService.getPinHash()`), password fallback (re-auth via Firebase), biometric auto-prompt if enabled. No lockout after failed attempts — only a helper message. PIN hashing note: the local hash is plain SHA-256, while the server stores HMAC-SHA256(salt + PIN_SECRET, clientHash) — these are deliberately different formats, not synced.

### 2.5 First-launch vs returning-user logic (`lib/features/splash/splash_screen.dart`)

`SplashScreen._navigateToNextScreen()` (2.5 s animation delay):

1. No Firebase Auth user → `/welcome`.
2. Auth user exists but `emailVerified == false` → `/otp-verification`.
3. Auth user exists, email verified, but `users/{uid}` missing → sign out → `/welcome`.
4. `kycStatus == 'verified'` OR `kycCompleted == true` (legacy): preload currency, preload exchange rates, save FCM token, then:
   - PIN hash present in SecureStorage → `/app-lock`
   - Else → `/main`
5. KYC not done → `/kyc`.

The router also enforces the same logic on every navigation (Section 1.4) as a secondary guard.

### 2.6 Firestore user document (`users/{uid}`)

Written initially by `AuthService.signUp*` (excluding server-only fields). Updated by many screens and Cloud Functions. Exact field names:

| Field | Type | Source / notes |
|---|---|---|
| `id` | String | Firebase Auth UID |
| `fullName` | String | Editable until `isNameLocked` |
| `legalName` | String? | Server-only. Written by Cloud Function from verified ID |
| `email` | String | |
| `phoneNumber` | String | E.164 |
| `profilePhotoUrl` | String? | |
| `walletId` | String? | Format `QRW-XXXX-XXXX-XXXX`, server-written |
| `isVerified` | bool | Email or phone verified |
| `kycCompleted` | bool | **Legacy** flag, still read alongside `kycStatus` |
| `kycVerified` | bool | Another legacy field written by `uploadKycDocuments` — orphaned, not read by router or splash |
| `kycStatus` | String? | **Server-only.** `'pending_review' \| 'verified' \| 'failed'`. Blocked from client writes by rules. |
| `createdAt` | String (ISO8601) | |
| `dateOfBirth` | String? (ISO8601) | Written during KYC |
| `country` | String? | 2-letter ISO |
| `currency` / `currencyCode` | String | Default `'NGN'` |
| `businessLogoUrl` | String? | Storage URL (see Section 15/16 flag) |
| `accountBlocked` | bool | **Server-only.** |
| `accountBlockedAt`, `accountBlockedBy`, `accountUnblockedAt` | mixed | **Server-only.** `accountBlockedBy` is `'user'` or `'admin'` |
| `pinHash`, `pinSalt` | String | **Server-only.** HMAC-SHA256 of client SHA-256 + random salt + `PIN_SECRET` |
| `role` | String? | **Server-only.** `'super_admin' \| 'admin' \| 'support'` |
| `phoneVerified` | bool | Written by `PhoneOtpScreen` after SMS OTP |
| `smileUserId` | String | `user_{timestamp}`, written by KYC screens |
| `smileJobId` | String? | Written by KYC screens |
| `fcmToken`, `fcmTokenUpdatedAt` | legacy | Dual-write alongside `users/{uid}/fcm_tokens/{tokenHash}` subcollection |
| `virtualAccount` | Map | `{bankName, accountNumber, accountName}` — written by `getOrCreateVirtualAccount` CF |
| `notificationSettings` | Map | Per-user preference map — Section 11 |

⚠️ There is no `kycVerifiedAt` or `kycType` field on the user document — the KYC type lives in `users/{uid}/kyc/documents`. There is NO `tenantId`, `sourceApp`, `merchantId`, or `organizationId` field anywhere (Section 10).

---

## Section 3 — KYC Verification Flow

### 3.1 Integrated providers

Only **SmileID** is integrated (`smile_id` 11.2.9 Flutter SDK + `smile-identity-core` 3.1.0 in Cloud Functions). No other KYC vendor is referenced. Africa's Talking is used for SMS but only from the admin recovery-OTP flow, not from KYC.

### 3.2 KYC types supported and screen mapping

All KYC screens are under `lib/features/auth/screens/kyc/`.

| Country | ID type | Screen | SmileID widget | Calls `submitBiometricKycVerification`? |
|---|---|---|---|---|
| NG | NIN | `nin_verification_screen.dart` | SmartSelfie | ❌ (divergent — see flags) |
| NG | BVN | `bvn_verification_screen.dart` | SmartSelfie | ✅ |
| NG | PASSPORT | `passport_verification_screen.dart` | DocumentVerification (front only) | ❌ |
| NG | VOTERS_ID | `voters_card_verification_screen.dart` | DocumentVerification (both sides) | ❌ |
| NG, GH, KE, ZA, CI, UG, TZ, + others | DRIVERS_LICENSE | `drivers_license_verification_screen.dart` | DocumentVerification (both sides) | ❌ |
| All countries | PASSPORT | `passport_verification_screen.dart` | DocumentVerification | ❌ |
| GH | GHANA_CARD | `national_id_verification_screen.dart` | DocumentVerification (both sides) | ❌ |
| GH | SSNIT | `ssnit_verification_screen.dart` | SmartSelfie | ✅ |
| KE, CI | NATIONAL_ID | `national_id_verification_screen.dart` | DocumentVerification (both sides) | ❌ |
| ZA | NATIONAL_ID | `national_id_verification_screen.dart` | SmartSelfie (database path) | ✅ |
| UG | UGANDA_NIN | `uganda_nin_verification_screen.dart` | SmartSelfie | ✅ (card number collected but **discarded**) |
| ZM | TPIN | Routes to `kycNationalId` (quirk) | SmartSelfie | ✅ |
| ZW | NATIONAL_ID_NO_PHOTO | `national_id_verification_screen.dart` | SmartSelfie | ✅ |
| Other African countries | DocumentVerification only | various | DocumentVerification | ❌ |

Countries with full Smile ID KYC: `['GH', 'NG', 'KE', 'ZA', 'CI', 'UG', 'ZM', 'ZW']`. Others go through phone verification only; Cloud Function `enforceKyc()` auto-verifies users in those countries with a phone on file at first financial operation.

### 3.3 User-facing KYC flow

1. After email verification, user lands on `/kyc` (or `/phone-otp` first for non-Smile-ID countries).
2. `KycScreen` reads `user.country` (or derives it from `user.phoneNumber` via `SmileIDService.extractCountryCode`), defaults to `GH`. Calls `SmileIDService.getIdTypesForCountry()` and renders a list of `KycIdTypeCard` options.
3. User selects an ID type, navigates to the appropriate sub-screen.
4. The sub-screen validates the ID number format locally (`SmileIDService.validateIdNumber`), collects DOB, opens the appropriate SmileID widget (`SmileIDSmartSelfieEnrollment` or `SmileIDDocumentVerification`), and passes `extraPartnerParams: {"callback_url": _smileIdCallbackUrl}` to wire up the async webhook.
5. On successful capture, the screen calls `UserService.uploadKycDocuments(...)` (writes to `users/{uid}/kyc/documents`), then Cloud Function `completeKycVerification` (sets `kycStatus: 'pending_review'`), and for database-KYC flows additionally calls `submitBiometricKycVerification`.
6. User is routed to `VerificationPendingScreen`.

### 3.4 `VerificationPendingScreen`

Dual-mechanism wait: a real-time `users/{uid}` Firestore listener watching `kycStatus`, plus a 5-second poll calling Cloud Function `checkSmileIdJobStatus({smileUserId, smileJobId})`.

- On `kycStatus == 'verified'`: polls `wallets/{uid}` up to 10 times (1 s intervals) waiting for wallet creation by the Cloud Function, then navigates to `/main`.
- On `kycStatus == 'failed'`: shows non-dismissible "Try Again" dialog → routes back to `/kyc`.
- Poll errors are silently logged; poll continues.

### 3.5 `lib/core/services/smile_id_service.dart` — `SmileIDService`

| Method | Purpose |
|---|---|
| `getIdTypesForCountry(String?)` | ID types for country; defaults `GH` |
| `supportsPhoneVerification(String?)` | Only `NG`, `ZA` |
| `extractCountryCode(String?)` | Maps phone dial code to country |
| `generateUserId()` / `generateJobId()` | Timestamp-based IDs (`user_{ms}`, `job_{ms}`) |
| `parseResultFiles(String?)` | Parses SmileID result JSON into `SmileIdFiles` |
| `getSmileIdDocumentType(String, String)` | Maps internal ID type + country → SmileID's document type string |
| `validateIdNumber(String, String, String)` | Format validation: NIN 11 digits, BVN 11 digits, SSNIT `[A-Z]\d{12}`, ZA NATIONAL_ID 13 digits, UGANDA_NIN 14 alphanumeric, TPIN 10 digits |
| `verifyPhoneNumber(...)` | Calls CF `verifyPhoneNumber` |
| `checkPhoneVerificationSupport(String)` | Calls CF `checkPhoneVerificationSupport` |

### 3.6 KYC document subcollection — `users/{uid}/kyc/documents`

Written by `UserService.uploadKycDocuments()`, directly by `NinVerificationScreen`, and by the `smileIdWebhook` Cloud Function (`users/{uid}/kyc/smile_id_results`). Fields observed:

| Field | Notes |
|---|---|
| `idType` | `'NIN' \| 'BVN' \| 'PASSPORT' \| 'DRIVERS_LICENSE' \| 'VOTERS_CARD' \| 'GHANA_CARD' \| 'NATIONAL_ID' \| 'NATIONAL_ID_NO_PHOTO' \| 'SSNIT' \| 'TPIN'` |
| `idNumber` | String? (for database-lookup types) |
| `dateOfBirth` | ISO8601 String |
| `submittedAt` | ISO8601 or `serverTimestamp()` |
| `status` | `'pending_review' \| 'approved'` |
| `smileIdVerified` | bool |
| `smileIdResult` | String? (raw JSON from SmileID SDK) |
| `smileUserId`, `smileJobId` | |
| `idFrontUrl`, `idBackUrl`, `selfieUrl` | Firebase Storage URLs (`kyc_documents/{uid}/...`) |
| `verificationMethod` | `'smile_id'` |
| `smileIdJobId`, `smileIdResultCode` | |
| `verifiedData` | Map — SmileID-returned user data |
| `countryCode` | |

### 3.7 SmileID webhook (`smileIdWebhook` — `functions/index.js`)

Inbound HTTP endpoint at `https://us-central1-qr-wallet-1993.cloudfunctions.net/smileIdWebhook`. Handles PascalCase and snake_case field variants. Evaluates liveness, selfie, document verification, and human review results. On success (valid result code + face match): sets `kycStatus: 'verified'`, stores legal name from ID doc, creates wallet if missing. On definitive failure codes (1016, 1022, 1013, 1014) or face match failure: sets `kycStatus: 'failed'`. Always writes the full result to `users/{uid}/kyc/smile_id_results`.

The URL is referenced in `lib/main.dart:71` (global SDK init) and per-screen constants in BVN/Passport/NationalId/SSNIT/UgandaNin/DriversLicense/VotersCard screens as `_smileIdCallbackUrl`. **The `NinVerificationScreen` does NOT pass this parameter** — see flags below.

### 3.8 Cloud Functions involved

| Function | Called from | Purpose |
|---|---|---|
| `completeKycVerification` | `UserService`, most KYC screens | Sets `kycStatus: 'pending_review'` via Admin SDK |
| `submitBiometricKycVerification` | BVN, SSNIT, Uganda NIN, ZA/ZM/ZW National ID | Submits Enhanced KYC to SmileID server-side |
| `checkSmileIdJobStatus` | `VerificationPendingScreen` | Polls SmileID `/v1/job_status`; promotes kycStatus on completion |
| `verifyPhoneNumber` | `SmileIDService.verifyPhoneNumber()` | SmileID phone-ownership check (NG, ZA, GH, KE, TZ, UG) |
| `checkPhoneVerificationSupport` | `SmileIDService.checkPhoneVerificationSupport()` | Open (no auth) — returns supported operators for a country |
| `markUserAlreadyEnrolled` | `UserService.markKycVerifiedForAlreadyEnrolledUser()` | Bypass flow when SmileID reports user already enrolled |
| `smileIdWebhook` | Inbound from SmileID servers | Async KYC result handler (above) |
| `updateKycStatus` | Admin dashboard only | `admin` role override: sets pending/verified/rejected |

### 3.9 Failure paths and gaps

1. **NIN screen is missing the `callback_url` partner param** and also bypasses both `completeKycVerification` and `submitBiometricKycVerification`. It writes `users/{uid}/kyc/documents` directly and sets `kycCompleted: true` on the user doc. Without the webhook URL, SmileID may never send back the async result, leaving `kycStatus` stuck at null / `pending_review`. This is a material bug.
2. **Uganda NIN card number collected but discarded**: `_cardNumberController` is validated as non-empty but never sent to `submitBiometricKycVerification`.
3. **TPIN routing quirk**: Zambia's `TPIN` routes to `AppRoutes.kycNationalId` rather than a dedicated screen.
4. **"Already enrolled" handling**: `ErrorHandler.isAlreadyEnrolledError(error)` checked in each SmileID `onError`. Returns a marker string; `markUserAlreadyEnrolled` CF is available to bypass.
5. **Dual `kycCompleted` / `kycStatus` fields**: splash uses `kycStatus == 'verified' || kycCompleted` — a user with `kycCompleted: true` but no `kycStatus` bypasses the gate. The orphan `kycVerified` bool is also written by `uploadKycDocuments` but unread by routing code.

---

## Section 4 — Wallet and Balance Management

### 4.1 `WalletModel` — `lib/models/wallet_model.dart`

Fields (all amounts in minor units — kobo / pesewas / cents):

| Field | Type | Default | Notes |
|---|---|---|---|
| `id` | String | — | Firestore doc ID (= Firebase Auth UID) |
| `walletId` | String | — | Human-readable `QRW-XXXX-XXXX-XXXX` |
| `userId` | String | — | Firebase Auth UID |
| `balance` | int | 0 | Single balance, minor units |
| `currency` | String | `'NGN'` | ISO code |
| `isActive` | bool | true | |
| `createdAt` | DateTime | — | Firestore Timestamp or ISO string |
| `updatedAt` | DateTime | — | |
| `dailyLimit` | int | 50,000,000 | Minor units = 500,000.00 major |
| `monthlyLimit` | int | 500,000,000 | Minor units = 5,000,000.00 major |
| `dailySpent` | int | 0 | Reset nightly by `resetDailySpendingLimits` CF |
| `monthlySpent` | int | 0 | Reset monthly by `resetMonthlySpendingLimits` CF |

**No separate `available`, `pending`, or `locked` balance fields.** Limit enforcement is via `dailySpent`/`monthlySpent` counters. `WalletModel.canTransact(int amount)` checks `isActive`, balance, and both limits client-side; the authoritative check is server-side in `sendMoney`.

Hive type ID: 1.

### 4.2 Firestore structure

- **`wallets/{userId}`** — one wallet document per user, doc ID = Firebase Auth UID (not the `walletId` string). `WalletService` uses `.collection('wallets').doc(_userId)`.
- **`users/{uid}.walletId`** — cross-reference to the wallet's human-readable `walletId`.
- **`wallets/platform`** — special platform revenue wallet (Section 10).

### 4.3 Multi-currency model

**One wallet per user.** There is no multi-wallet-per-user structure. Each wallet holds a single `balance` in a single `currency`. Cross-currency transfers are handled at transfer time: sender's wallet is debited in its own currency; recipient's wallet is credited in its own currency. The `ExchangeRateService.convert()` method is used client-side for previews; the Cloud Function `previewTransfer` returns the authoritative `creditAmount` and `exchangeRate`.

⚠️ Relevant for Shop Afrik integration: a Shop Afrik customer paying a seller in a different currency uses the same cross-currency mechanics. If Shop Afrik platform fees are to be split from QR Wallet's own, the fee-collection logic in `sendMoney` needs to be extended with a tenant/source field before tenants can reliably attribute revenue.

### 4.4 Wallet creation timing

The wallet is **NOT created at sign-up**. `auth_service.dart:58` comments: "NO wallet yet — created after verification."

Wallet creation is triggered by Cloud Functions in three places:
- `createWalletForUser` callable (idempotent)
- Inside `smileIdWebhook` (creates wallet when KYC passes)
- Inside `checkSmileIdJobStatus` (creates wallet on pass)
- Inside `markUserAlreadyEnrolled`

`VerificationPendingScreen` polls `wallets/{uid}` up to 10 × 1 s after `kycStatus` flips to `verified`. If creation takes longer, the user may momentarily navigate to `/main` with an empty wallet state until the real-time listener catches up — a race edge case flagged earlier.

### 4.5 Balance updates

All balance mutations go through Cloud Functions:
- `sendMoney` — debits sender, credits recipient, collects platform fee
- `verifyPayment` — credits wallet after Paystack confirmation
- `chargeMobileMoney` (Paystack MoMo) — credits wallet on immediate success
- `momoRequestToPay` / `momoCheckStatus` / `momoWebhook` — MTN MoMo collections
- `initiateWithdrawal` / `finalizeTransfer` / `paystackWebhook` — withdrawals (bank + MoMo)
- `momoTransfer` — MTN MoMo disbursement
- `updateWalletCurrency` — change preferred currency

Client has `WalletNotifier.updateBalance(int)` for optimistic UI, but the real-time `watchWallet()` Firestore listener overwrites it almost immediately. Firestore rules `wallets/{walletId}` `allow update, delete: if false` — clients cannot update wallets directly.

### 4.6 Supported countries and currencies

`lib/core/constants/african_countries.dart` lists 53 African countries. Currencies with dedicated symbols in `WalletModel.currencySymbol`: NGN, GHS, KES, ZAR, EGP, TZS, UGX, RWF, ETB, MAD, DZD, TND, XAF, XOF, ZWG, ZMW, BWP, NAD, MZN, AOA, CDF, SDG, LYD, MUR, MWK, SLL, LRD, GMD, GNF, BIF, ERN, DJF, SOS, SSP, LSL, SZL, MGA, SCR, KMF, MRU, CVE, STN, USD, EUR, GBP.

`CurrencyService.supportedCurrencies` ships 24 currencies for the UI selector (21 African + USD, GBP, EUR). Exchange rates cover ~45 currencies and come from `api.exchangerate.host` via `updateExchangeRatesDaily` scheduled function, stored in `app_config/exchange_rates` with hardcoded fallback rates baked into `ExchangeRateService`.

---

## Section 5 — Sending Money (Peer-to-Peer)

### 5.1 Screens (`lib/features/send/screens/`)

- **`send_money_screen.dart`** — `SendMoneyScreen` (entry: wallet-ID typed input + scan-QR card).
- **`scan_qr_screen.dart`** — `ScanQrScreen` (camera + `mobile_scanner`).
- **`confirm_send_screen.dart`** — `ConfirmSendScreen` (preview + PIN + biometric + final send).

### 5.2 Path A — manual wallet ID entry

1. User opens `SendMoneyScreen`, types `QRW-XXXX-XXXX-XXXX`.
2. After 800 ms debounce, `_lookupRecipient()` calls `WalletService.lookupWallet(walletId)` → CF `lookupWallet`. Returns `{recipientName, maskedName, currency, currencySymbol}`.
3. User enters amount (major units; prefix = sender's currency symbol from `currencyNotifierProvider`) and optional note.
4. Regex validation: `^QRW-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$`. Amount > 0, max 10,000,000.
5. On "Continue", amount is converted to minor units (`(amountMajor * 100).round()`) and pushed to `/confirm-send` with `extra` map including `recipientWalletId`, `recipientName`, `amount`, `note`, `items`, `fromScan`, `amountLocked`, `recipientCurrency`, `recipientCurrencySymbol`.

### 5.3 Path B — QR scan

1. `ScanQrScreen` opens `MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back)`.
2. `_onDetect(BarcodeCapture)` deduplicates via `_isProcessing` flag.
3. `_processQrCode(code)` tries three parsers in order:
   a. **Signed v2** `qrwallet://pay?signed=<urlEncoded({"p":"<payload>","s":"<signature>"})>` → `QrSigningService.parseQrData()` + `QrSigningService.verifySignature()` → CF `verifyQrSignature`. If signature invalid, scan is rejected.
   b. **Legacy v1** `qrwallet://pay?id=...&name=...&amount=...&currency=...&note=...` — plaintext URI.
   c. **Plain wallet ID** matching `QRW-XXXX-XXXX-XXXX` or legacy `QRW-DDDDD-DDDDD`.
4. Calls `lookupWallet` to get recipient metadata. For verified QRs, lookup failure is tolerated; for unverified, it aborts.
5. `context.pushReplacement(AppRoutes.confirmSend, extra: {...})` with `amountLocked: amount != null && amount > 0`, `fromScan: true`, `isVerifiedQr: true`.

### 5.4 ConfirmSend flow

1. On load, `_fetchPreview()` calls CF `previewTransfer` (15 s timeout). Returns `{fee, totalDebit, creditAmount, exchangeRate, sufficient}`.
2. For merchant QR with cross-currency (amountLocked + sender currency ≠ recipient currency), the amount field auto-calculates the buyer's equivalent via `ExchangeRateService.convert()` in `didChangeDependencies()`.
3. If preview fails, client falls back to a tiered local fee estimate (same-country: 1.5/1/0.75/0.5%; cross-country: 3/2/1.5/1%).
4. User taps "Send [symbol][total]".
5. `_verifyTransactionPin()` — inline 6-digit PIN dialog. Client sends SHA-256(PIN) hash to CF; local unlock comparison uses `SecureStorageService.getPinHash()`.
6. If biometric enabled (`SecureStorageService.isBiometricEnabled()`), `BiometricService.authenticateForTransaction()` prompts.
7. `WalletService.sendMoney(recipientWalletId, amount, note, items)` → CF `sendMoney` with an `idempotencyKey` (format `idem_sendMoney_{ms}_{12-byte-base64url}`).
8. On success: `walletNotifierProvider.notifier.refreshWallet()` + `transactionsNotifierProvider.notifier.refreshTransactions()`, then a success dialog. "Done" navigates to `/main`.

### 5.5 Cloud Functions used

| Function | Purpose |
|---|---|
| `lookupWallet` | Recipient resolution; triple rate-limited (in-memory IP burst 100/min + persistent failed-lookup IP tracking 10/5min + user rate limit 30/5min) |
| `previewTransfer` | Fee, totalDebit, creditAmount, exchangeRate, sufficient |
| `sendMoney` | KYC-gated, rate-limited (20/hr), idempotent, fraud-checked, fee-collecting transfer |

`sendMoney` atomically (in a Firestore transaction):
- Debits sender's wallet + updates spending counters
- Credits recipient's wallet
- Credits platform wallet: `wallets/platform.totalBalanceUSD`, `.totalFeesCollected`, `wallets/platform/balances/{currency}`, and writes a `wallets/platform/fees/{txId}` record
- Writes transaction docs to both `users/{senderUid}/transactions/{txId}` and `users/{recipientUid}/transactions/{txId}`
- Writes `audit_logs` and `idempotency_keys`
- Runs `checkForFraud()` → may write `fraud_alerts`
- Sends FCM notifications to both parties (and pushes to `users/{uid}/notifications`)

### 5.6 Recipient identification

Only by **`walletId`** (format `QRW-XXXX-XXXX-XXXX`). No phone/username lookup. Typed manually or extracted from a QR code. `lookupWallet` CF is the only resolver — clients never directly read `wallets/*` collection for discovery.

### 5.7 Post-success

- Real-time Firestore listeners on `wallets/{uid}` and `users/{uid}/transactions` update UI.
- No client-side transaction record creation — Cloud Function writes both sides.
- Push notifications (actions `'money_sent'` / `'money_received'`) are sent server-side and routed to `/notifications` on tap.

### 5.8 Flags

- `SendMoneyState.fee` getter in `wallet_provider.dart:432` is a flat `(amount * 0.01).clamp(1000, 10000)` — a simplified fallback that diverges from the server's tiered formula. Display-only; server is authoritative.
- `_generateTransactionId()` in `wallet_service.dart:438` is dead code.
- `SendMoneyState.clear()` has an empty body — use `SendMoneyNotifier.reset()` instead.
- `ConfirmSendScreen` calls `FirebaseFunctions.instance.httpsCallable('previewTransfer')` directly at line 166 instead of going through `WalletService.previewTransfer()` — minor layering inconsistency.

---

## Section 6 — Receiving Money

### 6.1 Screens (`lib/features/receive/screens/`)

- **`receive_money_screen.dart`** — `ReceiveMoneyScreen`. Static "receive" QR displaying the user's own wallet ID.
- **`request_payment_screen.dart`** — `RequestPaymentScreen`. Merchant-style QR with configurable amount and items.

### 6.2 ReceiveMoneyScreen

Generates an **unsigned legacy QR**:
```
qrwallet://pay?id=<walletId>&name=<urlEncodedDisplayName>
```
`walletId` and `displayName` come from `walletNotifierProvider` and `currentUserProvider`. Rendered with `qr_flutter`'s `QrImageView` at error-correction level H with embedded app logo. Actions: copy wallet ID, share, download to gallery (via `gal`).

**Flag:** this QR is unsigned. Anyone who knows a target's `walletId` and name can construct an identical QR. The scanner will still route money to the correct `walletId` (verified via `lookupWallet`), but a spoofed `name` displayed on the confirm screen is a social-engineering vector.

### 6.3 RequestPaymentScreen (merchant QR)

Generates a **signed v2 QR**:
1. User enters decimal amount (sender's currency) and up to 20 line items.
2. "Generate QR Code" → `QrSigningService.signQrPayload(walletId, amount, note, items)` → CF `signQrPayload`. Returns `SignedQrPayload{payload, signature, expiresAt, nonce}`.
3. `QrSigningService.generateSignedQrData(signedPayload)` encodes:
   ```
   qrwallet://pay?signed=<urlEncoded({"p":"<payload>","s":"<signature>"})>
   ```
4. Rendered with `QrImageView`; embedded image is `businessLogoUrl` (if set) or app logo.
5. Shareable as image, saveable to gallery.

When scanned, `amountLocked: true` is set on the confirm screen, amount is read-only, and cross-currency conversion auto-computes buyer's equivalent.

### 6.4 How incoming transfers surface

No dedicated "incoming payment received" screen. Incoming transfers appear via:
1. FCM push notification with `action: 'money_received'` → taps to `/notifications`.
2. Real-time `watchWallet()` stream — balance updates immediately.
3. Real-time `watchTransactions()` stream — new transaction appears in the list.
4. `recentTransactionsProvider` (top 5 on home screen).

### 6.5 Request-payment lifecycle gap

There is **no server-side "request" record**. A payment request exists only as the QR string. The merchant cannot mark a request as "paid" / "pending" / "expired" — they only observe transaction history. A request QR could be paid multiple times (each scan by a different payer triggers a separate transfer). No UX warning. ⚠️ Relevant for Shop Afrik integration: an e-commerce integration will likely need a proper `payment_request` collection with lifecycle states (created / awaiting_payment / paid / expired / refunded) — none exists today.

---

## Section 7 — QR Code System

### 7.1 Libraries

- Generation: **`qr_flutter` 4.1.0**, `QrImageView`, error-correction H, `QrVersions.auto`.
- Scanning: **`mobile_scanner` 6.0.2**, `MobileScannerController`.

### 7.2 `QrSigningService` — `lib/core/services/qr_signing_service.dart`

All cryptographic operations are **server-side**. The client never HMACs or verifies locally.

| Method | Cloud Function | Notes |
|---|---|---|
| `signQrPayload()` | `signQrPayload` | Returns `{payload, signature, expiresAt, nonce}` |
| `verifyQrSignature()` / `verifySignature()` | `verifyQrSignature` | Returns `{valid, walletId, amount, note, items, recipientName, profilePhotoUrl}` or `{valid: false, reason}` |

Server uses **HMAC-SHA256** with secret from `functions.config().qr.secret`. Nonce is a UUID stored in `qr_nonces/{nonce}` with 15-minute TTL and `used: false`; on verify, the function atomically marks it `used: true`. Nonce replay is rejected with a security log. Expiry is enforced server-side (the client has an `isExpired` getter on `SignedQrPayload` but does not check it before scanning).

### 7.3 QR payload formats

**Signed v2** — `qrwallet://pay?signed=<urlEncoded({"p":"<payload>","s":"<sig>"})>`
- `payload` and `signature` are opaque to the client.
- Server-returned fields on verify: `walletId`, `amount` (double, major units), `note`, `items`, `recipientName`, `profilePhotoUrl`.

**Legacy v1** — `qrwallet://pay?id=<walletId>&name=<name>&amount=<amount>&currency=<currency>&note=<note>`
- Plaintext. No signature. Used by `ReceiveMoneyScreen` (static receive) and accepted as input in `DeepLinkService`.

**Plain wallet ID** — `QRW-XXXX-XXXX-XXXX` (or legacy `QRW-DDDDD-DDDDD`) accepted as fallback.

### 7.4 QR types generated in the app

| Type | Generated by | Format | Amount locked | Signed |
|---|---|---|---|---|
| Static receive | `ReceiveMoneyScreen` | Legacy v1 URI | No | No |
| Merchant payment request | `RequestPaymentScreen` | Signed v2 | Yes | Yes |
| Inbound via deep link | `DeepLinkService._handlePayQRCallback` | Legacy v1 URI | Conditional | No |

### 7.5 Scan flow, end-to-end

1. Camera detects barcode → `_onDetect`.
2. `QrSigningService.parseQrData(code)` attempts signed v2 parse (extracts `p`, `s` from JSON after URL decoding).
3. If signed → CF `verifyQrSignature`. On failure, scan rejected with error.
4. If not signed → legacy URI parsing → else plain wallet ID regex match.
5. `lookupWallet(walletId)` is called to confirm the wallet and get recipient metadata.
6. `context.pushReplacement('/confirm-send', extra: {walletId, recipientName, recipientCurrency, recipientCurrencySymbol, amount, note, items, amountLocked, fromScan: true})`.

### 7.6 Deep link handling — `lib/core/services/deep_link_service.dart`

Built on `app_links` 6.1.1. Stores pending link if router not yet ready.

**Paystack callback** (`qrwallet://payment/<status>?reference=<ref>&trxref=<ref>`): extracts reference, pushes `/payment-result` with `{reference, status}`.

**Pay-QR deep link** (`qrwallet://pay?id=<walletId>&name=<name>&amount=<amount>&currency=<currency>&note=<note>`):
- Validates wallet ID regex (new + legacy).
- Validates amount ≥ 0, ≤ 10,000,000.
- Sanitizes `name` / `note` (strips HTML tags, `<>"'` chars, truncates to 100).
- Validates currency `^[A-Z]{3}$`.
- Pushes `/confirm-send` with `amountLocked: parsedAmount != null && parsedAmount > 0`.

Router has a deep-link guard that requires auth before processing any `qrwallet://` URL.

### 7.7 Flag

The web payment callback at `public/payment-callback.html` reads `reference` / `trxref` query params and redirects to `qrwallet://payment/success?reference=...`. After a 2 s fallback window, it renders the reference in plain text without sanitization. Low XSS risk since it's displayed only after redirect attempt, but noting it.

---

## Section 8 — Top-up and Withdrawal

### 8.1 `AddMoneyScreen` — `lib/features/wallet/screens/add_money_screen.dart`

Three tabs via `TabController(length: 3)`:
- **Card** → `_buildCardTab()` → `_handleCardPayment()`
- **Mobile Money** → `_buildMobileMoneyTab()` → `_handleMobileMoneyPayment()`
- **Bank Transfer** → `_buildBankTransferTab()` → `_loadVirtualAccount()` (lazy on tab change)

Amount validation (major units): min 100, max 5,000,000. Quick amount chips: `[1000, 2000, 5000, 10000, 20000, 50000]`.

**Card flow:** `PaymentService.initializePayment()` → CF `initializeTransaction` → returns `authorizationUrl` → opened via `url_launcher` in external browser. User completes Paystack checkout, which redirects to `qrwallet://payment/success?reference=...` deep link → `PaymentResultScreen`.

**Mobile Money flow:** branches on `MomoService.isMtnProvider(code)`:
- MTN → `_handleMtnMomoPayment()` → `PaymentService.initializeMtnMomoPayment()` → `MomoService.requestToPay()` → CF `momoRequestToPay` → shows "approve on your phone" dialog → "I've Approved" → `_checkMtnPaymentStatus()` → CF `momoCheckStatus`.
- Non-MTN → `_handlePaystackMomoPayment()` → `PaymentService.initializeMobileMoneyPayment()` → CF `chargeMobileMoney`.

**Bank Transfer flow:** `PaymentService.getOrCreateVirtualAccount(email, name)` → CF `getOrCreateVirtualAccount` (Paystack Dedicated Virtual Account, Wema Bank). Shows bank name / account number / account name with copy buttons.

### 8.2 `WithdrawScreen` — `lib/features/wallet/screens/withdraw_screen.dart`

Two tabs: Bank / Mobile Money.

**Bank withdrawal flow:**
1. On init, `PaymentService.getBanks(country)` → CF `getBanks` populates bank picker.
2. Account number input (10-20 digits). 2.5-second debounce fires `_verifyBankAccount()` → CF `verifyBankAccount` to resolve account name.
3. Amount validation: min 100 major units, max = current balance.
4. Confirmation dialog → `PaymentService.initiateWithdrawal(amount, bankCode, accountNumber, accountName, type: 'bank')` → CF `initiateWithdrawal`.
5. If `result.requiresOtp == true` → inline 6-digit OTP dialog → `PaymentService.finalizeTransfer(transferCode, otp)` → CF `finalizeTransfer`.

**Mobile Money withdrawal flow:**
- MTN path: `PaymentService.initiateMtnMomoWithdrawal()` → `MomoService.transfer()` → CF `momoTransfer`. 3-second `Future.delayed`, then `PaymentService.checkMtnMomoStatus(ref, type: 'disbursement')` → CF `momoCheckStatus`.
- Non-MTN path: `PaymentService.initiateMobileMoneyWithdrawal()` → CF `initiateWithdrawal` with `type: 'mobile_money'`.

### 8.3 `PaymentResultScreen` — `lib/features/wallet/screens/payment_result_screen.dart`

Constructor: `String reference`, `String? status`. On `initState`, `_verifyPayment()` calls `PaymentService.verifyPayment(reference)` → CF `verifyPayment` (30-second timeout). On success, refreshes wallet + transactions, displays amount and new balance. "Try Again" re-invokes. "Done" → `/main`.

### 8.4 `PaymentService` — `lib/core/services/payment_service.dart`

Wraps all payment-related callable functions. Idempotency key format: `idem_{operation}_{ms}_{12-byte-base64url}`.

| Method | Callable function |
|---|---|
| `verifyPayment(reference)` | `verifyPayment` |
| `initializePayment(...)` | `initializeTransaction` |
| `initializeMobileMoneyPayment(...)` | `chargeMobileMoney` |
| `getOrCreateVirtualAccount(email, name)` | `getOrCreateVirtualAccount` |
| `getBanks(country)` | `getBanks` |
| `verifyBankAccount(accountNumber, bankCode)` | `verifyBankAccount` |
| `initiateWithdrawal(...)` | `initiateWithdrawal` (covers bank and MoMo via `type` field) |
| `finalizeTransfer(transferCode, otp)` | `finalizeTransfer` |
| `initializeMtnMomoPayment(...)` | `momoRequestToPay` (via `MomoService`) |
| `checkMtnMomoStatus(referenceId, type)` | `momoCheckStatus` (via `MomoService`) |
| `initiateMtnMomoWithdrawal(...)` | `momoTransfer` (via `MomoService`) |

### 8.5 `MomoService` — `lib/core/services/momo_service.dart`

Direct-API MTN MoMo integration. CFs called: `momoRequestToPay`, `momoTransfer`, `momoCheckStatus`, `momoGetBalance` (admin). `MomoStatusResult` has `isSuccessful` / `isPending` / `isFailed` helpers. Default sandbox currency hardcoded to `'EUR'`.

### 8.6 MoMo provider mapping

`MobileMoneyProvider.getProviders(country)`:

| Country | Providers (code) |
|---|---|
| ghana | MTN (`MTN`), Vodafone Cash (`VOD`), AirtelTigo (`ATL`) |
| kenya | M-Pesa (`MPESA`) |
| uganda | MTN, Airtel (`AIRTEL`) |
| rwanda, nigeria, DRC, congo, guinea, liberia, zambia, south africa, eswatini, south sudan, guinea-bissau, sierra leone, sudan, benin | MTN only |
| cameroon, ivory coast | MTN, Orange (`ORANGE`) |
| (unmapped) | empty → "Mobile Money Not Available" |

`getCountryFromCurrency('NGN')` maps to `'nigeria'` (now has MTN MoMo PSB — partially resolves the CLAUDE.md-flagged fallback issue). Non-African currencies (USD/EUR/GBP) would still incorrectly fall back to Nigeria. XAF / XOF shared-currency regions route to Cameroon / Ivory Coast respectively.

### 8.7 Fee / limit logic

Client-side fallback display estimate — see Section 5.4. Authoritative fee comes from `previewTransfer` / `sendMoney`. Platform fee is collected into `wallets/platform/balances/{currency}` — Section 10.

Wallet limits: `dailyLimit` 50,000,000 minor / `monthlyLimit` 500,000,000 minor (defaults on new wallets). Reset by scheduled CFs.

### 8.8 Linked bank accounts / cards — `lib/features/profile/screens/linked_accounts_screen.dart`

`LinkedAccountsScreen`. Two tabs (Bank Accounts / Cards). Writes directly to Firestore subcollections — **no API verification**, **no encryption on card numbers** (only visual masking on display):
- `users/{uid}/linkedBankAccounts` — `{bankName, accountNumber, accountName, createdAt}`
- `users/{uid}/linkedCards` — `{cardNumber, cardHolder, expiry, createdAt}`

**⚠️ Security flag:** card numbers stored in Firestore plaintext.
**⚠️ Bug flag:** these two subcollections are NOT declared in `firestore.rules`, meaning they fall through to the implicit-deny default and reads/writes will fail unless rules are updated. They are also not integrated with `WithdrawScreen` — users must re-enter bank details each time.

---

## Section 9 — Transaction History and Logs

### 9.1 `TransactionModel` — `lib/models/transaction_model.dart`

Hive type ID: 2. Enums: `TransactionType { send, receive, deposit, withdraw }` (typeId 3), `TransactionStatus { pending, completed, failed, cancelled }` (typeId 4).

| Field | Type | Notes |
|---|---|---|
| `id` | String | Transaction ID |
| `senderWalletId` | String | |
| `receiverWalletId` | String | |
| `senderName` | String? | |
| `receiverName` | String? | |
| `amount` | int | Minor units |
| `fee` | int | Minor units (default 0) |
| `currency` | String | default `'NGN'` |
| `type` | enum | send / receive / deposit / withdraw |
| `status` | enum | pending / completed / failed / cancelled |
| `note` | String? | Also accepts `description` alias on fromJson |
| `createdAt` | DateTime | |
| `completedAt` | DateTime? | |
| `reference` | String? | External payment reference |
| `failureReason` | String? | |
| `senderCurrency` | String? | For cross-currency |
| `receiverCurrency` | String? | |
| `convertedAmount` | int? | Recipient amount, minor units |
| `exchangeRate` | double? | Ratio (not minor units) |
| `method` | String? | e.g. `'MTN'`, `'Bank Transfer'` |
| `items` | List\<String\>? | Line items for merchant QR |

No dedicated `fee` transaction type. No `topup` value — top-ups use `deposit`.

### 9.2 Storage

**Path:** `users/{uid}/transactions/{txId}` — subcollection under each user, NOT a flat top-level `transactions` collection. Confirmed by `WalletService` usage: `_firestore.collection('users').doc(_userId).collection('transactions')`.

**Cloud Function writers** include: `sendMoney`, `verifyPayment`, `chargeMobileMoney`, `initiateWithdrawal`, `momoCheckStatus`, `momoWebhook`, `paystackWebhook`, `adminFlagTransaction` (flag field update).

Firestore rules allow owner `create` and `update` despite comments saying Cloud Functions-only. **⚠️ Security flag**: a malicious user could fabricate transaction records in their own subcollection. The rule does not match the documented intent.

**No separate `audit_log` or `events` collection is referenced from Flutter.** The `audit_logs` top-level collection exists (Cloud Functions only; see Section 14) and serves as the server-side audit trail.

### 9.3 `TransactionsScreen` — `lib/features/transactions/screens/transactions_screen.dart`

5 tabs (`TabController(length: 5)`): All, Sent (types `send` or `withdraw`), Received (types `receive` or `deposit`), Pending (status `pending`), Failed (status `failed`). Initial load = 50 items; "Load More" button adds 30 at a time on the All tab. Pull-to-refresh.

### 9.4 `TransactionDetailsScreen` — `lib/features/transactions/screens/transaction_details_screen.dart`

Constructor: `String transactionId`. Looks up the transaction from the already-loaded `transactionsNotifierProvider.transactions` list — **does not fetch from Firestore**. If not in the loaded window, shows "Transaction not found". ⚠️ Deep links to older transactions may fail.

Displays: amount card (credit/debit colored via `isCredit(walletId)`), status badge, details (from/to, date, ID with copy, note, items, fee, currency conversion block, failure reason).

### 9.5 Providers — `lib/providers/wallet_provider.dart`

`TransactionsNotifier extends StateNotifier<TransactionsState>`:
- Init order: Hive cache → `refreshTransactions()` one-shot (limit 50) → `watchTransactions(limit: 50)` real-time stream ordered by `createdAt desc`.
- `addTransaction(tx)` optimistic local prepend (used after `sendMoney`).
- `loadMore()` — paginates older transactions by 30.
- Filter enum `TransactionFilter { all, sent, received, pending }` — `failed` is not in the enum but is used as a tab filter directly.

Also exposed: `transactionsStreamProvider` (pure stream variant), `recentTransactionsProvider` (top 5).

---

## Section 11 — Notifications

### 11.1 `PushNotificationService` — `lib/core/services/push_notification_service.dart`

Singleton. FCM setup:
- Permissions: `alert: true, badge: true, sound: true, provisional: false`.
- Background handler: top-level `firebaseMessagingBackgroundHandler` (`@pragma('vm:entry-point')`).
- Foreground: `FirebaseMessaging.onMessage.listen(_handleForegroundMessage)` displays via `flutter_local_notifications`.
- Tap: `onMessageOpenedApp` + cold-start `getInitialMessage()` checked on init.
- Token refresh: `onTokenRefresh` updates Firestore atomically.

**No FCM topic subscriptions** — all targeting is token-based.

**Android channel:** id `qr_wallet_transactions`, name "Transaction Notifications", importance `Importance.high`, sound enabled.

**Dual token storage:**
- Primary: `users/{uid}/fcm_tokens/{tokenHashHex}` with `{token, platform, updatedAt}`.
- Legacy: `users/{uid}.fcmToken` + `users/{uid}.fcmTokenUpdatedAt`.

On logout, `removeToken()` deletes that device's subcollection doc and updates the root doc to another remaining token or clears it.

### 11.2 Notification tap routing (`action` field in FCM data)

| `action` value | Route |
|---|---|
| `deposit` | `/notifications` |
| `money_sent` | `/notifications` |
| `money_received` | `/notifications` |
| `withdrawal_completed` | `/notifications` |
| `withdrawal_initiated` | `/notifications` |
| `withdrawal_failed` | `/notifications` |
| `momo_timeout` | `/notifications` |
| `pin_changed` | `/profile` |
| `account_blocked` | `/profile` |
| `account_blocked_by_admin` | `/profile` |
| `account_unblocked` | `/profile` |
| `suspicious_activity` | `/profile` |
| (default) | `/notifications` |

500 ms `Future.delayed` ensures navigator context is available on cold start.

### 11.3 `NotificationsScreen` — `lib/features/notifications/screens/notifications_screen.dart`

Uses **direct Firestore stream** (not via Riverpod): `FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').orderBy('createdAt', descending: true).limit(50).snapshots()`.

Operations:
- `_markAsRead(id)` — sets `isRead: true` on single doc.
- `_markAllAsRead()` — batch update all unread.
- `_deleteNotification(id)` — swipe-to-dismiss hard deletes.

Display uses `timeago` for relative timestamps. **Tapping a notification marks it read but does NOT navigate to the referenced transaction** — the comment `// Handle notification tap based on type/data` is a TODO / stub.

### 11.4 `NotificationModel` — `lib/models/notification_model.dart`

**Not a Hive model.**

| Field | Type |
|---|---|
| `id` | String |
| `title` | String |
| `body` | String |
| `type` | `NotificationType { transaction, promotion, security, system }` |
| `isRead` | bool |
| `createdAt` | DateTime |
| `data` | Map\<String, dynamic\>? |

All writes come from Cloud Functions (`users/{uid}/notifications` has `create: false` for clients per Firestore rules).

### 11.5 Notification preferences — `lib/features/profile/screens/notification_settings_screen.dart`

Stored as a nested map in `users/{uid}.notificationSettings`. Fields:
- `pushNotifications` (default true)
- `emailNotifications` (true)
- `transactionAlerts` (true)
- `promotionalUpdates` (false)
- `securityAlerts` (true; hardcoded always-on — toggle is disabled with `onChanged: null`)
- `paymentReminders` (true)

**⚠️ Flag:** no evidence in Cloud Functions that these preferences are checked before sending FCM pushes. The field exists but enforcement (if any) would be entirely server-side and is not visible in `functions/index.js`.

---

## Section 10 — The Collection / Platform Layer (Shop Afrik Critical)

This section is the most important for Shop Afrik planning. It documents what exists today and, bluntly, what does not.

### 10.1 Where the platform layer lives

The "collection platform" has three components:

1. **Platform wallet in Firestore** — `wallets/platform` + subcollections (`balances/`, `fees/`, `withdrawals/`).
2. **Cloud Functions** — ~26 `admin*` callables plus scheduled cleanup / aggregation jobs in `functions/index.js`.
3. **React admin dashboard** — `admin-dashboard/` (Vite + React 18 + `react-router-dom` v6 + `firebase` v10). This is NOT documented in `CLAUDE.md`.

The mobile Flutter app has **no admin UI whatsoever**. Grepping `lib/` for `admin`, `isAdmin`, `adminClaim`, `AdminRole` returns only notification-action labels and block-message copy (`push_notification_service.dart`, `profile_screen.dart`, `home_screen.dart`). There is no role-gated screen, no admin route, no claim check. Admin is entirely the React dashboard.

### 10.2 Platform wallet — `wallets/platform`

A single Firestore document accumulating all platform fee revenue, written atomically inside the `sendMoney` Cloud Function.

**Root doc** (`wallets/platform`):
- `totalBalanceUSD` — running USD-equivalent total
- `totalTransactions`
- `totalFeesCollected`
- `isActive`, `name`

**Subcollections:**
- `balances/{currency}` — per-currency: `{amount, usdEquivalent, txCount, lastTransactionAt}`
- `fees/{txId}` — per-fee: `{transactionId, originalAmount (fee), currency, usdAmount, senderName, senderUid, recipientUid, transferAmount, createdAt}`
- `withdrawals/{id or reference}` — platform disbursements: `{amount, currency, usdEquivalent, purpose, status, withdrawnBy, withdrawnByEmail, bankDetails, paystackReference, transferCode}`

All subcollections have `allow read, write: if false` in `firestore.rules` — Cloud Functions only.

### 10.3 Country-by-country breakdown — what exists

**There is no per-country aggregation.** The closest thing is **per-currency** aggregation (since each currency roughly maps to a country). There is no `country` field on transactions or fee records. There is no `country_aggregates` collection. There is no scheduled aggregation function.

The admin dashboard's `TransactionsPage` "Volume by Currency" tab calls `adminGetTransactionStats` which aggregates `collectionGroup('transactions')` over N days (default 7, max 90) into `volumeByCurrency`, `byType`, `byStatus`, `volumeByDay` — **all computed on-demand at query time, scanning up to 1,000 transactions per call.** No pre-aggregation, no caching, no historical rollups.

**⚠️ Relevant for Shop Afrik integration:** if cross-country compliance reporting is required, it must be built — it does not exist.

### 10.4 Cloud Functions — admin / platform surface

All functions are `us-central1` callables, gated by `verifyAdmin(context, requiredRole)` which checks the custom claim `context.auth.token.adminRole`. Role hierarchy: `support (1) < admin (2) < super_admin (3)`.

**User lifecycle (admin-initiated):** `setupSuperAdmin`, `adminPromoteUser`, `adminDemoteUser`, `adminSearchUser` (support+), `adminGetUserDetails` (support+), `adminBlockAccount` (admin+), `adminUnblockAccount` (admin+), `adminUpdateUserEmail` (admin+), `adminSendRecoveryOTP` (support+), `adminVerifyRecoveryOTP` (support+), `adminListAdmins` (admin+).

**Stats / reporting:** `adminGetStats` (support+; counts users, wallets, blocked, KYC done, recent 24h, flagged), `adminExportUsers` (admin+; up to 5,000), `adminLogActivity` (any admin), `adminGetActivityLogs` (support+; support sees own only), `adminGetAuditLogs` (admin+).

**Platform wallet (revenue):**
- `adminGetPlatformWallet` (admin+) — returns root doc + per-currency balances.
- `adminGetFeeHistory` (admin+) — paginated fees, limit 200.
- `adminPlatformWithdraw` (**super_admin only**) — bookkeeping-only manual withdrawal; decrements balances, writes `wallets/platform/withdrawals/{id}`.
- `adminGetPlatformWithdrawals` (admin+).

**Platform bank transfers (real money):**
- `adminGetBanks` (admin+) — proxies Paystack.
- `adminVerifyBankAccount` (admin+) — proxies Paystack.
- `adminInitiateTransfer` (**super_admin only**) — real Paystack transfer from platform wallet to external bank. Creates Paystack transfer recipient, deducts `wallets/platform/balances/{currency}`, atomically refunds on Paystack failure.

**Transaction monitoring / compliance:**
- `adminGetAllTransactions` (admin+) — `collectionGroup('transactions')`, filters type/status/currency/date, limit 200.
- `adminGetTransactionStats` (admin+) — aggregates volumeByCurrency / byType / byStatus / volumeByDay.
- `adminFlagTransaction` (support+) → writes `flagged_transactions` + marks original tx `flagged: true`.
- `adminGetFlaggedTransactions` (support+), `adminResolveFlaggedTransaction` (admin+).
- `adminGetFraudAlerts` (support+), `adminResolveFraudAlert` (admin+; optional block), `adminGetFraudStats` (support+).

Full per-function detail in Section 13.

### 10.5 Admin dashboard (`admin-dashboard/`)

**Stack:** React 18 + Vite 5 + react-router-dom v6 + Firebase v10. No charting library, no pagination library. All reads go through Cloud Functions — `admin-dashboard/src/firebase.js` exports only `auth` and `functions`, not `firestore`.

**Auth** (`src/contexts/AuthContext.jsx`): `onAuthStateChanged` + `getIdTokenResult(true)` reads `claims.adminRole`. Valid values: `'super_admin' | 'admin' | 'support'`. On login, calls `adminLogActivity`. Exposes `isSuper` / `isAdmin` / `isSupport` helpers.

**Pages:**

| Page | Minimum role | What it does |
|---|---|---|
| `DashboardPage` | support | 7 stat cards from `adminGetStats` + `adminGetFraudStats`. No filters, no charts. |
| `TransactionsPage` | admin | 3 tabs: All (filter type/status), Flagged, Volume by Currency. CSV export. |
| `UserSearchPage` | support | `adminSearchUser` by email/phone/name. |
| `UserDetailsPage` | support (view) / admin (block/unblock) | Full profile + wallet + last 20 tx + KYC docs. |
| `RevenuePage` | admin | 4 tabs: Overview (per-currency balances), Fees, Withdrawals, Bank Transfer (**super_admin only**, live Paystack). |
| `ReportsPage` | admin | 3 one-click CSV downloads: Users, Transactions, Fees. **No PDF, no server-side report gen, no Cloud Storage upload, no scheduled delivery.** |
| `AuditLogPage` | admin | Reads `audit_logs`, CSV export. |
| `ActivityLogPage` | support | Reads `admin_activity`. Support sees own only; admin+ sees all staff. |
| `FraudAlertsPage` | support (view) / admin (resolve) | Paginated fraud alerts with severity filter. |
| `RecoveryPage` | support | 2-step OTP flow: generate → staff reads OTP to user through secure channel → verify. |
| `AdminManagementPage` | admin (view) / super_admin (promote/demote) | Manages admin roster. |
| `LoginPage` | — | Email/password. |

**CSV export** (`src/utils/csvExport.js`): client-side only, triggers `<a download>` with filename `{name}_{YYYY-MM-DD}.csv`.

### 10.6 ⚠️ CRITICAL BUG — custom claim name mismatch

Dashboard reads `tokenResult.claims.adminRole` (`AuthContext.jsx:26`). `verifyAdmin` in Cloud Functions (`functions/index.js:4338`) also reads `claims.adminRole`. BUT `setCustomUserClaims` in `setupSuperAdmin` (line 4375) and `adminPromoteUser` (line 4420) writes `{ role: 'super_admin' }` / `{ role: newRole }` — the key is `role`, not `adminRole`.

**Effect:** any user promoted through the standard flow has `claims.role`, not `claims.adminRole`. The dashboard's claim check returns `undefined` and immediately signs them out with "You do not have admin privileges." **The admin dashboard login is non-functional for any promoted admin.** This is a blocking bug that must be fixed before the platform can be considered operational. The only workaround today is manual `setCustomUserClaims({ adminRole: '...' })` outside the `admin*` Cloud Functions.

### 10.7 Withdrawals from the platform

Two paths:

1. **`adminPlatformWithdraw` (super_admin only)** — bookkeeping only. Decrements platform balance, writes a `wallets/platform/withdrawals/{id}` record with `status: 'completed'`, and expects the operator to initiate the actual bank transfer manually out-of-band.

2. **`adminInitiateTransfer` (super_admin only)** — real Paystack bank transfer. Creates a Paystack transfer recipient, atomically deducts from `wallets/platform/balances/{currency}`, calls `POST /transfer`. On failure, atomically refunds. Supported Paystack countries only (Nigeria, Ghana, South Africa, Kenya).

### 10.8 Tax / compliance reports

**None generated.** There is no compliance report generation function, no scheduled tax rollup, no PDF generation, no Cloud Storage export. `archiver ^7.0.1` is listed as a functions dependency but is not imported in `functions/index.js` (likely vestigial). CSV export exists only in the admin dashboard and is client-side manual.

### 10.9 ⚠️ Multi-tenancy assessment (the Shop Afrik question)

Grepping the entire repository for `tenantId`, `merchantId`, `orgId`, `sourceApp`, `clientId`, `partnerId` (excluding SmileID partner context), `sub_account`, `tenant`, `integrator`, `org_id`, `source_app` returns **zero hits for any multi-tenancy identifier.**

The only `merchant` reference is `_isMerchantQR` — a local UI flag in `ConfirmSendScreen` that labels cross-currency fixed-amount QRs. It is not persisted. `partner_id` references at lines 7798 / 7860 are SmileID's KYC partner ID, unrelated.

**The architecture is strictly single-tenant:**
- Every wallet belongs to exactly one Firebase Auth user.
- Every transaction is stored at `users/{uid}/transactions/{txId}`, scoped to an individual user, not a business.
- `wallets/platform` is a single document with no tenant subcollections.
- `users` has a `country` field but no `tenantId`, `sourceApp`, or `organizationId`.
- Firestore rules do not reference tenant scope.
- The admin dashboard has no concept of "which app this transaction originated from."

**Bluntly: Shop Afrik cannot plug in as an isolated tenant without a significant refactor.** At minimum, the following would need to be built:
- Add `sourceApp` (or `tenantId`) to every transaction, fee, and withdrawal record.
- Add tenant filtering to every `admin*` function.
- Introduce a `platform_tenants/{tenantId}` collection (or `wallets/platform/tenants/{tenantId}` subcollection) for per-tenant revenue aggregation.
- Introduce per-tenant revenue views in the dashboard, or a separate Shop Afrik dashboard.
- Add a first-party authentication pathway (Firebase Custom Tokens or a tenant API key) so Shop Afrik's backend can act on behalf of Shop Afrik customers without being a human end-user.
- Optionally: per-country / per-tenant compliance report generation + scheduled rollups.

### 10.10 Access control

- Admin-only Cloud Functions: claim `adminRole` + `verifyAdmin(requiredRole)`.
- Dashboard routes: `ProtectedRoute` wraps `Layout`; claim check happens inside `AuthContext`.
- Firestore: admin-only collections (`audit_logs`, `admin_activity`, `fraud_alerts`, `flagged_transactions`, `withdrawals`, `momo_transactions`, `rate_limits`, `idempotency_keys`, `qr_nonces`, `recovery_otps`, `pending_transactions`, `payments`) all have `allow read, write: if false`.
- Storage: admin has no special storage path; reports are generated client-side as CSV.

### 10.11 Notable gaps specific to the platform layer

- Dead `admin_users` collection — `functions/index.js:2509` reads it to find FCM tokens for fraud admin pushes, but **no code anywhere writes to it**. Either admin FCM tokens are never delivered (silent gap) or the collection was migrated elsewhere and the read is stale.
- `adminGetStats` counts recent transactions using a top-level `transactions` collection — but production transactions are all under `users/{uid}/transactions`. The count will silently return 0 unless there is separate legacy data.
- `adminSendRecoveryOTP` returns the plaintext OTP to the dashboard as a fallback ("remove this line when going fully live" comment — still active).
- `exports.resetPin` is declared twice (lines 3970 and 4147) — dead code duplication.
- `resetDailySpendingLimits` / `resetMonthlySpendingLimits` cap at 500 wallets per run, will silently miss wallets beyond that.
- No App Check enforcement on any Cloud Function (Section 12).
- No referrals collection, no localization, no in-app ticketing system, no localized tax rate table.

---

## Section 12 — Security and Access Control

### 12.1 `firestore.rules` summary

**Helpers:** `isAuthenticated()`, `isOwner(userId)`, and four server-only-field guards: `kycStatusUnchanged()`, `accountBlockedUnchanged()` (covers accountBlocked + accountBlockedAt/By/accountUnblockedAt), `pinHashUnchanged()` (covers pinHash + pinSalt), `roleUnchanged()`.

**`/users/{userId}`:**
- Read: owner only.
- Create: owner + MUST NOT include `kycStatus`, `pinHash`, `pinSalt`, or `role` fields.
- Update: owner + all four server-only guards enforced simultaneously.
- Delete: always denied.

**User subcollections:**

| Subcollection | Read | Create | Update | Delete |
|---|---|---|---|---|
| `transactions/{txId}` | owner | owner | owner | not declared |
| `notifications/{notifId}` | owner | denied | owner | owner |
| `fcm_tokens/{tokenId}` | owner | owner | owner | owner |
| `linkedAccounts/{accountId}` | owner | owner | owner | not declared |
| `bankAccounts/{accountId}` | owner | owner | owner | not declared |
| `cards/{cardId}` | owner | owner | owner | not declared |
| `kyc/{docId}` | owner | owner | owner | not declared |

**⚠️ Flag:** `users/{uid}/transactions` is supposed to be Cloud-Function-write-only (per rule comments), but owner `create` and `update` are allowed — an integrity gap.

**⚠️ Flag:** `users/{uid}/linkedBankAccounts`, `users/{uid}/linkedCards`, `users/{uid}/settings`, `users/{uid}/verifications` are referenced in client code or Cloud Functions but NOT declared in `firestore.rules`. Client reads/writes to these paths will be implicitly denied.

**`/wallets/{walletId}`:**
- Read: auth + `uid == walletId`.
- Create: auth + `uid == walletId` + `balance == 0` + has required fields `walletId`, `currency`, `balance` + no `isAdmin`/`role` keys.
- Update, delete: denied (Cloud Functions only).
- Subcollections `balances/`, `fees/`, `withdrawals/`: fully denied.

**Other collections (all `read, write: false` — Cloud Functions only via Admin SDK):**
`rate_limits`, `audit_logs`, `payments`, `idempotency_keys`, `momo_transactions`, `withdrawals`, `qr_nonces`, `admin_activity`, `fraud_alerts`, `recovery_otps`, `flagged_transactions`, `pending_transactions`.

**Read-only for auth'd users:** `exchange_rates`, `app_config`.

**Server-only fields on `users`:** `kycStatus`, `accountBlocked`, `accountBlockedAt`, `accountBlockedBy`, `accountUnblockedAt`, `pinHash`, `pinSalt`, `role`.

### 12.2 `storage.rules` summary

| Path | Read | Write |
|---|---|---|
| `profile_photos/{userId}/{fileName}` | auth + owner | auth + owner + image + jpeg/png/webp + ≤5 MB |
| `kyc_documents/{userId}/{fileName}` | auth + owner | auth + owner + image + jpeg/png/webp + ≤10 MB; delete denied |
| `qr_codes/{userId}/{fileName}` | auth + owner | auth + owner + image + ≤1 MB |
| `receipts/{userId}/{transactionId}/{fileName}` | auth + owner | denied (Cloud Functions only) |
| `app_assets/{**}` | public | denied |

**⚠️ Flag:** `business_logos/{uid}.png` is written by `BusinessLogoSection` but has **no matching storage rule** — it falls through and is implicitly denied. Business logo uploads will fail in production until rules are updated.

### 12.3 `firestore.indexes.json` summary (14 composite indexes)

`transactions` (COLLECTION_GROUP): `type↑ createdAt↓`, `status↑ createdAt↓`, `currency↑ createdAt↓`, `type↑ status↑ createdAt↓`.

`admin_activity`: `uid↑ timestamp↓`, `action↑ timestamp↓`, `uid↑ action↑ timestamp↓`.

`audit_logs`: `userId↑ timestamp↓`, `operation↑ timestamp↓`, `userId↑ operation↑ timestamp↓`.

`momo_transactions`: `status↑ createdAt↑`.

`flagged_transactions`: `resolved↑ flaggedAt↓`.

`fraud_alerts`: `status↑ createdAt↓`.

The COLLECTION_GROUP scope on `transactions` is what enables `adminGetAllTransactions` / `adminGetTransactionStats` to query across all users' transactions.

### 12.4 Cloud Functions security

All callables use `context.auth` presence check. Financial functions additionally:
- `enforceKyc(userId)` — email verified + `users/{uid}.kycStatus === 'verified'`. Users in non-SmileID countries with a phone on file are auto-verified at first financial call.
- `users/{uid}.accountBlocked` check (rejects blocked accounts).
- Per-operation rate limit (`enforceRateLimit`).
- Idempotency wrapper (`withIdempotency`).
- Withdrawal callables (`initiateWithdrawal`, `finalizeTransfer`) require **`auth_time` freshness** — token issued within last 5 minutes.

**⚠️ No Firebase App Check enforcement** — grep for `appCheck` / `enforceAppCheck` in `functions/index.js` returns zero hits. Client-side App Check is initialized in `main.dart` but not enforced server-side. Any client with a valid Firebase Auth token (including curl) can call every callable. Significant gap.

### 12.5 Rate limiting

Two tiers:
1. **In-memory burst limiter** (`checkRateLimit`) — per function instance, resets on cold start. Used at `lookupWallet` for IP-level burst: 100 req/min per hashed IP.
2. **Firestore sliding window** (`enforceRateLimit`) — stored in `rate_limits/{userId}_{operation}`.

Per-operation persistent limits:

| Operation | Window | Max |
|---|---|---|
| `verifyPayment` | 1 hr | 30 |
| `sendMoney` | 1 hr | 20 |
| `initiateWithdrawal` | 1 hr | 5 |
| `momoRequestToPay` | 1 hr | 10 |
| `momoTransfer` | 1 hr | 5 |
| `lookupWallet` | 5 min | 30 |
| `changePin` | 1 hr | 5 |
| `resetPin` | 1 hr | 3 |
| `finalizeTransfer` | 1 hr | 10 |
| `exportUserData` | 24 hr | 2 |
| `checkSmileIdJobStatus` | 1 min | 30 |

Separate persistent failed-lookup tracker: `lookupWallet` IP that fails 10 times in 5 minutes is blocked.

**⚠️ Flag — fails open:** on Firestore error inside `enforceRateLimit`, the function silently returns `true` (`index.js:2284`), bypassing all persistent limits during transient Firestore issues.

### 12.6 PIN / biometric / transaction protection

**PIN — server side:**
- Stored as `pinHash` + `pinSalt` on user doc (both blocked from client writes).
- Client sends SHA-256 of PIN. Server re-hashes: `HMAC-SHA256(salt + PIN_SECRET, clientHash)`. `PIN_SECRET` from `functions.config().pin.secret`.
- `timingSafeCompare` used for comparison.

**PIN — client side:**
- `flutter_secure_storage` (`encryptedSharedPreferences` Android, Keychain `first_unlock_this_device` iOS). Stores **plain SHA-256** of PIN for `AppLockScreen` comparison only. Intentionally different format from Firestore (documented in `splash_screen.dart:82`).

**Biometric — `lib/core/services/biometric_service.dart`:** `local_auth` plugin. `authenticateForTransaction` prompts with amount/recipient in the reason string. `biometricOnly: true` for login and transactions; `biometricOnly: false` for settings (allows PIN/password fallback). Enable/disable stored as bool in `SecureStorageService.biometric_enabled`.

**Transaction PIN + biometric gate** is enforced by `ConfirmSendScreen` before calling `sendMoney`. Withdrawals additionally require `auth_time` freshness server-side.

### 12.7 Admin determination

Firebase Auth custom claim `adminRole` — values `super_admin`, `admin`, `support`. But per Section 10.6, **the claim is actually written as `role` by `setCustomUserClaims`**, which is the critical mismatch bug.

`setupSuperAdmin` is locked to hardcoded UID `TBQolEM1nkejIU4W83vqhuhpyLx2`. After bootstrap, `adminPromoteUser` handles further role assignment.

### 12.8 Notable issues

- `SUPER_ADMIN_UID` hardcoded in source.
- Duplicate `exports.resetPin` declaration (first is dead code).
- Admin recovery OTP exposes plaintext to dashboard.
- `admin_users` collection referenced for fraud alert notifications but never written.
- No tests of substance — `test/widget_test.dart` is a smoke test only.

---

## Section 13 — Cloud Functions Inventory

All functions in `functions/index.js`. Node 22 runtime (per `functions/package.json`). Region `us-central1`. Dependencies: `firebase-admin ^11.11.0`, `firebase-functions ^4.5.0`, `node-fetch ^2.7.0`, `smile-identity-core ^3.1.0`, `africastalking ^0.7.9`, `archiver ^7.0.1` (unused).

**Cross-cutting helpers:** `verifyAdmin`, `enforceKyc`, `enforceRateLimit`, `withIdempotency`, `auditLog`, `checkForFraud`, `sendPushNotification`, `timingSafeCompare`, `calculateFee`.

### 13.1 Authentication / User lifecycle

| Function | Trigger | Access | Description |
|---|---|---|---|
| `setupSuperAdmin` | onCall | hardcoded UID | One-time bootstrap; sets `role: 'super_admin'` custom claim. r/w: `users/{SUPER_ADMIN_UID}`, `audit_logs`. |
| `blockAccount` | onCall | self | User-initiated block with PIN verification. w: `users/{uid}`, `audit_logs`, `users/{uid}/notifications`. |
| `unblockAccount` | onCall | self | Only if blocked by user (not admin). w: same as above. |
| `exportUserData` | onCall | self, 2/day | GDPR Article 20. Returns profile + wallet + 1000 tx + 500 notifications + linked accounts + bank accounts + cards. |
| `deleteUserData` | onCall | self, `'DELETE_MY_ACCOUNT'` confirmation | GDPR right-to-erasure. Blocks if pending withdrawals/MoMo or non-zero balance. Anonymizes audit logs (userId → `'DELETED_USER'`). Deletes Firebase Auth account. |

### 13.2 Wallets & balances

| Function | Trigger | Description |
|---|---|---|
| `createWalletForUser` | onCall | Creates `wallets/{uid}` with unique `QRW-XXXX-XXXX-XXXX`. Idempotent. |
| `updateWalletCurrency` | onCall | Updates wallet currency from whitelist. |
| `lookupWallet` | onCall | Triple rate-limited. Returns `{found, walletId, recipientName, maskedName, currency}`. Records failed lookups against hashed IP. |
| `markUserAlreadyEnrolled` | onCall | Handles SmileID "already enrolled" — sets `kycStatus: 'verified'` + creates wallet. |

### 13.3 Peer-to-peer transfers

| Function | Trigger | Description |
|---|---|---|
| `previewTransfer` | onCall | Dry-run: fee, totalDebit, creditAmount, exchangeRate, sufficient. |
| `sendMoney` | onCall | KYC-gated, rate-limited (20/hr), idempotent. Atomic Firestore transaction: debit sender + spending counters, credit recipient, credit platform wallet (totalBalanceUSD + balances/{currency} + fees/{txId}), write tx docs both sides, audit, fraud check, FCM to both parties. |

### 13.4 Payments / top-ups (Paystack)

| Function | Trigger | Description |
|---|---|---|
| `initializeTransaction` | onCall | Paystack `POST /transaction/initialize`. Returns `authorizationUrl`. Writes `pending_transactions/{reference}` for webhook amount cross-validation. |
| `verifyPayment` | onCall | Paystack `GET /transaction/verify/{reference}`. Credits wallet. Idempotent via `payments/{reference}`. |
| `chargeMobileMoney` | onCall | Paystack `POST /charge` (Ghana/West Africa MoMo). If immediate success, credits; else returns pending for webhook. |
| `getOrCreateVirtualAccount` | onCall | Paystack Dedicated Virtual Account (Wema Bank). Stores on user doc. |

### 13.5 MTN MoMo (direct API)

| Function | Trigger | Description |
|---|---|---|
| `momoRequestToPay` | onCall | MTN Collections API `POST /requesttopay`. Writes `momo_transactions/{referenceId}`. |
| `momoCheckStatus` | onCall | Polls MTN API. On SUCCESSFUL, credits wallet (collection) or records completion (disbursement). On FAILED for disbursement, refunds wallet. |
| `momoTransfer` | onCall | MTN Disbursements `POST /transfer`. Debits wallet first; refunds on API failure. **⚠️ duplicate `transaction.set()` at lines 7438 and 7451 (same doc written twice inside one Firestore transaction — wasteful but not corrupting).** |
| `momoGetBalance` | onCall | Admin only. MTN `GET /account/balance`. |

### 13.6 Withdrawals / bank transfers

| Function | Trigger | Description |
|---|---|---|
| `initiateWithdrawal` | onCall | Paystack `POST /transferrecipient` + `POST /transfer`. Handles both bank and MoMo via `type` field. Debits atomically; refunds on Paystack failure. Returns `{requiresOtp, transferCode}` when OTP required. |
| `finalizeTransfer` | onCall | Paystack `POST /transfer/finalize_transfer` with OTP. |
| `getBanks` | onCall | Paystack `GET /bank?country=X`. |
| `verifyBankAccount` | onCall | Paystack `GET /bank/resolve`. |

### 13.7 KYC / SmileID

| Function | Trigger | Description |
|---|---|---|
| `completeKycVerification` | onCall | Sets `users/{uid}.kycStatus: 'pending_review'`. |
| `updateKycStatus` | onCall | Admin override — set `pending`/`verified`/`rejected`. |
| `verifyPhoneNumber` | onCall | SmileID `POST /v2/verify-phone-number` (job type 7). NG/GH/KE/ZA/TZ/UG. Writes `users/{uid}/verifications`. |
| `checkPhoneVerificationSupport` | onCall | Stateless. **⚠️ No `context.auth` check — callable without authentication.** |
| `checkSmileIdJobStatus` | onCall | Polls SmileID `POST /v1/job_status`. On pass: sets `kycStatus: 'verified'`, writes legalName/DOB/idNumber, creates wallet. |
| `submitBiometricKycVerification` | onCall | Server-side SmileID submission via SDK. Downloads selfie + liveness frames from Storage to `/tmp`, builds ZIP, submits. Sets `kycStatus: 'pending_review'`. Cleans up `/tmp` in `finally`. |

### 13.8 QR / nonce

| Function | Trigger | Description |
|---|---|---|
| `signQrPayload` | onCall | HMAC-SHA256 sign + UUID nonce (15-min TTL) in `qr_nonces/{nonce}`. |
| `verifyQrSignature` | onCall | Timing-safe signature check + atomic nonce mark-used. Returns `{valid, walletId, amount, note, items, recipientName}`. |

### 13.9 Auth / account security

| Function | Trigger | Description |
|---|---|---|
| `changePin` | onCall | Client sends SHA-256 of PIN. Server HMAC-hashes with per-user salt + `PIN_SECRET`. Rate-limited 5/hr. |
| `resetPin` (duplicate exports at lines 3970 and 4147) | onCall | Requires `auth_time` within 5 min + `method: 'email'|'phone'`. Second declaration wins at runtime. Rate-limited 3/hr. |

### 13.10 Admin / platform / compliance (26 functions)

Listed in Section 10.4. Summary: user lifecycle (promote/demote/search/block/email/OTP), stats/reporting/export, platform wallet (overview/fees/withdrawals/bank transfer), transaction monitoring (all-transactions/stats/flag/resolve), fraud (alerts/resolve/stats), activity + audit log readers.

**super_admin-only (real money):** `adminPlatformWithdraw`, `adminInitiateTransfer`.

### 13.11 Scheduled jobs (pubsub)

| Function | Schedule | Description |
|---|---|---|
| `updateExchangeRatesDaily` | `0 0 * * *` UTC | Fetches `api.exchangerate.host/latest?base=USD` → `app_config/exchange_rates`. 45+ currencies. |
| `resetDailySpendingLimits` | `0 0 * * *` UTC | Sets `dailySpent: 0` on wallets where `dailySpent > 0`, max 500/run. |
| `resetMonthlySpendingLimits` | `0 0 1 * *` UTC | Same for `monthlySpent`, 1st of month. |
| `cleanupIdempotencyKeys` | every 6 hrs | Deletes expired `idempotency_keys`, max 500/run. |
| `cleanupExpiredQrNonces` | every 1 hr | Deletes expired `qr_nonces`, max 500/run. |
| `cleanupPendingMomoTransactions` | every 6 hrs | Times out MoMo pending >24h. Refunds wallet for disbursements. |
| `cleanupExpiredData` | `0 3 * * *` UTC | TTL cleanup: `rate_limits` 24h, `pending_transactions` 7d, `flagged_transactions` 180d, `audit_logs` 365d, user `notifications` 90d. Max 400/collection/run, only first 500 users for notifications. |

**⚠️ No revenue aggregation job, no compliance report generation, no monthly rollup, no CSV/PDF export to Cloud Storage.**

### 13.12 Webhooks (onRequest)

| Function | Description |
|---|---|
| `updateExchangeRatesNow` | Admin-only manual trigger. HMAC-SHA256 signature on timestamp (5-min replay window), `X-Admin-Signature` + `X-Timestamp` headers, `admin.exchange_rate_secret` config. |
| `paystackWebhook` | Paystack callbacks. HMAC-SHA512 signature (timing-safe). Handles `charge.success` (cross-validates `pending_transactions` amount, flags mismatches), `transfer.success`, `transfer.failed`. |
| `momoWebhook` | MTN MoMo async callbacks. Multi-layer security: method + secret token (timing-safe) + cross-verification via MTN API GET. Handles SUCCESSFUL / FAILED. |
| `smileIdWebhook` | SmileID KYC results. Evaluates liveness, selfie, document, human review codes. On pass: sets `kycStatus: 'verified'`, stores legal name/DOB/ID, creates wallet. On fail codes (1016/1022/1013/1014/face-mismatch): `kycStatus: 'failed'`. Always writes `users/{uid}/kyc/smile_id_results`. |

### 13.13 Summary

**Total exports:** ~75 (74 unique, `resetPin` declared twice).

| Category | Count |
|---|---|
| Admin / Platform / Compliance | 26 |
| Payments / Transfers / Withdrawals | 11 |
| Scheduled | 7 |
| Auth / Account Security | 6 |
| KYC / SmileID | 6 |
| MTN MoMo | 4 |
| Wallets / Balances | 4 |
| Webhooks | 4 |
| QR / Nonce | 2 |
| GDPR | 2 |

**No Firestore triggers** (onCreate/onUpdate/onDelete/onWrite) and **no Firebase Auth triggers** (`onCreate`/`onDelete`). All side effects flow through callables or webhooks. This keeps logic centralized but means user deletion from the Firebase Auth console would not cascade to Firestore unless `deleteUserData` is called explicitly.

---

## Section 14 — Firestore Collections Inventory

### 14.1 Top-level collections

**`users/{uid}`** (doc ID = Firebase Auth UID)
- Fields: `id`, `fullName`, `legalName`, `email`, `phoneNumber`, `profilePhotoUrl`, `walletId`, `isVerified`, `kycCompleted`, `kycStatus` (server-only), `kycVerified` (legacy), `createdAt`, `dateOfBirth`, `country`, `currency` (or `currencyCode`), `businessLogoUrl`, `accountBlocked` / `accountBlockedBy` / `accountBlockedAt` / `accountUnblockedAt` (server-only), `pinHash` / `pinSalt` (server-only), `role` (server-only), `phoneVerified`, `smileUserId`, `smileJobId`, `fcmToken` (legacy), `fcmTokenUpdatedAt`, `virtualAccount` (nested: `bankName`, `accountNumber`, `accountName`), `notificationSettings` (nested map), `pinChangedAt`, `pinResetAt`, `pinResetMethod`.
- Readers (client): owner. Writers: auth_service (signup, restricted fields), user_service (profile fields), Cloud Functions (KYC, PIN, block, role, wallet ref).

**Subcollections under `users/{uid}`** (see 12.1 for rules):
- `transactions/{txId}` — one per financial event. Fields match `TransactionModel`. Writers: Cloud Functions; also allowed by rules for owner (⚠️ gap).
- `notifications/{notifId}` — one per notification. Fields: `title`, `body`, `type`, `isRead`, `createdAt`, `data`. Writers: Cloud Functions only.
- `fcm_tokens/{tokenHashHex}` — one per device. Fields: `token`, `platform`, `updatedAt`.
- `linkedAccounts/{id}` — generic linked payment accounts (from rules).
- `bankAccounts/{id}` — bank account details for withdrawals.
- `cards/{id}` — tokenized card references.
- `kyc/{docId}` — KYC submissions. Fields: `idType`, `idNumber`, `dateOfBirth`, `submittedAt`, `status`, `smileIdVerified`, `smileIdResult`, `smileUserId`, `smileJobId`, `idFrontUrl`, `idBackUrl`, `selfieUrl`, `verificationMethod`, `smileIdJobId`, `smileIdResultCode`, `verifiedData`, `countryCode`. Standard docId: `documents`, also `smile_id_results`, `pending_job`.
- `linkedBankAccounts/{id}` — ⚠️ referenced by `LinkedAccountsScreen`; NOT in firestore.rules.
- `linkedCards/{id}` — ⚠️ referenced by `LinkedAccountsScreen`; NOT in firestore.rules. Stores cardNumber plaintext.
- `settings/{docId}` — referenced by `user_service.dart`; NOT in firestore.rules.
- `verifications/{id}` — written by `verifyPhoneNumber` CF; NOT in firestore.rules.

**`wallets/{uid}`** (doc ID = Firebase Auth UID)
- Fields: all from `WalletModel` (id, walletId, userId, balance, currency, isActive, createdAt, updatedAt, dailyLimit, monthlyLimit, dailySpent, monthlySpent).
- Readers: owner. Writers: Cloud Functions only (update/delete denied by rules).

**`wallets/platform`** (special)
- Fields: `totalBalanceUSD`, `totalTransactions`, `totalFeesCollected`, `isActive`, `name`, `walletId`.
- Subcollections: `balances/{currency}`, `fees/{txId}`, `withdrawals/{id}`. All `read, write: false` from clients.
- See Section 10.2.

**`exchange_rates/{rateId}`** — read by auth'd clients; writes by Cloud Functions only. (Also used at path `app_config/exchange_rates` — the active location used by `sendMoney` for USD conversions.)

**`app_config/{doc}`** — includes `exchange_rates` doc with `{rates: {...}, updatedAt}`. Read-only for clients.

**`rate_limits/{userId}_{operation}` and `failed_lookup_{hashedIp}`** — Cloud Functions only. Fields: `userId`, `operation`, `requests[]` (timestamps), `updatedAt`; for failed lookups: `count`, `resetTime`. TTL 24h.

**`audit_logs/{logId}`** — Cloud Functions only. Fields: `userId`, `operation`, `result`, `amount`, `currency`, `error`, `metadata`, `timestamp`, `ipHash`, `correlationId`. TTL 365d.

**`payments/{reference}`** — Idempotency tracking for Paystack verifications. Fields: `processed`, `reference`, `userId`, `createdAt`.

**`idempotency_keys/{key}`** — Generic idempotency. Fields: `operation`, `userId`, `result`, `createdAt`, `expiresAt`. Cleaned by scheduled function.

**`momo_transactions/{referenceId}`** — MoMo state machine. Fields: `status`, `userId`, `amount`, `currency`, `reference`, `createdAt`, `provider`, `type` (collection/disbursement).

**`withdrawals/{reference}`** — Per-withdrawal state. Fields: `userId`, `reference`, `status`, `amount`, `currency`, `bankCode`, `accountNumber`, `createdAt`, `transferCode`.

**`qr_nonces/{nonce}`** — One-time QR nonces. Fields: `used`, `usedBy`, `usedAt`, `expiresAt`, `createdAt`. 15-min TTL, cleaned hourly.

**`admin_activity/{id}`** — Admin action log. Fields: `uid`, `email`, `role`, `action`, `targetUid`, `targetInfo`, `details`, `ip`, `timestamp`.

**`fraud_alerts/{alertId}`** — Fields: `userId`, `userEmail`, `userName`, `transactionId`, `transactionType`, `amount`, `currency`, `severity`, `alerts[]`, `status`, `resolvedByEmail`, `resolution`, `resolvedAction`, `createdAt`.

**`flagged_transactions/{txId}`** — Fields: `transactionId`, `userId`, `type`, `amount`, `currency`, `reason`, `flaggedBy`, `flaggedByEmail`, `flaggedAt`, `resolved`, `resolution`, `resolvedAt`. TTL 180d.

**`pending_transactions/{reference}`** — Amount cross-validation for Paystack webhook. Fields: `expectedAmount`, `userId`, `createdAt`. TTL 7d.

**`recovery_otps/{targetUid}`** — Admin-initiated recovery OTP (SHA-256 hash). Fields: `hashedOtp`, `attempts`, `expiresAt`, `createdAt`, `verified`.

**`admin_users/{uid}`** — ⚠️ Read by `checkForFraud` to find admin FCM tokens for high-severity alerts. **No write path in current code — effectively dead.** Not in firestore.rules.

**Collections not found (confirmed absent):** `kyc_events`, `paystack_events`, `country_aggregates`, `platform_revenue` (revenue is under `wallets/platform/fees` instead), `referrals`, `support_requests`, `reports`.

### 14.2 Collections summary table

| Collection | Readers | Writers | Purpose |
|---|---|---|---|
| `users` | owner (client), admin SDK | auth_service, user_service, Cloud Functions | Core user profile |
| `wallets` | owner (client) | Cloud Functions | User wallets (+ `wallets/platform` for revenue) |
| `exchange_rates`, `app_config` | all auth'd clients | Cloud Functions | FX + config |
| `rate_limits` | — | Cloud Functions | Rate limiting |
| `audit_logs` | admin (via CF) | auditLog() helper (~30 callers) | Server-side audit trail |
| `payments` | — | Cloud Functions | Paystack idempotency |
| `idempotency_keys` | — | Cloud Functions | Generic idempotency |
| `momo_transactions` | — | Cloud Functions | MoMo state machine |
| `withdrawals` | — | Cloud Functions | Withdrawal state |
| `qr_nonces` | — | Cloud Functions | QR replay protection |
| `admin_activity` | admin (via CF) | admin* Cloud Functions | Admin action log |
| `fraud_alerts` | admin (via CF) | runFraudDetection() | Fraud alerts |
| `flagged_transactions` | admin (via CF) | adminFlagTransaction + paystackWebhook | Manual review queue |
| `pending_transactions` | — | initializeTransaction + paystackWebhook | Amount cross-validation |
| `recovery_otps` | — | adminSendRecoveryOTP / Verify | Admin-assisted recovery |
| `admin_users` | CF read (dead) | NOWHERE | ⚠️ Dead reference |

---

## Section 15 — Settings, Profile, and Utility Features

### 15.1 Profile screens (`lib/features/profile/screens/`)

| File | Class | Notes |
|---|---|---|
| `profile_screen.dart` | `ProfileScreen` | Main hub. Real-time `StreamBuilder` on `users/{uid}` to detect `accountBlocked`. Sections: Account Settings, Business (logo), Security (biometric toggle, change password, change PIN), Preferences (currency, appearance, notifications), Account Safety, Support. App version hardcoded `'1.0.0'`. |
| `edit_profile_screen.dart` | `EditProfileScreen` | Edits `fullName`, `phoneNumber`, `profilePhotoUrl`. Direct Firestore writes. Image picker → Storage `profile_photos/`. |
| `change_pin_screen.dart` | `ChangePinScreen` | 3-step: verify current → set new → confirm. SHA-256 hash sent to `changePin` CF. Also writes new hash to `SecureStorageService` for local unlock. |
| `reset_pin_screen.dart` | `ResetPinScreen` | Forgot-PIN flow via `resetPin` CF (email/phone). |
| `change_password_screen.dart` | `ChangePasswordScreen` | Firebase Auth re-auth + `updatePassword`. |
| `notification_settings_screen.dart` | `NotificationSettingsScreen` | Writes `users/{uid}.notificationSettings` (Section 11.5). |
| `linked_accounts_screen.dart` | `LinkedAccountsScreen` | Bank/Card tabs. ⚠️ Writes to undeclared subcollections + plaintext cards. |
| `theme_settings_screen.dart` | `ThemeSettingsScreen` | Light/Dark/System via `themeNotifierProvider`. |
| `help_support_screen.dart` | `HelpSupportScreen` | Email: `qrwallet.support@bongroups.co`. Phone: `+233 12 345 6789` (placeholder-looking). Live chat: "coming soon" snackbar. 6 FAQ items. |
| `about_screen.dart` | `AboutScreen` | Version, company info, legal links. |

### 15.2 Settings (`lib/features/settings/`)

`currency_selector_screen.dart` — `CurrencySelectorScreen` lists `CurrencyService.supportedCurrencies` (24 entries). Selection persists via `currencyNotifierProvider` which writes `currencyCode` to `users/{uid}` and also calls `updateWalletCurrency` CF.

### 15.3 Business logo

`lib/features/profile/widgets/business_logo_section.dart` — Upload to Firebase Storage `business_logos/{uid}.png` (512x512 max, 85% quality). URL stored as `users/{uid}.businessLogoUrl`. Visible in `RequestPaymentScreen` as embedded QR image. **⚠️ Storage rule missing for this path — uploads will fail in production.**

### 15.4 Localization / language

**None.** No `l10n`, `flutter_localizations`, or `arb` files anywhere. English-only UI. All strings in `AppStrings` constants.

### 15.5 Currency preference

Stored as `users/{uid}.currencyCode`. Managed via `currencyNotifierProvider`. `ExchangeRateService` fetches rates from `app_config/exchange_rates` with 10-min in-memory cache and hardcoded fallback rates baked into the service.

### 15.6 Referral / invite

**None.** Zero matches in `lib/` for `referral`, `invite`, `referralCode`. No `referrals` collection. Feature absent.

### 15.7 Help / support / FAQ

- Email: `qrwallet.support@bongroups.co`
- Phone: `+233 12 345 6789` (appears to be placeholder)
- Live chat: unimplemented ("coming soon")
- 6 inline FAQ items
- Social links: Facebook, Instagram, X (generic handles)

No ticketing system, no in-app chat, no `support_requests` collection.

### 15.8 Theme

Light/Dark/System mode via `ThemeSettingsScreen` + `themeNotifierProvider`.

---

## Section 16 — Anything Else Found

### 16.1 Core services not covered elsewhere

- **`lib/core/services/screenshot_prevention_service.dart`** — Reference-counted singleton using `no_screenshot`. Applied via `ScreenshotProtectedScreen` to: `main`, `confirmSend`, `receiveMoney`, `requestPayment`, `addMoney`, `withdraw`, `paymentResult`, `transactions`, `transactionDetails`, `linkedAccounts`.
- **`lib/core/services/currency_service.dart`** — Static service with 24 currencies + formatting helpers.
- **`lib/core/services/exchange_rate_service.dart`** — 10-min cache + hardcoded fallback rates. Sets `_usingFallbackRates` flag silently on failure — no UI warning.
- **`lib/core/services/secure_storage_service.dart`** — `flutter_secure_storage` with Android `encryptedSharedPreferences` + iOS Keychain. Keys: `auth_token`, `refresh_token` (appear vestigial — Firebase Auth manages its own tokens), `pin_hash`, `biometric_enabled`.
- **`lib/core/services/qr_signing_service.dart`** — CF wrapper (Section 7).
- **`lib/core/services/deep_link_service.dart`** — `qrwallet://` scheme handler (Section 7).
- **`lib/core/services/smile_id_service.dart`** — SmileID SDK wrapper (Section 3).

### 16.2 Splash and home

- `SplashScreen` — 2.5 s animated delay; handles email verification check, Firestore user existence check, KYC routing, currency + exchange rate preload, FCM token registration, local PIN-hash check (→ `AppLockScreen` or `/main`). Signs out if user exists in Auth but not Firestore.
- `HomeScreen` — Real-time `StreamBuilder` on `users/{uid}` for block banner. Quick actions (Send, Receive, Add Money, Withdraw). Recent transactions. Pull-to-refresh.
- `MainNavigationScreen` — bottom nav container.

### 16.3 `public/payment-callback.html`

Minimal Firebase Hosting page. Reads `reference` / `trxref` query params, redirects to `qrwallet://payment/success?reference=...`. 2 s fallback displays reference in plain text (low XSS risk but no sanitization).

### 16.4 Full route table (43 routes)

From `lib/core/router/app_router.dart`:

| Route | Path | Notes |
|---|---|---|
| `splash` | `/` | |
| `appLock` | `/app-lock` | verificationRoutes |
| `welcome` | `/welcome` | public |
| `signUp` | `/sign-up` | public |
| `login` | `/login` | public |
| `forgotPassword` | `/forgot-password` | public |
| `otpVerification` | `/otp-verification` | email verification |
| `phoneOtp` | `/phone-otp` | |
| `kyc` | `/kyc` | |
| `kycPassport` | `/kyc-passport` | |
| `kycNin` | `/kyc-nin` | |
| `kycBvn` | `/kyc-bvn` | |
| `kycDriversLicense` | `/kyc-drivers-license` | |
| `kycVotersCard` | `/kyc-voters-card` | |
| `kycNationalId` | `/kyc-national-id` | |
| `kycSsnit` | `/kyc-ssnit` | |
| `kycUgandaNin` | `/kyc-uganda-nin` | |
| `kycPhoneVerification` | `/kyc-phone-verification` | |
| `verificationPending` | `/verification-pending` | |
| `main` | `/main` | screenshot-protected; wallet existence check |
| `sendMoney` | `/send-money` | |
| `scanQr` | `/scan-qr` | |
| `confirmSend` | `/confirm-send` | screenshot-protected |
| `receiveMoney` | `/receive-money` | screenshot-protected |
| `requestPayment` | `/request-payment` | screenshot-protected |
| `addMoney` | `/add-money` | screenshot-protected |
| `withdraw` | `/withdraw` | screenshot-protected |
| `paymentResult` | `/payment-result` | screenshot-protected |
| `currencySelector` | `/currency-selector` | |
| `transactions` | `/transactions` | screenshot-protected |
| `transactionDetails` | `/transaction-details` | screenshot-protected |
| `editProfile` | `/edit-profile` | |
| `linkedAccounts` | `/linked-accounts` | screenshot-protected |
| `changePassword` | `/change-password` | |
| `changePin` | `/change-pin` | |
| `resetPin` | `/reset-pin` | |
| `helpSupport` | `/help-support` | |
| `about` | `/about` | |
| `notificationSettings` | `/notification-settings` | |
| `themeSettings` | `/theme-settings` | |
| `notifications` | `/notifications` | |

### 16.5 Tests

Single file: `test/widget_test.dart`. A smoke test:
```dart
testWidgets('QR Wallet app smoke test', (WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: QRWalletApp()));
  expect(find.text('QR Wallet'), findsOneWidget);
});
```
**Effective test coverage is zero.** No unit tests, no integration tests, no service tests, no Cloud Functions tests.

### 16.6 TODO / FIXME

Zero TODO/FIXME/HACK comments in `lib/` or `functions/index.js`. Noteworthy intentional inline notes:
- `splash_screen.dart:82` — Documents the deliberate PIN hash format split (Firestore HMAC vs local SHA-256).
- `app_router.dart:253` — Documents the deliberate fail-open on KYC check error.
- `functions/index.js` `adminSendRecoveryOTP` — "remove this line when going fully live" comment next to plaintext OTP return.

### 16.7 Other notable findings

- **Admin dashboard (`admin-dashboard/`)** is a separate React 18 + Vite app not mentioned in `CLAUDE.md`. See Section 10.5.
- **`functions/MOMO_SETUP.md`** contains MTN MoMo integration setup instructions (not read in detail — treat as operator runbook).
- **`SECURITY_AUDIT_PHASE1.md`** at repo root is a prior security audit (~29 KB, not re-read here — likely overlapping with this report's findings).
- **`functions/scripts/`** — Utility scripts folder (not inventoried; likely one-off migration / admin scripts).
- **No Firebase Analytics** — never imported.
- **No referral, no multi-tenant abstraction, no sub-accounts, no merchant accounts** (Section 10.9).
- **Node runtime: 22** (not 20 as CLAUDE.md claims).
- **Exchange rate dependency on `api.exchangerate.host`** — third-party free-tier API. Outages silently trigger hardcoded fallback rates in Flutter and the CF's last-known DB value.

---

## Appendix: Ground-truth references

- `git rev-parse HEAD` → `1b72127dc42ef0d18cd099486f95e1aabbf6f91c`
- `wc -l functions/index.js` → 295,765 bytes (~7,000 lines)
- CLAUDE.md mentions Node 20; actual runtime is Node 22
- CLAUDE.md does not mention the React admin dashboard or the business_logos storage path
- Requested output path was `/Users/bonstrahegmail.com/Development/projects/qr_wallet/QR_WALLET_AUDIT.md` (macOS); audit was run on Linux so the document was written to `/home/user/Claude_qr_wallet/QR_WALLET_AUDIT.md` (actual repo root).







