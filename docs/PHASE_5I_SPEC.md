# Phase 5i — Dispute Lifecycle Redesign with Escrow & Verified Release

**Status:** SPEC — not yet implemented
**Author conversation:** 2026-05-04
**Target file path in repo:** `docs/PHASE_5I_SPEC.md`
**Estimated implementation effort:** 3–5 working sessions
**Risk level:** HIGH — money-movement code, multi-component, customer-facing
**Prerequisites:** Phases 5e, 5f, 5g+5h must be deployed (already done as of 2026-05-04)

---

## How to Use This Document

This spec exists because Phase 5i is too large to investigate, design, and implement in a single conversation. Rather than risk shipping the wrong fix, the previous conversation invested its time in producing this document so a fresh conversation can:

1. Read sections 1–6 to understand **what** to build and **why**
2. Read sections 7–10 to find the **exact** code changes
3. Read sections 11–14 to plan the **deploy** safely
4. Use section 15 as a **reference** while implementing

**Do not deviate from this spec without flagging it explicitly.** Every design decision in here was reached by walking the operator (Eric) through tradeoffs and getting an explicit answer. If you (the implementing AI) think something should be different, that's a signal to ask Eric, not to change unilaterally.

**The Phase 5d cautionary tale applies in full.** That phase failed three times because the implementer assumed they understood the bug from a one-line description. This spec exists to prevent the same class of failure on a much larger and more dangerous fix. Take the time to read carefully before changing anything.

**Each step is testable independently.** The spec is structured so you can implement, deploy, and verify in stages — not all at once. Section 12 (Deployment Order) is binding: deploy in the listed order, verify each stage before proceeding.

---

## 1. Executive Summary

### What This Phase Builds

Phase 5i redesigns the dispute resolution lifecycle to add a **verified-release escrow model** between manager decision and money landing in the recipient's account. It also adds the missing seller-notification path, a buyer "partial release on demand" mechanism, the seller's right to respond before investigation, support for the "buyer owes seller" decision direction, and stuck-case detection with auto-archiving.

### Why It Matters (Eric's Words)

The current dispute system has the manager make a decision and money moves immediately as it becomes available — directly from seller's wallet to buyer's wallet. Eric pushed back on this:

> "I think it should not be refunded immediately... it should be held so that the support team will verify from both ends — yes the item has not been sent. Because in real life the item may have been returned but the app will not know, and also will deduct money from the seller to the buyer. So I prefer holding it, then admin, admin supervisor or manager confirm it after contacting both parties, then it is sent to the right person."

The current code assumes the manager's decision is a complete instruction: "refund 400 to buyer, do it as money becomes available." But manager decisions are made on the evidence the manager has at decision time. By the time recovery completes — which can take days, weeks, or months — physical reality may have changed:

- The seller may have actually delivered the goods after all
- The buyer may have received what they paid for and not reported it
- Both parties may have settled outside the app
- The dispute may have been frivolous and the buyer changed their mind

Without a human verification step before release, the app can cause **double recovery** (buyer gets refund AND keeps the goods) or **wrongful loss** (seller pays for something they actually delivered). Worse, once money has moved, undoing it is operationally hard.

The fix: introduce a **holding period** between manager decision and final release. During this period:
- Money is collected from seller into a platform-owned escrow wallet
- The dispute is in a `solved` state — agreement reached, money in flight
- Once fully collected, the dispute moves to `awaiting_release` — support team contacts both parties, verifies physical reality
- A **two-person admin release** then either sends the money to the buyer (`closed`) or returns it to the seller (reversal)

This is the standard escrow pattern used by mature financial-ops platforms. The current code's "auto-pay as collected" model is the unusual choice.

### The Operational Workflow This Enables

```
Buyer files dispute → Seller is notified → Seller can respond
  ↓
Admin assigned → Admin investigates (with seller's response visible)
  ↓
Admin submits findings → Supervisor reviews
  ↓
Supervisor agrees → Manager decides (refund/release/buyer-owes-seller)
  ↓ [for refund decisions]
Money collected from seller → Held in escrow wallet
  ↓
Once fully collected: support contacts both parties
  ↓
Support verifies: did delivery actually happen?
  ↓
Two admins agree on release → Money sent to buyer (closed)
  OR
Verification finds buyer wrong → Money returned to seller (closed_returned)
```

Plus the edge cases:
- Seller can never deposit enough → 90-day stuck timer → `closed_stuck`
- Seller's account closed → 3-day grace → `closed_stuck`
- Buyer requests partial release before full collection → admin verifies + releases what's collected, rest stays in flight
- Buyer cancels their own dispute → support verifies intent + closing remarks recorded

### Scope of This Phase (Eric's Final Confirmation)

In scope:
- ✅ Backend: state machine, escrow wallet, recovery flow rewrite, two-person release, reversal, stuck detection, buyer-owes-seller decision outcomes, all notifications, buyer self-service, seller appeal/response
- ✅ Flutter: full UI for new states, buyer's actions, seller's view
- ✅ Admin dashboard: verification UI, two-person release UI, stuck-case handling, evidence export
- ✅ Firestore rules: new states, escrow wallet, new fields
- ✅ Migration plan for existing `resolved` disputes
- ✅ Cloud Functions config for new scheduled jobs (90-day stuck check, 3-day account-closure check)

Out of scope (explicitly deferred):
- Translation/localization of new notification text (English only for v1)
- Push notifications via FCM beyond what already exists (SMS-first)
- Buyer's ability to upload additional evidence after dispute is `solved` (only allowed before manager decision)
- Bulk admin actions on multiple disputes
- Reporting/analytics on dispute outcomes (separate phase if needed)

---

## 2. Conventions Used in This Spec

**Code blocks marked `// FIND:`** are exact text to locate in the existing codebase. Match Case ON, Use Regular Expression OFF in VS Code.

**Code blocks marked `// REPLACE WITH:`** are exact text to substitute.

**Code blocks marked `// NEW FUNCTION:`** are entirely new code to add at a specified location.

**Field names** are referenced as `dispute.fieldName` for clarity, even though they live in a Firestore document.

**Roles** are referenced by their Firebase Auth custom claim values: `support`, `admin`, `admin_supervisor`, `admin_manager`, `super_admin`. The full hierarchy is defined in `functions/index.js:4499–4508`.

**"The implementing AI"** refers to whoever picks up this spec in a future conversation — likely Claude in a fresh session.

**"Eric"** is the operator. Wherever this document says "ask Eric," it means the implementing AI must pause and confirm via chat before proceeding.

**Money values** are stored in major units (e.g., 100.00 GHS, not pesewas). This convention is established throughout the codebase — do not change it.

**Currencies** mentioned: GHS (Ghana cedi), NGN (Nigerian naira). The system supports more — check `lib/core/constants/` and `app_config/exchange_rates` for the complete list at implementation time.

---

## 3. Current State (As of 2026-05-04)

This section documents what the code does **today**, before any Phase 5i changes. The implementing AI must read this carefully — the current code is more sophisticated than a casual reading suggests, and several apparent gaps turn out to be intentional design (just incomplete).

### 3.1 Dispute State Machine (Current)

```
filed                              [userFileDispute creates this]
  ↓
investigating                      [adminAssignDispute moves filed→investigating]
  ↓
supervisor_review                  [adminSubmitInvestigation moves investigating→supervisor_review]
  ↓
manager_review                     [adminSupervisorDecision: agree → manager_review]
                                   [adminSupervisorDecision: disagree_kickback → investigating, ONCE]
  ↓
resolved                           [adminManagerDecision: refund_full | refund_partial | release → resolved]
                                   [adminManagerDecision: kickback → investigating, ONCE]
  
super_admin_escalation             [Auto-set by disputeEscalationCheckScheduled after 5 days in manager_review]
  ↓
resolved                           [adminSuperAdminDisputeDecision: refund_full | refund_partial | release → resolved]
```

**File locations of each transition function:**
- `userFileDispute` — line 14052
- `adminAssignDispute` — line 14514
- `adminSubmitInvestigation` — line 14595
- `adminSupervisorDecision` — line 14670
- `adminManagerDecision` — line 14786
- `adminSuperAdminDisputeDecision` — line 15105
- `adminListDisputes` — line 15390
- `disputeEscalationCheckScheduled` — search the file (sets `super_admin_escalation` after 5-day timer)

### 3.2 Dispute Document Schema (Current)

A dispute document at `disputes/{disputeId}` has the following fields after `userFileDispute` runs (full set, line 14225–14260):

```
disputeId: string                          // primary key, format: DSP-{timestamp}-{hex}
status: string                             // see state machine above
originalTransactionId: string              // the disputed transaction ID
disputedAmount: number                     // amount in dispute, major units, source currency
disputedCurrency: string                   // source currency
usdEquivalent: number                      // disputedAmount converted to USD at filing time
filedBy: { uid, email, displayName, phoneNumber }
filedAt: timestamp
recipientUid: string                       // seller's UID, derived from tx.receiverWalletId
recipientEmail: string
recipientDisplayName: string
recipientPhoneNumber: string
issueType: string                          // 'money_sent_not_received' | 'service_not_delivered' | 'item_not_delivered' | 'other'
description: string                        // buyer's complaint, ≥10 chars
evidence: array                            // initially empty, intended for buyer evidence uploads
recipientResponse: null                    // RESERVED — seller's side of story (NEVER FILLED CURRENTLY)
recipientResponseAt: null                  // RESERVED
recipientEvidence: null                    // RESERVED
assignedAdmin: null | { uid, email, displayName }
investigationFindings: null | string       // ≥50 chars when filled
investigationSubmittedAt: null | timestamp
reviewingSupervisor: null | { uid, email, role, displayName }
supervisorDecision: null | 'agree' | 'disagree_kickback'
supervisorNotes: null | string             // ≥20 chars
supervisorDecidedAt: null | timestamp
reviewingManager: null | { uid, email, role, displayName }
managerDecision: null | 'refund_full' | 'refund_partial' | 'release' | 'kickback'
managerDecisionAmount: null | number       // for refund_partial
managerNotes: null | string
managerDecidedAt: null | timestamp
resolvedAt: null | timestamp
resolutionType: null | 'refund_full' | 'refund_partial_with_debt' | 'refund_pending_debt' | 'released'
amountRecovered: null | number             // amount actually moved to buyer
amountUnrecovered: null | number           // amount still owed (recovery watch handles)
currentHoldAmount: number                  // initially 0; placeOpportunisticHoldStub sets it
holdHistory: array                         // initially empty
feeCharged: number                         // dispute filing fee
feeRefunded: boolean                       // true if buyer wins and was charged at filing
feeDeductedFrom: 'wallet_at_filing' | 'recovery'
escalatedToSuperAdmin: boolean             // initially false
superAdminDecision: null | string
superAdminDecidedAt: null | timestamp
superAdminDecidedBy: null | { uid, email, role, displayName }
decidedByRole: null | 'manager' | 'super_admin'
stuckCaseFlag: boolean                     // initially false; meaning currently undefined
notificationsSent: object                  // map of notification keys to timestamps
graceTriggered: boolean                    // true if supervisor or manager kicked back once
graceTriggeredAt: null | timestamp
expectedResolutionBy: timestamp            // initially +3 days; +2 each kickback
_awaitingMoneyMovement: boolean            // private flag, always set to false on writes
_recoveryWatchActive: boolean              // private flag, true when wallet_debts exists
```

**Important:** the field names `recipientResponse`, `recipientResponseAt`, `recipientEvidence` are **already present in the schema** but are never populated by any code path. This is a reserved-but-not-implemented seller-response feature. Phase 5i will fill these in.

### 3.3 Money Flow at Decision Time (Current)

When `adminManagerDecision` is called with `decision === 'refund_full'` or `'refund_partial'` (line 14918–14930):

1. `requestedRefund` is computed (full disputed amount or partial amount)
2. `actualRefund = min(requestedRefund, currentHoldAmount)` — capped at what's currently in seller's `heldBalance`
3. `unrecovered = requestedRefund - actualRefund` — what's still owed

**Inside an atomic Firestore transaction (line 14952–15022):**
4. Recipient's wallet: `heldBalance -= actualRefund`, `balance -= actualRefund` (money leaves seller permanently)
5. Filer's wallet: `balance += netToFiler`, `availableBalance += netToFiler` (where `netToFiler` accounts for fee deduction)
6. If fee was deducted from filer's wallet at filing, refund the fee
7. If `unrecovered > 0`: create a `wallet_debts` document with `status: 'active'` and `disputeId` reference
8. Update dispute: `status: 'resolved'`, `_recoveryWatchActive: (unrecovered > 0)`, plus all the manager decision fields

After the transaction:
9. Mark all `wallet_blocks` for this dispute as lifted
10. Update `dispute_history` counters
11. Send SMS to filer and recipient (with hardcoded English text)

### 3.4 Recovery Watch (Current)

The `wallet_debts` collection drives a separate scheduled function (`recoveryWatchScheduled` or similar — search around line 15676) that:

1. Periodically scans `wallet_debts` where `status === 'active'`
2. Checks if the `recipientUid` has new available balance
3. Atomically deducts from recipient's wallet and credits the filer
4. Records a `debt_recoveries` entry
5. If `wallet_debts.amountOwed === wallet_debts.amountRecovered`, marks the debt `closed`

**This is the part that Eric said is wrong.** Today, money flows: seller's wallet → buyer's wallet directly. The Phase 5i change: seller's wallet → escrow wallet → (after verification) → buyer's wallet OR back to seller.

### 3.5 Notifications (Current)

Confirmed via grep: there are **no notifications** sent to the seller (`recipientUid`) when a dispute is filed. The seller learns about the dispute when:
- Their balance is held (no notification, just appears in their wallet)
- An admin contacts them by phone (manual)
- The dispute is resolved and an SMS goes out (only at decision time, not at filing time)

Three notification helper functions exist:
- `sendProposalEmail()` — line 858
- `sendCustomerSms()` — line 913
- `sendPushNotification()` — line 2601

All three are used in the current dispute flow except for filing-time seller notification.

### 3.6 Wallet Schema (Relevant Fields)

A wallet at `wallets/{uid}` has at minimum:

```
balance: number                            // total money including held; major units
availableBalance: number                   // spendable; major units
heldBalance: number                        // locked; major units
currency: string                           // single currency per wallet
walletId: string                           // human-readable; format: QRW-XXXX-XXXX-XXXX
updatedAt: timestamp
```

**Invariant:** `balance === availableBalance + heldBalance` for any user wallet. This must remain true after Phase 5i changes.

### 3.7 Existing Helper Patterns to Reuse

Eric's code already uses these patterns. Phase 5i should not invent new versions:

- **Two-person approval:** see `platform_transfer_proposals` collection and `adminApproveTransfer` flow. This pattern (proposer + approver, different uids, both required) will be reused for two-person release.
- **Idempotency keys:** every admin action requires `idempotencyKey` parameter ≥16 chars. Continue this for all new functions.
- **Rate limiting:** see `RATE_LIMITS` config (line 2471) and `checkRateLimitPersistent`. New functions need rate limit entries.
- **Audit logging:** every admin action writes to `audit_logs` and `admin_activity` collections. Continue this.
- **Atomic transactions:** every money-moving operation uses `db.runTransaction`. Continue this.
- **App Check:** every callable uses `runWith({ enforceAppCheck: true })`. Continue this.

### 3.8 What Currently Works Correctly (Do Not Break)

The implementing AI must preserve these behaviors:

- The 7-day filing window
- The max-3-active-disputes-per-filer limit
- The fee calculation (tiered by USD equivalent)
- The fee deduction from filer's wallet at filing if balance allows, else from recovery
- The supervisor/manager kickback-once limit
- The 5-day auto-escalation to super_admin
- The `_recoveryWatchActive: false` flag pattern (or equivalent) at status transitions
- The lifting of `wallet_blocks` at terminal states
- The `dispute_history` counter updates
- The audit and admin_activity logging
- The 50-character minimum notes requirement on every admin action
- The 20-character minimum on supervisor decision notes
- The 50-character minimum on investigation findings

---

## 4. Target State (After Phase 5i)

### 4.1 New Dispute State Machine

