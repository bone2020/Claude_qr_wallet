# Shop Afrik × QR Wallet — Integration & Build Specification (v2, all decisions resolved)

**Status:** Agreed design, ready to build. **Audience:** the QR Wallet build agent (Part A) and the Shop Afrik build agent (Part B).

Single source of truth for how Shop Afrik's money works on top of QR Wallet. Verified against the live QR Wallet code (`bone2020/Claude_qr_wallet`, `functions/index.js`). Where the live code already provides something, it is named so the agent reuses it rather than rebuilds.

---

## 1. The architecture decision

- **QR Wallet is the bank and the rails.** It holds all the money and moves it.
- **Shop Afrik is the brain.** It runs the marketplace, keeps the order records, and tells QR Wallet when to move money.
- Shop Afrik's money lives in **a single, Shop-Afrik-owned account inside QR Wallet**, multi-currency, kept completely separate from QR Wallet's own revenue (`wallets/platform`).
- Shop Afrik serves **all QR Wallet countries** (~22), launching live in **Ghana and Nigeria**, expanding by config (no code change to add a country).

---

## 2. The Shop Afrik account model

One account, **multi-currency inside** — built like QR Wallet's `wallets/platform` (one entity, a per-currency balance bucket for each currency), but owned by Shop Afrik and separate from QR Wallet's revenue. One dashboard, one set of logins; currencies never blend.

Per currency, three logical buckets:

