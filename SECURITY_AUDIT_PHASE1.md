# Security Audit — Phase 1: Security & Logic Review

**Date:** 2026-03-13
**Scope:** Cloud Functions (`functions/index.js`), Firestore/Storage Rules, Flutter App (`lib/`), Admin Dashboard
**Total Findings:** 45 (5 Critical, 9 High, 18 Medium, 13 Low)

---

## 1. CRITICAL Issues (5)

### C-1: smileIdWebhook Has Zero Authentication
```
[🔴 CRITICAL] File: functions/index.js (line ~7431)
Issue: smileIdWebhook has no signature verification, no token check, no IP
       allowlist. Compare with momoWebhook (token + cross-verification) and
       paystackWebhook (HMAC-SHA512) -- both properly authenticated.
Impact: Any attacker who discovers the Cloud Functions URL can POST a forged
       payload containing any userId and resultCode '0220' to write
       kycVerified=true/isVerified=true on any user document. Combined with
       the KYC bug below, this is a full KYC bypass chain enabling
       unverified users to perform financial operations.
Fix: Verify the Smile ID webhook signature using HMAC with the API key,
     matching paystackWebhook and momoWebhook patterns. Alternatively,
     cross-verify by calling the Smile ID GET job status API before
     updating user state.
```

### C-2: KYC Auto-Verify Accepts Unverified Phone Number as Proof of Identity
```
[🔴 CRITICAL] File: functions/index.js (line ~2624)
Issue: enforceKyc() auto-verifies users in non-Smile-ID countries if
       userPhoneVerified is truthy. Line 2624 defines:
         userData.phoneVerified === true ||
         (userData.phoneNumber != null && userData.phoneNumber !== '')
       The second condition means ANY user who has a phoneNumber field
       populated (self-settable during registration) passes the check.
Impact: A user can bypass KYC entirely by: (1) registering with a non-Smile-ID
       country code, (2) setting any phone number during signup, (3) calling
       any financial function -> enforceKyc auto-verifies them. Full financial
       access with zero identity verification.
Fix: Change line 2624 to only trust the server-set boolean:
       const userPhoneVerified = userData.phoneVerified === true;
     Remove the phoneNumber non-empty fallback entirely. Add phoneVerified
     to Firestore rules protected fields.
```

### C-3: Admin Custom Claims Key Mismatch — Entire Admin System Broken
```
[🔴 CRITICAL] File: functions/index.js (line ~4155 vs ~4192)
Issue: verifyAdmin reads `claims.adminRole` (line 4155) but setupSuperAdmin
       sets `{ role: 'super_admin' }` (line 4192) and adminPromoteUser sets
       `{ role: newRole }` (line 4237). The key names don't match.
Impact: verifyAdmin will ALWAYS see role as undefined, making `!role` true,
       throwing "permission-denied" for ALL admin users. Either the entire
       admin dashboard is non-functional, or there is a separate undocumented
       mechanism setting adminRole.
Fix: Change line 4155 to: `const role = claims.role;`
     Or change all setCustomUserClaims calls to use { adminRole: newRole }.
     Verify which key is actually in use in production.
```

### C-4: Firestore Rules Allow Users to Self-Assign Admin Role
```
[🔴 CRITICAL] File: firestore.rules (line ~46, ~48)
Issue: User document create rule blocks kycStatus, pinHash, pinSalt but NOT
       the "role" field. Update rule enforces kycStatusUnchanged(),
       accountBlockedUnchanged(), pinHashUnchanged() but has no roleUnchanged()
       guard. A client can set { role: 'super_admin' } on create or update.
Impact: Direct privilege escalation. If Cloud Functions check the role field
       from Firestore (rather than custom claims), a user gains admin access
       by writing to their own document.
Fix: Block role on create:
       !request.resource.data.keys().hasAny(['kycStatus','pinHash','pinSalt','role','accountBlocked'])
     Add roleUnchanged() to the update rule.
```

### C-5: Wallet Create Rule Allows Arbitrary Starting Balance
```
[🔴 CRITICAL] File: firestore.rules (line ~96)
Issue: The wallet create rule `allow create: if isAuthenticated() &&
       request.auth.uid == walletId` has no field-level validation. A client
       can create their wallet document with { balance: 999999 }.
Impact: A user could mint money by creating a wallet with a non-zero balance,
       bypassing the Cloud Function createWalletForUser which enforces
       balance: 0.
Fix: Add: `&& request.resource.data.balance == 0;`
     Or change to `allow create: if false` and require all wallet creation
     through Cloud Functions only.
```