```
filed
  ↓ [adminAssignDispute]
investigating  ←──────┐
  ↓ [adminSubmitInvestigation]   │ kickback (once)
supervisor_review  ───┘
  ↓ [adminSupervisorDecision: agree]
manager_review
  ↓ [adminManagerDecision]
  ├─ release             →  closed
  ├─ refund_full         →  solved          (collecting from seller into escrow)
  ├─ refund_partial      →  solved
  ├─ buyer_owes_seller   →  solved          (collecting from buyer into escrow)  [NEW Q-L]
  └─ kickback (once)     →  investigating

solved                    [Recovery Watch deposits collected funds into escrow wallet]
  ↓ [when fully collected: automatic]
awaiting_release          [support team contacts both parties, verifies physical reality]
  ↓ [adminProposeDisputeRelease + adminConfirmDisputeRelease — two persons]
  ├─ release_to_payee     →  closed              (money sent to the party owed)
  └─ reverse_to_payer     →  closed_returned     (verification finds payer was right; money goes back)

solved
  ├─ [scheduled job] dispute_account_closed_check →  3 days after detection →  closed_stuck
  └─ [scheduled job] dispute_no_progress_check    →  90 days zero deposits  →  closed_stuck

solved
  └─ [adminCancelOnBuyerRequest]  [buyer asks to cancel; support verifies reason]
                                     →  closed_buyer_cancelled

solved
  └─ [userRequestPartialRelease]  [buyer says "release what's collected now"]
                                     →  awaiting_release  (only the collected portion;
                                                          remainder continues collecting)

super_admin_escalation
  ↓ [adminSuperAdminDisputeDecision]
  └─ same outcomes as adminManagerDecision  →  same target states
```

**Plain-English summary of the new states:**

| State | Meaning | User-visible text suggestion |
|---|---|---|
| `filed` | Buyer just filed | "Dispute received" |
| `investigating` | Admin is looking into it | "Under investigation" |
| `supervisor_review` | Admin submitted findings; supervisor reviewing | "Awaiting supervisor review" |
| `manager_review` | Supervisor agreed; manager deciding | "Awaiting manager decision" |
| `super_admin_escalation` | Auto-escalated after 5 days in manager_review | "Escalated for executive review" |
| **`solved` (NEW)** | Decision made; collecting & holding money in escrow | "Decision made. Recovering funds…" |
| **`awaiting_release` (NEW)** | Money fully collected; support verifying before release | "Funds collected. Pending verification before release." |
| **`closed` (NEW)** | Money released to the party owed | "Resolved" |
| **`closed_returned` (NEW)** | Verification reversed the decision; money returned | "Resolved — funds returned to recipient" |
| **`closed_stuck` (PROMOTED)** | Recovery impossible (account closed or 90+ days dormant) | "Closed — recovery not possible" |
| **`closed_buyer_cancelled` (NEW)** | Buyer requested cancellation, support verified | "Closed — cancelled by buyer" |

### 4.2 Money Flow (New Model)

**Escrow wallet pattern (Q-A confirmed):** ONE platform-owned wallet per currency.

Document path: `wallets/dispute_recovery_<CURRENCY>`. Examples:
- `wallets/dispute_recovery_GHS`
- `wallets/dispute_recovery_NGN`
- `wallets/dispute_recovery_USD`

These docs are created on first use (lazy-initialized by helper `getOrCreateRecoveryWallet(currency)`). Schema:

```
walletId: 'PLATFORM-DISPUTE-RECOVERY-<CURRENCY>'
balance: number                        // sum of all escrowed amounts in this currency
availableBalance: number               // === balance for these wallets (no concept of held)
heldBalance: 0                         // always 0 for platform wallets
currency: string                       // matches the suffix
isPlatform: true                       // marker — security rules use this
createdAt: timestamp
updatedAt: timestamp
```

**Money flow at decision time** (manager rules `refund_full`):

Old model:
```
seller.heldBalance──→ buyer.balance
```

New model:
```
seller.heldBalance ──→ wallets/dispute_recovery_GHS.balance
                       (parked here, with audit trail tying it to disputeId)

[time passes, support verifies]

wallets/dispute_recovery_GHS.balance ──→ buyer.balance      (release_to_payee)
                                  OR
wallets/dispute_recovery_GHS.balance ──→ seller.balance     (reverse_to_payer)
```

