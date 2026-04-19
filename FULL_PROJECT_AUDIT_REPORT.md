# QR Wallet Full Project Audit Report

Prepared for: Project Stakeholders  
Project: QR Wallet  
Repository: `qr_wallet`  
Audit Scope: Flutter mobile app, Firebase backend, Cloud Functions, Firebase rules, storage rules, and admin dashboard  
Audit Date: April 17, 2026

## Executive Summary

This audit reviewed the QR Wallet project across its full application surface, including frontend flows, backend transaction handling, Firebase security controls, KYC enforcement, payment integration, and the admin dashboard.

The project has a solid architectural direction in several important areas:

- Financial writes are mostly centralized in Cloud Functions.
- Firestore rules block direct client writes to core wallet balances and transaction collections.
- Paystack webhooks implement signature verification.
- MoMo flows include callback cross-verification.
- QR signing includes nonce-based replay protection.
- Transaction PIN handling is server-side.

However, the current implementation also contains several high-risk issues that should be treated as release-blocking:

- KYC verification can be bypassed through callable and webhook paths.
- Payment flows contain double-credit risk under race conditions.
- A super-admin bootstrap path remains exposed in production behavior.
- Admin account recovery exposes raw OTP codes to staff.
- Some trust-sensitive user fields remain client-writable.

Overall assessment:

- Security posture: Moderate to weak in its current state for a financial product
- Operational readiness: Partial
- Production readiness for regulated money movement: Not recommended until critical issues are remediated

## Scope Reviewed

The following areas were reviewed:

- Flutter mobile application under `lib/`
- Firebase Cloud Functions under `functions/index.js`
- Firestore security rules in `firestore.rules`
- Firebase Storage rules in `storage.rules`
- Admin dashboard under `admin-dashboard/`
- Payment callback page under `public/payment-callback.html`
- Basic project verification via `flutter analyze`, `flutter test`, and admin dashboard build tooling

## Methodology

The audit was performed through:

- Source code review of high-risk modules
- Trust-boundary analysis
- Authentication and authorization review
- Payment flow and state consistency review
- KYC and onboarding flow review
- Static verification using available build and test commands

This was a code-level audit and not a live penetration test against deployed infrastructure.

## Overall Status

### Working Areas

The following areas appear structurally sound or partially well-implemented:

- Wallet and transaction writes are primarily restricted to backend functions.
- Firestore rules appropriately deny direct client writes to `wallets`, `transactions`, `payments`, `withdrawals`, `wallet_holds`, `idempotency_keys`, and related sensitive collections.
- Paystack webhook verification is implemented with HMAC signature checking.
- MTN MoMo webhook processing includes additional transaction status cross-verification.
- QR signing and verification use signed payloads and replay-protected nonces.
- Account blocking and PIN changes are processed server-side.
- Admin dashboard production build succeeds.

### Not Working or Not Reliable

The following areas are broken, incomplete, or not reliable enough for a financial system:

- KYC trust model is not consistently enforced.
- Some onboarding and wallet-creation paths allow state transitions before verification is complete.
- Payment crediting logic is vulnerable to duplicate processing in some races.
- The test suite is not functioning as a useful quality gate.
- Admin reporting contains data mismatches and likely inaccurate statistics.

## Critical Findings

### 1. KYC can be forged through the Smile ID webhook

Severity: Critical

The Smile ID webhook endpoint accepts POST requests and processes verification outcomes, but it does not validate a Smile ID webhook signature or equivalent server-side authenticity proof before setting `kycStatus: 'verified'` and creating a wallet.

Impact:

- An attacker who can submit a crafted request with a valid-looking payload can force KYC completion for a user.
- This directly affects access to regulated financial operations.

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:7767)

Recommendation:

- Add mandatory webhook authenticity verification before any user state mutation.
- Reject unsigned or unverifiable webhook payloads.
- Log and alert on invalid webhook attempts.

### 2. `markUserAlreadyEnrolled` allows direct self-service KYC bypass

Severity: Critical

Any authenticated user can call `markUserAlreadyEnrolled`, which immediately sets their own `kycStatus` to `verified` and may create a wallet, without requiring trusted proof from Smile ID or an admin-controlled verification process.

Impact:

- Users can promote themselves to verified financial status.
- This bypasses the intended KYC trust model.

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:2896)

Recommendation:

- Remove this callable from public client access.
- Replace it with a strictly server-trusted workflow.
- If this path is needed, it should only be triggered after verified upstream evidence.

## High Findings

### 3. Paystack deposits can be double-credited

Severity: High

The client verification path (`verifyPayment`) and the webhook path (`handleSuccessfulCharge`) both credit wallets. Each checks whether the payment has already been processed, but that check is performed outside the transaction that performs the credit. Under concurrent execution, both paths may pass the check and both may credit the wallet.

Impact:

