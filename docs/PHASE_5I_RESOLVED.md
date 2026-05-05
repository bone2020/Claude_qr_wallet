# Phase 5i — Resolved Open Questions & Sequencing Decision

**Companion to:** `docs/PHASE_5I_SPEC.md`
**Date resolved:** 2026-05-05
**Operator:** Eric (bonstrahe@gmail.com — super_admin)
**Status:** All Section 15.4 open questions answered. Sequencing decision recorded.

---

## How to Read This Document

`PHASE_5I_SPEC.md` was authored on 2026-05-04 with six unanswered design questions in Section 15.4 plus several implementation assumptions that needed Eric's explicit confirmation before code work could begin. This document captures Eric's answers in full, locks in the design choices that flow from those answers, and records the project-sequencing decision Eric made on 2026-05-05.

Future sessions implementing Phase 5i should treat both documents as authoritative: the spec describes **what** to build, this document describes **the decisions that resolve the spec's open points**.

When the two documents disagree, this document wins.

---

## 1. Sequencing Decision (Project-Level)

**Decision:** Localization comes before disputes.

The spec's open question 5 surfaced a desire for multi-language notifications (English, French, Arabic). Discussion of that question expanded into a broader question about whether the app itself should be multilingual. Eric's preference is a fully localized app where the user picks their language and every screen, button, message, and notification appears in that language.

Three sequencing options were on the table:

1. Localize the app first, then ship Phase 5i on top of the localized base
2. Ship Phase 5i in English first, then localize everything afterward
3. Build localization and Phase 5i in parallel, ship them together

Eric chose option 1 (localize first, then disputes), with the recommendation accepted that doing them sequentially separates risk and lets each piece ship cleanly.

**Practical effect:**

- A new phase, **Phase 6 — App-wide Localization**, becomes the next implementation work.
- `PHASE_5I_SPEC.md` and this resolved document remain in `docs/` untouched, awaiting Phase 6 completion.
- When Phase 5i implementation begins, the app will already have the `preferredLanguage` field on the user model, a working language-picker, and an `intl`-based template system. Phase 5i's notification matrix (Section 4.4 of the spec) will then be implemented across all three languages from the start, rather than English-only.
- The dispute redesign itself is unchanged in scope or design.

**Phase 6 spec authoring is the immediate next task** after this resolved document is committed.

---

## 2. The Six Open Questions, Resolved

### Q1 — Money in escrow when a dispute hits `closed_stuck`

**Spec section affected:** 7.12 (scheduled stuck-detection functions), 6.6 (stuck-case detection logic).

**Spec's prior assumption:** Default to "release escrow to eventual payee" automatically, but flagged for confirmation.

**Eric's answer:** The decision is not automatic. When a dispute is at risk of stuck status, support takes action **before the system makes any disposition of the escrow money**:

1. Support contacts the **buyer** to inform them that recovery is no longer possible (account closed, or 90 days dormant), states the amount collected so far, and explains options.
2. Support contacts the **seller** to find out what actually happened — they may have delivered the product, settled outside the app, or genuinely refused to pay.
3. Based on what those calls reveal, support decides direction:
   - If the seller has already settled outside the app (delivered the product, paid by other means) → the collected escrow money is **returned to the seller**.
   - If the seller refuses to pay or cannot be reached → the collected escrow money is **released to the buyer**, and the buyer is advised to contact authorities to pursue the remainder.

**Empty-escrow case:** If nothing was collected before the dispute went stuck, the same support process runs but no money movement occurs at decision time; the dispute simply closes once support has made the call.

**Implementation implications (changes to spec):**

- `closed_stuck` is no longer a fully terminal state set automatically by a scheduled job. Instead, the scheduled jobs (`disputeAccountClosureCheckScheduled`, `disputeNoProgressCheckScheduled`) move a dispute into a new pending-review state — call it **`stuck_pending_review`** — which signals support to start the calls.
- From `stuck_pending_review`, the **two-person admin release flow already designed for `awaiting_release`** is reused. Two admins must agree on direction (release_to_payee vs. reverse_to_payer), with mandatory checkboxes confirming both parties were contacted and notes recorded.
- Only after the two-person decision does the dispute reach `closed_stuck` (final). The dispute doc records both the support-call summary and the release direction taken.
- The stuck check applies symmetrically to the buyer-owes-seller direction (see Q3) — buyer's account closed or buyer dormant 90 days triggers the same support process.
- The closing-remarks template in Section 6.8 of the spec needs updating to reflect that `closed_stuck` always carries a human-decided direction.