**Money flow during Recovery Watch** (when seller didn't have full amount at decision time):

Old model:
```
[seller deposits 100]  →  recovery watch deducts 100 from seller  →  buyer.balance += 100
```

New model:
```
[seller deposits 100]  →  recovery watch deducts 100 from seller  →  wallets/dispute_recovery_GHS.balance += 100
                                                                     dispute.amountInEscrow += 100
                                                                     [seller is notified per-deduction]
```

When `dispute.amountInEscrow >= dispute.amountOwed`, the dispute auto-transitions `solved → awaiting_release`.

### 4.3 New Decision Outcomes (Q-L Includes "Buyer Owes Seller")

The manager's `VALID_DECISIONS` array expands from:

```javascript
const VALID_DECISIONS = ['refund_full', 'refund_partial', 'release', 'kickback'];
```

To:

```javascript
const VALID_DECISIONS = [
  'refund_full',           // existing — buyer made whole, seller owes the disputed amount
  'refund_partial',        // existing — buyer gets partial, seller owes the partial amount
  'release',               // existing — no money moves, hold lifted
  'kickback',              // existing — back to investigating (once)
  'buyer_owes_seller_full',     // NEW — buyer owes the full disputed amount to seller
  'buyer_owes_seller_partial',  // NEW — buyer owes a partial amount to seller
];
```

Same expansion for `adminSuperAdminDisputeDecision` (which doesn't have `kickback`):

```javascript
const VALID_DECISIONS = [
  'refund_full', 'refund_partial', 'release',
  'buyer_owes_seller_full', 'buyer_owes_seller_partial',
];
```

When a `buyer_owes_seller_*` decision is made, the recovery flow runs in the OPPOSITE direction:

- `buyer.heldBalance` is the source (need to opportunistically hold buyer's wallet at filing time too — see section 6.7)
- Money flows: buyer.heldBalance → escrow → (after verification) → seller.balance OR back to buyer
- New field on dispute: `decisionDirection: 'refund_to_buyer' | 'pay_to_seller'`
- New per-direction recovery flow

### 4.4 Notification Matrix (After Phase 5i)

| Event | Filer (Buyer) | Recipient (Seller) | Admin Side |
|---|---|---|---|
| Dispute filed | SMS confirmation | **NEW: SMS notifying of dispute** with disputeId, brief description, link to respond | Supervisors/admins notified via existing email path when admin assigned |
| Seller responds (NEW) | Notified that seller responded | n/a | Investigating admin notified |
| Admin assigned | (existing, no change) | (existing, no change) | (existing) |
| Investigation submitted | (no notification — internal step) | (no notification) | Supervisors emailed (existing) |
| Supervisor decides | (no notification — internal step) | (no notification) | Manager emailed (existing) |
| Manager decides — refund | "Decision: <decision>. Recovering <amount> <currency>." | "Decision: <decision>. <amount> <currency> will be deducted from your wallet over time." | (existing audit log) |
| Manager decides — release | "Dispute closed in favor of recipient." | "Dispute resolved in your favor. Hold lifted." | (existing) |
| Manager decides — buyer_owes_seller (NEW) | "Decision: you owe <amount> <currency> to recipient. Will be deducted from your wallet." | "Decision: <amount> <currency> will be transferred to you over time." | (existing audit log) |
| **Recovery deduction (NEW Q-F)** | "<amount> <currency> recovered for dispute <disputeId>. Total recovered: <X>/<Y>." | "<amount> <currency> held from your wallet for dispute <disputeId>." (per-deduction) | (audit log per recovery) |
| **Fully collected, awaiting verification (NEW)** | "All <amount> <currency> collected. Support team will verify before release." | "All amounts collected for dispute <disputeId>. Support will verify outcome." | Admin dashboard: dispute appears in "Awaiting Release" queue |
| Buyer requests partial release (NEW) | (confirmation SMS after request) | n/a | Admin dashboard: appears in queue |
| **Two-person release proposed (NEW)** | n/a | n/a | Email to all admins (level admin+) of any role of: "Release proposed for dispute <disputeId> by <admin>. Awaiting second confirmation." |
| **Release confirmed (NEW)** | "Dispute <disputeId> resolved. <amount> sent to your wallet." | "Dispute <disputeId> resolved. Funds released to other party." | (existing audit log) |
| **Reversal to payer (NEW)** | "Dispute <disputeId> verification reversed the decision. Funds returned to other party." (Note: this can be confusing to the buyer; phrasing carefully) | "Dispute <disputeId> verification confirmed in your favor. Funds returned to your wallet." | (audit log) |
| **Closed stuck — account closed (NEW)** | "Dispute <disputeId> cannot be resolved through the platform — recipient's account is closed. Contact authorities for assistance. Evidence package available on request." | n/a (account closed) | (audit log) |
| **Closed stuck — 90 days dormant (NEW)** | "Dispute <disputeId> has been closed due to no recovery progress in 90 days. Contact support if circumstances change." | "Dispute <disputeId> closed. Outstanding balance is no longer being deducted." | (audit log) |

### 4.5 Two-Person Release Pattern (Q-J Confirmed: Combined Option 1 + Option 3)

Eric chose: **System logs who released the money AND two-person release**. This means:

1. Admin A clicks "Propose Release" on a dispute in `awaiting_release` state.
   - A.1 Modal pops up: forced confirmation checkboxes:
     - ☐ "I have personally contacted the buyer and verified outcome"
     - ☐ "I have personally contacted the seller and verified outcome"
     - ☐ "Decision direction (release_to_payee or reverse_to_payer)" radio
     - Notes textarea (≥50 chars)
   - A.2 On submit: calls `adminProposeDisputeRelease`.
   - A.3 Dispute moves to internal `releaseProposed` state (sub-state, not main status). Dispute remains visible in `awaiting_release` queue with a "Proposal pending" badge.
2. Email goes out to all `admin+` users (any of admin/admin_supervisor/admin_manager/super_admin) **except admin A** announcing: "Release proposal for dispute X. Click to review."
3. Admin B clicks the link, sees the proposal + admin A's notes + the dispute history.
   - B.1 Same forced confirmations (must independently verify).
   - B.2 Admin B can: **Approve** (calls `adminConfirmDisputeRelease`) or **Reject** (calls `adminRejectDisputeRelease` with reason).
   - B.3 Reject sends the dispute back to plain `awaiting_release` (proposal cleared). A new proposal can be made.
   - B.4 Approve atomically:
     - Moves money from escrow to the receiving party
     - Updates dispute status to `closed` or `closed_returned`
     - Logs both admins (proposer and confirmer) on the dispute doc
4. **Admin B MUST be a different uid from Admin A.** Enforced server-side. Anyone admin+ in role can be either A or B (Eric: "all three can do it" referring to admin/supervisor/manager).
5. **24-hour proposal expiry.** If admin B doesn't respond within 24h, the proposal auto-expires and clears. Admin A or anyone else can propose again.
6. **Audit trail records both admins separately.** Each gets their own entry in `admin_activity`, plus the dispute doc has `releaseProposedBy` and `releaseConfirmedBy` fields.

### 4.6 Stuck-Case Detection (Q-G Confirmed)

Two scheduled functions, running daily.

**`disputeAccountClosureCheckScheduled`** — runs daily.
For each dispute in `solved` state with `_recoveryWatchActive: true`:
1. Fetch the recipient's user doc.
2. If user doc doesn't exist OR user doc has `accountDeleted: true` (or equivalent — check what the existing user-deletion code sets):
   - If `dispute.accountClosureDetectedAt` is null, set it to now (start the 3-day clock).
   - Else if (now - accountClosureDetectedAt) >= 3 days, transition to `closed_stuck` with closing remarks template:
     ```
     "Recovery impossible — recipient account closed on <date>. Buyer advised to contact authorities. Evidence package available on request."
     ```
3. **Manual override:** an admin (admin+ role) can call `adminMarkDisputeAccountClosed(disputeId, evidence)` to set `dispute.accountClosureDetectedAt` immediately rather than wait for the daily job.

**`disputeNoProgressCheckScheduled`** — runs daily.
For each dispute in `solved` state with `_recoveryWatchActive: true`:
1. Compute `daysSinceLastDeduction = (now - dispute.lastRecoveryDeductionAt) / 1 day` (use `dispute.solvedAt` if no deduction yet).
2. Also check seller's wallet activity: `daysSinceSellerLastDeposit = (now - sellerWallet.lastDepositAt) / 1 day`.
3. If `min(daysSinceLastDeduction, daysSinceSellerLastDeposit) >= 90`:
   - Transition to `closed_stuck` with closing remarks template:
     ```
     "Recovery progress stalled — no deductions or deposits in 90 days. Buyer may contact support for evidence package or to escalate."
     ```

**Q-G3 confirmed:** Dispute fee is **NOT** refunded on `closed_stuck`. The buyer paid for the investigation service which was rendered.

### 4.7 Buyer Self-Service Actions (Q-E Confirmed)

These new buyer-callable functions:

**`userRequestPartialRelease(disputeId)`**
- Caller must be `dispute.filedBy.uid`.
- Dispute must be in `solved` with `dispute.amountInEscrow > 0` AND `dispute.amountInEscrow < dispute.amountOwed`.
- Action:
  - Sets `dispute.partialReleaseRequested: true`, `dispute.partialReleaseRequestedAt: serverTimestamp`.
  - Triggers admin email: "Buyer X requested partial release on dispute Y. Verify intent and proceed via Two-Person Release flow."
  - **Does NOT auto-release.** Admin must still go through Two-Person Release with explicit confirmation that they contacted the buyer and verified intent.
  - After release, dispute remains in `solved` for the unrecovered portion; the dispute doc records `partialReleasedAt` and `partialReleasedAmount` for history.

**`userCancelDispute(disputeId, reason)`**
- Caller must be `dispute.filedBy.uid`.
- Dispute must be in `filed`, `investigating`, `supervisor_review`, `manager_review`, OR `solved` (NOT in `awaiting_release` or any closed state — at that point it's too late).
- Action:
  - Sets `dispute.cancellationRequested: true`, `dispute.cancellationRequestedAt: serverTimestamp`, `dispute.cancellationReason: reason` (≥20 chars).
  - Triggers admin email.
  - **Does NOT auto-cancel.** A support+ admin must call `adminConfirmCancellation(disputeId, supportNotes)` after contacting the buyer.
  - On confirmation: dispute → `closed_buyer_cancelled`. Money flow:
    - If money is in escrow, return all of it to the seller.
    - If money has not been collected yet, lift any wallet hold on seller.
    - Fee handling: dispute fee is NOT refunded (buyer initiated cancellation; no recovery failure).

### 4.8 Seller Response Path (Q4 Confirmed)

When a dispute is filed against a seller, the seller has the right to respond before investigation begins.

**`userRespondToDispute(disputeId, response, evidence)`**
- Caller must be `dispute.recipientUid`.
- Dispute must be in `filed`, `investigating`, OR `supervisor_review` (response window closes once supervisor moves it forward).
- `response` is text ≥20 chars.
- `evidence` is optional array of file references (uploaded separately via existing dispute-evidence upload path).
- Action:
  - Sets `dispute.recipientResponse: response`, `dispute.recipientResponseAt: serverTimestamp`, `dispute.recipientEvidence: evidence`.
  - If multiple responses: appends to an array `dispute.recipientResponseHistory`.
  - Notifies the assigned admin (if any) via email.

**Eric's clarification:** seller's response is OPTIONAL. There is NO time-window enforcement. The investigation can proceed without a response. But if a response exists, it must be visible to admin during investigation.

### 4.9 Migration of Existing Disputes

There are existing disputes in the database with `status: 'resolved'` from the old code. We must NOT silently change their meaning.

**Migration policy:**
- All existing `resolved` disputes stay `resolved` forever. The new code does not query for or transition `resolved`.
- The new code uses `solved`, `awaiting_release`, `closed`, `closed_returned`, `closed_stuck`, `closed_buyer_cancelled` — all of which are new strings. No collision with existing `resolved`.
- The `_recoveryWatchActive` flag on existing disputes still works as before (the old recovery watch logic flows the money seller→buyer directly). The new recovery watch logic only kicks in for NEW disputes that have moved through the new state machine.
- **For dashboards/lists:** treat `resolved` as a synonym for `closed` in display logic. Backend still distinguishes them.
- **A one-time data audit script** must run before deploy to count: how many `resolved` disputes exist? How many have `_recoveryWatchActive: true`? This informs the size of the legacy tail. Eric can decide whether to keep both code paths long-term or migrate the active legacy ones manually.

---

## 5. Gap Analysis (Current vs Target)

This is a focused, scannable list of gaps. Each one becomes a change item in section 7.

| # | Gap | Where | Severity |
|---|---|---|---|
| 1 | No SMS to seller when dispute filed | `userFileDispute` line 14260 area | HIGH |
| 2 | `recipientResponse` field exists, never written | No function exists | HIGH |
| 3 | All 4 manager/super_admin decision sites jump straight to `resolved` instead of `solved` | Lines 14873, 15009, 15172, 15299 | HIGH |
| 4 | No `solved` or `awaiting_release` state in the state machine | All decision functions | HIGH |
| 5 | Recovery Watch flows seller→buyer directly | Around line 15676 | HIGH |
| 6 | No platform escrow wallet | New collection / helper needed | HIGH |
| 7 | No two-person release flow | New functions needed | HIGH |
| 8 | No reversal-to-seller after verification path | New function needed | HIGH |
| 9 | No `buyer_owes_seller_*` decision outcomes | `VALID_DECISIONS` arrays in 2 places | MEDIUM |
| 10 | No buyer-owes flow (mirror of refund flow with reversed parties) | New code + opportunistic hold on buyer side at filing | MEDIUM |
| 11 | No buyer self-service: cancel | New function needed | MEDIUM |
| 12 | No buyer self-service: request partial release | New function needed | MEDIUM |
| 13 | No 90-day stuck check scheduled function | New scheduled function | MEDIUM |
| 14 | No 3-day account-closure stuck check | New scheduled function + admin override | MEDIUM |
| 15 | No notification per Recovery Watch deduction | Inside Recovery Watch loop | MEDIUM |
| 16 | No "fully collected, awaiting release" auto-transition | Inside Recovery Watch loop | MEDIUM |
| 17 | Flutter dispute screen doesn't show new states | `lib/features/disputes/screens/dispute_detail.dart` | LOW (cosmetic, blocks UX) |
| 18 | Admin dashboard has no "Awaiting Release" queue | `admin-dashboard/src/pages/DisputesPage.jsx` (existence to be confirmed) | LOW (cosmetic, blocks UX) |
| 19 | Admin dashboard has no two-person release UI | New admin-dashboard component | LOW (cosmetic, blocks UX) |
| 20 | Firestore rules don't gate the new escrow wallet | `firestore.rules` | HIGH (security) |
| 21 | Firestore rules don't allow the new fields on dispute doc | `firestore.rules` | HIGH (security) |
| 22 | Composite indexes for new queries (e.g., `awaiting_release` + `proposalProposedAt`) | `firestore.indexes.json` | MEDIUM (performance) |
| 23 | Evidence-package export function for `closed_stuck` cases | New admin function | LOW |
| 24 | Closing-remarks template field on dispute doc | Schema addition | LOW |
| 25 | Seller's view of "money held against you" | Flutter screen update | LOW (cosmetic) |

### 5.1 Things This Spec Does NOT Change

To prevent scope creep, the implementing AI MUST NOT change:
- The fee calculation logic
- The 7-day filing window
- The max-3-active-disputes limit
- The kickback-once-per-tier logic
- The 5-day auto-escalation timer
- Any role tier requirements (`support`, `admin`, etc.)
- The `wallet_blocks` lifting logic — which still happens at terminal states
- The `dispute_history` counter logic — which still applies at the new terminal states
- The existing audit logging patterns
- The format of `disputeId` (DSP-{timestamp}-{hex})

If a change to any of the above seems necessary, **stop and ask Eric.**

---

## 6. Detailed Design

### 6.1 New State Machine — Full Transition Table

All transitions are listed below. Each row is a single state change that some piece of code performs. The implementing AI must implement all of them, no more and no less.

| From | To | Trigger Function | Notes |
|------|------|------|------|
| (none) | filed | `userFileDispute` | (existing — no change) |
| filed | investigating | `adminAssignDispute` | (existing — no change) |
| investigating | supervisor_review | `adminSubmitInvestigation` | (existing — no change) |
| supervisor_review | manager_review | `adminSupervisorDecision` (agree) | (existing — no change) |
| supervisor_review | investigating | `adminSupervisorDecision` (disagree_kickback) | (existing — no change; one-time) |
| manager_review | investigating | `adminManagerDecision` (kickback) | (existing — no change; one-time) |
| manager_review | closed | `adminManagerDecision` (release) | NEW: was `resolved`. No money owed → directly closed. |
| manager_review | solved | `adminManagerDecision` (refund_full / refund_partial / buyer_owes_seller_full / buyer_owes_seller_partial) | NEW: enter the escrow flow. |
| manager_review | super_admin_escalation | (scheduled — auto, after 5 days) | (existing — no change) |
| super_admin_escalation | closed | `adminSuperAdminDisputeDecision` (release) | NEW: was `resolved`. |
| super_admin_escalation | solved | `adminSuperAdminDisputeDecision` (refund / buyer_owes) | NEW: enter escrow flow. |
| solved | awaiting_release | (Recovery Watch detects full collection) | NEW: auto-transition. |
| solved | awaiting_release | `userRequestPartialRelease` + admin two-person release | NEW: only the collected portion. Remainder stays in `solved`. |
| solved | closed_stuck | `disputeAccountClosureCheckScheduled` (after 3 days) | NEW. |
| solved | closed_stuck | `disputeNoProgressCheckScheduled` (after 90 days zero deposits) | NEW. |
| solved | closed_buyer_cancelled | `adminConfirmCancellation` after `userCancelDispute` | NEW. |
| awaiting_release | (proposal pending) | `adminProposeDisputeRelease` | NEW: sub-state via `dispute.releaseProposal` field. Status remains `awaiting_release`. |
| awaiting_release | closed | `adminConfirmDisputeRelease` (release_to_payee) | NEW: money goes to the party owed. |
| awaiting_release | closed_returned | `adminConfirmDisputeRelease` (reverse_to_payer) | NEW: money goes back to the party who paid (seller in refund flow, buyer in buyer-owes flow). |
| awaiting_release | awaiting_release (proposal cleared) | `adminRejectDisputeRelease` | NEW: returns to plain awaiting state. |
| awaiting_release | awaiting_release (proposal expires) | (scheduled — auto, after 24h) | NEW. |
| (any non-terminal) | closed_buyer_cancelled | `adminConfirmCancellation` (after `userCancelDispute`) | NEW. |

**State validation invariants** (must be enforced by every transition function):
- Source state must match expected. If not, throw `failed-precondition` with the actual state.
- Idempotency key (≥16 chars) must be present on every admin transition.
- Caller must have correct role.
- Money-moving transitions must occur in `db.runTransaction`.

### 6.2 New Dispute Doc Fields

All new fields added to the dispute doc as part of Phase 5i:

```
// Money in escrow tracking (Section 4.2)
amountInEscrow: number                     // money currently held in dispute_recovery_<currency>
amountOwed: number                         // = managerDecisionAmount or disputedAmount
                                           // (snapshot at time of solved-transition)
decisionDirection: 'refund_to_buyer' | 'pay_to_seller'
                                           // determined at solved-transition. drives recovery direction.
solvedAt: timestamp                        // when entered solved state
lastRecoveryDeductionAt: null | timestamp  // updated by Recovery Watch on each deduction

// awaiting_release transition tracking
awaitingReleaseAt: null | timestamp        // when entered awaiting_release
fullyCollectedAt: null | timestamp         // === awaitingReleaseAt unless partial release was done

// Two-person release proposal (Section 4.5)
releaseProposal: null | {
  proposedBy: { uid, email, displayName, role }
  proposedAt: timestamp
  releaseDirection: 'release_to_payee' | 'reverse_to_payer'
  notes: string                            // ≥50 chars
  buyerContacted: boolean                  // confirmation checkbox
  sellerContacted: boolean                 // confirmation checkbox
  expiresAt: timestamp                     // proposedAt + 24h
}
releaseConfirmedBy: null | { uid, email, displayName, role }
releaseConfirmedAt: null | timestamp
releaseRejectedBy: null | { uid, email, displayName, role }
releaseRejectedAt: null | timestamp
releaseRejectionReason: null | string

// Reversal & closing
releaseDirection: null | 'release_to_payee' | 'reverse_to_payer'
                                           // set on close
closingRemarks: null | string              // template-filled or custom

// Stuck detection
accountClosureDetectedAt: null | timestamp // when system or admin first noted recipient gone
accountClosureDetectedBy: null | 'auto' | { uid, email }
stuckReason: null | 'account_closed' | 'no_progress_90d' | 'manual'

// Buyer self-service
partialReleaseRequested: boolean           // initially false
partialReleaseRequestedAt: null | timestamp
partialReleasedAmount: null | number
partialReleasedAt: null | timestamp
cancellationRequested: boolean             // initially false
cancellationRequestedAt: null | timestamp
cancellationReason: null | string
cancellationConfirmedBy: null | { uid, email, displayName, role }
cancellationConfirmedAt: null | timestamp

// Seller response
recipientResponse: null | string           // (existing field — now writable)
recipientResponseAt: null | timestamp      // (existing field — now writable)
recipientEvidence: null | array            // (existing field — now writable)
recipientResponseHistory: array            // appended to on each new response. initially empty.
```

### 6.3 Recovery Watch Rewrite (Section 4.2 implementation)

The existing Recovery Watch scheduled function must be modified. Find it by searching for `wallet_debts` and `recoveryWatch` in `functions/index.js` (around line 15676).

**Old behavior** (pseudo-code):
```
for each active wallet_debt:
  recipient_wallet = get(wallet_debt.recipientUid)
  if recipient.availableBalance > 0:
    deduct min(remaining, recipient.availableBalance)
    credit filer's wallet
    record debt_recovery
    if fully recovered: mark debt closed
```

**New behavior** (pseudo-code):
```
for each active wallet_debt:
  source_uid = wallet_debt.sourceUid                       // NEW field on wallet_debt: who owes
  source_wallet = get(source_uid)
  dispute = get(disputes/wallet_debt.disputeId)
  
  if dispute.status != 'solved':
    log warning, skip                                       // sanity check
    
  if source_wallet.availableBalance > 0:
    deduction = min(wallet_debt.remaining, source_wallet.availableBalance)
    
    db.runTransaction:
      source_wallet.availableBalance -= deduction
      source_wallet.balance -= deduction
      escrow_wallet = get(wallets/dispute_recovery_<currency>)
      escrow_wallet.balance += deduction
      escrow_wallet.availableBalance += deduction
      wallet_debt.amountRecovered += deduction
      dispute.amountInEscrow += deduction
      dispute.lastRecoveryDeductionAt = now
      record debt_recovery (with type='to_escrow')
      
    send_sms to source_uid: "<deduction> <currency> held from your wallet for dispute <id>"
    send_sms to filer (if direction is refund_to_buyer): "<deduction> recovered for dispute <id>. Total: <X>/<Y>."
    send_sms to seller (if direction is pay_to_seller): "<deduction> recovered for dispute <id>. Total: <X>/<Y>."
    
    if dispute.amountInEscrow >= dispute.amountOwed:
      transition dispute solved → awaiting_release
      send_sms to filer: "All amounts collected. Awaiting verification before release."
      send_sms to other_party: "All amounts collected for dispute. Support team will verify."
      mark wallet_debt status = 'closed_pending_release'
```

The `wallet_debts` schema gets a new field:
- `sourceUid: string` — the party that owes (replaces the implicit "always the recipient" assumption). Set at debt creation based on `decisionDirection`.

### 6.4 Two-Person Release Flow (Section 4.5 implementation)

Three new admin callable functions:

**`adminProposeDisputeRelease`**
- Required role: `admin` or higher
- Inputs: `disputeId`, `releaseDirection` ('release_to_payee' | 'reverse_to_payer'), `buyerContacted` (must be true), `sellerContacted` (must be true), `notes` (≥50 chars), `idempotencyKey`
- Validation:
  - Dispute must be in `awaiting_release` AND `releaseProposal === null`
  - All three confirmations must be true (`buyerContacted`, `sellerContacted`, both implicit in the spec — make explicit booleans)
- Action: writes `dispute.releaseProposal` with proposer info, expiresAt = now + 24h
- Notifications: email all admin+ users (except proposer)
- Audit + admin_activity entries

**`adminConfirmDisputeRelease`**
- Required role: `admin` or higher
- Inputs: `disputeId`, `buyerContacted`, `sellerContacted`, `notes` (≥50 chars), `idempotencyKey`
- Validation:
  - Dispute must be in `awaiting_release` AND `releaseProposal !== null`
  - `releaseProposal.expiresAt` must be in the future
  - Caller's uid must NOT equal `releaseProposal.proposedBy.uid` (different person enforcement)
  - `buyerContacted` and `sellerContacted` must both be true
- Action: atomically (in db.runTransaction):
  - Move money based on `releaseProposal.releaseDirection`:
    - `release_to_payee` → escrow wallet → buyer (if refund_to_buyer) OR seller (if pay_to_seller)
    - `reverse_to_payer` → escrow wallet → seller (if refund_to_buyer) OR buyer (if pay_to_seller)
  - Update dispute: `status: 'closed'` (if release_to_payee) or `'closed_returned'` (if reverse_to_payer), populate `releaseConfirmedBy`, `releaseConfirmedAt`, `releaseDirection` (snapshot), `closedAt`
  - Lift any remaining `wallet_blocks`
  - Update `dispute_history` counters
- Notifications: SMS both parties with appropriate text from notification matrix
- Audit + admin_activity (TWO entries: one for proposer earlier, one for confirmer now)

**`adminRejectDisputeRelease`**
- Required role: `admin` or higher
- Inputs: `disputeId`, `reason` (≥20 chars), `idempotencyKey`
- Validation:
  - Dispute in `awaiting_release` with active `releaseProposal`
  - Rejecter must NOT equal proposer
- Action: clears `releaseProposal`, sets `releaseRejectedBy`, `releaseRejectedAt`, `releaseRejectionReason`. Dispute remains in `awaiting_release` — a new proposal can be made.
- Notifications: email original proposer
- Audit + admin_activity

**`disputeReleaseProposalExpiryScheduled`** — runs hourly
- For each dispute in `awaiting_release` with `releaseProposal !== null` AND `releaseProposal.expiresAt < now`:
  - Clear the proposal (set to null, no rejection record)
  - Email proposer: "Your release proposal expired without a second confirmation. Please re-propose if still needed."

### 6.5 Reversal Flow (Section 4.2 implementation)

Reversal is just `release_direction === 'reverse_to_payer'` in `adminConfirmDisputeRelease`. Implementation detail:

When `release_direction === 'reverse_to_payer'`:
- For `decisionDirection === 'refund_to_buyer'`: money in escrow returns to seller's wallet (since seller was the source)
- For `decisionDirection === 'pay_to_seller'`: money in escrow returns to buyer's wallet (buyer was the source)
- `dispute.status` becomes `closed_returned`
- `dispute.resolutionType` set to `reversed_after_verification`
- Notifications go out per the matrix

The buyer (filer) will be informed that the verification reversed the decision. The closing remarks should include the reason — admin must write meaningful notes.

### 6.6 Stuck-Case Detection Implementation (Section 4.6 implementation)

Two new scheduled functions, plus one new admin manual override callable.

**`disputeAccountClosureCheckScheduled`** (daily, see section 4.6 logic):

```javascript
exports.disputeAccountClosureCheckScheduled = functions.pubsub
  .schedule('every day 03:00')
  .timeZone('UTC')
  .onRun(async (context) => {
    // Logic per section 4.6
    // 1. Find all disputes where status === 'solved' AND _recoveryWatchActive === true
    // 2. For each, check recipient (or buyer if direction='pay_to_seller') auth user
    // 3. If user gone or accountDeleted: set accountClosureDetectedAt if null,
    //    else if 3+ days passed: transition to closed_stuck
    // ... see 6.6 detail in section 7 for full code
  });
```

**`disputeNoProgressCheckScheduled`** (daily):

```javascript
exports.disputeNoProgressCheckScheduled = functions.pubsub
  .schedule('every day 04:00')
  .timeZone('UTC')
  .onRun(async (context) => {
    // 1. Find all disputes where status === 'solved' AND _recoveryWatchActive === true
    // 2. For each, compute days since lastRecoveryDeductionAt (or solvedAt if no deductions)
    // 3. Also check source wallet's lastDepositAt
    // 4. If both >= 90 days: transition to closed_stuck with stuckReason='no_progress_90d'
    // ... see 6.6 detail in section 7 for full code
  });
```

**`adminMarkDisputeAccountClosed`** (callable, admin+):
- Inputs: `disputeId`, `evidence` (≥50 chars description of what admin found), `idempotencyKey`
- Validates dispute in `solved` state
- Sets `accountClosureDetectedAt: now`, `accountClosureDetectedBy: { uid, email }`
- Daily scheduled job will then complete the 3-day transition. (We do NOT immediately transition here — the 3-day window applies even with admin override, in case admin made a mistake.)

### 6.7 Buyer Owes Seller — Mirror Flow (Section 4.3 implementation)

The "buyer owes seller" case is symmetrical to refund. Implementation:

**At decision time** (manager rules `buyer_owes_seller_full` or `_partial`):
1. `decisionDirection: 'pay_to_seller'`
2. Source = buyer's wallet (instead of seller's)
3. `currentHoldAmount` for buyer-owes case is computed from `buyerHoldBalance` (a new opportunistic hold)
4. Same logic: actualPayment = min(requestedAmount, currentBuyerHold), unrecovered = requestedAmount - actualPayment
5. Atomic transaction: deduct from buyer's wallet, credit escrow, optionally create wallet_debt
6. Status → `solved`

**Opportunistic hold on buyer at filing time:**
The existing `placeOpportunisticHoldStub` (line 14072) holds money on the SELLER's wallet at filing. This was based on the assumption that the seller is always the party who might owe.

In Phase 5i, since the manager could rule either direction, we hold on BOTH parties opportunistically:
- Hold on seller for `disputedAmount` (existing behavior)
- Hold on buyer for `disputedAmount` ALSO (NEW — covers the buyer-owes outcome)

The hold is RELEASED on the party that doesn't end up owing money:
- If manager rules `refund_*`: buyer's hold is lifted; seller's hold stays (and gets converted to escrow)
- If manager rules `buyer_owes_seller_*`: seller's hold is lifted; buyer's hold stays (and gets converted to escrow)
- If manager rules `release`: both holds are lifted

Implementation note: this changes the meaning of `dispute.currentHoldAmount`. It becomes a struct:
```
holds: {
  filer: number       // hold on buyer's wallet
  recipient: number   // hold on seller's wallet
}
```
Or two separate fields:
```
filerHoldAmount: number
recipientHoldAmount: number
```
The `currentHoldAmount` field stays for backward compat with old disputes; new code reads/writes the structured fields.

### 6.8 Closing Remarks Template Engine

A simple helper that fills in templates based on close reason:

```javascript
function generateClosingRemarks(dispute, reason) {
  switch (reason) {
    case 'released_to_payee_refund':
      return `Verification confirmed buyer's claim. ${dispute.amountOwed} ${dispute.disputedCurrency} released from escrow to filer.`;
    case 'released_to_payee_buyer_owes':
      return `Verification confirmed seller's claim. ${dispute.amountOwed} ${dispute.disputedCurrency} released from escrow to recipient.`;
    case 'reverse_to_payer_refund':
      return `Verification reversed decision — buyer's claim not substantiated. ${dispute.amountInEscrow} ${dispute.disputedCurrency} returned to recipient.`;
    case 'reverse_to_payer_buyer_owes':
      return `Verification reversed decision — seller's claim not substantiated. ${dispute.amountInEscrow} ${dispute.disputedCurrency} returned to filer.`;
    case 'stuck_account_closed':
      const closedDate = dispute.accountClosureDetectedAt?.toDate().toISOString().split('T')[0];
      return `Recovery impossible — ${dispute.decisionDirection === 'refund_to_buyer' ? 'recipient' : 'filer'} account closed on ${closedDate}. Buyer advised to contact authorities. Evidence package available on request.`;
    case 'stuck_no_progress':
      return `Recovery progress stalled — no deductions or deposits in 90 days. Buyer may contact support for evidence package or to escalate.`;
    case 'buyer_cancelled':
      return `Closed at buyer's request. Reason: ${dispute.cancellationReason}. Confirmed by support after verification.`;
    default:
      return 'Dispute closed.';
  }
}
```

The implementing AI must place this helper near the dispute functions (e.g., just before `userFileDispute` at line ~14050).

### 6.9 Evidence Package Export (Section 4.6 final step)

For `closed_stuck` cases, support needs to give the buyer an evidence package they can take to authorities.

**`adminExportDisputeEvidencePackage(disputeId)`** — callable, admin+
- Validates dispute is in any closed state (`closed_stuck`, `closed`, `closed_returned`, `closed_buyer_cancelled`)
- Returns a structured object containing:
  - All dispute doc fields (sanitized — no internal flags)
  - All audit_log entries with `metadata.disputeId === disputeId`
  - All admin_activity entries with `details.includes(disputeId)`
  - All wallet_debts entries with `disputeId === disputeId`
  - All debt_recoveries entries with `disputeId === disputeId`
  - Original transaction details
  - Timeline (chronological list of events)
  - Closing remarks
- The Flutter app + admin dashboard render this as a printable/exportable document. Eric mentioned "evidence package" — implementation can be PDF (use existing PDF skill if available) or a structured JSON the user copies/saves.

For Phase 5i v1: return JSON. PDF generation is a v2 polish.

---

## 7. Backend Changes (File-by-File)

This section is the implementing AI's primary build target. Each subsection corresponds to a discrete change. **Implement and verify each one in isolation before moving to the next.** This is critical for money-movement code.

### 7.1 Add Helper: `getOrCreateRecoveryWallet`

**Location:** `functions/index.js`, near other wallet helpers. Search for where wallet docs are first created (e.g., `createWallet` or similar) and place this nearby. If unsure, place it just before `userFileDispute` at line ~14050.

**NEW FUNCTION (add):**

```javascript
/**
 * Phase 5i: Get or create a platform-owned dispute recovery escrow wallet
 * for the given currency. These wallets hold money during the verification
 * window between manager decision and final release.
 *
 * Document path: wallets/dispute_recovery_<CURRENCY>
 * isPlatform: true marker is used by Firestore rules to gate access.
 */
async function getOrCreateRecoveryWallet(currency) {
  const docId = `dispute_recovery_${String(currency).toUpperCase()}`;
  const ref = db.collection('wallets').doc(docId);
  const snap = await ref.get();
  if (snap.exists) return ref;

  await ref.set({
    walletId: `PLATFORM-DISPUTE-RECOVERY-${String(currency).toUpperCase()}`,
    balance: 0,
    availableBalance: 0,
    heldBalance: 0,
    currency: String(currency).toUpperCase(),
    isPlatform: true,
    purpose: 'dispute_recovery_escrow',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return ref;
}
```

### 7.2 Add Helper: `generateClosingRemarks`

**Location:** Same area as 7.1, immediately after.

**NEW FUNCTION (add):** See section 6.8 for the function body. Copy that function literally.

### 7.3 Modify `userFileDispute` to Notify Seller and Hold Buyer's Wallet

**Location:** `functions/index.js:14052`. Specifically, the changes go inside the function body.

**Change A — Hold buyer's wallet too (Section 6.7):**

Currently the function holds only on the seller side via `placeOpportunisticHoldStub` (line 14072). We need to ADD a hold on the buyer's side (the filer's wallet) for the symmetrical buyer-owes-seller case.

**FIND:** (line ~14072 area)
```javascript
    // Place opportunistic hold (stub returns 0)
    const holdAmount = await placeOpportunisticHoldStub({
      recipientUid,
      currency: txCurrency,
      requestedAmount: disputedAmount,
      disputeId,
    });
```

**REPLACE WITH:**
```javascript
    // Phase 5i: Place opportunistic holds on BOTH parties' wallets.
    // Until the manager decides direction, either party could end up owing.
    // The hold on the non-owing party is released at decision time.
    const recipientHoldAmount = await placeOpportunisticHoldStub({
      recipientUid,
      currency: txCurrency,
      requestedAmount: disputedAmount,
      disputeId,
    });
    const filerHoldAmount = await placeOpportunisticHoldStub({
      recipientUid: callerUid,    // the filer; placeOpportunisticHoldStub uses this as the wallet to hold against
      currency: txCurrency,
      requestedAmount: disputedAmount,
      disputeId,
    });
```

**Change B — Update dispute schema fields:**

**FIND:** (within the `transaction.set(disputeRef, { ... })` block around line 14225)
```javascript
        currentHoldAmount: holdAmount,
        holdHistory: [],
```

**REPLACE WITH:**
```javascript
        // Phase 5i: track holds per party (we now hold on both)
        currentHoldAmount: recipientHoldAmount,    // legacy compat — equals recipientHoldAmount
        recipientHoldAmount,
        filerHoldAmount,
        holdHistory: [],
        // Phase 5i: escrow & solved-state tracking — initialized to defaults
        amountInEscrow: 0,
        amountOwed: 0,
        decisionDirection: null,
        solvedAt: null,
        lastRecoveryDeductionAt: null,
        awaitingReleaseAt: null,
        fullyCollectedAt: null,
        // Phase 5i: two-person release proposal — initialized null
        releaseProposal: null,
        releaseConfirmedBy: null,
        releaseConfirmedAt: null,
        releaseRejectedBy: null,
        releaseRejectedAt: null,
        releaseRejectionReason: null,
        releaseDirection: null,
        closingRemarks: null,
        // Phase 5i: stuck detection
        accountClosureDetectedAt: null,
        accountClosureDetectedBy: null,
        stuckReason: null,
        // Phase 5i: buyer self-service
        partialReleaseRequested: false,
        partialReleaseRequestedAt: null,
        partialReleasedAmount: null,
        partialReleasedAt: null,
        cancellationRequested: false,
        cancellationRequestedAt: null,
        cancellationReason: null,
        cancellationConfirmedBy: null,
        cancellationConfirmedAt: null,
        // Phase 5i: seller response history
        recipientResponseHistory: [],
```

**Change C — SMS the seller after the dispute write succeeds (Gap #1):**

**FIND:** (just before the function's `return` statement — find the line after `audit_logs` write, around line 14275-14290 area; we add SMS sending here)

The exact existing code I need to find depends on what's there at the end of the function. The implementing AI should locate the section after the audit_logs write and BEFORE the function's `return` statement, then ADD this code block:

**ADD (before the return statement):**
```javascript
    // Phase 5i (Section 4.4): notify the seller (recipient) that a dispute has been filed.
    // The seller has the right to respond before investigation begins (see userRespondToDispute).
    if (recipientPhone) {
      try {
        await sendCustomerSms({
          phoneNumber: recipientPhone,
          message: `A dispute has been filed against transaction ${originalTransactionId}. Dispute ID: ${disputeId}. Open the app to view details and respond.`,
          relatedTo: `dispute:${disputeId}`,
        });
      } catch (smsError) {
        // Notification failure should not block dispute filing.
        logWarning('userFileDispute: failed to SMS recipient', { disputeId, recipientUid, error: smsError.message });
      }
    }
```

### 7.4 Add Function: `userRespondToDispute`

**Location:** `functions/index.js`, immediately after `userFileDispute` function ends (find its closing `});` then add).

**NEW FUNCTION (add):**

```javascript
/**
 * Phase 5i (Section 4.8): User (seller / recipient) responds to a dispute filed against them.
 * Optional — investigation can proceed without a response. Multiple responses allowed
 * (each appended to history) until supervisor moves dispute forward.
 */
exports.userRespondToDispute = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Authentication required.');
    }
    const callerUid = context.auth.uid;

    const { disputeId, response, evidence, idempotencyKey } = data || {};

    if (!disputeId || typeof disputeId !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
    }
    if (!response || typeof response !== 'string' || response.trim().length < 20) {
      throw new functions.https.HttpsError('invalid-argument', 'response must be at least 20 characters.');
    }
    if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
      throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
    }

    const withinLimit = await checkRateLimitPersistent(callerUid, 'userRespondToDispute');
    if (!withinLimit) {
      throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.userRespondToDispute.message);
    }

    try {
      const disputeRef = db.collection('disputes').doc(disputeId);
      const disputeSnap = await disputeRef.get();
      if (!disputeSnap.exists) {
        throw new functions.https.HttpsError('not-found', `Dispute ${disputeId} not found.`);
      }
      const dispute = disputeSnap.data();

      if (dispute.recipientUid !== callerUid) {
        throw new functions.https.HttpsError('permission-denied',
          'Only the recipient of the disputed transaction can respond.');
      }

      const ALLOWED_STATES = ['filed', 'investigating', 'supervisor_review'];
      if (!ALLOWED_STATES.includes(dispute.status)) {
        throw new functions.https.HttpsError('failed-precondition',
          `Cannot respond — dispute is in '${dispute.status}'. Response window closes after supervisor review begins.`);
      }

      const responseEntry = {
        response: response.trim(),
        respondedAt: admin.firestore.Timestamp.now(),
        evidence: Array.isArray(evidence) ? evidence : [],
      };

      await disputeRef.update({
        recipientResponse: response.trim(),    // most recent
        recipientResponseAt: admin.firestore.FieldValue.serverTimestamp(),
        recipientEvidence: Array.isArray(evidence) ? evidence : [],
        recipientResponseHistory: admin.firestore.FieldValue.arrayUnion(responseEntry),
      });

      // Notify assigned admin if any
      if (dispute.assignedAdmin && dispute.assignedAdmin.email) {
        try {
          await sendProposalEmail({
            to: dispute.assignedAdmin.email,
            toName: dispute.assignedAdmin.displayName || null,
            subject: `Recipient responded on dispute ${disputeId}`,
            htmlBody: `<p>The recipient on dispute <strong>${disputeId}</strong> has submitted a response.</p>
<p><strong>Response:</strong> ${response.trim()}</p>
<p>Review in the admin dashboard.</p>`,
            textBody: `Recipient responded on dispute ${disputeId}. Review in dashboard.`,
            relatedTo: `dispute:${disputeId}`,
          });
        } catch (emailError) {
          logWarning('userRespondToDispute: failed to email assigned admin', {
            disputeId, error: emailError.message,
          });
        }
      }

      await db.collection('audit_logs').add({
        userId: callerUid,
        operation: 'userRespondToDispute',
        result: 'success',
        metadata: { disputeId },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, disputeId };
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      logError('userRespondToDispute failed', { disputeId, callerUid, error: error.message });
      throw new functions.https.HttpsError('internal', 'Failed to submit response: ' + error.message);
    }
  });