- Duplicate deposits
- Financial loss
- Reconciliation failures

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:1002)
- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:1210)

Recommendation:

- Move the processed-payment guard fully inside a single Firestore transaction.
- Ensure the transaction reads and writes the same canonical payment state document before balance updates.
- Prefer webhook-driven final credit with idempotent settlement semantics.

### 4. Mobile money deposits can also be double-credited

Severity: High

In `chargeMobileMoney`, the immediate-success branch credits the wallet directly but does not mark the payment in the same canonical `payments` collection used by the webhook path. If a later success callback arrives, it may be credited again through webhook handling.

Impact:

- Duplicate mobile money deposits
- Ledger inconsistency

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:1815)
- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:1210)

Recommendation:

- Use one canonical settlement record for all deposit sources.
- Do not credit money in more than one success path without a shared processed-state lock.

### 5. Super-admin bootstrap remains active in runtime behavior

Severity: High

`setupSuperAdmin` can still be invoked by authenticated users whose email is included in the allowlist, and the admin dashboard attempts to self-promote users automatically on login if no role is present.

Impact:

- Persistent privilege-escalation path
- Increased risk if an allowlisted mailbox is compromised

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:4304)
- [AuthContext.jsx](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/admin-dashboard/src/contexts/AuthContext.jsx:45)

Recommendation:

- Remove self-promotion behavior from the dashboard.
- Disable or delete bootstrap promotion logic after initial provisioning.
- Move admin provisioning to a one-time controlled operational process.

### 6. Recovery OTP is exposed to support staff in the response body

Severity: High

`adminSendRecoveryOTP` returns the raw OTP to the dashboard response and the dashboard flow is designed to show it to staff.

Impact:

- Weakens account recovery integrity
- Creates an insider misuse and support-account takeover risk

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:4806)

Recommendation:

- Stop returning raw OTP values to the client.
- Deliver OTP only through the intended out-of-band channel.
- Require stronger recovery workflows for high-value accounts.

## Medium Findings

### 7. Wallet creation is possible before verification is complete

Severity: Medium

`createWalletForUser` does not enforce KYC or phone-verification prerequisites.

Impact:

- Unverified users may receive wallet identifiers too early
- Downstream flows can operate on accounts that should still be gated

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:2777)

Recommendation:

- Require authoritative verification status before wallet creation.
- Centralize wallet creation to trusted post-verification transitions only.

### 8. Inconsistent wallet schema in one KYC bypass path

Severity: Medium

`markUserAlreadyEnrolled` creates wallets without `heldBalance` and `availableBalance`, while other wallet creation flows include them.

Impact:

- Inconsistent data shape
- Risk of malfunction in hold-related or balance-derived logic

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:2947)

Recommendation:

- Enforce one wallet schema across all creation paths.
- Add backend validation or schema migration for legacy/incomplete wallet documents.

### 9. Trust-sensitive user fields remain writable by the client

Severity: Medium

Firestore rules protect `kycStatus`, `pinHash`, `pinSalt`, `accountBlocked`, and `role`, but a broad range of other trust-relevant flags remain client-writable, including fields such as `phoneVerified`, `kycCompleted`, and similar metadata.

Impact:

- Frontend guards and admin views can be misled
- Security assumptions become inconsistent between UI and backend

Evidence:

- [firestore.rules](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/firestore.rules:53)

Recommendation:

- Treat verification and trust fields as server-only.
- Reduce user document write scope to profile-safe fields only.

### 10. Route guard fails open on Firestore errors

Severity: Medium

The router allows navigation if KYC checks fail due to runtime errors.

Impact:

- Protected screens may become reachable during backend failures or offline states
- Confusing user experience and inconsistent access behavior

Evidence:

- [app_router.dart](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/lib/core/router/app_router.dart:201)

Recommendation:

- Fail closed for routes that require verified backend state.
- Show a loading or retry screen instead of allowing protected navigation after failed checks.

### 11. Payment callback page contains reflected XSS risk

Severity: Medium

The hosted callback page writes the payment reference into the DOM using `innerHTML` without sanitization.

Impact:

- Reflected XSS on the callback domain
- Increased risk if that page is reused or embedded elsewhere

Evidence:

- [payment-callback.html](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/public/payment-callback.html:17)

Recommendation:

- Replace `innerHTML` with safe text-node rendering.
- Treat all query parameters as untrusted input.

## Low Findings

### 12. Admin dashboard statistics are not aligned with actual backend data

Severity: Low

`adminGetStats` counts `kycStatus == 'completed'`, while the backend primarily uses `verified`, `pending_review`, and `failed`. It also queries a top-level `transactions` collection that is not the app’s main transaction storage path.

Impact:

- Misleading dashboard metrics
- Incorrect operational reporting

Evidence:

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:4999)

Recommendation:

- Align dashboard queries with the real source-of-truth schema.

### 13. Admin user details use field names inconsistent with signup writes

Severity: Low

The signup flow stores `country` and `currency`, while the admin detail response reads `countryCode` and `currencyCode`.

Impact:

- Blank or incorrect fields in admin views

Evidence:

- [auth_service.dart](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/lib/core/services/auth_service.dart:35)
- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js:4624)

Recommendation:

- Standardize field naming across app, backend, and admin dashboard.

## Frontend Audit Summary

### What is working

- App startup structure is coherent.
- Riverpod-based state organization is usable.
- The application routing model is clear and feature-oriented.
- Screens for send, receive, wallet, auth, and profile are organized sensibly.

### What is not working well

- Trust-sensitive frontend gating depends on mutable user-document flags.
- Some onboarding transitions rely on client-side document updates instead of authoritative backend workflows.
- Error handling often falls back to permissive behavior in route guards.

### Improvement opportunities

- Move all verification state transitions fully server-side.
- Reduce frontend reliance on Firestore document shape as an authorization source.
- Add stronger screen-level state handling for partial onboarding, retries, and backend failures.

## Backend Audit Summary

### What is working

- Cloud Functions are the main path for money movement.
- Several functions use idempotency helpers and structured logging.
- Core payment/provider abstractions are reasonably centralized.

### What is not working well

- Multiple success paths can mutate balances for the same payment.
- Some functions rely on checks outside the write transaction.
- KYC and wallet-creation trust boundaries are inconsistent.

### Improvement opportunities

- Introduce a single canonical ledger settlement path per payment type.
- Enforce consistent schema validation before every wallet mutation.
- Reduce callable surface area for sensitive account transitions.

## Firebase Rules Review

### Strengths

- Wallet writes are blocked from direct client access.
- Transaction writes are blocked from direct client access.
- Sensitive backend collections are server-only.

### Weaknesses

- `users/{uid}` updates are too permissive for a regulated product.
- Trust metadata should not be client-controlled.

## Admin Dashboard Review

### Positive observations

- Dashboard build succeeds.
- Role-aware UI logic exists.
- Admin activity logging is present.

### Risks

- Login flow includes self-promotion behavior.
- Recovery workflow exposes OTP values.
- Reporting data does not match backend reality in several places.

## Test and Verification Results

### Flutter analyze

Status: Completed

Result:

- `flutter analyze` reported 182 issues.
- Most findings were warnings or informational items.
- The codebase needs cleanup, but the analyzer output did not by itself prove a release blocker.

### Flutter test

Status: Failed

Result:

- The smoke test fails because Hive is not initialized before the app is bootstrapped in the test environment.
- The test also expects text that is not reliably present.

Evidence:

- [widget_test.dart](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/test/widget_test.dart:1)

Assessment:

- The current test suite is not functioning as a meaningful regression safety net.

### Admin dashboard build

Status: Passed

Result:

- `npm run build` completes successfully for the admin dashboard.

### Admin dashboard tests

Status: Not available

Result:

- No `npm test` script is defined.

## Priority Remediation Plan

### Immediate

- Secure or disable the Smile ID webhook until authenticity verification is enforced.
- Remove or restrict `markUserAlreadyEnrolled`.
- Fix duplicate deposit processing in Paystack and mobile money flows.
- Remove self-promotion behavior from admin login.
- Stop returning recovery OTPs to the dashboard.

### Near-Term

- Lock down client-writable trust fields in `users/{uid}`.
- Require KYC verification before wallet creation.
- Normalize all wallet creation paths to the same schema.
- Fix route guards to fail safely.
- sanitize the payment callback page.

### Medium-Term

- Align admin reporting with real data structures.
- Expand automated tests for onboarding, KYC, deposits, withdrawals, and admin flows.
- Add reconciliation checks for deposits and withdrawals.
- Add schema validation and migration coverage for legacy documents.

## Final Assessment

QR Wallet demonstrates a promising core structure and several good backend security patterns, but it is not yet at the standard expected for a production financial application. The most serious concerns are not cosmetic defects; they are trust-boundary failures in KYC and payment settlement.

The project should be considered a strong prototype or partially hardened pre-production system, but not yet safe for full production rollout until the critical and high findings above are resolved.

## Appendix: Key Reference Files

- [functions/index.js](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/functions/index.js)
- [firestore.rules](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/firestore.rules)
- [storage.rules](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/storage.rules)
- [app_router.dart](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/lib/core/router/app_router.dart)
- [auth_service.dart](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/lib/core/services/auth_service.dart)
- [payment-callback.html](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/public/payment-callback.html)
- [AuthContext.jsx](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/admin-dashboard/src/contexts/AuthContext.jsx)
- [widget_test.dart](/Users/bonstrahegmail.com/Development/Projects/qr_wallet/test/widget_test.dart)