| Bucket | Holds | Whose money |
|---|---|---|
| **Escrow** | Captured funds for orders not yet settled | The buyer's until settled (refundable in window) |
| **Seller payable** | Transient, mid-settlement | The sellers' |
| **Commission revenue** | Accumulated 15% (net of QR Wallet's fee) + delivery fees | Shop Afrik's |

No currency is ever mixed; no implicit FX except the one legitimate cross-border seller payout at settlement (real rate, refuse if unavailable).

---

## 3. What already exists in QR Wallet (reuse, do not rebuild)

- **Holds / escrow:** `createHold`, `releaseHold`, `convertHoldToTransfer`, `expireOldHolds`; `wallet_holds`; wallets carry `balance`/`heldBalance`/`availableBalance`, invariant `availableBalance = balance − heldBalance`. A `shop_afrik_order` hold reason already exists (14-day default).
- **Service auth:** the `walletHoldsWrite` claim lets a service create/convert/release holds on any wallet. Shop Afrik's service path.
- **Business wallet system** (`createBusinessWallet`, `businessWalletGetOverview`, `…GetTransactions`, `…GetCountryBreakdown`, `businessWalletWithdraw`, `businessWalletRefundTransaction`) — but **single-currency**; Shop Afrik needs the multi-currency variant (§2).
- **QR Wallet's own revenue:** `wallets/platform` with per-currency `balances/{currency}`, fed by `sweepBalanceToPlatform` and `convertHoldToTransfer` fees. **Shop Afrik's account must never touch this.** QR Wallet's intercompany fee (§5) routes here.
- **Fee logic:** `calculateFee` (currently hardcodes `amount / 100` — see §6 decimals).
- **Idempotency** infrastructure (`idempotency_keys`).
- **Cross-currency safety:** `convertHoldToTransfer` converts at a real rate and **refuses** if the rate is unavailable. Reuse this.

---

## 4. Payment options

Two options at checkout, both from the wallet (no cash on delivery):

1. **Pay now (primary).** Money is captured from the buyer's wallet into Shop Afrik's escrow immediately at checkout. Safest — secured at once.
2. **Pay on delivery (secondary).** Money is frozen (a hold) in the buyer's wallet at checkout — the *guarantee*, not the payment — and only captured into escrow at delivery, gated by the delivery handover.

---

## 5. The order & money lifecycle

1. **Order placed.** Buyer selects items and sees the **item total** with a note that delivery isn't included yet and will be added shortly. Order state: *awaiting delivery quote*. (No money held yet.)
2. **Admin quotes delivery.** App notifies an admin with the order + delivery location; admin sets the delivery price **with a breakdown**. Buyer now sees the **full total = items + delivery**.
3. **Buyer confirms & pays** (full total), choosing one option:
   - **Pay now:** money is captured from the buyer's wallet into Shop Afrik's **escrow** bucket (buyer's currency), full total.
   - **Pay on delivery:** the full total is **frozen** (hold, `reason: shop_afrik_order`, `referenceId: orderId`) in the buyer's wallet.
4. **Before shipment** the buyer may **cancel** → pay-now: refund from escrow; pay-on-delivery: unfreeze. Money back to the buyer, their currency.
5. **Order leaves the warehouse** → cancel disabled.
6. **Delivery.** Pay-now: money already in escrow. Pay-on-delivery: the held money is **captured** into escrow at the door; if it cannot move, the goods are **returned** and the order fails (delivery gate). Buyer currency = escrow currency → no FX at capture.
7. **7-day window after delivery** → refundable from escrow, buyer's currency. **No refunds after the window / after settlement.**
8. **Day 8 — settlement.** The escrow for the order is split (see §5a).

### 5a. Settlement math (per order)

Let **S** = item sale value (order currency), **D** = delivery fee.

- **Seller** receives **85% × S** (= S − 15% commission), converted to the seller's currency if cross-border (real rate, refuse if unavailable).
- **QR Wallet** receives its intercompany fee of **0.3% × S**, taken **out of Shop Afrik's commission**, routed once to `wallets/platform` (order currency).
- **Shop Afrik** keeps **(15% × S − 0.3% × S) + D = 14.7% × S + D** in its commission/income bucket (order currency). It pays its couriers out of D operationally.

Worked example (GHS 1,000 item, GHS 50 delivery): seller GHS 850; QR Wallet GHS 3; Shop Afrik GHS 147 + GHS 50 delivery = GHS 197 gross.

Notes: the 15% commission is on the **item only**, never on delivery. The delivery fee is entirely Shop Afrik's (covers couriers + a small margin). QR Wallet's 0.3% is on the **item sale**, charged **once per order at settlement**, and comes out of Shop Afrik's side (never added on top for buyer or seller).

---

## 6. Currency rules

- One bucket per currency, never mixed; no implicit FX except the cross-border seller payout.
- **Whitelist gap — add these 23 to `VALID_CURRENCIES`:** MAD, DZD, TND, LYD, SDG, ETB, AOA, MZN, MWK, BWP, NAD, LSL, MUR, MGA, SCR, KMF, MRU, GMD, CVE, STN, SOS, DJF, ERN.
- **Decimals are NOT all 2.** Replace hardcoded `/100` (in `calculateFee`, the new fee/commission math, and all conversions/formatting) with a per-currency ISO 4217 exponent:
  - 3 decimals: TND, LYD
  - 0 decimals: DJF, KMF — note XOF, XAF, GNF, RWF, UGX are 0-decimal and **already whitelisted** (latent bug today)
  - subdivide by 5 (treat as 0): MRU, MGA
  - 2 decimals: everything else

---

## 7. PART A — QR Wallet repo: what to build

Match existing conventions (gen-1, `runWith({ enforceAppCheck:true })`, `runTransaction`, `auditLog`, `resolveRate`, error codes, idempotency).

**A1. Shop Afrik multi-currency account.** One Shop-Afrik-owned account, per-currency buckets (escrow / seller-payable / commission), mirroring the `wallets/platform` structure, separate from `wallets/platform`. Per-order escrow ledger keyed by `orderId`. Business-wallet-style role access.

**A2. Capture — money into escrow.** Two entry points, both landing money in Shop Afrik's escrow bucket (same currency as the buyer → no FX), idempotent:
- **Pay now — `shopAfrikCapture`:** at checkout, debit the buyer's wallet, credit the escrow bucket, write the order's escrow ledger entry.
- **Pay on delivery — `shopAfrikCaptureHold`:** at delivery, consume the buyer's active `shop_afrik_order` hold (`balance −= amount`, `heldBalance −= amount`), credit the escrow bucket, mark hold `captured`. If the hold isn't available, throw a clear error so the goods are returned. (Mirrors `convertHoldToTransfer`, but the recipient is the escrow bucket and **no fee** is taken at capture.)

**A3. Settlement — `settleShopAfrikOrder`.** Auth: service or admin. Input `{ orderId, sellerWalletId, itemSale (S), deliveryFee (D), orderCurrency, idempotencyKey }`. Atomic, idempotent (if settled, return success):
- `sellerShare = 0.85 × S`; convert to seller currency if cross-border (refuse if no rate).
- `qrWalletFee = 0.003 × S` (configurable rate), routed to `wallets/platform` (order currency), taken from Shop Afrik's commission.
- Debit escrow bucket by (S + D); credit seller wallet `sellerShare` (seller currency); credit Shop Afrik commission bucket `0.15×S − 0.003×S + D` (order currency); credit `wallets/platform` `qrWalletFee`.
- Mark order settled; write transaction records.

**A4. Within-window refund — `shopAfrikRefund`.** Auth: service or admin. Idempotent on `refundId`. Debit escrow bucket (order currency), credit buyer wallet (same currency — no conversion), mark order refunded. Reject after settlement.

**A5. Account reads/withdraw.** Currency-aware overview (three buckets per currency for the dashboard), per-currency transactions, per-currency commission withdrawal to bank (like `businessWalletWithdraw`, currency-aware).

**A6. Hold hardening.** For `reason === 'shop_afrik_order'`: disallow the wallet-owner (buyer) release path in `releaseHold` (only service/admin may release/capture); and exclude these holds from `expireOldHolds` while the order is active (or have Shop Afrik renew them) so a slow multi-leg delivery never auto-releases funds.

**A7. Currency whitelist + decimals.** Add the 23 currencies and the per-currency exponent handling (§6).

**A8. Connection / auth.** Grant Shop Afrik's backend a `walletHoldsWrite` (or dedicated `shopAfrikService`) claim. Every call carries explicit currency + idempotency key; confirmations to Shop Afrik are signed.

**A9. Configurable rates.** The QR Wallet intercompany fee (default **0.3% of item sale**) and the commission (15%) are config values, changeable without code.

---

## 8. PART B — Shop Afrik repo: what to build

(Prior sessions scaffolded the app, added per-currency exponents, dropped the flat delivery fee. Continue from there.)

**B1. Order state machine** driving the money calls:
`placed → awaiting_delivery_quote → (admin quotes) → confirmed/paid` then per option:
- pay-now: `shopAfrikCapture` at confirm; pay-on-delivery: `createHold` at confirm.
- `cancellable` (until shipped) → cancel: refund-from-escrow (pay-now) or `releaseHold` (pay-on-delivery).
- `shipped` (cancel disabled) → `delivered` (pay-on-delivery: `shopAfrikCaptureHold`) → `window` (7 days) → optional `refunded` (`shopAfrikRefund`) → `settled` (`settleShopAfrikOrder`).

**B2. Delivery-quote step.** On order, show item total + "delivery added shortly" note; notify admin with order + location; admin enters delivery price with breakdown; buyer then pays the full total.

**B3. Cancellation rules.** Cancel allowed only before shipment; removed once the order leaves the warehouse.

**B4. Payment options UI.** Pay now (default) and pay on delivery.

**B5. Admin dashboard.** Three buckets per currency — held in escrow, owed to sellers, earned commission — never blended; only commission labelled revenue. Fed by A5.

**B6. Per-order bookkeeping.** Store `holdId` per order; guard against double-creating a hold (`createHold` is not deduped on `referenceId`); treat "already captured/settled" as success.

**B7. Reconciliation.** Shop Afrik's records reconcile per currency against the QR Wallet account buckets; alert on drift.

**B8. Marketplace screens** (buyer shopping, seller dashboard, admin approval/refund queues) as previously instructed.

---

## 9. Security & integrity

- Money state server-written only; deterministic, idempotent IDs on every operation.
- Settlement/capture error if a hold is already converted (not silent) — Shop Afrik treats "already done" as success.
- Append-only audit on every money movement and admin decision.
- Per-currency reconciliation (§B7).

---

## 10. Smaller operational details to flesh out (not blockers)

- **Paying couriers from the delivery fee** — Shop Afrik pays its delivery people out of D; this is an operational payout flow to spec later.
- **Awaiting-quote edge cases** — admin quote timeout, buyer abandonment, and stock handling during the quote wait (no money is held yet at that point).
- **Multi-seller carts** — if one order contains items from different sellers, settlement pays each seller their portion; confirm whether orders are split per seller.

---

## 11. Note to the building agents

This reflects the live QR Wallet code as read during design, but the QR Wallet agent has the full codebase and must match its actual helpers, error codes, and conventions and confirm exact field shapes before implementing. Build money paths inside `runTransaction`, reuse the existing rate-resolution and idempotency patterns, and keep Shop Afrik's account strictly separate from `wallets/platform`.