```

**Don't forget:** add a rate limit entry. In `RATE_LIMITS` config (line 2471 area), add:
```javascript
userRespondToDispute: { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many responses to disputes.' },
```

### 7.5 Modify `adminManagerDecision` — New Decision Outcomes & New Status Targets

**Location:** `functions/index.js:14786`.

This is the biggest single change. Read the entire current function body first (lines 14786 through ~15103), understand its current shape, then apply these changes systematically.

**Change A — Expand `VALID_DECISIONS`:**

**FIND:**
```javascript
  const VALID_DECISIONS = ['refund_full', 'refund_partial', 'release', 'kickback'];
```

**REPLACE WITH:**
```javascript
  // Phase 5i: 'buyer_owes_seller_*' added — manager can decide either direction.
  const VALID_DECISIONS = [
    'refund_full', 'refund_partial', 'release', 'kickback',
    'buyer_owes_seller_full', 'buyer_owes_seller_partial',
  ];
```

**Change B — Validate partial amount for buyer_owes:**

**FIND:**
```javascript
    if (decision === 'refund_partial') {
      if (!amount || typeof amount !== 'number' || amount <= 0 || amount >= dispute.disputedAmount) {
        throw new functions.https.HttpsError('invalid-argument',
          `Partial refund amount must be between 0 and ${dispute.disputedAmount} (exclusive).`);
      }
    }
```

**REPLACE WITH:**
```javascript
    if (decision === 'refund_partial' || decision === 'buyer_owes_seller_partial') {
      if (!amount || typeof amount !== 'number' || amount <= 0 || amount >= dispute.disputedAmount) {
        throw new functions.https.HttpsError('invalid-argument',
          `Partial amount must be between 0 and ${dispute.disputedAmount} (exclusive).`);
      }
    }
```

**Change C — Replace the entire `release` branch (move from `resolved` to `closed` + lift BOTH holds):**

**FIND:** the entire `} else if (decision === 'release') {` block — from the `} else if` line through the closing `}` of that branch (around line 14857–14920 area). It currently lifts hold from recipient's wallet and writes `status: 'resolved'`.

**REPLACE WITH:**
```javascript
    } else if (decision === 'release') {
      // Phase 5i: release means "no money owed in either direction." Lift both holds.
      newStatus = 'closed';

      const recipientHold = dispute.recipientHoldAmount || dispute.currentHoldAmount || 0;
      const filerHold = dispute.filerHoldAmount || 0;

      await db.runTransaction(async (transaction) => {
        // Lift recipient's hold (existing logic)
        if (recipientHold > 0 && dispute.recipientUid) {
          const recipientWalletRef = db.collection('wallets').doc(dispute.recipientUid);
          transaction.update(recipientWalletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-recipientHold),
            availableBalance: admin.firestore.FieldValue.increment(recipientHold),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        // Lift filer's hold (Phase 5i — symmetric)
        if (filerHold > 0 && dispute.filedBy && dispute.filedBy.uid) {
          const filerWalletRef = db.collection('wallets').doc(dispute.filedBy.uid);
          transaction.update(filerWalletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-filerHold),
            availableBalance: admin.firestore.FieldValue.increment(filerHold),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        transaction.update(disputeRef, {
          status: 'closed',
          resolutionType: 'released',
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          closedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewingManager: managerInfo,
          managerDecision: 'release',
          managerNotes: notes.trim(),
          decisionDirection: null,
          amountRecovered: 0,
          amountUnrecovered: 0,
          amountOwed: 0,
          _awaitingMoneyMovement: false,
          _recoveryWatchActive: false,
          closingRemarks: 'Manager ruled release. No money owed in either direction.',
        });
      });

      // Lift wallet_blocks (existing logic, unchanged)
      const blocksSnap = await db.collection('wallet_blocks')
        .where('disputeId', '==', disputeId)
        .where('liftedAt', '==', null)
        .get();
      const blockBatch = db.batch();
      blocksSnap.docs.forEach(blockDoc => {
        blockBatch.update(blockDoc.ref, {
          liftedAt: admin.firestore.FieldValue.serverTimestamp(),
          liftReason: 'dispute_closed_release',
        });
      });
      if (!blocksSnap.empty) await blockBatch.commit();

      await db.collection('dispute_history').doc(dispute.filedBy.uid).set({
        totalRejected: admin.firestore.FieldValue.increment(1),
        totalActiveCount: admin.firestore.FieldValue.increment(-1),
      }, { merge: true });

      // Notifications (per Section 4.4)
      await sendCustomerSms({
        phoneNumber: dispute.filedBy.phoneNumber,
        message: `Dispute ${disputeId} closed in favor of recipient. No funds returned.`,
        relatedTo: `dispute:${disputeId}`,
      });
      if (dispute.recipientPhoneNumber) {
        await sendCustomerSms({
          phoneNumber: dispute.recipientPhoneNumber,
          message: `Dispute ${disputeId} closed in your favor. Hold lifted.`,
          relatedTo: `dispute:${disputeId}`,
        });
      }
```

**Change D — Replace the refund-with-money-movement branch:**

**FIND:** the `} else { // refund_full or refund_partial — REAL money movement` block — from the `} else {` opening through the closing `}` (around line 14918–15050). This includes the SMS notifications at the end.

**REPLACE WITH:**
```javascript
    } else if (decision === 'refund_full' || decision === 'refund_partial') {
      // Phase 5i: refund flow — collect from seller, hold in escrow, await verification.
      // Status moves to 'solved' (was 'resolved'). Money goes to escrow wallet, not directly to buyer.
      newStatus = 'solved';

      const requestedRefund = decision === 'refund_partial' ? amount : dispute.disputedAmount;
      const recipientHold = dispute.recipientHoldAmount || dispute.currentHoldAmount || 0;
      const filerHold = dispute.filerHoldAmount || 0;
      const initialEscrow = Math.min(requestedRefund, recipientHold);
      const unrecovered = Math.max(0, requestedRefund - initialEscrow);

      // Get/create escrow wallet for this currency
      const escrowRef = await getOrCreateRecoveryWallet(dispute.disputedCurrency);

      await db.runTransaction(async (transaction) => {
        // Lift filer's hold (filer is not the source in refund flow)
        if (filerHold > 0 && dispute.filedBy && dispute.filedBy.uid) {
          const filerWalletRef = db.collection('wallets').doc(dispute.filedBy.uid);
          transaction.update(filerWalletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-filerHold),
            availableBalance: admin.firestore.FieldValue.increment(filerHold),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Move recipient's hold into escrow
        if (initialEscrow > 0 && dispute.recipientUid) {
          const recipientWalletRef = db.collection('wallets').doc(dispute.recipientUid);
          transaction.update(recipientWalletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-initialEscrow),
            balance: admin.firestore.FieldValue.increment(-initialEscrow),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          transaction.update(escrowRef, {
            balance: admin.firestore.FieldValue.increment(initialEscrow),
            availableBalance: admin.firestore.FieldValue.increment(initialEscrow),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Create wallet_debt for unrecovered portion (Recovery Watch will deduct over time)
        if (unrecovered > 0 && dispute.recipientUid) {
          const debtRef = db.collection('wallet_debts').doc();
          transaction.set(debtRef, {
            debtId: debtRef.id,
            disputeId,
            sourceUid: dispute.recipientUid,        // Phase 5i: explicit source
            recipientUid: dispute.recipientUid,     // legacy compat
            recipientEmail: dispute.recipientEmail || '',
            recipientPhoneNumber: dispute.recipientPhoneNumber || '',
            filerUid: dispute.filedBy.uid,
            filerEmail: dispute.filedBy.email || '',
            filerPhoneNumber: dispute.filedBy.phoneNumber || '',
            amountOwed: unrecovered,
            amountRecovered: 0,
            currency: dispute.disputedCurrency,
            status: 'active',
            decisionDirection: 'refund_to_buyer',   // Phase 5i: explicit direction
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastDeductionAt: null,
            closedAt: null,
            createdBy: 'adminManagerDecision',
          });
        }

        // Update dispute → solved
        transaction.update(disputeRef, {
          status: 'solved',
          decisionDirection: 'refund_to_buyer',
          amountOwed: requestedRefund,
          amountInEscrow: initialEscrow,
          amountRecovered: 0,                      // moved to amountInEscrow now; only counts on release
          amountUnrecovered: unrecovered,
          solvedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewingManager: managerInfo,
          managerDecision: decision,
          managerDecisionAmount: requestedRefund,
          managerNotes: notes.trim(),
          _awaitingMoneyMovement: unrecovered > 0,
          _recoveryWatchActive: unrecovered > 0,
        });
      });

      // If fully collected at decision time, immediately transition to awaiting_release
      if (unrecovered === 0) {
        await disputeRef.update({
          status: 'awaiting_release',
          awaitingReleaseAt: admin.firestore.FieldValue.serverTimestamp(),
          fullyCollectedAt: admin.firestore.FieldValue.serverTimestamp(),
          _recoveryWatchActive: false,
        });
        newStatus = 'awaiting_release';
      }

      // Lift wallet_blocks (recipient holds get lifted because the money is no longer "held" — it's in escrow)
      const blocksSnap = await db.collection('wallet_blocks')
        .where('disputeId', '==', disputeId)
        .where('liftedAt', '==', null)
        .get();
      const blockBatch = db.batch();
      blocksSnap.docs.forEach(blockDoc => {
        blockBatch.update(blockDoc.ref, {
          liftedAt: admin.firestore.FieldValue.serverTimestamp(),
          liftReason: 'dispute_solved_to_escrow',
        });
      });
      if (!blocksSnap.empty) await blockBatch.commit();

      // Notifications (per Section 4.4)
      if (newStatus === 'awaiting_release') {
        // Fully collected immediately
        await sendCustomerSms({
          phoneNumber: dispute.filedBy.phoneNumber,
          message: `Dispute ${disputeId}: decision made (${decision}). Full ${requestedRefund} ${dispute.disputedCurrency} collected and held. Support team will verify before release.`,
          relatedTo: `dispute:${disputeId}`,
        });
        if (dispute.recipientPhoneNumber) {
          await sendCustomerSms({
            phoneNumber: dispute.recipientPhoneNumber,
            message: `Dispute ${disputeId} resolved. ${requestedRefund} ${dispute.disputedCurrency} held from your wallet pending verification.`,
            relatedTo: `dispute:${disputeId}`,
          });
        }
      } else {
        // Partial collected, recovery in progress
        await sendCustomerSms({
          phoneNumber: dispute.filedBy.phoneNumber,
          message: `Dispute ${disputeId}: decision made (${decision}). Recovering ${requestedRefund} ${dispute.disputedCurrency}. ${initialEscrow} held so far; remaining will be collected as recipient deposits.`,
          relatedTo: `dispute:${disputeId}`,
        });
        if (dispute.recipientPhoneNumber) {
          await sendCustomerSms({
            phoneNumber: dispute.recipientPhoneNumber,
            message: `Dispute ${disputeId} resolved against you. ${requestedRefund} ${dispute.disputedCurrency} owed. ${initialEscrow} deducted now; remaining ${unrecovered} will be deducted as funds become available.`,
            relatedTo: `dispute:${disputeId}`,
          });
        }
      }

      await db.collection('dispute_history').doc(dispute.filedBy.uid).set({
        totalUpheld: admin.firestore.FieldValue.increment(1),
        totalActiveCount: admin.firestore.FieldValue.increment(-1),
      }, { merge: true });

    } else {
      // Phase 5i: buyer_owes_seller_full or buyer_owes_seller_partial
      // Mirror of refund flow with parties reversed.
      newStatus = 'solved';

      const requestedAmount = decision === 'buyer_owes_seller_partial' ? amount : dispute.disputedAmount;
      const filerHold = dispute.filerHoldAmount || 0;
      const recipientHold = dispute.recipientHoldAmount || dispute.currentHoldAmount || 0;
      const initialEscrow = Math.min(requestedAmount, filerHold);
      const unrecovered = Math.max(0, requestedAmount - initialEscrow);

      const escrowRef = await getOrCreateRecoveryWallet(dispute.disputedCurrency);

      await db.runTransaction(async (transaction) => {
        // Lift recipient's hold (recipient is not the source in buyer_owes flow)
        if (recipientHold > 0 && dispute.recipientUid) {
          const recipientWalletRef = db.collection('wallets').doc(dispute.recipientUid);
          transaction.update(recipientWalletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-recipientHold),
            availableBalance: admin.firestore.FieldValue.increment(recipientHold),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Move filer's hold into escrow
        if (initialEscrow > 0 && dispute.filedBy && dispute.filedBy.uid) {
          const filerWalletRef = db.collection('wallets').doc(dispute.filedBy.uid);
          transaction.update(filerWalletRef, {
            heldBalance: admin.firestore.FieldValue.increment(-initialEscrow),
            balance: admin.firestore.FieldValue.increment(-initialEscrow),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          transaction.update(escrowRef, {
            balance: admin.firestore.FieldValue.increment(initialEscrow),
            availableBalance: admin.firestore.FieldValue.increment(initialEscrow),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Create wallet_debt for unrecovered, with sourceUid = filer
        if (unrecovered > 0 && dispute.filedBy && dispute.filedBy.uid) {
          const debtRef = db.collection('wallet_debts').doc();
          transaction.set(debtRef, {
            debtId: debtRef.id,
            disputeId,
            sourceUid: dispute.filedBy.uid,             // Phase 5i: filer is source
            recipientUid: dispute.recipientUid,         // legacy compat — unused for this direction
            recipientEmail: dispute.recipientEmail || '',
            recipientPhoneNumber: dispute.recipientPhoneNumber || '',
            filerUid: dispute.filedBy.uid,
            filerEmail: dispute.filedBy.email || '',
            filerPhoneNumber: dispute.filedBy.phoneNumber || '',
            amountOwed: unrecovered,
            amountRecovered: 0,
            currency: dispute.disputedCurrency,
            status: 'active',
            decisionDirection: 'pay_to_seller',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastDeductionAt: null,
            closedAt: null,
            createdBy: 'adminManagerDecision',
          });
        }

        transaction.update(disputeRef, {
          status: 'solved',
          decisionDirection: 'pay_to_seller',
          amountOwed: requestedAmount,
          amountInEscrow: initialEscrow,
          amountRecovered: 0,
          amountUnrecovered: unrecovered,
          solvedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewingManager: managerInfo,
          managerDecision: decision,
          managerDecisionAmount: requestedAmount,
          managerNotes: notes.trim(),
          _awaitingMoneyMovement: unrecovered > 0,
          _recoveryWatchActive: unrecovered > 0,
        });
      });

      // If fully collected, immediate awaiting_release
      if (unrecovered === 0) {
        await disputeRef.update({
          status: 'awaiting_release',
          awaitingReleaseAt: admin.firestore.FieldValue.serverTimestamp(),
          fullyCollectedAt: admin.firestore.FieldValue.serverTimestamp(),
          _recoveryWatchActive: false,
        });
        newStatus = 'awaiting_release';
      }

      // Lift wallet_blocks
      const blocksSnap2 = await db.collection('wallet_blocks')
        .where('disputeId', '==', disputeId)
        .where('liftedAt', '==', null)
        .get();
      const blockBatch2 = db.batch();
      blocksSnap2.docs.forEach(blockDoc => {
        blockBatch2.update(blockDoc.ref, {
          liftedAt: admin.firestore.FieldValue.serverTimestamp(),
          liftReason: 'dispute_solved_to_escrow',
        });
      });
      if (!blocksSnap2.empty) await blockBatch2.commit();

      // Notifications: filer is now the one paying
      if (newStatus === 'awaiting_release') {
        await sendCustomerSms({
          phoneNumber: dispute.filedBy.phoneNumber,
          message: `Dispute ${disputeId}: decision made (${decision}). Full ${requestedAmount} ${dispute.disputedCurrency} held from your wallet. Support team will verify before release to recipient.`,
          relatedTo: `dispute:${disputeId}`,
        });
        if (dispute.recipientPhoneNumber) {
          await sendCustomerSms({
            phoneNumber: dispute.recipientPhoneNumber,
            message: `Dispute ${disputeId} resolved in your favor. ${requestedAmount} ${dispute.disputedCurrency} held in escrow pending verification before release.`,
            relatedTo: `dispute:${disputeId}`,
          });
        }
      } else {
        await sendCustomerSms({
          phoneNumber: dispute.filedBy.phoneNumber,
          message: `Dispute ${disputeId}: decision made (${decision}). ${initialEscrow} ${dispute.disputedCurrency} held now; remaining ${unrecovered} will be collected from your wallet over time.`,
          relatedTo: `dispute:${disputeId}`,
        });
        if (dispute.recipientPhoneNumber) {
          await sendCustomerSms({
            phoneNumber: dispute.recipientPhoneNumber,
            message: `Dispute ${disputeId} resolved in your favor. Recovery in progress: ${initialEscrow} of ${requestedAmount} ${dispute.disputedCurrency} collected so far.`,
            relatedTo: `dispute:${disputeId}`,
          });
        }
      }

      await db.collection('dispute_history').doc(dispute.filedBy.uid).set({
        totalActiveCount: admin.firestore.FieldValue.increment(-1),
        // Note: 'totalUpheld' / 'totalRejected' counters are buyer-centric in the original schema.
        // For buyer_owes_seller, the buyer's history shows totalActiveCount decrement only.
        // Future: add totalOwedToOthers counter or similar. Out of scope for v1.
      }, { merge: true });
    }
```

The kickback branch (around line 14829-14857) stays unchanged — kickback still goes to `investigating`.

The `audit_logs` and `admin_activity` writes at the end of the function (around line 15077-15090) stay unchanged.

### 7.6 Modify `adminSuperAdminDisputeDecision` Symmetrically

**Location:** `functions/index.js:15105`.

The super_admin decision function is structurally identical to `adminManagerDecision` minus the `kickback` option. Apply the same changes (Change A through Change D from 7.5) but:
- Skip the `kickback` parts (super_admin has no kickback)
- Use `superAdminDecision` and `superAdminDecidedBy` fields instead of `managerDecision` and `reviewingManager`
- Set `decidedByRole: 'super_admin'` on each branch
- VALID_DECISIONS array: `['refund_full', 'refund_partial', 'release', 'buyer_owes_seller_full', 'buyer_owes_seller_partial']`

The implementing AI must write out the equivalent code for this function. It is NOT a literal copy-paste of 7.5 — the field names differ. Take care.

### 7.7 Add Function: `adminProposeDisputeRelease`

**Location:** `functions/index.js`, after `adminSuperAdminDisputeDecision` ends.

**NEW FUNCTION (add):**

```javascript
/**
 * Phase 5i (Section 4.5): Propose release of a dispute that is in 'awaiting_release'.
 * Two-person release: this function is step 1 of 2.
 * The proposer must have personally contacted both parties and verified outcome.
 */
exports.adminProposeDisputeRelease = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');
  const { disputeId, releaseDirection, buyerContacted, sellerContacted, notes, idempotencyKey } = data || {};

  if (!disputeId) throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
  if (!['release_to_payee', 'reverse_to_payer'].includes(releaseDirection)) {
    throw new functions.https.HttpsError('invalid-argument', 'releaseDirection must be release_to_payee or reverse_to_payer.');
  }
  if (buyerContacted !== true) throw new functions.https.HttpsError('invalid-argument', 'You must confirm you contacted the buyer.');
  if (sellerContacted !== true) throw new functions.https.HttpsError('invalid-argument', 'You must confirm you contacted the seller.');
  if (!notes || typeof notes !== 'string' || notes.trim().length < 50) {
    throw new functions.https.HttpsError('invalid-argument', 'notes must be at least 50 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }

  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminProposeDisputeRelease');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminProposeDisputeRelease.message);

  try {
    const disputeRef = db.collection('disputes').doc(disputeId);
    const disputeSnap = await disputeRef.get();
    if (!disputeSnap.exists) throw new functions.https.HttpsError('not-found', `Dispute ${disputeId} not found.`);
    const dispute = disputeSnap.data();

    if (dispute.status !== 'awaiting_release') {
      throw new functions.https.HttpsError('failed-precondition', `Dispute is in '${dispute.status}', expected 'awaiting_release'.`);
    }
    if (dispute.releaseProposal) {
      throw new functions.https.HttpsError('failed-precondition', 'A release proposal is already active for this dispute. Wait for it to be confirmed, rejected, or expire.');
    }

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;
    const proposerInfo = { uid: caller.uid, email: callerEmail, role: caller.role, displayName: callerDisplayName };

    const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;
    const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + TWENTY_FOUR_HOURS_MS);

    await disputeRef.update({
      releaseProposal: {
        proposedBy: proposerInfo,
        proposedAt: admin.firestore.Timestamp.now(),
        releaseDirection,
        notes: notes.trim(),
        buyerContacted: true,
        sellerContacted: true,
        expiresAt,
      },
    });

    // Email all admin+ users except proposer
    const adminUsersSnap = await db.collection('admin_users')
      .where('role', 'in', ['admin', 'admin_supervisor', 'admin_manager', 'super_admin'])
      .get();
    for (const adminUserDoc of adminUsersSnap.docs) {
      if (adminUserDoc.data().uid === caller.uid) continue;
      try {
        await sendProposalEmail({
          to: adminUserDoc.id,
          toName: adminUserDoc.data().displayName || null,
          subject: `Release proposal for dispute ${disputeId}`,
          htmlBody: `<p>${callerDisplayName} (${caller.role}) has proposed to <strong>${releaseDirection === 'release_to_payee' ? 'RELEASE TO PAYEE' : 'REVERSE TO PAYER'}</strong> on dispute <strong>${disputeId}</strong>.</p>
<p><strong>Notes:</strong> ${notes.trim()}</p>
<p>Review and confirm or reject in the admin dashboard. <strong>Important:</strong> independently contact both parties before confirming. Wrongful release = personal liability.</p>
<p>Proposal expires in 24 hours.</p>`,
          textBody: `Release proposal for dispute ${disputeId} by ${callerDisplayName}. Direction: ${releaseDirection}. Review in dashboard.`,
          relatedTo: `dispute:${disputeId}`,
        });
      } catch (emailError) {
        logWarning('adminProposeDisputeRelease: failed to email admin', { adminEmail: adminUserDoc.id, error: emailError.message });
      }
    }

    await db.collection('audit_logs').add({
      userId: caller.uid, operation: 'adminProposeDisputeRelease', result: 'success',
      metadata: { disputeId, releaseDirection, notes: notes.trim() },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('admin_activity').add({
      uid: caller.uid, email: callerEmail, role: caller.role,
      action: 'propose_dispute_release', details: `Proposed ${releaseDirection} on dispute ${disputeId}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, disputeId, releaseDirection };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminProposeDisputeRelease failed', { disputeId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to propose release: ' + error.message);
  }
});
```

Add rate limit entry:
```javascript
adminProposeDisputeRelease: { windowMs: 60 * 60 * 1000, maxRequests: 30, message: 'Too many release proposals.' },
```

### 7.8 Add Function: `adminConfirmDisputeRelease`

**Location:** `functions/index.js`, immediately after `adminProposeDisputeRelease`.

**NEW FUNCTION (add):**

```javascript
/**
 * Phase 5i (Section 4.5): Confirm a release proposal. Step 2 of 2.
 * Confirmer MUST be different uid than proposer. Atomically moves money from
 * escrow to the receiving party and closes the dispute.
 */