---

## 2. HIGH Issues (8)

### H-1: smileIdWebhook Sets Wrong KYC Fields — Webhook Is Dead Code
```
[🟡 HIGH] File: functions/index.js (line ~7486)
Issue: Webhook sets kycVerified=true, isVerified=true but NOT kycStatus.
       enforceKyc() exclusively checks userData.kycStatus === 'verified'.
Impact: Legitimate Smile ID verifications via webhook do NOT grant financial
       access. The webhook is functionally dead code.
Fix: Add kycStatus: 'verified' and kycStatusUpdatedAt to the webhook update.
```

### H-2: adminSendRecoveryOTP Returns Plaintext OTP in Response
```
[🟡 HIGH] File: functions/index.js (line ~4731-4734)
Issue: The OTP is returned in the function response body. Comment says
       "remove this line when going fully live."
Impact: If an admin account is compromised, attacker can request OTP for any
       user and immediately receive it, enabling full account takeover.
Fix: Remove otp from the return value. Rely solely on SMS delivery.
```

### H-3: Non-Transactional Wallet Reads in MoMo Functions — Double-Credit Risk
```
[🟡 HIGH] File: functions/index.js (lines ~6896, ~7336, ~7381)
Issue: momoCheckStatus and momoWebhook read wallets using db.collection()
       .where().get() INSIDE db.runTransaction() instead of transaction.get().
       Firestore transaction isolation only applies to transaction.get() reads.
Impact: Concurrent webhook deliveries or poll+webhook races could read the
       same stale balance and both credit the wallet, causing double-credit.
Fix: Look up wallet doc ref before the transaction, then use
     transaction.get(walletRef) inside it.
```

### H-4: momoCheckStatus FAILED Refund Is Not Atomic
```
[🟡 HIGH] File: functions/index.js (line ~6976-6989)
Issue: When momoCheckStatus detects a failed disbursement, the refund uses
       walletDoc.ref.update() directly — NOT inside a Firestore transaction.
Impact: Two concurrent momoCheckStatus calls could both detect FAILED status
       and both refund, doubling the user's balance.
Fix: Combine status update and wallet refund into a single transaction.
```

### H-5: sendMoney Recipient Wallet Read Not Transactionally Isolated
```
[🟡 HIGH] File: functions/index.js (line ~6396)
Issue: Recipient wallet is looked up via db.collection('wallets').where()
       .get() (a regular query) inside runTransaction, NOT transaction.get().
Impact: Two concurrent sends to the same recipient could read the same
       balance, and safeAdd would compute based on stale data, losing one credit.
Fix: Re-read recipient document using transaction.get(recipientDoc.ref).
```

### H-6: Hardcoded Fallback Exchange Rates Used Silently
```
[🟡 HIGH] File: lib/core/services/exchange_rate_service.dart (lines ~16-62)
Issue: Synchronous convert() uses _cachedRates ?? _fallbackRates with no
       staleness check. If Firestore is unreachable or cache expired, hardcoded
       development-time rates are used for real conversions.
Impact: Users could see and act on significantly wrong exchange rates.
Fix: Add staleness check. If rates are older than threshold (e.g., 1 hour),
     throw or return error rather than silently using stale rates.
```

### H-7: Financial Amounts Stored as IEEE 754 Doubles
```
[🟡 HIGH] File: lib/models/wallet_model.dart (line ~19), functions/index.js
Issue: Balance, amounts, fees, and spending limits are all stored as double
       (Dart) / Number (JS). Both are IEEE 754 floating point.
Impact: Rounding errors accumulate over many transactions. E.g., 0.1 + 0.2
       !== 0.3. Balance discrepancies compound across the platform.
Fix: Store amounts in smallest currency unit (kobo/cents) as integers, or
     adopt a Decimal library on both client and server.
```