**Questions for the Phase 6/Phase 5i implementer to verify against the spec:**
- Does `adminConfirmDisputeRelease` need new validation to handle the `stuck_pending_review → closed_stuck` transition, or is a small new function (e.g., `adminConfirmStuckResolution`) cleaner? Probably the former, but the implementer should compare both designs before writing code.

---

### Q2 — Partial release on demand: buyer's choice

**Spec section affected:** 4.7 (buyer self-service), 13.3 (Scenario H), 6.4 (two-person release flow).

**Spec's prior assumption:** Partial release sends the collected portion to the buyer; dispute remains in `solved` and continues collecting until the rest is recovered.

**Eric's answer:** When the buyer requests partial release, the app gives them a choice between two outcomes:

- **Option A — Take the collected amount and close the dispute.** The remaining unrecovered amount is forgiven. Dispute moves to a closed state. Recovery Watch stops for this dispute.
- **Option B — Take the collected amount but keep the dispute open.** Recovery continues until the full amount is collected, at which point the dispute returns to `awaiting_release` for a second two-person release of the remainder.

Both options route through the existing two-person release flow before any money moves. Support contacts the buyer to confirm intent regardless of which option is chosen.

**Implementation implications (changes to spec):**

- `userRequestPartialRelease` (Section 4.7 of spec) takes a new required parameter: `releaseMode: 'close_after' | 'continue_collecting'`.
- The Flutter UI for "Request partial release" presents the two options clearly. Plain-language labels suggested:
  - "Take what's collected and close this dispute" (close_after)
  - "Take what's collected but keep recovering the rest" (continue_collecting)
- The two-person release flow accepts the buyer's chosen mode as input. On `adminConfirmDisputeRelease`:
  - For `close_after`: dispute transitions to a new closed state — call it **`closed_partial_buyer_choice`** — to distinguish from a normal `closed`. The unrecovered debt is marked `forgiven` in `wallet_debts`. Recovery Watch ignores it from then on.
  - For `continue_collecting`: dispute returns to `solved` for the remaining amount. The dispute doc records `partialReleasedAmount` and `partialReleasedAt`. When the remainder is fully collected later, it follows the normal `solved → awaiting_release → closed` path.
- A new closing-remarks template is needed for the `close_after` outcome.
- The negative-test list (Section 13.4) gains a case: buyer cannot request partial release on a dispute already in `awaiting_release`, `closed_partial_buyer_choice`, or any other closed state.

---

### Q3 — Buyer who owes seller has insufficient funds

**Spec section affected:** 4.3 (new decision outcomes), 6.7 (buyer-owes mirror flow), 7.5 (manager decision).

**Spec's prior assumption:** Mirror the seller-owes recovery — slowly deduct from buyer's future deposits via Recovery Watch. Buyer is not blocked from app usage.

**Eric's answer:** Confirmed — same recovery process used for sellers is used for buyers. Recovery Watch runs in the opposite direction (buyer's wallet → escrow → seller). Buyer is not blocked from the app.

By extension, **stuck handling applies symmetrically**: a buyer who closes their account or goes 90 days dormant triggers the same support-driven decision process as Q1, just with parties reversed.

**Implementation implications:**

- The stuck-detection scheduled functions (`disputeAccountClosureCheckScheduled`, `disputeNoProgressCheckScheduled`) must check the **source UID** based on `decisionDirection`, not always the recipient.
- The Q1 resolution (support calls both parties, two admins decide direction) applies in both directions. The phrasing of SMS messages flips: in the buyer-owes-stuck case, the seller is the eventual payee, the buyer is the source. The support-call script flips accordingly.
- No additional code beyond the symmetry already designed in spec Section 6.7 — Q3 is essentially a confirmation that the mirror flow is correct.

---

### Q4 — Sellers see disputes filed against them

**Spec section affected:** 9.3 (`my_disputes.dart`), 9.4 (new screen consideration).

**Spec's prior assumption:** Open question whether the existing `my_disputes` screen should dual-purpose, or whether sellers need their own separate screen.

**Eric's answer:** A single screen with a tabbed split, showing disputes filed by the user in one tab and disputes filed against the user in another.

**Locked-in design:**

- `my_disputes.dart` becomes a tabbed screen with two tabs at top:
  - **"Filed by me"** — disputes where `dispute.filedBy.uid == currentUid`
  - **"Filed against me"** — disputes where `dispute.recipientUid == currentUid`
