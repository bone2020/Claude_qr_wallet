# Phase 6 — Resolved Open Questions

**Companion to:** `docs/PHASE_6_LOCALIZATION_SPEC.md`
**Date resolved:** 2026-05-05
**Operator:** Eric (bonstrahe@gmail.com — super_admin)
**Status:** All Section 13.4 open questions answered. Budget plan finalized.

---

## How to Read This Document

`PHASE_6_LOCALIZATION_SPEC.md` was authored on 2026-05-05 with six open questions in Section 13.4 covering translator engagement, reviewer sourcing, code-cleanup choices, picker UX, architectural normalization, and backend rollout sequencing. This document captures Eric's answers in full and locks in the implementation choices that flow from those answers.

When this document and the spec disagree, this document wins. The spec was written before the budget reality of "$0 for v1" was confirmed; this document resolves that.

---

## 1. Budget Decision (Project-Level)

**Decision:** Phase 6 ships at $0 translation cost.

The original spec assumed professional translator engagement at $240-600 USD. After confirming budget constraints, we are shifting to a free-tier translation approach: machine translation (DeepL Free + AI assistance) for the initial pass, supplemented by free human review from native-speaker contacts.

**Practical effect:**

- No paid translator engagement.
- No translation agency contract.
- No Crowdin / Lokalise platform subscription.
- Translation work is done in-house by the implementing AI (Claude) using DeepL Free and the AI's own multilingual capabilities.
- Human review for quality assurance comes from operator-sourced native speakers at zero cost.
- If a language cannot get human review before ship date, that language is **deferred** rather than shipped untested. Better to launch English + reviewed French than to launch all three with one unreviewed.

**Risk profile of the $0 approach:**

- Translation quality is "good enough to ship," not "professional polish." Some strings will sound awkward to native ears. This is acceptable for v1.
- Most-likely failure mode: an awkward phrase that gets corrected in a v1.1 patch after user feedback. Recoverable.
- Worst-case failure mode: a money-related term mistranslated such that users misunderstand a transaction. Mitigated by human review specifically focusing on money/action terms (Send, Receive, Withdraw, Deposit, Confirm, Cancel, etc.) before ship.

**This budget decision can be revisited at any time.** If translation quality becomes a meaningful issue post-launch, paying for professional review of the existing translations is much cheaper than full from-scratch translation ($50-100 per language for review-only).

---

## 2. The Six Open Questions, Resolved

### Q1 — Translator Engagement

**Spec section affected:** 13.4 #1, Section 6.8 (translation workflow).

**Spec's prior assumption:** Professional translator hired via Upwork, Gengo, or similar. Cost $240-600.

**Eric's answer:** Use DeepL Free + AI translation (Claude/ChatGPT) for the initial translation pass. Zero cost.

**Workflow this enables:**

1. Implementer (Claude in implementation session) takes the final `app_en.arb` after Step 9 of the spec.
2. Implementer translates each string to French using DeepL Free (deepl.com) — the free tier supports up to 500,000 characters/month, more than enough for our ~10,000-character ARB file.
3. Implementer also runs a parallel translation pass through AI (Claude or similar) for cross-validation. Where DeepL and AI agree, the translation is accepted. Where they differ, the implementer picks the cleaner option or flags for human review.
4. Same process for Arabic.
5. Both translated ARB files (`app_fr.arb`, `app_ar.arb`) are committed.
6. Same process for backend SMS/email templates in `functions/i18n.js`.

**Implementation implications (changes to spec Section 6.8):**

- Step 10 of the spec is restructured: instead of "engage translator and wait for return," it becomes "implementer produces machine translation in the implementation session itself." No external dependency, no waiting period.
- The translation step happens **in the same session** as Step 11 (Profile → Language row) — the implementer can do both back-to-back.
- A new sub-step is added: **machine-translation source citation in ARB metadata.** Each translated key gets a comment indicating the translation source (`"@_translation_source": "DeepL Free + Claude cross-check"`) so future maintainers know what was machine-translated vs. human-edited.

---

### Q2 — Native-Speaker Reviewers