### H-8: Unsigned Pending Offline Transactions in Local Cache
```
[🟡 HIGH] File: lib/core/services/local_storage_service.dart (lines ~133-162)
Issue: Pending offline transactions cached in Hive contain full transaction
       details (amounts, phone numbers, wallet IDs) with no integrity check.
Impact: If device is compromised, queued financial operations could be
       inspected or tampered with before server sync.
Fix: Add HMAC integrity check before storage. Validate all pending
     transaction data server-side when syncing.
```

---

## 3. MEDIUM Issues (17)

### M-1: markUserAlreadyEnrolled Callable by Any Authenticated User — KYC Bypass
```
[🟡 HIGH] File: functions/index.js (line ~2890)
Issue: Any authenticated user can call markUserAlreadyEnrolled, which
       unconditionally sets kycStatus='verified', creates KYC documents, and
       creates a wallet. The function never contacts SmileID to verify the
       "already enrolled" claim — it trusts the client's assertion entirely.
Impact: Complete KYC bypass for ANY authenticated user regardless of country
       or prior verification. This is a direct path to full financial access
       without identity verification.
Fix: Either: (a) restrict to admin-only via verifyAdmin('admin'), (b) call
     SmileID API to verify enrollment before setting kycStatus, or (c) remove
     this function and handle via completeKycVerification.
```
**NOTE: Elevated to HIGH severity — this is a direct, unconditional KYC bypass.**

### M-2: Cross-Currency Sends Not Converted Server-Side
```
[🟢 MEDIUM] File: lib/features/send/screens/confirm_send_screen.dart (lines ~59-79)
       + functions/index.js (line ~6428)
Issue: Server's sendMoney credits raw `amount` to recipient WITHOUT currency
       conversion: safeAdd(recipientData.balance, amount). The client shows
       a converted amount but the server ignores it.
Impact: User sees "Recipient receives X KES" but recipient actually receives
       the NGN amount added to their KES balance, corrupting their balance.
Fix: Implement server-side currency conversion in sendMoney function.
```

### M-3: Currency Update Blocked by Firestore Rules
```
[🟢 MEDIUM] File: lib/providers/currency_provider.dart (lines ~96-106)
Issue: setCurrency() attempts client-side Firestore wallet update, but rules
       set `allow update, delete: if false` for wallets.
Impact: Currency change succeeds locally but fails server-side, creating a
       mismatch between user profile currency and wallet currency.
Fix: Move wallet currency update to a Cloud Function.
```

### M-4: Weak Amount Validation in 4 Financial Functions
```
[🟢 MEDIUM] File: functions/index.js (lines ~1460, ~1821, ~6758, ~7042)
Issue: initiateWithdrawal, chargeMobileMoney, momoRequestToPay, momoTransfer
       use `!amount || amount <= 0` instead of requirePositiveNumber().
       String "100" passes this check.
Impact: Type coercion bugs, potential NaN propagation in financial operations.
Fix: Use requirePositiveNumber(amount, 'amount') consistently.
```

### M-5: Rate Limiter Fails Open on Firestore Errors
```
[🟢 MEDIUM] File: functions/index.js (line ~2280)
Issue: checkRateLimitPersistent catches all errors and returns true (allow).
Impact: During Firestore outage, all rate limiting silently disappears.
       Attacker could exploit outage window for unlimited operations.
Fix: Fail closed for financial operations (return false on error).
```

### M-6: chargeMobileMoney Sends Unvalidated Currency to Paystack
```
[🟢 MEDIUM] File: functions/index.js (line ~1839)
Issue: Line 1829 computes validatedCurrency but line 1839 sends raw
       `currency || 'NGN'` to Paystack. Validated value only for Firestore.
Impact: Payment currency and recorded currency could diverge.
Fix: Replace with `currency: validatedCurrency` in the Paystack request.
```

### M-7: MoMo Webhook Secret Exposed in Callback URL
```
[🟢 MEDIUM] File: functions/index.js (line ~6634)
Issue: MOMO_WEBHOOK_SECRET appended as query parameter in callback URL sent
       to MTN MoMo API.
Impact: Secret appears in MTN's logs, HTTP access logs, any intermediary
       proxy logs.
Fix: Use HMAC-based signature verification where secret never leaves server.
```