- Each tab shows a count badge (e.g., "Filed against me (1)").
- **Default tab on first open:**
  - Open to "Filed by me" if the user has any disputes filed by them.
  - Open to "Filed against me" only if the user has zero filed-by-them and at least one filed-against-them. (Avoids landing on an empty screen when there's actionable content on the other tab.)
- **Unread indicator:** if the user has a dispute in "Filed against me" they have not yet opened, show a red dot on that tab. The dot clears once the user opens the dispute detail.
- **Per-row action differences:**
  - In "Filed by me": cancel button, request-partial-release button (when state allows), progress bar showing collection progress.
  - In "Filed against me": respond button (when state allows — `filed`, `investigating`, `supervisor_review`), view of buyer's complaint, holds visible against their wallet.
- The dispute-detail screen (`dispute_detail.dart`) needs to render different action panels based on whether the current user is the filer or the recipient.

**Implementation implications:**

- Backend: `userGetMyDisputes` (line 14340 in `functions/index.js`) currently returns disputes where `filedBy.uid == callerUid`. It must be expanded to optionally return disputes where `recipientUid == callerUid` based on a new query parameter, or to return both kinds in a single call with a `role` field on each dispute indicating the caller's relationship to it. The implementer should pick the cleaner approach after looking at the function.
- Firestore composite indexes may be needed for `recipientUid + status` queries — to be confirmed during implementation.

---

### Q5 — Notification languages

**Spec section affected:** 4.4 (notification matrix), Section 1 (out-of-scope list).

**Spec's prior assumption:** English-only for v1; translations deferred to a later phase.

**Eric's answer:** All app strings and all notifications in **English, French, and Arabic**. The user picks their preferred language at first app launch after the localization update; everything they see — UI labels, button text, error messages, SMS, email, in-app notifications — appears in that language. The choice is changeable later via Settings.

**This answer expanded scope significantly and triggered the sequencing decision recorded in Section 1 of this document.** Localization is no longer "extra work bolted onto Phase 5i" — it is its own phase (Phase 6) which precedes Phase 5i.

**Implementation implications (now scoped under Phase 6, not Phase 5i):**

- Flutter `flutter_localizations` + `intl` packages added.
- ARB-based string catalogs for `en`, `fr`, `ar`.
- A `preferredLanguage` field added to the user document (default `en` for existing users).
- A first-launch language picker presented after the user updates the app.
- A Profile → Settings → Language screen for changing preference at any time.
- All hardcoded user-facing strings in `lib/` migrated into ARB catalogs.
- All SMS and email templates (existing and new) parameterized by language. The `sendCustomerSms()` and `sendProposalEmail()` helpers in `functions/index.js` accept the recipient's `preferredLanguage` and select the right template.
- RTL layout support enabled for Arabic. Most Flutter widgets handle RTL automatically; custom layouts need per-screen verification.
- Professional translators engaged for French and Arabic. Native-speaker review before launch.

**By the time Phase 5i implementation begins**, the framework is in place. Phase 5i's new dispute notifications get added in all three languages from day one as a routine task — the heavy lifting is in Phase 6.

---

### Q6 — Buyer's filing fee in the buyer-owes-seller outcome

**Spec section affected:** 7.5 (Change D — modified manager decision), fee logic at original lines 14924-14938.

**Spec's prior assumption:** Buyer's filing fee not refunded; no extra penalty fee charged.

**Eric's answer:**

- **Sub-question A — Refund the filing fee?** No. The fee stays with the platform.
- **Sub-question B — Charge an extra penalty?** No additional fee was requested. Default assumption (no extra penalty) stands.

**Reasoning recorded:** The buyer paid for an investigation; the investigation was conducted; the result simply went against them. They owe the seller what investigation determined and nothing more.

**Implementation implications:**

- The fee logic block in `adminManagerDecision` (currently at lines 14924-14938) does **not** refund the fee in the `buyer_owes_seller_full` or `buyer_owes_seller_partial` branches.
- No additional fee is charged on top of the original filing fee in either branch.
- `dispute.feeRefunded: false` for buyer-owes outcomes (matching the existing `release` outcome semantics).
- No new `penaltyFee` or similar field is added to the dispute schema.

---

## 3. Cross-Cutting Implementation Notes

### 3.1 New / Renamed States

The spec's state machine (Section 4.1) needs three additions to reflect the Q1 and Q2 resolutions:

| State | Purpose | Set by |
|---|---|---|
| `stuck_pending_review` | Dispute identified as recoverable-no-further; awaiting support calls + two-admin direction decision | `disputeAccountClosureCheckScheduled` after 3-day window, `disputeNoProgressCheckScheduled` after 90 days |
| `closed_stuck` | Final state after support + two-admin decision on a stuck dispute | `adminConfirmDisputeRelease` (or equivalent) |
| `closed_partial_buyer_choice` | Buyer chose to take collected portion and close, forgiving the rest | `adminConfirmDisputeRelease` with `releaseMode: 'close_after'` |

The migration policy (Section 4.9) is unchanged — existing `resolved` disputes are unaffected.

### 3.2 Two-Person Release Flow Reuse

The two-person release flow described in spec Section 4.5 was originally designed only for the `awaiting_release` state. The Q1 resolution extends it to also handle `stuck_pending_review`. The Q2 resolution adds a new `releaseMode` parameter.

The implementer should review whether `adminProposeDisputeRelease` and `adminConfirmDisputeRelease` can be generalized to handle all three cases (normal awaiting-release, partial release with mode choice, stuck resolution), or whether separate functions are clearer. Recommendation: one set of functions with mode/source-state parameters, to avoid duplicating the two-person-rule and audit-trail logic.

### 3.3 Symmetry Auditing

Several Q&A answers depend on the buyer-owes flow being a true mirror of the seller-owes flow. Before Phase 5i ships, the implementer should explicitly walk through:

- Each Recovery Watch site → does it correctly read `wallet_debt.sourceUid` and route money in the right direction?
- Each stuck-detection check → does it inspect the source's account/wallet, not always the recipient's?
- Each notification → does it address the correct party (source vs. payee) for the direction in play?
- Each Flutter screen → does it render the correct "you owe" vs. "you are owed" copy for the current user's relationship to the dispute?

This audit is part of Phase 5i pre-deploy verification (Section 13.1 of spec).

---

## 4. What This Document Does Not Decide

The following items remain for future investigation and are not blocked by this document:

- The exact wording of every SMS and email template in three languages — depends on Phase 6 translation work.
- The Phase 6 spec itself — to be written after investigation of the current Flutter app's structure.
- Composite Firestore indexes needed for the new queries (e.g., `recipientUid + status`, `awaiting_release + releaseProposal.expiresAt`) — to be added during implementation as Firestore surfaces the index requirement on first query.
- Whether the admin-dashboard "Awaiting Release Queue" page should also include `stuck_pending_review` disputes, or those should have their own page. Both layouts are reasonable; implementer to propose during dashboard work.

---

## 5. Workflow Going Forward

1. **This document is committed** to `docs/PHASE_5I_RESOLVED.md` alongside `docs/PHASE_5I_SPEC.md`.
2. **Phase 6 (localization) investigation begins.** A new set of `grep`/`cat` commands is issued to read the current Flutter app's string usage, user model, settings structure, and `pubspec.yaml`. Output is reviewed before any spec is written.
3. **Phase 6 spec is written** — `docs/PHASE_6_LOCALIZATION_SPEC.md` — at the same level of detail as the dispute spec.
4. **Phase 6 is implemented and shipped.** Standard investigate → spec → apply → verify cycle per session for each sub-step.
5. **Phase 5i implementation begins** on the localized app, using `PHASE_5I_SPEC.md` and this document as the authoritative reference.
6. **The Recovery Watch rewrite (spec Section 7.11) deploys last** in Phase 5i, with rollback ready before deploy. This was specified in the original spec and remains binding.

---

## 6. Decision Audit Trail

| Decision | Date | Made By | Source |
|---|---|---|---|
| Q1 — stuck disputes route through support + two-admin decision | 2026-05-05 | Eric | Chat answer |
| Q2 — partial release offers buyer two options (close_after vs. continue_collecting) | 2026-05-05 | Eric | Chat answer |
| Q3 — buyer-owes recovery mirrors seller-owes recovery | 2026-05-05 | Eric | Chat answer |
| Q4 — single tabbed screen, Filed by me / Filed against me | 2026-05-05 | Eric | Chat answer |
| Q5 — full app localization in en/fr/ar | 2026-05-05 | Eric | Chat answer |
| Q6 — no fee refund, no penalty fee on buyer-owes outcome | 2026-05-05 | Eric | Chat answer |
| Sequencing — localization phase precedes dispute phase | 2026-05-05 | Eric | Chat answer |

---

## End of Resolved Document

Commit alongside `PHASE_5I_SPEC.md` in the `docs/` directory. Future Phase 5i implementers are expected to read both documents in full before any code work begins.