exports.adminConfirmDisputeRelease = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');
  const { disputeId, buyerContacted, sellerContacted, notes, idempotencyKey } = data || {};

  if (!disputeId) throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
  if (buyerContacted !== true) throw new functions.https.HttpsError('invalid-argument', 'You must confirm you independently contacted the buyer.');
  if (sellerContacted !== true) throw new functions.https.HttpsError('invalid-argument', 'You must confirm you independently contacted the seller.');
  if (!notes || typeof notes !== 'string' || notes.trim().length < 50) {
    throw new functions.https.HttpsError('invalid-argument', 'notes must be at least 50 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }

  const withinLimit = await checkRateLimitPersistent(caller.uid, 'adminConfirmDisputeRelease');
  if (!withinLimit) throw new functions.https.HttpsError('resource-exhausted', RATE_LIMITS.adminConfirmDisputeRelease.message);

  try {
    const disputeRef = db.collection('disputes').doc(disputeId);
    const disputeSnap = await disputeRef.get();
    if (!disputeSnap.exists) throw new functions.https.HttpsError('not-found', `Dispute ${disputeId} not found.`);
    const dispute = disputeSnap.data();

    if (dispute.status !== 'awaiting_release') {
      throw new functions.https.HttpsError('failed-precondition', `Dispute is in '${dispute.status}', expected 'awaiting_release'.`);
    }
    if (!dispute.releaseProposal) {
      throw new functions.https.HttpsError('failed-precondition', 'No active release proposal on this dispute.');
    }
    if (dispute.releaseProposal.proposedBy.uid === caller.uid) {
      throw new functions.https.HttpsError('permission-denied', 'You cannot confirm your own release proposal. A different admin must confirm.');
    }
    const expiresAt = dispute.releaseProposal.expiresAt;
    if (expiresAt && expiresAt.toMillis && expiresAt.toMillis() < Date.now()) {
      throw new functions.https.HttpsError('failed-precondition', 'Release proposal has expired. Please re-propose.');
    }

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;
    const confirmerInfo = { uid: caller.uid, email: callerEmail, role: caller.role, displayName: callerDisplayName };

    const releaseDirection = dispute.releaseProposal.releaseDirection;
    const amountInEscrow = dispute.amountInEscrow || 0;
    const escrowRef = await getOrCreateRecoveryWallet(dispute.disputedCurrency);

    let payeeUid, payerReturnUid, finalStatus, closingRemarksReason;

    if (dispute.decisionDirection === 'refund_to_buyer') {
      // Refund flow: payee = buyer (filer), payer = seller (recipient)
      payeeUid = dispute.filedBy.uid;
      payerReturnUid = dispute.recipientUid;
    } else {
      // buyer_owes_seller flow: payee = seller (recipient), payer = buyer (filer)
      payeeUid = dispute.recipientUid;
      payerReturnUid = dispute.filedBy.uid;
    }

    if (releaseDirection === 'release_to_payee') {
      finalStatus = 'closed';
      closingRemarksReason = dispute.decisionDirection === 'refund_to_buyer' ? 'released_to_payee_refund' : 'released_to_payee_buyer_owes';
    } else {
      finalStatus = 'closed_returned';
      closingRemarksReason = dispute.decisionDirection === 'refund_to_buyer' ? 'reverse_to_payer_refund' : 'reverse_to_payer_buyer_owes';
    }

    const targetUid = releaseDirection === 'release_to_payee' ? payeeUid : payerReturnUid;
    const closingRemarks = generateClosingRemarks(dispute, closingRemarksReason);

    await db.runTransaction(async (transaction) => {
      // Move money from escrow to target
      if (amountInEscrow > 0 && targetUid) {
        const targetWalletRef = db.collection('wallets').doc(targetUid);
        transaction.update(escrowRef, {
          balance: admin.firestore.FieldValue.increment(-amountInEscrow),
          availableBalance: admin.firestore.FieldValue.increment(-amountInEscrow),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.update(targetWalletRef, {
          balance: admin.firestore.FieldValue.increment(amountInEscrow),
          availableBalance: admin.firestore.FieldValue.increment(amountInEscrow),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // Update dispute → closed or closed_returned
      transaction.update(disputeRef, {
        status: finalStatus,
        releaseDirection,
        releaseConfirmedBy: confirmerInfo,
        releaseConfirmedAt: admin.firestore.FieldValue.serverTimestamp(),
        closedAt: admin.firestore.FieldValue.serverTimestamp(),
        amountRecovered: releaseDirection === 'release_to_payee' ? amountInEscrow : 0,
        amountUnrecovered: releaseDirection === 'reverse_to_payer' ? 0 : (dispute.amountUnrecovered || 0),
        closingRemarks,
        // Clear releaseProposal — no longer needed
        releaseProposal: null,
      });
    });

    // Notifications per Section 4.4
    if (releaseDirection === 'release_to_payee') {
      // Tell payee they got the money
      const payeePhone = (dispute.decisionDirection === 'refund_to_buyer') ? dispute.filedBy.phoneNumber : dispute.recipientPhoneNumber;
      const otherPhone = (dispute.decisionDirection === 'refund_to_buyer') ? dispute.recipientPhoneNumber : dispute.filedBy.phoneNumber;
      if (payeePhone) {
        await sendCustomerSms({
          phoneNumber: payeePhone,
          message: `Dispute ${disputeId} resolved. ${amountInEscrow} ${dispute.disputedCurrency} sent to your wallet.`,
          relatedTo: `dispute:${disputeId}`,
        });
      }
      if (otherPhone) {
        await sendCustomerSms({
          phoneNumber: otherPhone,
          message: `Dispute ${disputeId} resolved. Funds released to other party.`,
          relatedTo: `dispute:${disputeId}`,
        });
      }
    } else {
      // Reversal: tell the original payer their money came back
      const payerPhone = (dispute.decisionDirection === 'refund_to_buyer') ? dispute.recipientPhoneNumber : dispute.filedBy.phoneNumber;
      const otherPhone = (dispute.decisionDirection === 'refund_to_buyer') ? dispute.filedBy.phoneNumber : dispute.recipientPhoneNumber;
      if (payerPhone) {
        await sendCustomerSms({
          phoneNumber: payerPhone,
          message: `Dispute ${disputeId} verification confirmed in your favor. ${amountInEscrow} ${dispute.disputedCurrency} returned to your wallet.`,
          relatedTo: `dispute:${disputeId}`,
        });
      }
      if (otherPhone) {
        await sendCustomerSms({
          phoneNumber: otherPhone,
          message: `Dispute ${disputeId} verification reversed the decision. Funds returned to other party.`,
          relatedTo: `dispute:${disputeId}`,
        });
      }
    }

    await db.collection('audit_logs').add({
      userId: caller.uid, operation: 'adminConfirmDisputeRelease', result: 'success',
      metadata: { disputeId, releaseDirection, notes: notes.trim(), proposedBy: dispute.releaseProposal.proposedBy.uid },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('admin_activity').add({
      uid: caller.uid, email: callerEmail, role: caller.role,
      action: 'confirm_dispute_release', details: `Confirmed ${releaseDirection} on dispute ${disputeId} (proposed by ${dispute.releaseProposal.proposedBy.email})`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, disputeId, finalStatus };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminConfirmDisputeRelease failed', { disputeId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to confirm release: ' + error.message);
  }
});
```

Add rate limit entry:
```javascript
adminConfirmDisputeRelease: { windowMs: 60 * 60 * 1000, maxRequests: 30, message: 'Too many release confirmations.' },
```

### 7.9 Add Function: `adminRejectDisputeRelease`

**Location:** Immediately after `adminConfirmDisputeRelease`.

**NEW FUNCTION (add):**

```javascript
/**
 * Phase 5i (Section 4.5): Reject an active release proposal.
 * Returns dispute to plain awaiting_release. A new proposal can be made.
 */
exports.adminRejectDisputeRelease = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  const caller = await verifyAdmin(context, 'admin');
  const { disputeId, reason, idempotencyKey } = data || {};

  if (!disputeId) throw new functions.https.HttpsError('invalid-argument', 'disputeId is required.');
  if (!reason || typeof reason !== 'string' || reason.trim().length < 20) {
    throw new functions.https.HttpsError('invalid-argument', 'reason must be at least 20 characters.');
  }
  if (!idempotencyKey || typeof idempotencyKey !== 'string' || idempotencyKey.length < 16) {
    throw new functions.https.HttpsError('invalid-argument', 'idempotencyKey must be at least 16 characters.');
  }

  try {
    const disputeRef = db.collection('disputes').doc(disputeId);
    const disputeSnap = await disputeRef.get();
    if (!disputeSnap.exists) throw new functions.https.HttpsError('not-found', `Dispute ${disputeId} not found.`);
    const dispute = disputeSnap.data();

    if (dispute.status !== 'awaiting_release' || !dispute.releaseProposal) {
      throw new functions.https.HttpsError('failed-precondition', 'No active release proposal to reject.');
    }
    if (dispute.releaseProposal.proposedBy.uid === caller.uid) {
      throw new functions.https.HttpsError('permission-denied', 'You cannot reject your own proposal.');
    }

    const callerRecord = await admin.auth().getUser(caller.uid);
    const callerEmail = callerRecord.email || 'unknown';
    const callerDisplayName = callerRecord.displayName || callerEmail;
    const rejecterInfo = { uid: caller.uid, email: callerEmail, role: caller.role, displayName: callerDisplayName };

    await disputeRef.update({
      releaseProposal: null,
      releaseRejectedBy: rejecterInfo,
      releaseRejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      releaseRejectionReason: reason.trim(),
    });

    // Email original proposer
    if (dispute.releaseProposal.proposedBy.email) {
      try {
        await sendProposalEmail({
          to: dispute.releaseProposal.proposedBy.email,
          toName: dispute.releaseProposal.proposedBy.displayName || null,
          subject: `Your release proposal for dispute ${disputeId} was rejected`,
          htmlBody: `<p>${callerDisplayName} (${caller.role}) rejected your release proposal for dispute <strong>${disputeId}</strong>.</p>
<p><strong>Reason:</strong> ${reason.trim()}</p>
<p>Review and propose again if appropriate.</p>`,
          textBody: `Release proposal for dispute ${disputeId} rejected by ${callerDisplayName}. Reason: ${reason.trim()}`,
          relatedTo: `dispute:${disputeId}`,
        });
      } catch (e) { /* non-blocking */ }
    }

    await db.collection('audit_logs').add({
      userId: caller.uid, operation: 'adminRejectDisputeRelease', result: 'success',
      metadata: { disputeId, reason: reason.trim() },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('admin_activity').add({
      uid: caller.uid, email: callerEmail, role: caller.role,
      action: 'reject_dispute_release', details: `Rejected release proposal on dispute ${disputeId}: ${reason.trim()}`,
      ip: context.rawRequest?.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || 'unknown',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, disputeId };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) throw error;
    logError('adminRejectDisputeRelease failed', { disputeId, caller: caller.uid, error: error.message });
    throw new functions.https.HttpsError('internal', 'Failed to reject release: ' + error.message);
  }
});
```

### 7.10 Add Functions: Buyer Self-Service

**Location:** `functions/index.js`, near the other `user*` functions (find `userFileDispute` and add nearby).

**NEW FUNCTION 1 — `userRequestPartialRelease`:** Per Section 4.7. Implementing AI: write the function following the same pattern as `userRespondToDispute` (above in 7.4). Validation: caller must be `dispute.filedBy.uid`, dispute must be `solved`, `amountInEscrow > 0`, and `amountInEscrow < amountOwed`. Action: set `partialReleaseRequested: true` and notify admins via email. Does NOT auto-release.

**NEW FUNCTION 2 — `userCancelDispute`:** Per Section 4.7. Caller must be `dispute.filedBy.uid`. Dispute must be in any active state (`filed`, `investigating`, `supervisor_review`, `manager_review`, `solved` — NOT `awaiting_release` or any closed state). Validation: reason ≥20 chars. Action: sets `cancellationRequested: true`. Triggers admin email. Does NOT auto-cancel.

**NEW FUNCTION 3 — `adminConfirmCancellation`:** Per Section 4.7. Caller must be `support` or higher. Validation: dispute must have `cancellationRequested === true`, must be in same active states. Action atomically:
- Return any escrowed money to the appropriate party (refund flow → seller; buyer_owes flow → buyer)
- Lift any wallet holds
- Set status to `closed_buyer_cancelled`
- Set `cancellationConfirmedBy`, `cancellationConfirmedAt`
- Generate closing remarks via `generateClosingRemarks(dispute, 'buyer_cancelled')`
- SMS both parties

The implementing AI should write these three functions following the established patterns. Don't shortcut — each needs its own input validation, rate limit, audit log, admin_activity entry. Add rate limit entries:
```javascript
userRequestPartialRelease: { windowMs: 60 * 60 * 1000, maxRequests: 10, message: 'Too many partial release requests.' },
userCancelDispute: { windowMs: 60 * 60 * 1000, maxRequests: 5, message: 'Too many cancellation requests.' },
adminConfirmCancellation: { windowMs: 60 * 60 * 1000, maxRequests: 30, message: 'Too many cancellation confirmations.' },
```

### 7.11 Modify Recovery Watch (Section 6.3 implementation)

**Location:** `functions/index.js` around line 15676. The exact function name needs to be found by the implementing AI.

The Recovery Watch function loops through active `wallet_debts` and deducts from the `recipientUid`'s wallet. The Phase 5i changes:

1. Read `wallet_debt.sourceUid` instead of (or in addition to, for legacy) `recipientUid`. The source is the party that owes — set explicitly at debt creation.
2. Move money to the escrow wallet (`getOrCreateRecoveryWallet(currency)`), NOT to the filer's wallet.
3. Update `dispute.amountInEscrow` and `dispute.lastRecoveryDeductionAt` in the same transaction.
4. After each deduction, send SMS to source (per-deduction notification) and to the eventual payee (progress notification).
5. After deduction, check if `dispute.amountInEscrow >= dispute.amountOwed`. If yes, transition `solved → awaiting_release` and send notifications.

**The implementing AI must read the existing Recovery Watch function carefully**, identify each money-move site, and refactor systematically. This is the riskiest single change in Phase 5i — every line involves money. Recommend implementing this with the Recovery Watch function disabled (commented out) until rest of system is stable, then enable last.

### 7.12 Add Scheduled Functions for Stuck Detection (Section 6.6)

Two new pubsub-scheduled functions per Section 6.6 logic. Place them near other scheduled dispute functions (search for `disputeEscalationCheckScheduled` for the pattern).

```javascript
exports.disputeAccountClosureCheckScheduled = functions.pubsub
  .schedule('every day 03:00')
  .timeZone('UTC')
  .onRun(async (context) => {
    // 1. Query disputes where status == 'solved' AND _recoveryWatchActive == true
    // 2. For each, get the source UID (depends on decisionDirection)
    // 3. Try to fetch user from auth — if 404, account closed
    // 4. If accountClosureDetectedAt is null, set it = now
    // 5. Else if (now - accountClosureDetectedAt) >= 3 days:
    //    - Transition to closed_stuck
    //    - Set stuckReason: 'account_closed'
    //    - Generate closing remarks via generateClosingRemarks(d, 'stuck_account_closed')
    //    - Lift escrow money: send back to filer if refund direction (since seller is gone),
    //      send back to seller if buyer_owes direction (since buyer is gone) — wait, no:
    //      the closed account is the SOURCE. If source is gone, the escrow money is whatever
    //      we managed to collect already. Decision: keep it in escrow for now, mark dispute
    //      stuck. Eric to decide later if escrow money should be released or held.
    //    - Actually, per Eric: "the buyer is advised to contact the authorities for assistance.
    //      We will help with the evidence gathered." So whatever's in escrow likely gets released
    //      to the eventual recipient (buyer in refund flow, seller in buyer_owes flow).
    //
    //    HOLD POINT FOR IMPLEMENTING AI: ask Eric what to do with the escrow money on stuck.
    //    Three options:
    //    (a) Release escrow to eventual payee (recovery so far counts)
    //    (b) Return escrow to original payer (recovery is undone)
    //    (c) Hold escrow indefinitely until manual admin decision
    //    Default in this spec: (a) — partial recovery is honored. Confirm with Eric before deploy.
    //
    //    - SMS both parties (with appropriate phrasing)
    //    - Audit + admin_activity entries
  });
```

Implementing AI: I am explicitly leaving an OPEN QUESTION above for Eric. Do not proceed with stuck-detection implementation without confirming what to do with money in escrow when the account is closed. Same question applies to the 90-day stuck case — though for that one, the source is still around (just not depositing), so it's less clear what should happen.

```javascript
exports.disputeNoProgressCheckScheduled = functions.pubsub
  .schedule('every day 04:00')
  .timeZone('UTC')
  .onRun(async (context) => {
    // 1. Query disputes where status == 'solved' AND _recoveryWatchActive == true
    // 2. For each:
    //    - daysSinceLastDeduction = (now - lastRecoveryDeductionAt or solvedAt) / 1 day
    //    - daysSinceLastSourceDeposit = (now - sourceWallet.lastDepositAt) / 1 day
    //    - If min(both) >= 90:
    //      - Transition to closed_stuck with stuckReason='no_progress_90d'
    //      - Same escrow handling question as above
    //      - SMS both parties
    //      - Audit + admin_activity
  });
```

### 7.13 Add Function: `adminMarkDisputeAccountClosed`

**Location:** Near other admin dispute functions.

**NEW FUNCTION:**
- Required role: `admin` or higher
- Inputs: `disputeId`, `evidence` (≥50 chars description), `idempotencyKey`
- Validation: dispute in `solved` state
- Action: sets `accountClosureDetectedAt: serverTimestamp`, `accountClosureDetectedBy: { uid, email, evidence }`. The 3-day daily job will pick it up and complete the transition.

Implementing AI: write following the established pattern. ~50 lines.

### 7.14 Add Function: `adminExportDisputeEvidencePackage`

**Location:** Near other admin dispute functions.

**NEW FUNCTION (per Section 6.9):**
- Required role: `admin` or higher
- Inputs: `disputeId`
- Validation: dispute in any closed state
- Action: aggregates all related data and returns structured JSON. No money movement, just reads.

Implementing AI: write following established read patterns. ~80 lines.

### 7.15 Add Function: `disputeReleaseProposalExpiryScheduled`

**Location:** Near other scheduled functions.

**NEW FUNCTION (per Section 6.4):** runs hourly, clears expired release proposals, emails proposer.

---

## 8. Firestore Rules Changes

**File:** `firestore.rules`

### 8.1 Add Rules for Platform Escrow Wallets

Find the `match /wallets/{walletId}` block. Currently it allows users to read their own wallets via Cloud Functions only. Add a sub-condition:

```
match /wallets/{walletId} {
  // Existing rules...
  
  // Phase 5i: platform-owned dispute recovery escrow wallets.
  // Only Cloud Functions can read or write. Marker: doc has isPlatform: true.
  // No client access whatsoever.
  allow read, write: if walletId.matches('dispute_recovery_.*') && false;
}
```

The `&& false` makes it unreachable from clients — Cloud Functions bypass rules entirely.

### 8.2 Add Field Allowances on Dispute Doc

Find the `match /disputes/{disputeId}` block. The new fields (Section 6.2) must be permitted in the schema. The existing rule likely uses an allowlist of fields — add the new ones to it.

Implementing AI must locate the existing dispute rule and update the field whitelist to include all the new Phase 5i fields. Important: any field that allows seller (recipient) writes must be guarded so only the recipient can write to it (e.g., `recipientResponse`).

### 8.3 Add Rules for `wallet_debts.sourceUid`

The new field `sourceUid` on `wallet_debts` must be allowed. Find the `wallet_debts` rule and add to its field whitelist.

---

## 9. Flutter Changes (Screen-by-Screen)

**Folder:** `lib/features/disputes/screens/`

The implementing AI must read the existing dispute screens (`my_disputes`, `dispute_detail`, `file_dispute`, `respond_to_dispute`) before changing.

### 9.1 `dispute_detail.dart`

**Changes:**
- Map all new statuses (`solved`, `awaiting_release`, `closed`, `closed_returned`, `closed_stuck`, `closed_buyer_cancelled`) to user-friendly displays per the table in Section 4.1.
- Show progress bar for `solved` disputes: `amountInEscrow / amountOwed` with "X of Y collected" text.
- Show "Awaiting verification" banner for `awaiting_release` disputes.
- Show closing remarks (`closingRemarks` field) for any closed status.
- For buyer (filer): if dispute is `solved` with `amountInEscrow > 0` and `amountInEscrow < amountOwed`, show "Request partial release" button → calls `userRequestPartialRelease`.
- For buyer (filer): if dispute is in any cancellable state, show "Cancel dispute" button → calls `userCancelDispute`.
- For seller (recipient): show response form if dispute is in a respondable state (`filed`, `investigating`, `supervisor_review`) → calls `userRespondToDispute`. If a response was already submitted, show it.

### 9.2 `respond_to_dispute.dart`

A new screen (or wire up existing one if it exists, per handover doc Phase 5j note that it's not wired). Calls `userRespondToDispute`. Shows: dispute summary, response text field (≥20 chars), optional evidence file picker.

### 9.3 `my_disputes.dart`

Update status badges/colors for the new statuses. Show new badges where appropriate.

### 9.4 New Screen: Seller's Dispute View

If the seller (recipient) has a dispute against them, they should see it in their dispute list too. Currently the dispute system seems buyer-centric. Implementing AI must check `my_disputes.dart` to see if it shows disputes where `recipientUid == currentUid`. If not, that's a separate UX consideration.

---

## 10. Admin Dashboard Changes (Page-by-Page)

**Folder:** `admin-dashboard/src/pages/`

### 10.1 Disputes Page (Existing — find it)

The implementing AI must locate the disputes page (likely `DisputesPage.jsx` or `DisputesListPage.jsx`).

**Changes:**
- Add filter for new statuses: `solved`, `awaiting_release`, `closed`, `closed_returned`, `closed_stuck`, `closed_buyer_cancelled`
- Add columns: `decisionDirection`, `amountInEscrow / amountOwed`, `releaseProposal status`
- Add quick-action buttons appropriate to status

### 10.2 Dispute Detail Page (Existing or New)

For each status, show appropriate admin actions:

- `awaiting_release`: show "Propose Release" button (modal with all the safeguards). If proposal exists: show proposal details + "Confirm" / "Reject" buttons (only visible to non-proposer).
- `solved` with `cancellationRequested: true`: show "Confirm cancellation" form
- `solved` with `partialReleaseRequested: true`: show "Process partial release" link (kicks into Two-Person Release flow)
- Any closed state: show "Export Evidence Package" button

### 10.3 New Page: "Awaiting Release Queue"

A dedicated page filtering disputes in `awaiting_release`. Shows pending proposals (admin can confirm/reject) and disputes with no proposal yet (admin can propose). Implementing AI: design layout following the existing dashboard patterns.

### 10.4 NotificationBanner

The existing banner code (`admin-dashboard/src/components/NotificationBanner.jsx`) currently watches for `evidence_overdue` proposals. Add a watcher for "release proposals awaiting your confirmation" — disputes in `awaiting_release` with `releaseProposal !== null` AND `releaseProposal.proposedBy.uid !== currentAdminUid` AND not expired.

---

## 11. Migration Plan

### 11.1 Existing Disputes — What Stays What

Per Section 4.9, **all existing `resolved` disputes stay `resolved` forever**. The new code is opt-in for new disputes only. Specifically:

- The new code paths only kick in when a NEW dispute is filed AND a manager makes a decision after deploy. Disputes already in any state at deploy time follow the OLD code path.
- Existing `wallet_debts` with `sourceUid: undefined` continue to be processed by the OLD recovery watch logic (deduct from `recipientUid` and credit filer directly). The new code reads `sourceUid` first; if undefined, falls back to the legacy field.

This dual-path approach prevents disrupting active disputes mid-flight.

### 11.2 Pre-Deploy Audit Script

Before deploy, run this script to inventory the legacy tail:

```javascript
// scripts/phase_5i_audit.js — run via firebase functions:shell or one-off Cloud Function
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function audit() {
  const resolvedSnap = await db.collection('disputes').where('status', '==', 'resolved').get();
  let active = 0, total = resolvedSnap.size;
  for (const doc of resolvedSnap.docs) {
    if (doc.data()._recoveryWatchActive === true) active++;
  }
  console.log(`Total resolved disputes: ${total}`);
  console.log(`Of those, with active recovery watch: ${active}`);
  console.log('These will continue processing under the OLD code path.');

  const debtsSnap = await db.collection('wallet_debts').where('status', '==', 'active').get();
  let withSource = 0, withoutSource = 0;
  for (const d of debtsSnap.docs) {
    if (d.data().sourceUid) withSource++; else withoutSource++;
  }
  console.log(`Active wallet_debts: ${debtsSnap.size}, with sourceUid=${withSource}, without=${withoutSource}`);
  console.log('Without-sourceUid debts run on legacy code path; with-sourceUid run on new code path.');
}
audit();
```

Run before deploy. Eric reviews the numbers and decides whether to manually migrate any active legacy disputes to the new code path (probably not — too risky for a small number of active legacy disputes).

### 11.3 No Schema Migration Needed

All the new fields (Section 6.2) are added with sensible defaults at filing time. Existing dispute docs lack these fields, but the new code reads them with `||` fallbacks so undefined behavior is well-defined.

The `wallet_debts.sourceUid` field is added on new debts. Old debts that don't have it use the legacy path.

The escrow wallets are lazily created — `getOrCreateRecoveryWallet` creates on first use.

---

## 12. Deployment Order

This order is BINDING. Do not deploy out of order. Each step must be verified before the next.

### Step 1: Firestore rules
Deploy: `firebase deploy --only firestore:rules`

This unblocks new dispute fields and the escrow wallet pattern. No code touches them yet, so this is harmless.

Verify: `firebase firestore:rules:list` shows the new rules. Try a malicious write from client SDK (e.g., attempt to write to `dispute_recovery_GHS` from a regular user) and confirm rejection.

### Step 2: Firestore indexes (if any new ones added)
Deploy: `firebase deploy --only firestore:indexes`

Verify: `firebase firestore:indexes` shows them.

### Step 3: Helper functions (no behavior change yet)
Deploy: `firebase deploy --only functions:getOrCreateRecoveryWallet,functions:generateClosingRemarks` — wait, these are not exports. They are internal helpers in `index.js`. Skip this step technically; helpers are deployed as part of any function deploy.

### Step 4: New read-only admin functions
Deploy: `firebase deploy --only functions:adminExportDisputeEvidencePackage`

Why first: pure read functions don't change behavior. Verifying this works tells you the new code shape is sound.

Verify: call from admin dashboard with a known disputeId, confirm it returns the expected structure.

### Step 5: New seller response function (no money movement)
Deploy: `firebase deploy --only functions:userRespondToDispute`

Verify: as recipient on a filed dispute, submit a response. Check it appears on the dispute doc.

### Step 6: New buyer self-service functions (no money movement)
Deploy: `firebase deploy --only functions:userRequestPartialRelease,functions:userCancelDispute`

Verify: as buyer on a filed dispute, request partial release. Check `partialReleaseRequested: true` on doc. Same for cancel.

### Step 7: New admin cancellation confirmation (involves money refund)
Deploy: `firebase deploy --only functions:adminConfirmCancellation`

Verify on a dispute with `cancellationRequested: true`: confirm cancellation. Verify money returned, status `closed_buyer_cancelled`, holds lifted, SMS sent.

### Step 8: New release-proposal functions (no money movement yet)
Deploy: `firebase deploy --only functions:adminProposeDisputeRelease,functions:adminRejectDisputeRelease`

Verify: propose release on a manually-set-to-`awaiting_release` dispute. Check proposal recorded. Reject the proposal. Check it cleared.

### Step 9: The big one — `adminConfirmDisputeRelease`
Deploy: `firebase deploy --only functions:adminConfirmDisputeRelease`

Verify on a manually-prepared test dispute in `awaiting_release` state: confirm release_to_payee. Check money moves from escrow to payee. Check status `closed`. Same for reverse_to_payer.

### Step 10: Modified `userFileDispute`
Deploy: `firebase deploy --only functions:userFileDispute`

Why last among non-decision changes: this changes the schema of NEW disputes. Existing disputes are unaffected. New disputes will have all the Phase 5i fields with their initial values.

Verify: file a new dispute. Check seller is SMS'd. Check both `recipientHoldAmount` and `filerHoldAmount` are set on the doc.

### Step 11: Modified `adminManagerDecision`
Deploy: `firebase deploy --only functions:adminManagerDecision`

Verify: take a dispute through full investigation flow → manager decision = `release`. Verify status is now `closed` (not `resolved`). Verify both holds lifted.

Then take another dispute through to `manager_review`. Manager decides `refund_full` with seller's wallet having less than full disputed amount. Verify:
- Status moves to `solved` (not `resolved`)
- Money moves from seller's heldBalance into escrow wallet
- `wallet_debts` created with `sourceUid: <recipientUid>` and `decisionDirection: 'refund_to_buyer'`
- SMS sent appropriately

Then take another dispute through to manager → `buyer_owes_seller_partial`. Verify:
- Status `solved`
- Money moves from buyer's heldBalance into escrow
- `wallet_debt` with `sourceUid: <filedBy.uid>` and `decisionDirection: 'pay_to_seller'`

### Step 12: Modified `adminSuperAdminDisputeDecision`
Deploy: `firebase deploy --only functions:adminSuperAdminDisputeDecision`

Verify on an escalated dispute. Same checks as Step 11 but for the super_admin path.

### Step 13: Modified Recovery Watch
Deploy: `firebase deploy --only functions:<recoveryWatchFunctionName>`

⚠ This is the most dangerous step. Recovery Watch processes money for many disputes simultaneously. The new code path runs for new debts (sourceUid set), legacy code path runs for old debts.

Verify by:
- Manually creating a test dispute in `solved` state with `_recoveryWatchActive: true`, then making a deposit on the source wallet. Wait for the next Recovery Watch run. Check money moved to escrow (not to payee). Check SMS sent.
- Confirming legacy disputes (without `sourceUid` on their debts) still process to the filer's wallet directly.

### Step 14: New scheduled stuck-detection functions
Deploy: `firebase deploy --only functions:disputeAccountClosureCheckScheduled,functions:disputeNoProgressCheckScheduled,functions:disputeReleaseProposalExpiryScheduled,functions:adminMarkDisputeAccountClosed`

These run on a schedule and don't immediately affect existing disputes (they only act on disputes meeting their criteria).

Verify: run them manually via `firebase functions:shell` against a test dispute that meets the criteria.

### Step 15: Flutter app
Build and submit.

### Step 16: Admin dashboard
Build and deploy. Existing dashboard continues to work; new pages/features unlock as they're built.

### Final
Run a smoke test: file a dispute as a real user, take it through the full new flow end-to-end. Verify every status, every notification, every money move. Eric must personally do this with his super_admin account on at least one dispute before Phase 5i is declared done.

---

## 13. Verification Plan

### 13.1 Pre-Deploy Verification (Implementing AI does this)

For each function added/modified, after writing the code:

1. `node -e "require('./functions/index.js')" && echo "ok"` — JS parses
2. `git diff` — only intended files changed
3. Commit message follows pattern `feat(5i): <short description>` or `fix(5i): <description>`

### 13.2 Post-Deploy Verification (Eric does this with implementing AI's guidance)

Each step in section 12 has its own verification noted. The verification signal is BOTH:

- **Functional:** the action produces the expected dispute state and money movement
- **Logged:** the function logs show `status code: 200` (or appropriate success), no `FAILED_PRECONDITION`, no `internal` errors

### 13.3 End-to-End Test Scenarios

Eric should walk through these on production after Phase 5i is fully deployed. Each takes 10-30 minutes including waiting for SMS / notifications.

**Scenario A — Buyer wins, full refund collected immediately:**
1. Buyer files dispute against a transaction where seller has full amount in wallet
2. Admin assigned, investigates, submits findings
3. Supervisor agrees
4. Manager decides refund_full
5. Verify: status `awaiting_release` (because fully collected), seller SMS'd, buyer SMS'd
6. Admin A proposes release_to_payee
7. Admin B (different uid) confirms
8. Verify: status `closed`, money in buyer's wallet, both SMS'd, audit trail shows both admins

**Scenario B — Buyer wins partial, recovery over time:**
1. Same as A but seller has less than full amount
2. Manager decides refund_full → status `solved`
3. Wait for seller to deposit (or simulate via direct write)
4. Recovery Watch runs → some money moves to escrow → seller SMS, buyer SMS
5. Eventually full amount in escrow → auto-transitions to `awaiting_release`
6. Same release flow as A

**Scenario C — Buyer wins, but verification reverses decision:**
1. Same as A or B until `awaiting_release`
2. Admin A proposes reverse_to_payer (reason: discovered item was actually delivered)
3. Admin B confirms
4. Verify: status `closed_returned`, money returned to seller, both SMS'd

**Scenario D — Buyer owes seller:**
1. Buyer files dispute
2. Investigation reveals buyer underpaid, owes more
3. Manager decides buyer_owes_seller_partial
4. Verify: status `solved`, money flowing buyer → escrow, seller SMS'd as eventual payee
5. After full collection: `awaiting_release`
6. Two-person release → `closed`, money to seller

**Scenario E — Buyer cancels mid-investigation:**
1. Buyer files dispute, regrets it 1 day later
2. Buyer calls `userCancelDispute` with reason
3. Admin calls `adminConfirmCancellation` after speaking with buyer
4. Verify: status `closed_buyer_cancelled`, holds lifted, no money moved unjustly

**Scenario F — Account closed, stuck:**
1. Dispute reaches `solved` with seller still owing
2. Seller deletes their account
3. Daily account-closure check finds them gone, sets `accountClosureDetectedAt`
4. 3 days later, daily check transitions to `closed_stuck`
5. Buyer SMS'd advising to contact authorities, evidence package available

**Scenario G — No progress, 90-day stuck:**
1. Dispute reaches `solved` with seller owing
2. Seller's wallet sits dormant, no deposits
3. 90 days pass; no-progress check transitions to `closed_stuck`
4. Both parties SMS'd

**Scenario H — Partial release on demand:**
1. Dispute reaches `solved`, 100 of 400 collected
2. Buyer requests partial release via app
3. Admin contacts buyer, verifies intent
4. Two-person release of the 100 (releaseDirection: release_to_payee)
5. Verify: 100 moves to buyer, dispute STILL in `solved` for the remaining 300
6. Recovery continues for the rest

### 13.4 Negative Test Cases

These should be REJECTED by the system:

- Admin A tries to confirm their own release proposal → `permission-denied`
- Admin tries to confirm an expired proposal (24h+) → `failed-precondition`
- Buyer tries to cancel a dispute already in `awaiting_release` → `failed-precondition`
- Seller tries to respond to a dispute already in `manager_review` → `failed-precondition`
- Admin tries to release to_payee on a `closed_returned` dispute → `failed-precondition`

---

## 14. Rollback Plan

Money-movement code rollback is dangerous. **Do not rollback wholesale** — surgical rollback by function.

### 14.1 If a Specific Function Misbehaves

Single function rollback (Eric's options after a bad deploy):

**Option A — Revert the function file change:**
```bash
git revert <commit-sha>
firebase deploy --only functions:<function-name>
```

This restores the previous version. The new code paths and Firestore rules stay in place. Eric must verify the function behaves correctly post-revert.

**Option B — Disable the function entirely:**
Replace function body with a stub that throws. Useful if rollback is unsafe but you need to halt traffic.

```javascript
exports.adminConfirmDisputeRelease = functions.runWith({ enforceAppCheck: true }).https.onCall(async (data, context) => {
  throw new functions.https.HttpsError('unavailable', 'This function is temporarily disabled. Contact support.');
});
```

### 14.2 Money Already Moved Incorrectly

If Phase 5i moves money to escrow that should not have moved, the recovery is:

1. **Stop the bleeding:** disable the function that did the movement (Option B above)
2. **Audit:** query `disputes` and `audit_logs` for affected disputes
3. **Manual reverse:** for each affected dispute, write a Cloud Function that runs once to reverse the money:
   - Move escrow money back to source's wallet
   - Set dispute back to a sane state
   - Log everything in audit_logs
4. **Re-enable** the function only after the bug is identified and fixed

Eric should NEVER manually edit wallet docs in the Firebase Console — even one fat-finger mistake on a wallet balance is hard to recover from. Always do reversals via Cloud Functions with full audit trail.

### 14.3 Schema Field Confusion

If a dispute doc has fields from both old and new schemas mixed, that's expected and handled by the `||` fallbacks in the new code. Don't try to "clean up" — let the dispute complete its current flow.

---

## 15. Appendix

### 15.1 Glossary

- **Filer / Buyer:** the user who submitted the dispute. In refund flow they receive money; in buyer_owes flow they pay money.
- **Recipient / Seller:** the user the dispute is filed against. Counterpart to the filer.
- **Source:** the party that owes money on a dispute decision. In refund flow = recipient. In buyer_owes flow = filer. Tracked via `wallet_debts.sourceUid`.
- **Payee:** the party that should receive money on release. Inverse of source.
- **Escrow wallet:** platform-owned wallet holding money during the verification window. One per currency. Path: `wallets/dispute_recovery_<CURRENCY>`.
- **Hold:** money in `wallet.heldBalance` — locked from spending but not yet moved out of the wallet. Set via `placeOpportunisticHoldStub` at filing.
- **Recovery Watch:** the scheduled function that periodically deducts from a source's wallet when they have available balance, moving money to escrow.
- **Two-Person Release:** the requirement that two distinct admins approve a release before money leaves escrow. Proposer + Confirmer, different uids.
- **Verification:** the human step where support contacts both parties to confirm physical reality before release. Must be done before two-person release proposal.

### 15.2 Role Tier Reference (Phase 5i action permissions)

| Action | Required Role |
|---|---|
| File dispute (as buyer) | any authenticated user |
| Respond to dispute (as seller) | any authenticated user (must be recipientUid) |
| Cancel own dispute (as buyer) | any authenticated user (must be filedBy.uid) |
| Request partial release (as buyer) | any authenticated user (must be filedBy.uid) |
| Confirm cancellation | support (level 3) |
| Assign dispute to admin | admin_supervisor (level 5) |
| Submit investigation findings | admin (level 4) — must be assigned admin |
| Supervisor decision | admin_supervisor (level 5) |
| Manager decision | admin_manager (level 7) |
| Super_admin escalation decision | super_admin (level 8) |
| Propose dispute release | admin (level 4) |
| Confirm dispute release | admin (level 4) — must be different uid than proposer |
| Reject dispute release | admin (level 4) — must be different uid than proposer |
| Mark dispute as account-closed | admin (level 4) |
| Export evidence package | admin (level 4) |

### 15.3 Field Reference (Phase 5i additions to dispute doc)

See Section 6.2 for the full list. Quick reference:

```
amountInEscrow         — money in escrow for this dispute (number)
amountOwed             — total owed for this dispute (number, snapshot at solved-transition)
decisionDirection      — 'refund_to_buyer' | 'pay_to_seller'
solvedAt               — timestamp
lastRecoveryDeductionAt — timestamp (nullable)
awaitingReleaseAt      — timestamp (nullable)
fullyCollectedAt       — timestamp (nullable)
releaseProposal        — object (nullable) — see schema in Section 6.2
releaseConfirmedBy     — { uid, email, displayName, role } (nullable)
releaseConfirmedAt     — timestamp (nullable)
releaseRejectedBy      — { ... } (nullable)
releaseRejectedAt      — timestamp (nullable)
releaseRejectionReason — string (nullable)
releaseDirection       — 'release_to_payee' | 'reverse_to_payer' (nullable)
closingRemarks         — string (nullable)
accountClosureDetectedAt — timestamp (nullable)
accountClosureDetectedBy — 'auto' | { uid, email } (nullable)
stuckReason            — 'account_closed' | 'no_progress_90d' | 'manual' (nullable)
partialReleaseRequested — boolean
partialReleaseRequestedAt — timestamp (nullable)
partialReleasedAmount  — number (nullable)
partialReleasedAt      — timestamp (nullable)
cancellationRequested  — boolean
cancellationRequestedAt — timestamp (nullable)
cancellationReason     — string (nullable)
cancellationConfirmedBy — { uid, email, displayName, role } (nullable)
cancellationConfirmedAt — timestamp (nullable)
recipientResponseHistory — array of { response, respondedAt, evidence }
recipientHoldAmount    — number (Phase 5i: separated from currentHoldAmount)
filerHoldAmount        — number (Phase 5i: NEW)
```

### 15.4 Open Questions for Eric

The implementing AI MUST get answers to these before proceeding past the corresponding deploy step:

1. **(Section 7.12)** When a dispute hits `closed_stuck` (account closed or 90-day no-progress), what happens to the money already in escrow?
   - (a) Release to eventual payee
   - (b) Return to original payer
   - (c) Hold indefinitely until manual admin decision

2. **(Section 13.3 Scenario H)** Confirm: when buyer requests partial release, the released amount goes to buyer immediately on two-person release confirmation. The remaining amount continues collecting under the same `solved` dispute. Is this the intended UX?

3. **(General)** The "buyer_owes_seller" flow assumes buyer has wallet funds available at decision time. If they don't, recovery is from buyer's future deposits. Confirm this is acceptable or whether buyer should be blocked from app usage until they pay.

4. **(Section 9.4)** Should sellers see disputes filed against them in their `my_disputes` screen? Currently the screen seems buyer-centric. Should it dual-purpose for both filed-by-me and filed-against-me?

5. **(Section 4.4)** Notification text in this spec is English-only. If the app supports other languages, when does Phase 5i text get translated? Defer to a later phase or require translation for v1?

6. **(Section 7.5 buyer_owes flow)** The fee logic from the original `adminManagerDecision` (lines 14924-14938) handles dispute fees for refund cases. Does the buyer_owes case need its own fee handling, or is the buyer_owes case fee-free? This spec assumed fee-free for buyer_owes but Eric should confirm.

### 15.5 References

- `functions/index.js` — primary backend file, 16,097+ lines
- `firestore.rules` — security rules
- `firestore.indexes.json` — Firestore index manifest
- `lib/features/disputes/` — Flutter dispute screens
- `admin-dashboard/src/pages/` — admin dashboard React components
- Phase 5e/5f/5g+5h commits on `main` (at the time of writing): `c6ebe5f6`, `34b4a5a0`, `eed4c1a1`

---

## End of Phase 5i Specification

**Total length:** ~3000 lines of structured spec.
**Implementation effort estimate:** 3-5 working sessions (~20-40 hours).
**Risk level:** HIGH — money-movement code, customer-facing changes, multi-component.
**Operator sign-off required before implementation:** Eric must answer the Open Questions in Section 15.4 and confirm any cost-related assumptions.

End of file.