### M-8: User Input Interpolated into URLs Without Encoding
```
[🟢 MEDIUM] File: functions/index.js (lines ~1780, ~5349, ~1745, ~5317)
Issue: accountNumber, bankCode, country passed directly into Paystack API
       URLs without encodeURIComponent().
Impact: Query parameter injection or URL malformation.
Fix: Apply encodeURIComponent() to all user-provided URL values.
```

### M-9: Internal Error Messages Exposed to Clients
```
[🟢 MEDIUM] File: functions/index.js (lines ~5270, ~5567, ~5941)
       + lib/features/send/screens/confirm_send_screen.dart (line ~336)
Issue: Catch blocks expose error.message to clients. Flutter shows raw
       e.toString() in SnackBars.
Impact: Information disclosure of Firestore paths, API error details, stack
       traces aiding attackers.
Fix: Return generic errors to clients. Log details server-side only. Use
     ErrorHandler.getUserFriendlyMessage(e) in Flutter.
```

### M-10: adminExportUsers Exposes Full PII Without Masking
```
[🟢 MEDIUM] File: functions/index.js (lines ~4896-4928)
Issue: Exports all user data (phone, email, name, wallet balance, wallet ID)
       for up to 5,000 users with no PII masking.
Impact: Mass PII exposure if admin account is compromised. GDPR risk.
Fix: Apply PII masking for lower-tier admins. Generate secure download links.
```

### M-11: adminGetUserDetails Returns Full PII to All Admin Tiers
```
[🟢 MEDIUM] File: functions/index.js (lines ~4466-4488)
Issue: No field-level redaction based on caller role. Support-tier admin sees
       full cleartext phone, email, balance.
Impact: No least-privilege enforcement on admin data access.
Fix: Implement field-level visibility by role. Exclude pinHash/pinSalt.
```

### M-12: Platform Wallet Subcollections Have No Explicit Rules
```
[🟢 MEDIUM] File: firestore.rules (lines ~93-98)
Issue: wallets/platform/balances, fees, withdrawals subcollections have no
       rules. Currently denied by default, but subcollections are NOT covered
       by parent rules.
Impact: If anyone adds a recursive wildcard, platform financial data exposed.
Fix: Add explicit deny rules for all platform wallet subcollections.
```

### M-13: KYC Subcollection Allows Unrestricted Client Writes
```
[🟢 MEDIUM] File: firestore.rules (lines ~86-90)
Issue: users/{userId}/kyc/{docId} allows create/update with no field-level
       validation. User can write arbitrary data.
Impact: Forged KYC document references, manipulated selfie URLs, fake
       document numbers could be injected.
Fix: Restrict KYC writes to Cloud Functions only, or add field validation.
```

### M-14: accountBlockedUnchanged() Does Not Protect Metadata Fields
```
[🟢 MEDIUM] File: firestore.rules (line ~28)
Issue: Only checks accountBlocked equality, not accountBlockedAt,
       accountBlockedBy, or accountUnblockedAt.
Impact: Blocked user can tamper with audit trail metadata.
Fix: Expand helper to check all associated metadata fields.
```

### M-15: Fee Calculation Duplicated Client-Side and Server-Side
```
[🟢 MEDIUM] File: lib/providers/wallet_provider.dart (line ~390)
Issue: Fee formula (amount * 0.01).clamp(10, 100) duplicated in client and
       server. No preview/quote endpoint exists.
Impact: User sees one fee but could be charged differently if implementations
       diverge due to floating point or code changes.
Fix: Implement a server-side fee preview endpoint, or mark client fee as
     "estimated."
```

### M-16: Client-Side Wallet Creation Bypasses Validation
```
[🟢 MEDIUM] File: functions/index.js (lines ~2807-2880) + firestore.rules (line ~96)
Issue: Firestore rules allow client-side wallet creation, bypassing the
       blocked-account check, standard QRW-XXXX-XXXX-XXXX format, and
       user document walletId update.
Impact: A blocked user could create a wallet directly.
Fix: Change rule to `allow create: if false`.
```

### M-17: Exchange Rates Read Not Transactionally Isolated in sendMoney
```
[🟢 MEDIUM] File: functions/index.js (lines ~6449-6461)
Issue: Exchange rates document read via db.collection().get() inside
       transaction instead of transaction.get().
Impact: Low practical impact but violates consistent-read principle within
       a financial transaction.
Fix: Use transaction.get() for exchange rates document.
```

