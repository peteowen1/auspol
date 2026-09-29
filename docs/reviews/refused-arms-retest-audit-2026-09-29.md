# Audit: which refused/abandoned model changes deserve a retest

Read-only audit, 2026-09-29. Triggered by the seat-swing port: refused three
times (August-September) for reasons that had nothing to do with whether the
idea works — (1) it modified `shares` before `xgb_primary_override()` and was
tested harness-only under the shipped default `AUSPOL_XGB_PRIMARY=1`, so the
change was silently overwritten by a stale cached prediction file before the
harness ever scored it; (2) its constant was fitted on the elections it was
scored on; (3) its input data had an error. Rebuilt properly, it improved
ledger seat log loss 0.2840 → 0.2756 and ships tonight as v48
(`docs/plans/prereg-seat-swing-port-v2-2026-09-29.md`).

This audit went through all 141 `docs/plans/prereg-*.md` files (via five
parallel researchers, ~28 files each, cross-checked against `docs/reviews/`
and `docs/DECISIONS.md`), asking the same question of every refusal: **was the
test itself sound, or would it fail the same way the seat-swing port did?**

## The four known-broken conditions

- **(a) ERASED** — the change acts on `shares` (or another input
  `xgb_primary_override()` overwrites) *before* that call in the harness, and
  was measured harness-only under the shipped default (`AUSPOL_XGB_PRIMARY=1`,
  no cache rebuild) rather than via a full `rebuild_forecasts.sh` pass. The
  override does a full cell replacement — `out[hit, p] <- pmax(0, v[hit])` —
  for every `(seat, party)` cell its cache covers, confirmed at
  `R/xgb_primary_override.R:63-86`. It was only created 2026-09-10, so nothing
  dated before that can have been erased by it.
- **(b) LEAKY BASELINE** — fitted leave-target-out or on all elections, before
  the 2026-09-28/29 fixes (`state_poll_dev` used the actual national swing;
  many `base_pred` constants were fitted without a strict time-forward cutoff).
- **(c) DEPRECATED CRITERION** — refused on calibration slope alone, on one
  harness/pair only, or on a pooled/aggregate bar when the fix targets a
  handful of seats.
- **(d) STARVED INPUT** — given a subset of data since expanded: seat-level
  polls (scraped 2026-09-29, `external/reference/polls/seat-polls/`),
  retirement/incumbent completion (`prereg-seat-context-complete-2026-09-28.md`),
  regional/state splits.
- **(e) none** — a clean refusal on the merits. Most refusals are this.

Harness override line numbers used to check before/after:
`backtest_candidate_fed.R:1455`, `_nsw.R:812`, `_qld.R:774`, `_sa.R:942`,
`_vic.R:722`, `_wa.R:617`.

## Current weak spots (why these particular items matter)

Seat log loss ours/AEF, lower is better: **nsw2023 0.2661/0.2138 (worst — Labor
under-called statewide: Parramatta, Heathcote, Camden)**, fed2022 0.2906/0.2339
(weak), fed2025 0.2905/0.3025, qld2024 0.2773/0.3578, sa2026 0.2567/0.3525,
vic2022 0.2283/0.2572, wa2025 0.2900/0.3537 (last four are fine). Winner's
primary RMSE worse than AEF in 5/7 elections. Worst seats: independent/teal
emergences (Wakehurst, Curtin, Hughes), change seats (Parramatta, Heathcote,
Morwell, Ipswich West), Richmond (GRN).

---

## HIGH and MEDIUM priority items (full detail)