**Spec section affected:** 13.4 #2, Section 6.8 (review process).

**Spec's prior assumption:** Operator sources fluent reviewers, possibly paid via Upwork at $50-100 per language.

**Eric's answer:**

- **Arabic:** Eric has Arabic-speaking friends who will review. Free, sourced from personal network.
- **French:** No reviewer identified yet. To be sourced when Step 10 work is complete, via Eric's network, Reddit/Discord communities, the existing 6 users (asking if any speak French), or post-launch user feedback.

**Workflow this enables:**

1. After machine translation is committed, Eric coordinates Arabic friends to do a review pass.
2. **What Arabic reviewers do:**
   - Install/run the app with Arabic locale selected
   - Walk through main flows: signup, login, wallet view, send money, receive money, profile, settings, error states
   - Time required per reviewer: 30-45 minutes
   - Output: list of strings that read awkwardly or are wrong, with suggested corrections
3. Implementer applies corrections to `app_ar.arb`, redeploys, ships.
4. **For French:** if no reviewer is available by ship time:
   - **Option A:** Ship French anyway, accept higher post-launch risk, fix from user feedback
   - **Option B:** Defer French to a later Phase 6.1 release; ship English + Arabic only
   - Recommendation when the time comes: lean toward Option A for French (it's a Latin-alphabet language that DeepL handles very well, lower risk than Arabic) and Option B if there were any concerns about Arabic quality.

**Implementation implications:**

- The spec's Section 6.8 review workflow is preserved but the timing shifts: review happens after machine translation rather than after professional translation.
- A simple feedback channel for Arabic reviewers should exist: a shared document (Google Doc, plain text file) where they can paste before/after suggestions. The implementer takes that document and applies corrections to ARB files.
- **Briefing for Arabic reviewers:** the app uses Modern Standard Arabic (MSA), not regional dialect. Reviewers should know this is intentional — feedback like "this would be different in Egyptian Arabic" should be acknowledged but the MSA version stands. Feedback like "this is wrong even in MSA" or "this is awkward MSA" should be acted on.
- Special focus areas for review (must be checked, even if review time is limited):
  - Money-related verbs: Send, Receive, Withdraw, Deposit, Pay, Refund
  - Action confirmations: Confirm, Cancel, OK, Done, Save
  - Error messages — especially "insufficient balance," "invalid amount," "transaction failed"
  - The dispute flow strings (added later in Phase 5i, not Phase 6, but reviewers should be ready to look at those when the time comes)

---

### Q3 — `AppStrings` Class Fate

**Spec section affected:** 13.4 #3, Step 8 (migration from AppStrings to AppLocalizations).

**Eric's answer:** A — delete the `AppStrings` class entirely after Step 8 migration is complete.

**Implementation implications:**

- After Step 8 is complete, `lib/core/constants/app_strings.dart` is deleted.
- The migration verification check (`grep -rn "AppStrings\." lib --include="*.dart"`) must return **zero results** — not just zero outside the strings file. If any reference remains, the build will fail; that surfaces missed migration sites.
- ARB files (`app_en.arb` etc.) are the sole source of truth for English strings going forward.
- Future developers adding strings: add to `app_en.arb`, run `flutter gen-l10n`, use `AppLocalizations.of(context)!.<key>` at call site, also add the same key with translated value to `app_fr.arb` and `app_ar.arb`.

---

### Q4 — First-Launch Picker Auto-Detection

**Spec section affected:** 13.4 #4, Step 13 (first-launch picker).

**Eric's answer:** A — highlight the device's locale as a visual suggestion, but require an explicit tap to confirm.

**Implementation implications:**

- At first-launch picker render: read `WidgetsBinding.instance.platformDispatcher.locale.languageCode`.
- If it's `en`, `fr`, or `ar`: that card gets a visual highlight (border in primary color, slight background tint, or similar — the implementer matches existing app design tokens).
- If it's anything else (Spanish, Hausa, Yoruba, etc.): English card gets the highlight.
- The highlight is purely visual. Tapping any card (highlighted or not) is what saves the choice. There is no auto-confirm timer.
- This preserves user agency while reducing friction for the common case where device locale matches a supported language.

---

### Q5 — Currency Selector Relocation

**Spec section affected:** 13.4 #5, Section 3.4 (Profile feature layout note).

**Eric's answer:** B — leave the currency selector at its current location (`lib/features/settings/screens/currency_selector_screen.dart`).

**Implementation implications:**

- Phase 6 does not touch the currency selector's location.
- The architectural inconsistency (currency in `features/settings/`, everything else settings-like in `features/profile/`) is documented as a known item but explicitly out of scope.
- A `// TODO(future): relocate currency selector to lib/features/profile/screens/ for consistency` comment may be added to the file's top-of-file docstring during Phase 6, but no actual relocation occurs.
- Future architectural cleanup phase (no current plan) can normalize this.

---

### Q6 — Backend Rollout Sequencing

**Spec section affected:** 13.4 #6, Section 9 (deployment order), Section 8 (backend changes).

**Eric's answer:** B — three-stage backend rollout.

**Locked-in deployment order:**

**Deploy 1 — Backend i18n module with English-only templates:**
- Create `functions/i18n.js` with `t()` and `getUserLanguage()` helpers
- All templates filled in English; French and Arabic objects are empty stubs
- Migrate every `sendCustomerSms` and `sendProposalEmail` call site to use `t('key', lang, params)`
- Behavior is functionally identical to today: SMS still goes out in English regardless of `preferredLanguage`
- Risk: very low — no user-visible change, just an indirection layer added
- Verifiable by: SMS still arrives in English for all test users

**Deploy 2 — Flutter app with Phase 6 framework + UI:**
- All Flutter changes from Steps 1-13 of the spec
- App ships to App Store / Play Store
- Users can pick languages and see the entire app translated
- **But notifications still come in English** because backend templates haven't been translated yet
- Risk: medium — wide surface area in app, but each piece tested
- Verifiable by: walk through the app in all three languages, confirm UI is translated, confirm SMS still arrives in English (expected)

**Deploy 3 — Backend templates translated:**
- Update `functions/i18n.js` with French and Arabic template objects filled in
- Deploy
- From this moment, SMS and email goes out in user's preferred language
- Risk: low — small backend change, easily revertable to Deploy 1 state if quality issues
- Verifiable by: trigger test SMS for users with each language preference, confirm correct language

**Implementation implications:**

- Step 10 of the spec (translator engagement, now: machine translation in-session) produces both Flutter ARB files AND the backend template translations in the same work session.
- Flutter translations and backend translations are committed in separate PRs but produced in the same session.
- The deploy sequencing means: **Deploy 1 can ship as soon as Steps 1-9 + the backend i18n module migration are done**, even before any translation work begins. This is the safest possible rollout — backend gets the indirection layer in place ahead of any user-visible change.

---

## 3. Cross-Cutting Implementation Notes

### 3.1 Updated Cost Estimate

| Item | Original spec | Resolved (this doc) |
|---|---|---|
| Translation cost | $240-600 USD | $0 |
| Translator turnaround time | 3-7 days each | 0 (in-session) |
| Reviewer cost | $0-200 USD | $0 |
| Total cash cost | $240-800 USD | **$0** |

Phase 6 is now genuinely zero-cost in cash terms. The cost is in implementation hours and in operator time coordinating Arabic-friend review.

### 3.2 Updated Timeline Estimate

| Stage | Original spec | Resolved (this doc) |
|---|---|---|
| Stage 1 (framework) | 1 session | 1 session |
| Stage 2 (code migration) | 1-2 sessions | 1-2 sessions |
| Translation work | Async (translator turnaround) | In-session (no waiting) |
| Stage 3 (languages + screens) | 1 session + translator wait | 1 session |
| Stage 4 (backend) | 1 session | Split: 1 session for Deploy 1 indirection + later session for Deploy 3 translated templates |
| Reviewer turnaround | 0-7 days | 0-7 days (Arabic friends' availability) |
| **Total active time** | 4-6 sessions | **4-5 sessions** |

The lack of paid-translator wait time saves a week or more of calendar time. Total work-hours roughly equal.

### 3.3 Quality Floor and Iteration Plan

**v1 ships with:** machine translation + Arabic human review. French may or may not have human review depending on whether one is sourced.

**Post-launch monitoring:** the implementer adds a hidden "report bad translation" mechanism (out of scope for this resolved doc — flagged for v1.1):
- Long-press any string in the app while in debug mode to show its key + open feedback flow
- Or simpler: an explicit "Suggest a better translation" link in Profile → Language

**v1.1 plan:** based on user feedback, low-volume iterative fixes to specific strings. ARB files are easy to patch — change one value, run `flutter gen-l10n`, ship.

**v2 plan (if scale justifies):** budget allocated for professional translation review of the existing machine translations. Only the strings flagged by users or by the operator's gut-check need re-translation, not the whole catalog. Budget: $50-100 per language, much cheaper than from-scratch translation.

---

## 4. Decision Audit Trail

| Decision | Date | Made By | Source |
|---|---|---|---|
| Q1 — DeepL Free + AI translation, no paid translator | 2026-05-05 | Eric | Chat answer (budget constraint) |
| Q2 — Arabic friends for review; French TBD | 2026-05-05 | Eric | Chat answer |
| Q3 — Delete AppStrings class after migration | 2026-05-05 | Eric | Chat answer |
| Q4 — Highlight device language but require tap | 2026-05-05 | Eric | Chat answer |
| Q5 — Leave currency selector at current location | 2026-05-05 | Eric | Chat answer |
| Q6 — Three-stage backend rollout | 2026-05-05 | Eric | Chat answer |
| Budget — $0 cash cost for Phase 6 | 2026-05-05 | Eric | Implicit in Q1 + Q2 |

---

## 5. Workflow Going Forward

1. **This document is committed** to `docs/PHASE_6_RESOLVED.md` alongside `docs/PHASE_6_LOCALIZATION_SPEC.md`.
2. **Phase 6 implementation begins** with Step 1 of the spec (pubspec dependencies). Smallest, safest change. Investigate-spec-apply-verify cycle per session, as established for the dispute work.
3. **Steps 1-7** are the framework — no user-visible change, no translation work needed yet.
4. **Step 8** migrates all 167 `AppStrings.foo` references. After completion, the file is deleted (per Q3).
5. **Step 9** migrates all hardcoded literals. By end of Step 9, `app_en.arb` is the authoritative English source.
6. **Step 10** runs in-session: implementer uses DeepL Free + AI to produce `app_fr.arb` and `app_ar.arb`. Same session produces backend French/Arabic templates ready for Deploy 3.
7. **Steps 11-13** add the UI surfaces (Profile row, language settings screen, first-launch picker).
8. **Backend Deploy 1** ships as soon as Steps 1-9 are stable + the `functions/i18n.js` indirection is done. SMS still in English.
9. **App ships (Stage 3)** with all languages active.
10. **Arabic friends review** — Eric coordinates while app is in soft-launch or beta.
11. **Backend Deploy 3** ships with translated templates.
12. **v1.1 fixes** based on review feedback.
13. **Phase 5i begins** on the localized base.

---

## 6. Risks Carried Forward

| Risk | Mitigation |
|---|---|
| French translation quality without human review | Ship English+Arabic first if no French reviewer found by Step 10 |
| Arabic friends unavailable when needed | Have backup plan: defer Arabic to Phase 6.1, ship English+French |
| DeepL Free quota exceeded | Unlikely — our content is ~10K chars, quota is 500K/month — but if hit, switch to AI translation only |
| Machine translation produces a money-related error | Human reviewers focus specifically on money verbs and action buttons (briefed in Q2 above) |
| User reports bad translation post-launch | v1.1 hot-fix path established; ARB edits + redeploy is fast |
| One language has noticeably worse quality than another | Acceptable risk for v1; document publicly that translations are machine-assisted and improving |

---

## End of Resolved Document

Commit alongside `PHASE_6_LOCALIZATION_SPEC.md`. Phase 6 implementation begins with spec Step 1.