### M-18: chargeMobileMoney and initializeTransaction Have No Effective Rate Limiting
```
[🟢 MEDIUM] File: functions/index.js (lines ~1819, ~2055, ~2215-2226)
Issue: Both functions call enforceRateLimit but their operation names
       ('chargeMobileMoney', 'initializeTransaction') are missing from the
       RATE_LIMITS config object. When checkRateLimitPersistent receives an
       unknown operation, it logs a warning and returns true (allow).
Impact: These two financial functions have zero effective persistent rate
       limiting. An attacker can initiate unlimited mobile money charges or
       create unlimited Paystack payment sessions.
Fix: Add entries to the RATE_LIMITS object:
     chargeMobileMoney: { windowMs: 60*60*1000, maxRequests: 10, ... },
     initializeTransaction: { windowMs: 60*60*1000, maxRequests: 20, ... },
```

---

## 4. LOW Issues (13)

### L-1: print() Statements Leak Financial Data to Device Logs
```
[⚪ LOW] File: lib/core/services/wallet_service.dart (lines ~65, ~168, ~247)
Issue: print('LOOKUP RESPONSE: $data') logs transaction IDs, recipient
       names, amounts to device console (logcat on Android).
Fix: Remove or replace with debugPrint() which is stripped in release.
```

### L-2: PIN Hashed with Unsalted SHA-256 Locally
```
[⚪ LOW] File: lib/core/services/secure_storage_service.dart (line ~47)
Issue: PIN stored as SHA-256 hash without salt. 6-digit PIN = 1M combos,
       trivially brute-forceable if hash is extracted.
Fix: Use bcrypt/Argon2/PBKDF2 with per-user salt, or remove local hash
     and always verify server-side.
```

### L-3: Paystack Test Public Key Hardcoded with Default Value
```
[⚪ LOW] File: lib/core/services/payment_service.dart (line ~26)
Issue: pk_test_... hardcoded as defaultValue. TODO says to replace with
       pk_live_xxxxx for launch.
Fix: Remove defaultValue. Require PAYSTACK_PUBLIC_KEY via --dart-define.
```

### L-4: sendMoney Returns Separately Computed Balance
```
[⚪ LOW] File: functions/index.js (line ~6543)
Issue: Returns senderBalance - totalDebit (raw arithmetic) instead of the
       value from safeSubtract.
Fix: Return the safeSubtract result variable instead.
```

### L-5: deleteUserData Limited to 500 Documents Per Sub-Collection
```
[⚪ LOW] File: functions/index.js (line ~3100)
Issue: Sub-collection cleanup capped at 500 docs. Heavy users may have
       orphaned PII after deletion (GDPR Article 17 risk).
Fix: Loop in batches until each sub-collection is fully empty.
```

### L-6: Daily/Monthly Spending Limit Resets Capped at 500 Wallets
```
[⚪ LOW] File: functions/index.js (lines ~3297, ~3322)
Issue: resetDailySpendingLimits and resetMonthlySpendingLimits query with
       .limit(500). Platforms with 500+ wallets will have incomplete resets.
Fix: Implement pagination loop.
```

### L-7: getBanks/adminGetBanks Do Not Validate Country Parameter
```
[⚪ LOW] File: functions/index.js (lines ~1744, ~5314)
Issue: data.country || 'nigeria' passed directly to Paystack URL.
Fix: Validate against a whitelist of supported countries.
```

### L-8: chargeMobileMoney Uses Raw Currency Instead of Validated
```
[⚪ LOW] File: functions/index.js (line ~1839)
Issue: Sends raw currency || 'NGN' to Paystack instead of validatedCurrency.
Fix: Use validatedCurrency in the charge request.
```

### L-9: verifyPayment Reference Not URL-Encoded
```
[⚪ LOW] File: functions/index.js (line ~1027)
Issue: Payment reference interpolated into Paystack verification URL without
       encoding.
Fix: Use encodeURIComponent(reference).
```

### L-10: markUserAlreadyEnrolled Wallet Creation Not Transactional
```
[⚪ LOW] File: functions/index.js (lines ~2941-2952)
Issue: Uses direct set() outside transaction. Concurrent calls could
       overwrite a wallet, resetting balance to 0.
Fix: Use runTransaction with existence check.
```