| Priority | Name | Date | Switch | What it does | Result & why refused (quoted) | How measured | Condition(s) + evidence | Citation |
|---|---|---|---|---|---|---|---|---|
| **HIGH** | Fundamentals: drop `fed_aligned` | 2026-09-20 | none/structural (`FUNDAMENTALS_FEATURES` constant) | Removes the federal-alignment "punishment" term from `fit_fundamentals()` — the term that drags the statewide anchor down in nsw2023 specifically | LOO MAE (61 elections): 3.042→3.586 (**+0.543, bar 1 SE = 0.253 — FAILS**). Mix MAE @1 day: 1.660→1.645, but "without nsw2023 itself the arm is worse by 0.018." @730 days: 2.249→2.706 (worse). REFUSED on both criteria; nsw2023 is exactly the election it gets wrong. | Both mixes refit **leave-one-out** across 42/61 elections, not time-forward. Statewide-only, entirely upstream of `shares`/override (condition a N/A by mechanism). | **(b) LEAKY BASELINE** — explicit LOO, predates the 09-28/29 time-forward fixes by 8 days, and is exactly the statewide/fundamentals layer those fixes target. Most direct hit on the model's single worst-scoring election of anything in this audit. | `docs/plans/prereg-fundamentals-drop-fed-aligned-2026-09-20.md` |
| **HIGH** | Partial-return split slope | 2026-09-09 | `AUSPOL_SPLIT_SLOPE` (stays 0) | Splits a class's prior vote into returning/departed portions with separate fitted slopes, instead of one binary-flag slope | Primary FAILS: target-cell RMSE 5.377→5.584; **catastrophic floor breached on Victoria (+0.0646 vs 0.02 bar)** and pooled log loss (+0.0242 vs 0.01). Root cause found post-hoc: the arm discarded the existing tuned slope system (`screened_slopes()`) entirely and substituted two pooled global slopes — "the split-vs-not question was never actually tested." Offline preview said the opposite (t=-3.04) because it scored a different quantity than the harness applies. Mechanism itself: R² 0.899 (returning) vs 0.575 (departed) at **17.6 SE** — real and large. | Full run, all 22 pairs, 20,000 sims, `AUSPOL_SPLIT_SLOPE=1`. Whether `AUSPOL_XGB_PRIMARY` was 0 or 1 is **not stated in the doc — unknown**. | **(a) possible** — `split_dev_slope()` replaces `dev_slope()` at `backtest_candidate_vic.R:613-614`, strictly before `xgb_primary_override()` at `:722` (same ordering all six harnesses); if run harness-only at the default xgb=1, cells the cache covers would be silently overwritten on top of the diagnosed bug. **(b) LEAKY BASELINE confirmed** — `s_ret`/`s_dep` fitted leave-target-out, predates the time-forward fixes. Author's own prescribed fix: keep the existing tuned slope for the returning portion, give only the departed portion its own (lower) slope — refine, don't replace. | `docs/plans/prereg-partial-return-split-slope-2026-09-09.md`; `scripts/backtest_candidate_vic.R:613-614` vs `:722` |
| **HIGH** | Phantom minor vote | 2026-09-20 | none (code reverted) | Unpolled classes (ONP/IND/OTH_RIGHT where unpolled) should draw exactly 0 instead of N(0, 2.85) noise, before renormalisation | Smoke test passed (nsw2023 seat RMSE improved) but full **rebuild v43 REFUSED**: pooled seat log loss 0.2943→**0.3022** (AEF 0.2851). Diagnosis: "the phantom vote was real, but it had been partly compensating for the anchoring pushing the Coalition up" — removing one leg of a compensating pair regresses until the other leg (anchoring) is fixed too. | Full ledger rebuild v43, 20,000 sims, xgb on — appears to be a genuine full-pipeline measurement (not stated as `rebuild_forecasts.sh` stages explicitly, but not a stale-cache harness-only read either). | **(e) clean refusal with a named, unexecuted joint fix**: "the anchoring arm must be designed with it (the two are one change)." The anchoring twin is the next row (live-level-anchor) — these two should be retested **together**. Directly implicates nsw2023 (motivating case: Labor under-called statewide). | `docs/plans/prereg-phantom-minor-vote-2026-09-20.md` |
| **HIGH / PENDING** | Live forecast anchored the way backtests are | 2026-09-28 | `AUSPOL_LIVE_LEVEL_ANCHOR` (default 0, held) | Fixes a parity gap: backtests anchor the statewide level fed to seats to the trend+fundamentals projection; the live forecast does not, so the ledger scores a recipe production doesn't run | All 3 criteria PASS (level lands within tolerance, backtests provably untouched, switch fires both ways). Effect is large: live expected seats ALP 34.89→31.07, LNP 34.36→36.61, ONP 13.45→14.89, P(ALP majority) 0.114→0.048, **7 favourites change**. **NOT SHIPPED** — "held for Pete... half of it is the remainder-OTH closure, which is the likely source of the backtests' +2 others-bucket bias" (the unresolved `others-bucket-size` item below). | Live-forecast-only experiment, explicitly verified backtests are byte-unaffected. Not shares/override-related — a `state_mean` shift applied before shares are built. | Correctly-run, criterion-passing fix parked on human judgement plus one open dependency, not a broken test. Flagged HIGH because it's the live-forecast twin of the exact statewide-anchoring issue behind nsw2023's miss, and the seat-count impact (7 favourites) is unusually large for something sitting unshipped. **Retest with phantom-minor-vote together, per that item's own diagnosis.** | `docs/plans/prereg-live-level-anchor-2026-09-28.md` |
| **HIGH** | Departed-member SIDE features (xgb layer) | 2026-09-28 | `AUSPOL_XGB_DEPARTED_SIDE` | Adds `own_departed_i`/`opp_departed_i` xgb features flagging which side of a two-major contest lost its sitting member | Rebuild D vs v44: seat log loss 0.2881→**0.2902 (+0.0021, t 1.01) — FAILS**. Named targets barely moved (Parramatta/Monaro Labor +0.1 each). "The xgb layer learns a small correction on base_pred, and the miss is in base_pred." | Feature added to the xgb override mechanism itself (not upstream of it), so not erased by the override — this changes what the override *produces*. Full retrain (rebuild D), not stale-cache. | **(d) STARVED INPUT, self-identified**: the doc's own next step says the `base_pred`-side version needs the just-completed retirement data (`external/reference/retirements/`, completed 2026-09-28) to separate retirement from lost preselection — that base_pred arm does not appear to have been run yet. Targets the current #1 weak spot by name (nsw2023 Parramatta/Heathcote/Camden). Satisfies CLAUDE.md's "test both base_pred and xgb layer" rule — only the xgb layer has been tried. | `docs/plans/prereg-departed-member-sides-2026-09-28.md` |
| **HIGH** | Independent emergence, 5-round chain | 2026-08-20 to 08-23 | none/structural — bespoke scoring scripts, never wired into `fit_seats_full.R` | Models a seat's independent vote directly (sitting-IND recontest+persistence / emergence / zero) instead of scaling IND into the OTH aggregate | Final round vs corrected baseline: log score **+1.49 SE (bar 2 SE — FAILS)**; Brier **worse by 1.96 SE (limit 1 SE — FAILS)**. "Five attempts. Closed." Model buys new-independent seats by degrading seats it already had right (accuracy 87.5%→86.5%). Federal-scale test (round 4, 886 seats) found the effect **reversed sign** vs the NSW-only reads. | All parameters fit **leave-one-election-out**, not time-forward; predates `xgb_primary_override()` entirely (created 2026-09-10; this work is 08-20/23) — erasure structurally impossible, confirmed. | **(b) LEAKY BASELINE** — same leave-one-out pattern the 09-28/29 fixes address elsewhere, never re-run time-forward. **(d) STARVED INPUT** — diagnosis is the model needs to know about a candidate "who did not exist last time" (Dubbo, Steggall, Chaney, Dai Le); seat-level polls (scraped 2026-09-29) are exactly this kind of signal and postdate all 5 rounds. This is the core mechanism behind the named independent/teal weak spot. | `docs/plans/prereg-independent-remeasure.md` (chain: `-emergence.md`→`-v2.md`→`-two-mechanism.md`→`-federal.md`→`-remeasure.md`) |
| **HIGH** | Candidate model's independent-calibration collapse | 2026-08-20 | none/structural (diagnostic, from the seat-swing-adjustment port backtest) | Genuine held-out NSW2019→2023 backtest of the candidate model's calibration, alongside an attempt to port `seat_swing_adjustment()` into it | Model **near-calibrated on major/Greens contests** (slope 0.962 excl. IND wins) but **collapses on new independents** (overall slope 0.541; 0.80-0.90 probability bin: predicted 0.845, observed **0.143** on 7 seats). 5 of 9 NSW2023 IND gains — **Kiama, Wakehurst, Murray, Orange** — were called at **p≈0** for the actual winner. The port itself was separately BLOCKED on a mis-sized tolerance (a coefficient shift of ~1.6 SE tripped a "must not move by more than half its value" rule) — the port lineage this predates has since shipped (today, v48, `fed_swing`-only, time-forward, applied after the override). | Genuine out-of-sample backtest (NSW2019→2023), no leakage, scored via `simulate_seat_contests()` directly. | **(c)-adjacent on the port** (an SE-based tolerance was needed, a relative-magnitude one was used — CLAUDE.md's "write every tolerance in SEs" rule was written the day before and not yet applied). The **calibration-collapse finding itself is not refused, just never acted on** — it is the clearest documented account of the exact independent/teal blind spot named in the current weak-spot list (Wakehurst is named in both places). | `docs/plans/prereg-candidate-model-backtest.md`; scoring in `docs/reviews/candidate-backtest-nsw2023-2026-08-20.md` |
| **HIGH** | Salience separates new candidates (AUC gate) | 2026-08-27 | none/structural (a scoring criterion) | Tests whether the salience signal (`jump`) can rank a genuine emergent winner above other new candidates, within the new-candidate population only | REFUSED per its own clause: fed2022 AUC 0.979 pass, nsw2023 AUC 0.894 pass, **sa2026 AUC 0.517 FAIL** — "one election carrying it is indistinguishable from chance." Diagnosed as sa2026 being **unmeasurable, not negative**: 104/109 SA candidates are exactly zero jump (95%), including all 4 winners, because the shared 2021-2026 Google Trends window is scaled to federal campaigns and floors state candidates to zero. | Direct AUC computation over the corpus, genuinely measured, not a harness backtest. | **(d) STARVED INPUT**, explicitly diagnosed in the review: "the design that removed the cross-election scale problem created a resolution problem." Remedy named but never actioned: fetch each election's salience in its own window/geography. **Cheapest high-value retest in this whole audit** — directly about detecting independent/teal emergences (a named weak spot), same unchanged criterion, just needs sa2026 refetched at proper resolution. | `docs/plans/prereg-salience-separates-new-candidates.md`; `docs/reviews/salience-new-candidates-2026-08-27.md` |
| **HIGH** | Vote belongs to the person — Rule 1 (departed-leader retention) | 2026-09-06 | `screened_slopes(honour_departed=)`, no `AUSPOL_*`, default OFF | When a screen-permitted newcomer's predecessor of the same class has actually departed, decay the departed leader's base at the fitted `new` slope instead of uniform swing | Six-pair mean log loss wash: 0.3717→0.3750 (+0.003, within 1 SE). New England 2013 improved for IND but "stays wrong because the 1.5x minor-vote scaling and the 0.73 surge hazard remain." Wentworth 2022 got materially worse (0.705→0.138 — Phelps' base decayed when the model didn't want it to). Rule 2 shipped; Rule 1 refused. | Bare harness runs at published defaults, one pair per launch. Predates `xgb_primary_override()` by 3 days (verified via git log) — erasure structurally impossible. | **(d) STARVED INPUT** — retention was measured as wildly heterogeneous (0.33 to 1.16) with no per-candidate feature to explain it; the plan's own conclusion is it needs "the departed leader's own size and the newcomer's salience." Seat-level polls (scraped 2026-09-29) and seat-context completion (retirement/incumbent flags, shipped 2026-09-28) did not exist at test time and are plausibly the missing signal. Directly targets teal/independent-emergence seats. | `docs/plans/prereg-vote-belongs-to-the-person-2026-09-06.md` |
| **HIGH** | Reentry: personal-vote priority for major-party defectors (Kiama/Pilbara) | 2026-09-08 | none new — a filter ahead of the (currently OFF) reentry GLM write | Before writing re-entry GLM values into `shares`, drop any (seat, party) cell that `personal_prior_vote()`'s defector floor already covers (12 named cells incl. Kiama/Gareth Ward, Pilbara/Larry Graham), so a generic re-entry model doesn't overwrite a specific, informed floor | **Never formally scored.** Code was implemented (`protect_personal_vote_cells()`) and confirmed wired **before** `xgb_primary_override()` in all six harnesses (e.g. `backtest_candidate_qld.R:632` vs override at `:774`; `_sa.R:675` vs `:942`) — condition (a) does not apply, it's plumbed correctly. `AUSPOL_REENTRY` stays 0 by default, so this filter is currently a dormant no-op. | Never run to a decision — implementation only. | Genuinely **open, not refused**, flagged HIGH because: correctly positioned relative to the override (verified file:line), directly targets Kiama (named nsw2023 problem seat, current worst pair) and Pilbara, and the entire reentry family is OFF — turning it on now, post seat-context-complete work, is cheap. | `docs/plans/prereg-reentry-personal-vote-priority-2026-09-08.md`; `scripts/backtest_candidate_qld.R:632` vs `:774`, `_sa.R:675` vs `:942` |
| **HIGH** | Calibration: temperature rescale (Ship C) — decided, blocked on implementation | 2026-08-21/22 | none yet (would need a new switch in `fit_seats_full.R`) | One-parameter temperature rescale of published seat probabilities, to fix calibration slope below 1 in 9 of 10 elections (federal 0.183-0.441, NSW 0.541, SA 0.299) | **Decisively wins and was never disputed**: C beats status quo by **+2.85 SE** (pooled log score 0.5631→0.3680, −35%), C beats a wider-spread alternative by 2.67 SE, temperature stable at 0.30-0.35 across all 10 folds, accuracy unchanged by construction. All refusal checks (K1-K4, K6) pass. **Blocked purely on K5**: temperature rescales per-seat probabilities but not the seat-count histogram published beside them on the same page — "the model is unchanged until it is done." Not a broken measurement; a finished, positive result with unfinished implementation. | Leave-one-election-out log score, clustered on election, 9 df, 1,187 seats across 10 elections. Verified independently in this audit (`docs/reviews/calibration-2026-08-21.md`) — this is a real, careful result, including two caught plumbing bugs (overwritten baseline files) that make the +2.85 SE figure more, not less, credible. | Not (a)-(e) — a different category entirely: **highest value-per-effort item in this audit**, since the measurement is done and only the histogram-consistency implementation remains. Worth prioritising above several "needs a full retest" items below since no retest is needed, only the finishing work. | `docs/plans/prereg-calibration.md`; `docs/reviews/calibration-2026-08-21.md` |
| MEDIUM | Independent/OTH-scaling exemption (South-West Coast) | 2026-08-19 | none/structural — code reverted, no switch built | Exempts seats the anchor's seat file marks as IND incumbent/challenger from the blanket ×0.65 OTH-scaling that crushes a personal independent vote into the minor-party aggregate | A1 (South-West Coast IND win prob ≥10%) → **0.06%, FAIL**. Independent lifted 16.3%→23.1% but One Nation is *also* projected at 26.7% in that seat and out-ranks it: "the binding constraint is the One Nation seat allocation, not the scaling." A2-A4 passed; reverted per its own pre-committed rule against tuning on one seat. | Direct live-forecast check on the actual Victoria 2026 seat file, one seat only — not a backtest. | **(d)-shaped**: the blocking dependency (ONP's seat-level allocation, which its own code comment says not to trust seat-by-seat) predates the extensive insurgency/surge/seat-swing-port work shipped since. Worth re-checking whether ONP's seat-level behaviour in this specific seat has since improved enough to clear A1 — this is the **live target election**, not a backtest abstraction. | `docs/plans/prereg-independent-projection.md`; `docs/reviews/independent-projection-2026-08-19.md` |
| MEDIUM | Fitted conditional slopes (replace 8 hardcoded same/new constants) | 2026-09-09 | `AUSPOL_FIT_SLOPES` (default 0) | Refits `conditional_slopes()`'s 8 hardcoded same/new deviation-slope constants from data, leave-one-election-out, instead of frozen values | Pooled seat log loss 0.3365→0.3393 (t=+1.21, worse than a ≥2.08 SE bar). 20 of 22 pairs a dead heat; fed2013 (Palmer United's debut, a surging-class case) is the clear cost — the frozen `new=0.325` (shrink hard to statewide level) beats the fitted `0.442` (preserves a pattern that didn't persist). Observed effect (+0.0028) below the run's own MDE (0.0032) — "this test could not resolve it." | Full 22-pair backtest, 20,000 sims, all 6 harnesses. `conditional_slopes()` is called before `xgb_primary_override()`, but the override didn't exist until the day after this test (2026-09-10) — erasure structurally impossible. | **(b) LEAKY BASELINE** — leave-one-election-out, predates the time-forward fixes; exactly the class of base_pred constant CLAUDE.md names as the leak-fix target. Named, unbuilt follow-up: "condition the slope on surge status," combinable with the now-shipped `AUSPOL_SALIENCE_SURGE_V2` (shipped 2026-09-06, available at test time but never combined with this mechanism). | `docs/plans/prereg-fit-conditional-slopes-2026-09-09.md`; `scripts/backtest_candidate_fed.R:955` (call) vs `:1455` (override) |
| MEDIUM | Widen majors' seat-SD in NSW departed-member seats | 2026-09-16 | `AUSPOL_SD_DEPARTED` | Widens ALP/LNP's per-cell simulation SD only in NSW seats where the previous winner isn't on the ballot | Primary target (42 seats) improved 0.9293→0.9040 (needed -0.05, got -0.0253 — FAILS at half the bar). "Confined to nsw2023" refusal condition fired: nsw2019 flat (+0.0003), nsw2023 carried all the gain. Root cause: all 4 of nsw2019's failures were won by a **minor** party (Shooters ×3, IND ×1) — widening the two majors cannot reach a seat lost to a fourth party. | Per-cell SD override (`R/xgb_primary_sd_override.R`), a different mechanism from `xgb_primary_override()` — variance, not primary-vote level; condition (a) not directly applicable. | **(e) clean refusal, scoped to the wrong classes** — majors only, should widen "whoever could plausibly win." Doc names the follow-up ("widen minor classes too") as **not yet written**. Both target NSW departed-member seats, and nsw2023 is the current worst pair. | `docs/plans/prereg-departed-member-width-2026-09-16.md` |
| MEDIUM | State-deviation v2 (add prior-state-election term) | 2026-09-19 | `AUSPOL_STATE_DEV=2` | Adds `state_elec_dev` (prior state election's Labor swing) as a second, ridge-shrunk predictor alongside the shipped polls-only `state_poll_dev` term | Primary (state-year sd of mean Labor miss): 2.814→2.777, delta −0.036, **jackknife SE 0.050 — NOT MET**. Do-no-harm: fed2025 +0.0090, at the pre-registered +0.010 bound. WA 2022 undercorrected, WA 2025 overcorrected. Later Tasmania smoke test also worse (RMSE 3.814→3.888, coefficient sign-flipped). | Full federal harness (7 pairs), 20,000 sims, against the stage-6 baseline. `state_deviation_apply()` called at `backtest_candidate_fed.R:1489`, **after** `xgb_primary_override()` at `:1455` — condition (a) does not apply, confirmed by grep. | **(b) plausible but uncertain direction**: `prereg-time-forward-constants-2026-09-28.md` names `R/state_deviation.R`'s coefficient among the leave-target-out constants it later fixed; this v2 predates that fix by 9 days. But a leaky/optimistic fit that still failed on its own bar suggests an honest refit would likely fail harder, not rescue it — flagged as lower-confidence than the other leaky-baseline items above. | `docs/plans/prereg-state-deviation-v2-2026-09-19.md` |

---

## Everything else refused/abandoned (clean refusals, low relevance, or already resolved — compact)

**Genuinely clean refusals (condition e), not flagged for retest:**
cross-party swing (own-base mean-reversion side-finding never followed up,
`prereg-cross-party-swing.md`) · class-concentration v2 (placebo matched the
damage exactly, `prereg-class-concentration-v2-2026-09-15.md`) · class-specific
variance v1/v2 (real but statistically unresolvable at this n,
`prereg-class-specific-variance*.md`) · couple-party-trends · bucket-total
blend/candidate-sum (`prereg-bucket-total-*-2026-09-28.md`) · close-proportional
· anchor-exhaust · anchor-implied-tpp · anchor-informativeness (day-0 anchor,
wrong theory) · demographic seat model & demographic axis & education
residual/ranked-concentration (all blocked further by a census-join gap that
excludes vic2026 entirely) · fed-swing-coefficient (retired two-party model) ·
dispersion-slope · onp-vote-sourcing, proximity-substitution, onp-concentration-
transport, onp-ordering-uncertainty, onp-seat-uncertainty (a consistent,
well-controlled "whose votes move where" refusal run, explicitly closed) ·
no-surge-against-sitting-member (a real SA counterexample existed) ·
nonmajor-vote-regression · nsw-onp-walk-threshold & poll-tracking-bound-scaling
(both genuinely undecidable, one cycle short of power) · oth-flow-composition
(structurally undecidable with aggregate data) · party-inclusion-floor (real
gain, reverted on a values judgement about folding a 20%+ party into OTH,
unlikely to reverse) · minor-defector-rate grid (gains concentrated in a
handful of large cases, not a better estimator) · party-sd-from-data (well-
powered 11/17 tie against a 13/17 bar) · reentry-defended-nonmajor,
reentry-bounded, reentry-flatratio-variance (diagnostic dead ends within the
still-off reentry family) · seat-calibration-grid & seat-type-441 & seat-swing-
predictors/revalidation (retired two-party model, or already superseded by the
shipped v48 port) · salience-expected-primary (P5 alone) & salience-c3-amended
(superseded by v3) · insurgency-conditional-shrink & insurgency-surge (both
functionally superseded by the shipped `AUSPOL_SALIENCE_SURGE_V2`) ·
joint-slope-spread-retune arm C (fix already shipped same day under salience
screen) · flow-cell-shrinkage · flow-uncertainty v1/v2 (Victoria's own history
couldn't test the case that matters — SA 2026 now has real ONP flow data that
didn't exist at test time, mild retest value if the ONP-flow question ever
resurfaces) · gap-decay · inclusion-floor-15 (reverted on principle, not
evidence) · major-defector-conserve (a 209%-margin decisive refusal) ·
firm-factors · statewide-cov-loo arm C2 (WA sign-flips the ALP/IND correlation)
· swing-shape-by-magnitude · surge-hazard-scale P4 (superseded same night by
its own sequel) · wa-flows & wa-three-cornered & survivor-multiplicity (flow-
matrix mechanisms, closed) · xgb-base-margin (cost concentrated in ALP) ·
xgb-surge-parameters v1 (works for IND, AUC 0.20-0.87 inverted for ONP/OTH_RIGHT
depending on class — v2 pre-registered but never run) · sitting-member-baseline
and slope-shrinkage (both already retested tonight on the corrected,
leak-fixed baseline and still refused cleanly).

**Superseded by later, resolved work (no independent retest value):**
seat-swing-port rounds 1-3 (→ shipped today as v48) · independent-emergence
predecessors folded into the 5-round chain above · salience-emergence-gate,
salience-c3-amended (→ v3) · screen-silent-not-permit (refused on its own
criterion, shipped anyway by Pete's judgment) · education-ranked-concentration
v1 (superseded by v2 before running).

**Genuinely open / never run to a decision** (not refusals, listed for
completeness): `prereg-backtest-model.md` (trend-model A/B comparison, no
result found anywhere) · `prereg-nonmajor-bloc-level.md` ·
`prereg-minor-candidate-defectors-2026-09-28.md` (v3 built, not yet wired or
scored) · `prereg-xgb-surge-parameters-v2-2026-09-11.md` (superseded before
running by a different approach) · `prereg-shrink-vs-surge-powered.md` (mixed
split, federal pairs never run).

**Structurally out of scope** (touch the retired two-party `simulate_seats()`
model, which CLAUDE.md forbids further work on): `prereg-seat-calibration.md`,
`prereg-seat-type-441.md`, `prereg-seat-swing-predictors.md`,
`prereg-seat-swing-revalidation.md`, `prereg-fed-swing-coefficient.md`,
`prereg-seat-probability-calibration.md`.

## Notes on confidence

- No item in this audit was confirmed as a **clean, unambiguous (a) ERASED**
  case — the closest are the partial-return split slope (acts before the
  override, XGB setting at test time not stated in the doc) and the
  fitted-conditional-slopes item (acts before the override, but the override
  didn't exist yet at test time, ruling it out). Every researcher was
  instructed to write "unknown" rather than guess, and did.
- For the 2026-09-28 bucket/anchor family, several "rebuild" runs are not
  explicitly confirmed as full `rebuild_forecasts.sh` passes vs. a
  harness-only run reading an existing cache — flagged as "appears full,
  unconfirmed" rather than asserted either way.
- The two 2026-09-28/29-night refusals retested directly on the corrected,
  leak-fixed baseline (sitting-member-baseline, slope-shrinkage) are treated as
  clean refusals, not retest candidates — they were already measured honestly.

## Top 5 HIGH items

1. **Fundamentals: drop `fed_aligned`** — targets nsw2023, the model's single
   worst-scoring election, and was refused on a leave-one-out fit the house
   has since replaced with time-forward fitting everywhere else.
2. **Partial-return split slope** — the underlying mechanism is real and large
   (17.6 SE), but the tested implementation threw away the existing tuned
   slope system; the original author's own prescribed fix (keep it for
   returning candidates, give only departed candidates a new slope) was never
   built.
3. **Departed-member SIDE features (xgb)** — built, refused, and the doc
   itself names the exact missing ingredient (completed retirement data) that
   didn't exist until this same week; targets Parramatta/Heathcote/Camden by
   name.
4. **Independent emergence, 5-round chain + the candidate model's independent-
   calibration collapse** — the model calls Kiama, Wakehurst, Murray and Orange
   at ~0% for their actual (independent) winners; both the leaky fitting and
   the starved-input problem (no seat-level polls) that sank five attempts are
   now fixed/available.
5. **Salience separates new candidates (AUC gate)** — cheapest item here: the
   sa2026 failure was a data-resolution artifact (a shared Trends window
   floors state candidates to zero), not a real negative; refetch sa2026's
   salience at proper resolution and rescore against the same, unchanged
   criterion.

(Also worth flagging outside the "retest" frame: **calibration Ship C** is a
finished, +2.85 SE positive result blocked only on making the seat-count
histogram consistent with the rescaled probabilities — no retest needed, just
the remaining implementation work.)

## Corrections after verification (main session, 2026-09-29)

This audit was written by a delegated agent and spot-checked afterwards:

- **live-level-anchor is NOT held.** `AUSPOL_LIVE_LEVEL_ANCHOR = "1"` shipped
  2026-09-28 (`scripts/published_flags.R:607`). Only the joint fix with the
  phantom minor vote remains untried.
- **Calibration temperature (Ship C) is not "finished, no retest needed".**
  The +2.85 SE is real (`docs/reviews/calibration-2026-08-21.md:30`), but it
  was measured on the 21 August model, before the candidate model, the
  xgb as-at pipeline and four leak fixes. It is a HIGH retest, not a ship.
- **fed_aligned drop**: confirmed refused on a leave-one-out fit
  (`plans/prereg-fundamentals-drop-fed-aligned-2026-09-20.md:14-24`).
- A fifth leak class was found the same day, after this audit: the surge-v2
  hazard trained on later elections in the fed/vic/nsw/qld harnesses (fixed
  `51b5259`). Every surge/salience refusal measured before that fix was
  measured on a leaky baseline.