### L-11: Zimbabwe Currency Symbol Inconsistency
```
[⚪ LOW] File: lib/core/constants/african_countries.dart (line ~175)
       vs lib/models/wallet_model.dart (line ~160)
Issue: african_countries.dart uses Z$ for ZWG, wallet_model.dart uses ZiG.
Fix: Standardize to one symbol.
```

### L-12: Fee Bounds Not Currency-Aware
```
[⚪ LOW] File: lib/features/send/screens/confirm_send_screen.dart (line ~51)
Issue: Fee minimum (10) and maximum (100) are in sender's local currency
       with no per-currency adjustment. 10 UGX = ~$0.003, 10 GBP = excessive.
Fix: Define per-currency fee bounds or use percentage-only model.
```

### L-13: momoCheckStatus Does Not Check accountBlocked Before Crediting
```
[⚪ LOW] File: functions/index.js (line ~6851)
Issue: momoCheckStatus checks auth and KYC but does not check accountBlocked
       before crediting the wallet when a MoMo collection succeeds.
Impact: A user blocked after initiating a MoMo collection can still poll for
       status and trigger a wallet credit. Window is narrow but allows a
       blocked user to receive funds.
Fix: Add accountBlocked check before the wallet credit path.
```

---

## Summary

| Severity | Count | Key Themes |
|----------|-------|------------|
| 🔴 CRITICAL | 5 | Unauthenticated webhook, KYC bypass, broken admin RBAC, privilege escalation via Firestore, wallet balance minting |
| 🟡 HIGH | 9 | Dead webhook code, OTP exposure, double-credit race conditions, stale exchange rates, floating-point finance, unsigned offline queue, markUserAlreadyEnrolled KYC bypass |
| 🟢 MEDIUM | 18 | Cross-currency corruption, missing input validation, rate limit fail-open, zero rate limiting on 2 functions, PII exposure, Firestore rule gaps |
| ⚪ LOW | 13 | Debug logging, unsalted PIN hash, hardcoded test keys, pagination limits, symbol inconsistencies, blocked user MoMo credit |

## Priority Remediation Order

1. **C-2**: Fix KYC auto-verify phoneNumber fallback (line 2624) — immediate full bypass
2. **C-1**: Add authentication to smileIdWebhook (line 7431) — external attack surface
3. **C-4**: Block role field in Firestore rules (lines 46, 48) — privilege escalation
4. **C-5**: Add balance validation to wallet create rule (line 96) — money minting
5. **C-3**: Fix admin claims key mismatch (line 4155) — admin system broken
6. **M-1**: Restrict markUserAlreadyEnrolled to admin-only or add SmileID verification — KYC bypass (elevated to HIGH)
7. **H-3/H-4**: Fix non-transactional wallet reads in MoMo functions — double-credit
8. **H-5**: Fix sendMoney recipient wallet read — lost credits
9. **H-2**: Remove plaintext OTP from admin response — account takeover
10. **M-2**: Implement server-side currency conversion — balance corruption
11. **M-18**: Add chargeMobileMoney and initializeTransaction to RATE_LIMITS config — zero rate limiting

## Positive Findings

The audit also identified several well-implemented security patterns:
- All 60+ onCall functions properly validate `context.auth`
- paystackWebhook and momoWebhook have proper signature verification
- Firestore rules correctly lock all financial write paths (transactions, linked accounts, bank accounts, cards)
- Sensitive server-only collections (rate_limits, audit_logs, payments, idempotency_keys, etc.) are fully locked
- accountBlocked is checked comprehensively across all user-facing financial functions
- enforceKyc is called on all financial functions
- enforceRateLimit is called on all financial functions with reasonable limits (5-30/hr)
- All user-scoped reads enforce isOwner(userId) — no cross-user data access
- Hive boxes are encrypted with AES using keys stored in SecureStorage
- No server-side secrets (Paystack secret key, MoMo API keys) found in Flutter code
- All Cloud Function calls use httpsCallable (HTTPS-only)
- Proper logout cleanup: both SecureStorage and LocalStorage cleared on sign-out
- Idempotency keys protect sendMoney, verifyPayment, initiateWithdrawal, momoTransfer
- sendMoney, verifyPayment, initiateWithdrawal use proper Firestore transactions for sender balance
