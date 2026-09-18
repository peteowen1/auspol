# auspol — work queue

## IN PROGRESS 2026-09-18 (exploratory pass done, deciding run next): the AEF-7 backtests now use the PRODUCTION pipeline, frozen "as at" each election

**Pete's rule, stated 2026-09-18 and now the design**: the AEF-7 ledger is
the main debugging surface for the production model, so it must be built by
the production pipeline -- same training recipe, same parameters, same
`base_margin` mode -- not by a parallel one, or a fix in one never reaches the
other. Concretely: one XGBoost primary model PER ELECTION, trained only on
pairs whose polling day is strictly before it (stricter than the old
leave-one-pair-out cache, which let fed2022's model learn from fed2025), saved
to disk; forecasts persisted as tables, one row per (election, seat, class)
with the leading candidate named. Production = the same recipe with cutoff =
now (`fit_xgb_primary_v6_final.R`, unchanged).

**Built this session (all parse, 1009/1009 tests pass; committed as WIP)**:
- `R/election_dates.R` -- `election_dates()`, ONE polling-day table (was six
  copies in the harnesses); `tests/testthat/test-election_dates.R`.
- `scripts/fit_xgb_primary_asat.R` -- the point-in-time trainer. Reads
  `output/xgb-primary-v6-features.csv` (the numeric model matrix -- NOT the
  similarly-named raw `xgb-primary-features-v6.csv`), drops `x_notional_adj`
  to match production's feature list, `AUSPOL_ASAT_MIN_PAIRS=4`. Writes
  `output/xgb-primary-asat/<target>.ubj`, `-manifest.csv`, and
  `output/xgb-primary-asat-predictions.csv` in the OOF file's schema so
  `xgb_primary_override()` reads it with NO harness change.
- `scripts/published_flags.R` -- `AUSPOL_XGB_PRIMARY_OOF` now points at the
  as-at predictions file (the shipped harness default); `AUSPOL_ASAT_MIN_PAIRS`
  registered. `R/xgb_primary_override.R` default + docstring + staleness deps
  updated. `scripts/build_model_registry.R` CLASSIFY: `AUSPOL_XGB_BASE_MARGIN`
  (was UNEXPLAINED) and `AUSPOL_ASAT_MIN_PAIRS` classified.
- `scripts/build_forecasts_table.R` -- `output/forecasts.csv` (class-level
  primary forecasts, ~13.7k rows over 23 pairs, AEF-7 subset by `election`)
  and `output/forecasts-seats.csv` (win probabilities, newest allprobs per pair).
- `scripts/rebuild_forecasts.sh` -- the ONE command, 8 timed stages in the
  non-circular order (harnesses at XGB_PRIMARY=0 -> pool -> v6 features ->
  as-at models -> production model -> harnesses at shipped flags -> pool +
  forecasts tables -> ledger). Runs BOTH pairs for nsw/qld/sa (the first
  version ran each harness once and `pool_sharedetail.R` correctly refused).
  Default 20000 sims (deciding); `AUSPOL_N_SIMS=5000` is exploratory and
  lowers `AUSPOL_POOL_MIN_SIMS` to match.

**Exploratory run (5,000 sims) COMPLETE 2026-09-18 ~17:00; ledger v31
published from it.** Stages 4-8 all ran; two defects found and fixed on the
way: (a) `build_aef_comparison.R` was never a stage of the driver, so the
first ledger rebuild read the stale 08:44 comparison file and printed a log
loss identical to the run before (now stage 8's first step); (b) it picked
the newest `backtest-sa-` file by NAME, so wave B's sa2022 run hid sa2026 and
the ledger fell to 613 seats -- now selects by the file's `pair` column like
`pool_backtests.R`. Results, all 660 AEF-7 seats (lower is better):

| metric | old ledger (leave-one-out, 20k sims) | as-at (5k sims) | AEF |
|---|---|---|---|
| seat log loss | 0.2627 | 0.2696 | 0.2851 |
| primary RMSE weighted by actual share, 4,489 candidate rows | 4.67 | 4.80 | -- |
| primary wRMSE, ledger definition | 5.301 | 5.277 | 5.424 |

Per pair log loss old -> as-at: fed2022 0.2817->0.2783, fed2025 0.2406->0.2403,
nsw2023 0.2274->0.2325, qld2024 0.3259->0.3422, sa2026 0.2942->0.3018,
vic2022 0.2353->0.2543, wa2025 0.2317->0.2559. The old number saw the future;
the as-at one is the honest one. Two confounds remain until the 20k run: sim
count, and `base_pred` itself changed (three fixes in `57ebced`).
`docs/PIPELINE.md` (new) is the stage map Pete asked for.

**Deciding run DONE 2026-09-18 17:12 (23 min at 20,000 sims); ledger v32
published from it.** Pooled seat log loss 0.2735 vs AEF 0.2851 (660 seats);
weighted primary RMSE 4.79 vs AEF 5.42. Found and fixed on the way: the
ledger was mixing THREE vintages on one page (`scripts/ledger_inputs.R` is
now the one rule -- every column from the harness run `pool_backtests.R`
scored; the pool refuses stage-1 xgb-off files). The weighted-RMSE card had
been comparing AEF against our PRE-xgb baseline (5.28) and calling it ours.

**Worst-seat pass on v32 (Pete's request)**: `docs/SEAT-REGISTRY.md` (new)
holds every seat's verdict so nothing gets re-dug. The Morwell rule (a
departed defector's vote returns to the party they came from) was built,
wired into all seven scripts and measured base_pred-only on 15 cases: 8 of
15 better, Morwell 1.86 -> 1.03, pooled log loss unchanged-to-better, but
the pre-registered primary criterion missed by 0.06 SE. **Switch
`AUSPOL_DEPARTED_ORIGIN` is OFF**; re-decide when the corpus grows.
`plans/prereg-departed-origin-return-2026-09-18.md`.

**Flow pattern resolved to a DATA item, 2026-09-18 evening.** With our own
flow tables run on the ACTUAL primaries, Footscray/Richmond/Brunswick/
Pascoe Vale still give ALP 6-8 points too much, and South Brisbane 6 too
little. One cell: Liberal/LNP preferences with ALP and GRN both alive.
Measured from the transfer files: vic2018 58% to ALP, vic2022 35% (Liberal
cards put Greens above Labor), qld2020 36%, qld2024 73% (Greens last),
federal 59-73%. The card order is public before polling day and the model
has no input for it. **OPEN: an HTV-order table** (election, party, seat or
"all", ALP-above-GRN yes/no) at `external/reference/htv/`, and a flow row
for that cell conditioned on it. For vic2026 this is worth ~8 points of 2CP
in every inner-Melbourne ALP v GRN seat the moment the Liberal cards are
published. Kooyong and Cottesloe are NOT flow (checked): teal primaries.

**Also found: the xgb flow models are leave-one-election-out, not as-at**
(`xgb-flows-v1-loo-<election>.model` trains on later elections). Same leak
shape as the primary cache replaced today. OPEN: `fit_xgb_flows_asat.R`
mirroring `fit_xgb_primary_asat.R`, as a stage of `rebuild_forecasts.sh`.

**Major-party retirement discount, found and SHIPPED 2026-09-18 evening.**
Across all 23 pairs, base_pred over-predicts an ALP/LNP class by 2.8
points (n=361, SE 0.35) when its sitting member does not re-stand, +0.6
when they do. Majors had no same/new tier at all (slope 1 always). Built:
`mp_departed` in `candidate_returns()`, `fit_major_departed_slope()`
(leave-target-out; ALP ~0.60, LNP ~0.65, stable across targets),
`conditional_slopes(major_departed=)`, wired in all seven scripts behind
`AUSPOL_MAJOR_DEPARTED` = 1. Measured: departed-cell error -0.71 points (SE 0.11), pooled
log loss 0.2979 -> 0.2951, Parramatta 2.20 -> 1.47. `plans/prereg-major-departed-slope-2026-09-18.md`.

**Major-party present-tier slope, SHIPPED 2026-09-18 evening** (`AUSPOL_MAJOR_SLOPE`
= 1): every non-departed ALP/LNP cell gets a fitted slope (~0.95 / ~0.89)
on its deviation from the statewide level. Non-departed cell error -0.049
(SE 0.013), concentrated in majors predicted under 15 (-0.77) and over 55
(-0.20); pooled log loss flat within 1 SE. `plans/prereg-major-present-slope-2026-09-18.md`.
Full rebuild with both tiers launched 18:35 -> ledger v33.

**By-election results as the seat baseline -- OPEN, DATA.** Black sa2026:
Dighton (ALP) won the 2024 by-election and held with 43.2; our baseline is
sa2022 (Speirs LNP 50.1) so ALP starts at 34.7. Only two NSW by-elections
are on disk (`build_nsw_byelection_prevpcv.R`, personal-vote fallback).
**Live relevance**: vic2026's baseline is vic2022, and Prahran changed
hands at a 2025 by-election (Mulgrave, Warrandyte, Narracan, Werribee also
had by-elections); `fit_seats_full.R` does not use any of them as a prior.

**Remaining**:
1. The flow pattern (ALP v GRN and
   LNP v teal 2CPs over-favour the major by ~10 points: Footscray, Richmond,
   Brunswick, Kooyong, Cottesloe).
2. Decide with Pete: the 19 `.ubj` files + `forecasts.csv`/`forecasts-seats.csv`
   as tracked exceptions in `output/` or a GitHub Release.
3. `docs/DECISIONS.md` row; `docs/PETE-ASKED-FOR.md` "AEF-7 must be
   production" -> SHIPPED after 1. Review gate before any PR.

## OPEN, 2026-09-18: intra-Coalition (Liberal vs National) seats have no TCP winner class

`classify_party()` buckets Liberal and National as one "LNP" class everywhere
in the pipeline, so a seat where BOTH stand (Port Macquarie nsw2023, Roe
wa2025 -- 2 of 660 in the AEF7 backtest corpus) collapses to "LNP vs LNP",
with no second class to score a TCP winner against. Checked AEF's own cached
data for Port Macquarie: they have the identical limitation (`tcp: {"LNP":
39.2}`, one entry, not two) -- not a gap unique to us. Zero Victorian seats
in the current (pre-nomination) 2026 candidate list have both a Liberal and
a National candidate, so this is not live-forecast-blocking today; re-check
closer to the nomination deadline. Pete's call: flag and leave for now.
Cheap partial fix available whenever it's worth doing -- show the real raw
party labels (LIB/NAT) instead of the collapsed class in ledger/verification
output for just these seats; the harder fix (the seat SIMULATION predicting
which of the two wins) needs `classify_party()` and the seat-contest model
to both know two Coalition candidates can contest one seat, which they
currently don't anywhere in the pipeline.

## RESOLVED 2026-09-18: AUSPOL_MINOR_DEFECT_BASE_PRED shipped, revised to "no discount for sitting members"

Follow-up to the two-rate `minor_discount` ship (`0a834e0`). The initial
retest of `AUSPOL_MINOR_DEFECT_BASE_PRED=1` (fitted sitting-member rate,
0.71 for nsw2023) showed Murray/Orange/Barwon with EXACTLY 0.000000 delta
despite the discount being correctly computed and logged -- traced to the
published default `AUSPOL_XGB_PRIMARY=1`: the XGB override layer runs
after `dev_slope()` and replaces `shares` entirely, so ANY base_pred-flag
test under default settings is measuring nothing. Retesting with
`AUSPOL_XGB_PRIMARY=0` (this repo's own established method for isolating
base_pred, per the 2026-09-16 "4-step non-circular retrain" note) confirmed
the wiring works -- but the fitted sitting-member rate made things WORSE:
Orange moved from an undiscounted 52.44 (already near actual 53.08) to a
discounted 44.96, moving AWAY from truth. `discount_mp`'s leave-target-out
fit for nsw2023 draws on only 2 other sitting cases (Mirani 0.79, Kennedy
0.63), underestimating what Murray/Orange/Barwon (108-136% retention)
actually needed.

**Fixed by removing the fitted sitting-member rate entirely.**
Leave-one-out cross-validated against all 5 sitting-member corpus cases
(Barwon 1.36, Murray 1.30, Orange 1.08, Mirani 0.79, Kennedy 0.63):
predicting flat 1.0 (no discount) gives HALF the squared error (0.405) of
predicting each case from the other four's median (0.782) -- n=5 is too
thin to fit a rate below 1 usefully, and the median/mean both sit almost
exactly on "keep it all" anyway. `personal_prior_vote()` now applies NO
discount to a confirmed sitting-member switcher; the fitted rate
(`minor_discount`) survives only as the fallback for unknown sitting
status. The 13-case non-sitting rate (median 0.276) is unaffected --
well-powered, no such problem.

**Shipped**, `AUSPOL_MINOR_DEFECT_BASE_PRED = "1"` in `published_flags.R`:
pooled RMSE across the 14 affected pairs moved +0.0014 (4.0554 -> 4.0568,
n=8910) -- negligible, a much better do-no-harm result than the original
refusal's real cost (8.8813 -> 11.4315). Murray/Orange/Barwon move from
~14-18 to 52.44/39.78/37.25 (actual 53.08/53.31/45.83) -- large, correctly
directed. **Honest trade-off, not hidden**: Mirani and Kennedy (the other
2 of 5 sitting cases, both of whom actually lost vote) also revert to no
discount, undoing 2026-09-16's Mirani-specific improvement. Accepted
because the aggregate evidence favours one rule over cherry-picking a rate
per seat -- the same logic already governing every other shrinkage
decision in this repo.

Full trace: `docs/reviews/minor-defector-two-rate-2026-09-17.md`.

## FIXED, 2026-09-17: a minor-to-major party switcher could erase a retiring
## major incumbent's entire seat base

Found tracing the single worst per-seat regression in today's
(refused) `base_margin` experiment — Pilbara/wa2013, `base_pred` predicted
LNP at 81.94% against actual 61.73%. **The cause had nothing to do with
that experiment**: confirmed by direct instrumentation of
`backtest_candidate_wa.R`, `personal_prior_vote()`'s `own_prev_pcv`
substitution let Howlett (GRN in 2008, 9.63%, switched to ALP in 2013 as
the new candidate after the actual ALP incumbent Stephens retired) replace
Stephens' real 44.38% seat base with Howlett's own unrelated 9.63% history.
ALP's projected class share collapsed to 6.93%, the seat's row summed to
61.50 instead of 100, and renormalisation inflated every OTHER class
proportionally — including LNP, to 81.94%, though nothing about LNP's own
projection was wrong.

Mirror image of today's major-defector conservation question (settled:
keep conserving) — a MINOR-party candidate arriving into a major party's
seat, rather than a MAJOR-party member leaving one. **Pete's call: fix it,
not just measure it** — this is a correctness bug, not a design tradeoff.
**Sized: 3 cases across the 22 concluded pairs** (Prospect/fed2007 36.7pt
understatement, Pilbara/wa2013 34.7pt, West Swan/wa2025 10.2pt — corrected
from an earlier wrong claim that all three were 35-37pt). **The sizing
script's own gap: it used `all_election_pairs()`, which never includes
vic2026** — the review gate caught this and found **2 LIVE cases in the
current published forecast**: Melton/LNP (18.5pt understatement, Jarrod
Bingham IND→LNP) and Morwell/ALP (28.6pt, Tracie Lund IND→ALP). **This was
not a future-nominations risk — it was actively wrong in today's forecast
until this fix landed.** Confirmed fixed by rerunning
`personal_prior_vote("vic2022","vic2026")` directly: both rows now
correctly resolve to NA. **Fixed in `personal_prior_vote()`**: a
major-party target row can no longer receive this substitution at all,
mirroring the already-existing opposite-direction guard for major-to-minor
switches. Also verified: 0 cases remain across all 22 concluded pairs;
Pilbara's projection moves from ALP=11.3/LNP=81.9 to ALP=40.6/LNP=49.1
(actual 29.8/61.7) — both errors roughly halved. Added a regression test
(`tests/testthat/test-candidate_returns.R`) for this exact shape.
**Pair-level seat log loss barely moved** on the two affected historical
pairs (fed2007 0.3137→0.3143, wa2013 0.5611→0.5649, same accuracy) — in all
3 known cases the safe party still won regardless, so no historical call
flips. The value is correctness and risk reduction (this mechanism landing
in a genuinely marginal seat could flip a call outright), not a measured
historical log-loss gain. Full trace:
[reviews/minor-to-major-personal-vote-substitution-2026-09-17.md](reviews/minor-to-major-personal-vote-substitution-2026-09-17.md).

## MERGED, 2026-09-17: PR #44 landed on `main` at `4e09ce3`

All 102 files, fully reviewed. `dev` is at `b9a941f`, `main` now matches it.
Branch not deleted (`dev` is the permanent working branch).

## CLOSED, 2026-09-17: PR #44 review — all items resolved

Full review across all 102 files (`aea1cb7`..`b9a941f`). Closed:

- CAL_TAG/`.arm_fingerprint` — false alarm, withdrawn; see the "Correct the
  record" and "Withdraw the fingerprint-parity item" commits (`fe91e68`,
  `f19f258`) for why the arms were never colliding.
- `AUSPOL_PARTY_COR` wa exclusion — deliberate, already in
  `docs/MODEL-REGISTRY.md:75,133` (`cor(ALP,IND)` −0.16 with WA included).
- fed2025 census gap: 1 seat (Bullwinkel), not 3 — measured against the CSV,
  both prereg docs corrected (`3f49748`'s predecessor commit).
- `concentration_order.R` Spearman range: 0.144–0.922, not "0.665–0.800
  wherever non-trivial" — fixed (`a697c11`).
- Partial fit failure in the three `*_apply()` functions now names the
  skipped class (`3f49748`).
- `state_deviation.R:68` clustering citation: CLAUDE.md records it once, not
  twice — fixed (`a697c11`).

- `fit_xgb_primary_v6.R`'s `seat_outperf` gate stopped 0-filling
  `retire_derived`, so `!is.na()` does real work instead of being dead code.
  Proved output-identical on every case (matched/departed/unmatched/NA
  incumbency) before shipping.

Nothing left open from this review. The one real bug of the whole pass — the
cross-engine `ov_sd` divergence in `R/seat_sim.R` — is fixed and tested;
everything else was comment accuracy or config drift, all closed above.

## OPEN, 2026-09-16: the review gate on PR #44 left three questions for Pete

The gate found one real cross-engine bug (fixed, with a test that fails on the
old code) and a pile of comment errors (fixed). Three things it turned up are
**modelling decisions, not defects**, so they are logged rather than changed.

**1. CLOSED 2026-09-17 — the minor-defector discount ships at a third, and
was sized at a half; settled by a pre-registered grid, kept shipped.**
Docstrings corrected to describe the number that actually ships (0.30-0.34,
median, `min_prior=10`), then
[plans/prereg-minor-defector-rate-2026-09-17.md](plans/prereg-minor-defector-rate-2026-09-17.md)
ran a 2×2 grid deconfounding `min_prior` (5 vs 10) and the aggregation
statistic (median vs geometric mean) against a fixed held-out case set.
Two of the four candidate rates (geomean at both `min_prior` settings)
looked like real improvements on the primary RMSE bar — 6.5% and 11.3%
better — but both were refused on a concentration check: 90-96% of the
apparent gain sat in 5 of 34 cases, the same overfitting shape the review
that started this already knew to watch for. **Shipped rate unchanged.**
Added `fit_minor_defector_discount()`'s `agg` parameter as reusable
machinery (default `"median"`, no behavior change) so the next attempt at
this doesn't start from scratch.

**2. CLOSED 2026-09-17 — measured, decisive: keep conserving.** The
major-party path (`R/candidate_returns.R:579`) conserves a departed member's
unclaimed vote for their old party; the minor-to-minor path doesn't.
[plans/prereg-major-defector-conserve-2026-09-17.md](plans/prereg-major-defector-conserve-2026-09-17.md)
measured non-conserving on the fixed 33-case set: RMSE **209% worse**
(8.59 → 26.54), every jurisdiction worse except NSW, only 1 of 33 cases
improved. Not a near-miss — my prediction (heterogeneity too wide for a
clean answer) was wrong; most major-party defector seats retain 70-97% of
their vote, so full removal massively under-predicts almost everywhere.
**No change** — current conserving behaviour stays.

**Found while tracing this, unrelated and LIVE**: the switch couldn't even
reach the xgb layer, because `fit_xgb_primary_v6.R` never passes
`major_discount` at all (only `minor_discount`) — fine, that's just this
mechanism's actual reach. But following that thread further:
`fit_seats_full.R` (the published forecast) shares ONE `own_prev` object
between the `mat22` base and the xgb-layer feature, and only applies
`major_discount` to it — never `minor_discount`, anywhere. Training's xgb
`own_prev_pcv` IS minor-discounted (`AUSPOL_MINOR_DEFECT`, on by default);
live-serving's is not. **Not dormant**: vic2026's current partial candidate
list already has 5 minor-to-minor defector cases (Frankston, Broadmeadows,
Lara, Werribee, Sydenham) being served the wrong value today. Fix in
progress, separate commit.

**3. CLOSED 2026-09-17 — the premise was wrong, not just the file to parse.**
This item claimed "we score against AEF on TCP and win probability, not at
all on primary vote." **False**: `output/aef-primary-all.csv` already holds
a per-(seat, party) AEF primary prediction and `build_aef_comparison.R`
already joins it against ours — it's where "mean primary error on the
winner: ours 4.23 vs AEF 4.50" (`docs/PETE-ASKED-FOR.md`) came from. The real
gap was that `aef-primary-all.csv` had **no generating script anywhere in
the repo** — a static, unreproducible artifact.

Built `scripts/build_aef_fp.R` to close that gap instead. It parses
`seatFpBands` (same 15-point percentile-band shape as `seatTcpBands`, median
at position 8 — `fpTrend` itself is a statewide campaign trend, not a seat
prediction, so it was never the right field regardless). Aggregated to class
level, it reproduces `aef-primary-all.csv` **exactly** — all 3,671 rows AEF
publishes a class for, max diff 0.007 (rounding). `output/aef-primary-all.csv`
now has a source. `output/aef7-fp.csv` additionally keeps the raw per-party-index
rows before class aggregation, which the existing file discarded.

## 2026-09-16, continued: items 1-3 of the 5-item list resolved

Working the list Pete approved ("work your way through these - i trust your
triage"). Item 4 needs Pete's design input, still open (see the NSW
variance-fault entry above). Item 5 was the hub trim.

Full detail on all three: `docs/reviews/base-pred-blind-to-tonights-fixes-2026-09-16.md`.

- **Item 1, major-party same/new conditional slopes: NOT shipped.** LNP
  same~0.91-0.92 vs new~0.826-0.831 is real (~9% relative), but tested on
  NSW base_pred it improved Parramatta while making pooled ALP+LNP across
  NSW marginally WORSE (MAE +0.066). Not ported further.
- **Item 2, AEF's own TCP prediction: shipped to the ledger.**
  `scripts/build_aef_tcp.R` parses it from our own cached AEF JSON
  (previously unparsed, all 660 AEF-7 rows matched). Confirms the NSW
  pattern from a second angle: AEF favoured ALP at Parramatta (52.6% TCP),
  we favoured LNP.
- **Item 3, a real bug found and fixed.** `personal_prior_vote()`'s
  `transfer` column under-removed the old class's vote, inflating its
  statewide average everywhere else it contests. ~~Zero effect on the
  published model, `AUSPOL_MINOR_DEFECT` defaults off~~ — **wrong when
  written**: it ships `"1"`, and this was itself a live bug, fixed later
  the same night by renaming to `AUSPOL_MINOR_DEFECT_BASE_PRED` (`3661447`).
  Re-tested Mirani: closer to correct than the bug, but discounting it
  specifically still moves it further from actual than no discount — the
  corpus-wide retention rate may just not fit this one seat.

## 2026-09-16 very late: base_pred never got either of tonight's fixes -- tested both layers, mixed result

Pete pushed back on Parramatta ("did its job" when LNP was predicted 48%
against an actual 35%) and it found something real: `seat_outperf` AND the
minor-to-minor defector discount both only reached `fit_xgb_primary_v6.R`'s
own feature-building calls, never the six harnesses' own `base_pred`-
building calls to the identical functions (`personal_prior_vote()`,
`screened_slopes()`'s same/new tables, which never covered ALP/LNP at all).
`seat_outperf`'s SHAP contribution on Parramatta: +0.4, against `base_pred`'s
+22.2. **New standing rule, added to `CLAUDE.md`: test any primary-vote fix
edited into `base_pred` AND as an xgb feature, always.**
Full trace: `docs/reviews/base-pred-blind-to-tonights-fixes-2026-09-16.md`.

Wired `minor_discount` into all six harnesses, ran the full non-circular
4-step retrain (`pool_sharedetail.R`'s own procedure, all 21 pairs,
`AUSPOL_XGB_PRIMARY=0`, `AUSPOL_N_SIMS=20000`). **Mirani improved a lot**
(base_pred 33.24->11.13, xgb_pred error 6.51->4.89) **but the full 28-row
targeted aggregate got WORSE** (RMSE 8.8813->11.4315) than the already-
shipped xgb-only version -- the discount ripples through
`remove_transferred_votes()`'s class-level redistribution and hurts other
rows. **Not shipped** -- reverted to the tested xgb-only state, harness
default back to OFF. Exactly the tradeoff the new rule exists to surface.

**Major-party same/new conditional slopes** (`R/dev_slope.R:207-210` only
covers IND/OTH_RIGHT/GRN/ONP) were sized, built and tested later the same
night -- see item 1 in the section above; real but modest, not shipped.
Also built tonight, reusable infrastructure: `AUSPOL_XGB_SAVE_OOF_MODELS`
(21 cached leave-one-pair-out models) and `scripts/shap_from_cached_model.R`,
so a single-seat SHAP question doesn't cost a full retrain.

## 2026-09-16 late: Mirani diagnosed, minor-to-minor defector discount SHIPPED

Mirani (qld2024) traced to a real, verified mechanism, not a bug: Stephen
Andrew won it for One Nation in 2017/2020, was disendorsed in 2024, joined
KAP mid-campaign, lost to LNP. `personal_prior_vote()`'s existing defector
discount excludes minor-to-minor switches by design ("a much smaller
behavioural jump for voters") — Andrew's case (31.66% -> 25.0%, 21% loss)
contradicted that. Sized across the full corpus (not just Mirani): 33 clean
cases, geometric mean retention **49%**, p=0.0003 — real. Built
`fit_minor_defector_discount()` as its own rate (not shared with the
major-party one, whose retention scale differs), wired via
`AUSPOL_MINOR_DEFECT` (published ON). Targeted RMSE 9.2363 -> 8.8813 (33
cases), Mirani 8.666 -> 6.511; pooled cost +0.0017, well inside the noise
floor below. Full derivation, both docs:
`docs/reviews/mirani-party-defection-2026-09-16.md`,
`docs/reviews/minor-to-minor-defector-2026-09-16.md`.

Also checked systematically (not guessed): any OTHER by-election-installed
incumbent our code can't see? Cross-referenced the anchor's 27 party-
changing by-elections against every pair's `incumbent` field — the 5 that
fall in our scored windows all correctly show the post-by-election party.
No gap beyond the KAP/CA/SFF classification fix below.

## MORNING READ, 2026-09-16 - the NSW failure is a VARIANCE fault, and it needs you to build

Full write-up and the whole investigation (widening arm refused, incumbent-
classification bug fixed, by-election fallback built/measured/reverted,
region-not-OPV resolved): `docs/backlog/journal-2026-09-08-to-16.md`, plus
`docs/reviews/nsw-departed-member-2026-09-15.md` and
`docs/reviews/nsw-departed-member-opv-ruled-out-2026-09-16.md`.

**One thing left, still needs you**: is a per-seat `seat_sd` worth the C++
change? A genuine per-seat multiplier means changing `src/seat_sim_core.cpp`,
which every harness and the live Victorian forecast run through. This is
item 4 on the 2026-09-16 list above - explicitly design-with-Pete, not
solo-build.

**2026-09-17: designed with Pete on the 11 real seats first, per `CLAUDE.md`'s
own rule.** Walked the table — nsw2019's 4 wrong seats all went to a minor
party/independent, nsw2023's 7 split 6-to-the-other-major-plus-1-independent
(and one, Holsworthy, backwards). The beneficiary differs every time, which
argues for genuine seat-level uncertainty over widening one specific class
— consistent with the review's own "primary model's sd, not simulation's
seat_sd" lean, but pointing toward a broader mechanism than the already-
refused major-only widening arm tried.

**Side investigation that grew into its own thread: Pete's `base_margin`
idea** (train xgb on the residual to `base_pred` rather than as a plain
feature) — real signal (AEF7 pooled primary RMSE -0.0452, sa2026 -0.60),
but **refused at the seat level**: pooled log loss 0.2841→0.2880, worse,
concentrated in 2 of 23 pairs, with ALP (not the predicted IND) carrying
the real cost. Of the three AEF7 pairs that regressed at the primary
level, only vic2022 (+0.0183) carries a comparable seat-level cost;
nsw2023 is a small real cost too (+0.0021); wa2025 reverses and actually
improves at the seat level (-0.0236) — a primary-level regression is not a
reliable predictor of a seat-level one either way. Full trace:
[plans/prereg-xgb-base-margin-2026-09-17.md](plans/prereg-xgb-base-margin-2026-09-17.md).
Genuine finding kept from it: **both current and base_margin models already
beat AEF pooled on the 7 comparable pairs** (ahead by 0.0113 and 0.0180
respectively) — worth knowing on its own, separate from this refused arm.
**Next arm, not yet built**: scope `base_margin` away from ALP, or to just
the sa2026/wa2021-shaped cases it measurably helps.

**The NSW seat_sd design question itself is still open** — the base_margin
detour didn't resolve it, only confirmed AEF beats us less than the
standing narrative suggested.

## 2026-09-16 evening: Pattern A SHIPPED — NA-fill beats 0-fill, and a noise-floor finding

Built, tested and **shipped** `seat_outperf` (Pattern A from the 2026-09-13
worst-seats review — a senior retiring MP's personal-vote premium, sized on
all 349 retirement cases, r=0.176 p=0.001). Full trace:
`docs/reviews/pattern-a-seat-outperf-2026-09-16.md`.

Gated to the retiring incumbent's row, **NA-filled elsewhere (not the usual
0-fill)**: clears a placebo-controlled comparison (+0.0061 pooled RMSE vs. a
same-convention zero-information placebo) and gives a real targeted gain
(held-party RMSE in retirement seats 7.6661 -> 7.2843; Riverstone's error
roughly quarters). Richmond (a different, untested mechanism per the
2026-09-13 review) gets worse, as expected. Pooled OOF RMSE now 3.8161;
`output/xgb-primary-v6-oof-predictions.csv` regenerated, every harness on
`AUSPOL_XGB_PRIMARY_LIVE=1` picks it up next run.

**SHIPPED 2026-09-17: `seat_prev_pcv` NA-fill, `AUSPOL_XGB_SEATPREV_NAFILL`,
on Pete's call — but the number he said yes to was wrong.** 16.7% of
(seat,party) rows have no prior-election vote for that party in that seat
(24.2% of minor-party rows, 4.5% major — concentrated in ONP/IND/OTH_RIGHT,
the classes the AEF gap analysis already names as our biggest error). Same
NA-fill mechanism as `seat_outperf`.

**First measurement (INVALID, superseded below):** tested by overriding
`AUSPOL_XGB_PRIMARY_OOF` to swap `output/xgb-primary-v6-oof-predictions.csv`
directly — but that file is not what ships. The published forecast reads
`output/xgb-primary-shipped-oof-predictions.csv`, v7's "v7f" arm built ON TOP
of v6's feature matrix, not v6 raw. That first pass reported pooled seat log
loss 0.2846→0.2844 (wash), SA -0.0127, sa2026 alone -0.0242 (the biggest
single-pair move found) — all **overstated 5-6x** by testing the wrong
artifact.

**Same session, separately: `output/xgb-primary-shipped-oof-predictions.csv`
was found genuinely 3 days stale** (mtime 2026-09-14 13:19, missing 21
commits including `seat_outperf` and the minor-to-minor defector discount —
the LIVE Victorian forecast was running without both). Fixed by regenerating
via the documented recipe in `published_flags.R`. **New true baseline, all
23 pairs: pooled seat log loss 0.2817, Brier 0.0844, accuracy 88.64%.**

**`seat_prev_pcv` re-measured through the corrected real pipeline
(v6→v7's v7f arm→shipped snapshot→six-harness backtest): pooled seat log
loss 0.2817→0.2811 (-0.0006), Brier -0.0005 — small, real, broad.** By
jurisdiction: FED, NSW, QLD, SA, VIC all slightly better (sa2026 itself
-0.0044, not the claimed -0.0242), **WA +0.0039 worse**. Both guards clear.
Pete confirmed ship on the corrected numbers. Default flipped to `1` in
`fit_xgb_primary_v6.R` and `published_flags.R`; shipped snapshot regenerated.

`x_notional_adj` and `retiring_mp_tenure` also 0-fill but are explicitly documented "0 where
not applicable" (a real value, not a stand-in for missing data) — not the
same failure shape as `seat_outperf` or `seat_prev_pcv`, not retested.

**Bigger finding: adding ANY column to this pipeline costs ~0.014 pooled
RMSE regardless of its information content** (measured directly with an
all-zero and an all-NA placebo column, both costing the same). Every past
"pooled RMSE moved by X" verdict in `fit_xgb_primary_v6.R` that added or
removed a feature should be read against that floor, not at face value.
And zero-fill vs NA-fill for a feature only meaningful on a row subset is
not cosmetic — NA-fill halved the pooled cost here. `seat_prev_pcv` and
other existing features use the same `ifelse(is.na(x), 0, x)` convention;
worth auditing before assuming any of them are gated correctly.

Next: decide whether to ship `seat_outperf` (NA-filled) as-is, and audit
existing 0-filled features for the same fix.

## 2026-09-15 later — demographics: the signal is REAL, the correction is too small

Two pre-registrations run and both refused, but the second one refused on
magnitude, not on whether the effect exists.

`docs/plans/prereg-education-residual-correction-2026-09-15.md` — one census
column (`yr12_pct`). Criterion passed, placebo condition fired, REFUSED. The
placebo was mis-specified: `born_aus_pct` correlates **-0.706** with `yr12_pct`
over 1,989 seats, so it was a second reading of the same axis, not a control.

`docs/plans/prereg-demographic-axis-2026-09-15.md` — all seven census columns
under a leave-one-pair-out elastic net, 22 pairs, 2,066 seat-elections. Pooled
seat log loss 0.2849 → 0.2831, **-0.0018**, 14 of 22 pairs improved
(t = -1.83, p = 0.08; binomial p = 0.143). REFUSED: qld2024 worsened by
+0.0024 and it is one of three named One Nation pairs.

**The permutation control is the thing to keep.** Permuting which seat gets
which seat's demographics lands the model on the baseline every time — sa2026
mean 0.3576 against a 0.3577 baseline over 8 draws, and within 0.0004 on all
three Victorian pairs — while the real arm sits 0.005 to 0.012 better. **The
demographic axis carries genuine seat-level information.** Use this control for
anything in this family; a correlated second column is not a placebo.

**Why it still failed, and the next hypothesis.** On sa2026 One Nation it
helped in **10 of the 10 worst-missed seats** and by about half a point where
the gap is seven to eleven — MacKillop 23.8 → 24.3 against an actual 35.3. One
coefficient per class is fitted across a corpus where most elections have a
tiny One Nation vote, so it cannot move a seat far enough in an election where
the party polls 23% statewide. A **level interaction** is the obvious fix and
needs its own pre-registration; fitting it now would be choosing the model
after seeing the result.

**Shipped regardless, and it was a real defect**: `census-features.csv` was
keyed on the previous election's feature file, so redistributions stranded
seats at both ends. `vic2026` had **no census rows at all** and now has 88 of
88; nsw2023 went 88 → 98, fed2022 149 → 152, and partial application unblocked
all seven WA pairs. Demographics could not have reached the live forecast by
any route before this.

**Still open**: `fit_seats_full.R` has no call site for either correction, so
nothing here touches the published forecast yet.

## MORNING READ, 2026-09-15 — the Victorian draft is done, three things need you

Full writeup: `docs/reviews/vic2026-first-correct-draft-2026-09-15.md`.

**The forecast, against AE Forecasts** (expected seats, their NAT folded into
our LNP): LNP 41.63 vs **32.86**, ALP 28.12 vs **34.09**, ONP 9.00 vs
**14.51**, GRN 4.60 vs **5.32**, IND 4.38 vs **0.22**. 19 of 87 seats called
differently. One Nation favourite in 7 seats for us, 0 for them.

**1. The independent under-call is now the biggest gap.** 0.22 against AEF's
4.38. Nothing overnight touched it and it is the largest proportional
disagreement in the table.

**2. One Nation at 14.51 is the number to argue about.** AEF under-called One
Nation badly in sa2026 (1 of 4 seats, favourite in none) — but our own
override was ALSO measured worse there than no override (4 of 4 correct off, 1
of 4 on). Both cannot be right and the corpus has exactly one election where
One Nation has won a seat.

**3. The backfill shipped against a worse backtest, on my judgement.**
`AUSPOL_HISTORIC_ELECTED_BACKFILL=1` costs 0.0141 pooled RMSE. The reasoning:
vic2026 is the target and never a training pair, so the 62 returning members
can only move the live forecast and never the RMSE — the backtest cannot see
the gain it is being weighed against. Reversible in one flag if you disagree.

**Not done, needs you**: the PR. 15 commits on `dev`, CI green, all reviewed.
Merging to `main` is yours per the standing rule.

## RESOLVED overnight 2026-09-14/15

- `historic_elected_i` fed as NA to the live model, deflating every prediction
  ~45% behind renormalisation. Fixed, written up in
  `reviews/live-path-missing-feature-2026-09-14.md`.
- Victorian candidate list in (379 candidacies, 88 districts), which unblocked
  `DS2` (0 → 87 seat-classes), `DS2o` (0 → 22) and `DS3` (flat → 30 seats).
- `DS2` was inert because Wikipedia's "Nina Taylor" and our "TAYLOR, Nina"
  resolve to opposite surnames. Worth 4.4 Labor seats.
- Review findings: Mac/Mc surnames inverting NSW rows; the forced-value
  detector blind to a multi-line `Sys.setenv`.

## SUPERSEDED, 2026-09-14: every Victorian number measured that day is stale (resolved same day)

`historic_elected_i` was reaching the live model as `NA`, deflating every
Victorian prediction ~45% behind renormalisation - fixed and the training
data backfilled same day (`88653b4`, `4e5fde4`), model retrained after.
Full narrative and the "what this cost" lesson (a bug that renormalisation
made look right): `docs/backlog/journal-2026-09-08-to-16.md`.

## RESOLVED (mostly), 2026-09-14: the registry now detects a harness that FORCES a switch

Was open: `_fed.R`/`_nsw.R` force `AUSPOL_SALIENCE_EXPECTED`/`_EXP_SD` to `1`
(deliberate, `01c8e1c`, arm C scoped to fed/NSW) while `published_flags.R`
ships both `0`, and neither doc recorded the scoping — so the registry's own
"reads the switch = yes" check couldn't see a harness that reads it and then
overrides it.

**`scripts/build_model_registry.R` was extended with a `forced_value()`
detector** (checked 2026-09-17, still there) — it now has its own "Switches a
harness FORCES away from its published value" table and correctly explains
this exact case as intentional. **Still open**: `published_flags.R`'s own
comment (line 41/43) still doesn't mention the fed/NSW scoping, only the
registry does — a one-line annotation, not a mechanism gap.


## WATCH, 2026-09-14: One Nation's Victorian level - not breaching, a judgement call still open

Fitted 20.57 vs 90-day poll average 23.04, a 2.47 gap, **0.03 inside the
2.5 bound** - the closest any party has been without crossing. Mechanism:
a near-zero 2022 prior (0.28%) against a surging party, same shape as the
NSW 2027 ONP breach. Investigated and answers the other way to intuition:
following recent polls instead of the trend is NOT better (MAE 1.755 vs
1.862, inside 2 SE), and the historical analogue (WA 2017 ONP) shows the
trend OVER-states, not under-states, near-zero-prior surges. Full evidence:
`docs/reviews/poll-lag-2026-08-19.md`, full narrative:
`docs/backlog/journal-2026-09-08-to-16.md`.

**Still a judgement, handed to Pete**: whether `POLL_TRACKING_BOUND` should
SCALE with how thin a party's polling is - the pre-registered test to decide
this stopped one cycle short of its own floor (19 vs 20) and can't re-run
until another election completes. `docs/plans/prereg-poll-tracking-bound-
scaling.md`.

**Process lesson kept live**: a 19-commit-stale anchor clone flipped this
entry's verdict once (2.85/breaching vs 2.47/inside). Always `git -C
external/aus-polling-analyser log -1` before quoting a poll number.

## sa2026's ONP fix — a real trade, not shipped (2026-09-14)

Full trace (SHAP chain, the `dev_slope()` rank-preserving bug, the VIC2022
regression): `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`.

`AUSPOL_ONP_CONC_SD` (already built, unused) fixes sa2026's worst miss —
18% log-loss gain on the raw model, 0.4339→0.3577 seat log loss after a full
retrain, 39/47→41/47 seats correct. But the full six-harness sweep found
**VIC2022 regresses** (72/78→69/78 seats, log loss +6.3%), the retrained
model over-predicting IND broadly — the same IND/OTH_RIGHT degeneracy
`fit_xgb_primary_v6.R` already names. NSW/QLD/WA/FED unaffected.

**Still open, in priority order:**
1. Fix the VIC2022/IND coupling before this can ship at all — candidates in
   the review doc's Recommendation section.
2. MacKillop's federal/state boundary mismatch — federal ONP vote ranks it
   15th of 47 SA seats, actual result is 2nd-highest; no CV setting fixes
   this, check the boundary maps.
3. Once 1 and 2 resolve, decide whether to default `AUSPOL_ONP_CONC_SD=9.18`
   in `published_flags.R`.

## Standing baseline, 2026-09-13: pooled log loss 0.2914 over 23 pairs

Commits `75a5076`/`8db4305`/`cea78e2`/`a8af56b`/`f3c4b3e`/`75462ea`: the
Frome→Ngadjuri seat-rename bug, the notional (redistribution-adjusted) prior
for federal seats (on by default regardless of aggregate effect — Pete's
call, "do the Antony Green ABC method"), `ret_exp` (IND retention feature,
confirmed real at two seeds). **Pooled log loss 0.2914 (was 0.2984); on the
7 AEF-comparable elections, ours 0.2743 vs AEF's 0.2851.**

Pattern A from that session's worst-seats review shipped 2026-09-16 (see
below). **Still unactioned**, from
[reviews/worst-seats-five-patterns-2026-09-13.md](reviews/worst-seats-five-patterns-2026-09-13.md):
SA One Nation surge broader than known; a defecting incumbent fragmenting
the right three ways; a departed independent's vote reverting rightward
(untested direction for `ret_exp`); QLD optional-preferential flows against
the primary leader.

## Session 2026-09-12/13 - PRs #34-39 merged, xgb-primary circularity found and enforced

Full narrative (the recycled-`pred_share` circularity bug, its enforcement
in `pool_sharedetail.R`, wa2001/wa2008 becoming the new worst pairs once
numbers were honest, the WA salience-exclusion fix, the CI workflow crash
fix): `docs/backlog/journal-2026-09-08-to-16.md`. Headline: pooled seat log
loss corrected to 0.2926 (2,097 seat-elections, 23 pairs), then 0.2915 after
the WA salience fix. `main` was at 0.2915 as of PR #39.

## PREVIOUS SESSIONS, 2026-09-10/11 — rolled to journal, open items carried forward

Full narrative (PR #31/#32, the xgb-primary leak fix, the SA2026 governed-
population fix, census correspondence build, seven shipped bugs):
[backlog/journal-2026-09-10-to-11.md](backlog/journal-2026-09-10-to-11.md).

**Still-open items from those sessions, not yet resolved or restated above:**

1. **Four harnesses still swing toward the ACTUAL statewide, not a prediction.**
   `AUSPOL_FORECAST_MODE` exists in fed and sa only; nsw/qld/vic/wa answer a
   different question from federal's. Core logic already extracted into
   `R/forecast_statewide.R` — this is wiring.
2. **The emergence model decision (v4 vs. salience)** — v4's hazard AUC 0.936
   vs. 0.751, sa2026 moves 0.6362 → 0.5891, but it failed its pre-registered
   bar and reads over-dispersed. Deciding test (seat count, 26 of 2,050
   historical seat-elections won by an emerging non-major) not yet run.
   `docs/plans/prereg-xgb-surge-parameters-v2-2026-09-11.md`.
3. **vic2026 re-check after 12 noon, 9 Nov 2026** (nominations close): re-run
   the three salience fetch/build scripts named in `published_flags.R`, and
   extend `build_candidacies.R` to write vic2026 rows so
   `candidate_returns(vic2022, vic2026)` stops erroring and the flow model's
   `dest_same`/`dest_same_mp` features (0.0% populated today) go live.
4. **GDELT** — parked, needs a GCP/BigQuery project first
   (`docs/plans/gdelt-feasibility-2026-09-10.md`).
5. **Census 2011/2006/2001** — correspondence mechanism now exists; 2006/2001
   have no bulk data pack (per-division Excel only).
6. **WA breaks out `NAT` separately and nothing merges it into `LNP`'s
   trend.** WA's OTH bias is +1.71 against Victoria's +0.45 — suggestive,
   within noise at n=7. Same shape as the fixed `LIB`-mislabelling bug, so
   worth an hour. Re-flagged 2026-09-13 — dropped from an earlier trim pass,
   confirmed still genuinely open (no later doc addresses it).
7. **Re-measure the xgb-primary/xgb-flows challengers with TIME-FORWARD
   folds**, not leave-one-group-out. fed2007 being predicted by a model
   trained on fed2025 is optimistic against the shipped baseline by an
   unmeasured amount, and every absolute number in
   `docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md` inherits it. Possibly
   superseded by the 2026-09-13 xgb-primary circularity fix (PR #36) — that
   fix addresses a DIFFERENT leak (training data recycling `pred_share`), not
   this one (fold direction), so re-check whether it still applies before
   running it. Re-flagged 2026-09-13, also dropped from the same trim pass.

## PARKED 2026-09-09, not killed: seat lean from several past elections (decayed)

Pete's idea, tested three ways on real federal 2pp data (140 seats, 4 real
cycles) — decayed average, momentum extrapolation, volatility-bucketing —
**all three found no usable signal** (best case 0.5% RMSE improvement,
statistically zero). Detail and numbers in
`docs/reviews/xgb-primary-challenger-2026-09-09.md`'s final section.
**Untested and still open**: using FEDERAL results as a correlated signal
for a STATE seat's own lean — genuinely different data, not just re-slicing
the seat's own history, needs seat-boundary matching that doesn't exist yet.

## REFUSED 2026-09-09: dispersion-slope arm (corr x sd-ratio for the flat "new" constant)

Two rounds (all 4 classes, then GRN/ONP only). Both failed the pre-registered
pooled-log-loss bar. Full detail: `docs/plans/prereg-dispersion-slope-2026-09-09.md`.
Machinery (`fit_dispersion_slopes()`) stays in the tree, inert.

## DONE 2026-09-09: the partial-pooling sweep, triaged - zero rescuable candidates

Checked every refused adjustment for whether pooled/shrinkage fitting could
have saved it. **Answer: no** - every refusal was correct on its own
measured grounds (wrong-signed effects, opposite-signed sub-groups with no
replication to shrink from, or a defect that reshapes the estimate not just
its precision). One genuine open item survives: the surge-conditioned slope
has a real effect but needs more corpus (more elections), not better fitting
of what exists. Full table and reasoning:
`docs/backlog/journal-2026-09-08-to-16.md`.

## SESSION 2026-09-09 (AM #3) - candidate/party tracking audit, `fit_defector_discount()` shipped

Mapped every between-election candidate/party transition and fixed what was
broken: `fit_defector_discount()` (major-party defector retention, pooled
across all six harnesses instead of one fitting it and five hardcoding a
stale copy). A completeness fix (sum every identity-matched returning
candidate of a class, not just the leader) was built, found genuinely mixed
on real backtests, and reverted - the real fix needs to separate
"identity-tracked personal vote" from "anonymous residual class vote", a
design question not a mechanical patch; full reasoning is the long comment
above `lead` in `personal_prior_vote()` (`R/candidate_returns.R`). Full
narrative: `docs/backlog/journal-2026-09-08-to-16.md`.

## SESSION 2026-09-09 (AM #2) - worst-seats-vs-AEF table reviewed with Pete

Standing instruction from this session: keep the worst-seats-vs-AEF table as
a living reference and keep working known misses down it - this is the main
improvement loop, not a one-off. Four items from that review: Waite/Kiama
confirmed NOT shipped (dormant behind arm D), a new minor-to-central-party
reversion hypothesis written up but not built
([plans/hypothesis-lean-scaled-minor-reversion-2026-09-09.md](plans/hypothesis-lean-scaled-minor-reversion-2026-09-09.md)),
teal leakage checked clean, salience-of-emerging-groups queued unscoped.
Full detail: `docs/backlog/journal-2026-09-08-to-16.md`.

## MORNING READ, 2026-09-09 overnight session

fed2022's teal seats shipped arm C (salience point estimate + variance),
scoped to federal+NSW only after SA/Victoria breached the pre-registration's
per-jurisdiction bound - Kooyong 5.3%->36.1%, Goldstein 2.0%->12.2%, still
under-called but genuinely better. Personal-vote-priority fix implemented
across all six harnesses, dormant behind unshipped arm D. Waite/SA2026
pattern (class vote-share swung forward after the specific candidates who
earned it left) investigated, not fixed that session. Full narrative:
`docs/backlog/journal-2026-09-08-to-16.md`.

## SESSION 2026-09-07: New South Wales 2019 scored — rolled to journal 2026-09-17

Full narrative (coverage stats, salience status, re-entry prior arm D,
closed-this-session items): `docs/backlog/journal-2026-09-04-to-07.md`. Live
items only, kept in full here:

- **HARD STOP 30 September**: harness-unification plan not started.
- **OPEN QUESTION, parked**: is one party class one party? `classify_party()`'s
  seven classes bucket Liberal/National/LNP together and Katter/Shooters/Family
  First together, and pool state vs. federal Labor without having asked. Major-
  party coding itself was checked 2026-09-07 and is sound — this is a
  granularity question, not a correctness one.
- **Orange/Wagga Wagga still wrong by 30-50 points** — `own_prev_pcv` is `NA`
  for both (by-election winners have no general-election match); a fallback
  fix was built, measured, and made things worse elsewhere, reverted —
  `docs/reviews/nsw-departed-member-opv-ruled-out-2026-09-16.md`. Needs a
  dedicated feature, not a fallback fill.
- **The statewide covariance's ERA is not settled.** All pairs are pooled
  regardless of date and the party structure of 2001 is not that of 2025.
  `docs/reviews/statewide-cov-loo-2026-09-07.md`.
- **Western Australia has no surge-v2 hazard at all.** The other five
  harnesses do. `docs/MODEL-REGISTRY.md` records it as 1 of 2 open gaps (the
  other is WA's screened slope mode only half-implementing what "screened"
  means elsewhere).
- **fed2004** remains unfound as a scored target (it already serves as a
  prior). The Queensland recipe applies — the commission's old results site
  published a package per election and the archive kept it. Parsers are the
  remaining work; sources were located.


## SESSION 2026-09-05/06: the AEF gap closed — shrink 0.10→0.01 (moved out)

Full write-up in
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).
Headline: fed2025 seat log loss 0.3663→0.2886 against AE Forecasts' 0.3025.
Cause was `shrink` capping every seat at `1-shrink/2` — at the old 0.10 no
seat could be called above 0.95. `AUSPOL_SHRINK` shipped at 0.01 (not 0.00,
which blows up fed2013). Also shipped: `scripts/fit_mp_slope.R` (refit the
sitting-member slope tier, fixing a leaked ONP value), `fit_seats_full.R`
passing `same_mp`/`major_discount`, `AUSPOL_SEAT_SD_MULT` un-inerted.

## THE OBJECTIVE, set by Pete 2026-09-06 evening

**Every model change is decided by overall seat log loss AND seat-share RMSE
pooled across ALL the elections we forecast** — every 21st-century state and
federal election in the harnesses — never one election or one harness. The
harnesses now print the RMSE line (`BF3r`/`BV2r`/`BT5r`/`BS2r`/`BW2r`,
`seat_share_rmse()` on the point estimate) beside log loss.

**Coverage today: 17 elections, ~1,570 seat-elections** — fed 2010, 2013,
2016, 2019, 2022, 2025; vic 2018, 2022; nsw 2023; sa 2026; wa 2001, 2005,
2008, 2013, 2017, 2021, 2025. **Buildable now**: qld2024 (2020 prior and
transfers on disk; also one of AEF's archived elections). **One prior fetch
each**: fed2007 (needs fed2004), vic2014 (vic2010), nsw2019 (nsw2015), sa2022
(sa2018). Those five would make 22.

## P4b SHIPPED 2026-09-07: surge reaches the candidate it was fitted for (moved out)

`AUSPOL_SURGE_RECIPIENT=1` published — pooled seat log loss 0.3631→0.3422.
Remaining gap is the hazard's calibration (ridge lambda 20 on ~13 winners).
Full write-up: [backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## DATA HUNT 2026-09-07: all five missing elections FOUND (moved out)

fed2004 fetched and wired in (fed2007 now forecasts, log loss 0.2858).
nsw2015, vic2010, qld2017, sa2018 located but still need parsers — that's
the open item, worth coverage 19→23 elections. Sources and the AEC path
gotcha (`/results/Downloads/` vs `/Website/Downloads/`, wrong path 404s
silently) are in
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Standing item found 2026-09-07: package functions read BARE RELATIVE paths

`surge_hazard_for()` and `surge_training_population()` read
`"output/candidacies.csv"` relative to the working directory. That is the
package root for everything in `scripts/`, and `tests/testthat` for the
suite -- so two tests of those functions guarded on `file.exists("output/...")`
and skipped **unconditionally, on every machine, including the ones that have
the corpus**. Found by review 2026-09-07; the tests now resolve from the root
(`skip_if_no_salience_corpus()`) and run their bodies there
(`with_package_root()`), both in `tests/testthat/helper-anchor.R`. The
underlying smell is unfixed: package functions should resolve through
`getOption("auspol.root")` the way `election_data_path()` does.

## SESSION 2026-09-07: a sixth harness, two refusals (moved out)

Queensland harness added (log loss 0.3351 vs AEF's 0.3578), salience point
estimate ported to all harnesses, two changes refused by their own criteria
(P5, P6). Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

**The one live thread, and it is Pete's:** the six fed2022 teals polled
25-40% and the model projects 2-14%. The hazard is calibrated and correctly
ranked; what's missing is that 2022 was a wave and nothing in the model can
see one. **The wave term is BLOCKED, diagnosed, no arm should be run**:
[reviews/wave-term-blocked-2026-09-07.md](reviews/wave-term-blocked-2026-09-07.md)
— the percentile-based salience signal can't distinguish a wave from a quiet
year, and the raw measure isn't comparable across elections (every batch is
anchored to Albanese, a nobody in 2008 and PM in 2026). The one unblocking
route before November: candidate-count NOMINATED per seat (a commission
fact, available after Victorian nominations close 9 November 2026) as a
crowding proxy, not a prominence one.

## P4c REFUSED and the calibration question ANSWERED, 2026-09-07 (moved out)

Letting a named recipient surge from zero share was refused (pooled
0.3422→0.3444) — the hazard is already calibrated out of fold; **the gap to
AE Forecasts is information, not calibration.** Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## THE SIMULATOR IS COMPILED, 2026-09-07 — a sweep is minutes, not an hour

`src/seat_sim_core.cpp`, the compiled per-draw core of
`simulate_seat_contests()`, proven byte-identical to the R reference engine
(full fed2022 run at 20,000 draws, byte-for-byte). **45 seconds against
about 11 minutes.** `AUSPOL_SIM_ENGINE=cpp` is published; `=r` forces the
reference loop for re-proving the identity. Full write-up:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## P4/P1 stage results, review gate, and per-seat shrink (all moved out, 2026-09-06)

P4 stage 1 found the surge was paying the wrong candidate (fixed by P4b
above); P1 shipped "vote belongs to the person" (rule 2) and refused the
departed-leader rule (rule 1); the pre-dev→main review gate caught a NINTH
data.table NSE instance (`party_swing()`'s region filter) plus four other
bugs, all fixed same-commit; per-seat shrink (`AUSPOL_INSURGENCY_SHRINK`)
was measured three ways and refused each time — the scalar 0.01 stayed
shipped. Full write-ups, tables and the deferred-fix list:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Then

1. ~~Re-measure the other four harnesses at `shrink=0.01`~~ — done above.
2. ~~Push `dev` and take it through the review gate to `main`~~ — **PR #27
   merged 2026-09-06** after the review gate above; CI green in 2m04s. `main`
   is current with `dev` for the first time since PR #26 (2026-08-23).
3. **Data threads, Pete's call**: One Nation how-to-vote cards (the ONP drift is
   a published pre-election decision this repo does not hold), and seat-level
   polling.

## Known gap

`output/` is gitignored, so `output/mp-slope-by-target.csv` and
`-by-class.csv` are NOT in the repo. A fresh clone must run
`scripts/fit_mp_slope.R` before `AUSPOL_MP_SLOPE=1` will work, and
`fit_seats_full.R` now needs `-by-class.csv` to run at all unless
`AUSPOL_MP_SLOPE=0`. Both error rather than falling back, deliberately — a
silent fallback to a constant is how the leaked value survived.

## ACTIVE PLAN: candidate-level seat model

[plans/plan-candidate-level-model.md](plans/plan-candidate-level-model.md) —
opened 2026-08-27, and it is the working checklist. The seat model is party-class
based, so "IND" is a residual bucket and a returning independent is
indistinguishable from a stranger. Measured across 17 election pairs, that one
fact moves a 30% seat to 30.3% or to 12.1%.

**Section A is CLOSED** (both tickets resolved 2026-08-27: A1 shipped as
level-dependent variance at `1.10,8.67`; A2 refused, so A3 never runs) **and
class-specific variance is CLOSED too, refused twice** — real effect,
negative in all 20 harness×arm cells, but small relative to its own noise
and gets WORSE at higher multipliers (not an undiscovered sweet spot past
the edge). Not worth its own parameter. Full write-up, both pre-registrations
and both review files:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).


Updated 2026-08-28. Remote: github.com/peteowen1/auspol (private, default
branch `dev`; `main` exists and is reached only through a reviewed PR).

Completed stage write-ups live in
[backlog/journal-2026-08.md](backlog/journal-2026-08.md) — this file holds
open state, not the narrative of how it got here.

**Hub-slimming passes: 2026-09-04 and 2026-09-06.** Sections older than about
two weeks roll into `backlog/journal-*.md` verbatim; live items get pulled
forward, never cut by line range (`hub-slimming` skill).

## DONE 2026-09-04: the seat simulator's hot loop, profiled 2026-09-03 (moved out)

**Shipped.** 36-38% faster in fresh-process wall clock (204→132 us per
seat-sim at n_sims=500). The string-keyed environment lookup in the
elimination-round loop is now a preallocated integer-indexed list.
Byte-identical output proven, not assumed (`output/seat-probs-vic-2026.csv`
etc. match before/after, same seed). Full write-up, the Rprof table, the
K=17 RNG-non-comparability dead end, and the no-O(n²) scaling table:
[backlog/journal-2026-09-04-to-07.md](backlog/journal-2026-09-04-to-07.md).

## Google Trends and the 2026-08-28 session — moved out

Both moved verbatim to
[backlog/journal-2026-08-26-and-28.md](backlog/journal-2026-08-26-and-28.md)
on 2026-09-06; every open item in them was closed by 2026-09-04 and the
Trends finding ships as arm CS. One line stays live:

**Hard date:** Victorian nominations close 12 noon 9 November 2026. The
salience signal is candidate-level so it cannot run before then;
`scripts/victoria_salience_dryrun.R` tests everything downstream against
Victoria 2022 — two lines change on the day.

## Closed items archived

Three closed 2026-08-25/26 items (data-registry lessons, that session's
resolved list, and the ONP seat-type asymmetry — whose own stale "next step"
was corrected before archiving: the follow-up test was run the same day and
REFUSED, reversing Pete's directional hypothesis) moved to
[backlog/journal-2026-08-25-to-26.md](backlog/journal-2026-08-25-to-26.md)
on 2026-09-09.

## Awaiting Pete

- ~~PRs #5–#12 merged, reviewed~~ / ~~VEC data licensing~~ — both **resolved**;
  see git history and `external/elections/` (gitignored, refetched behind a
  cache) if the detail is ever needed again.
- **Decide whether the repo goes public.** Private on purpose. Two things are
  outward-facing and should be deliberate: `docs/plans/product-features.md`
  carries critical commentary on named competitors (theswingison, DemosAU —
  the latter also a pollster in our own data), and the scorecard publishes
  named firms' house effects and accuracy. Both defensible; neither should
  appear publicly by accident.
- **Poll data licensing.** The anchor's data is gitignored and not committed —
  verified: no `external/`, no CSVs, no outputs are tracked — so nothing of
  his is republished. His repo has no LICENCE and his site invites use of the
  files, but formal permission is worth having before going public.
- **Answer the four improvement-quiz questions** (context in
  [ANCHOR-MODEL.md](ANCHOR-MODEL.md), "Honest assessment"): demographics in the
  seat model, seat-level preference flows, the 2019 herding problem, and the
  trend-versus-simulator scope call. Two of the four now have measured answers
  — see the seat-type and methodology reviews below — so this is smaller than
  it was.
- ~~South Australia's allocation slope survives~~ — **resolved 2026-08-18**,
  both pre-registered checks passed. Trust the One Nation total, not any
  individual seat (0.122 MAE better than uniform).
  [reviews/onp-allocation-checks-2026-08-18.md](reviews/onp-allocation-checks-2026-08-18.md).
- **Find a signal for a first-time regional independent breakout** (Priestly
  in Nicholls, 23.5%, our worst-scoring miss). Search-interest salience is
  confirmed strong for teal-type candidates but does not move Priestly, Boele
  or Heise at either national or state geography — see below. News-article
  mention counts (GDELT) were the other candidate mechanism raised earlier
  this session and are untried.
- **Carried forward from the archived 2026-08-19/22 sessions, 2026-09-04.**
  Three items with a genuine open question in them, pulled out before the
  narrative around them was archived to
  [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md):
  - **Centre Alliance / Nick Xenophon Team / SA-BEST classify as `OTH`**, so
    Mayo's winner reads "OTH" in 2016/2019/2022/2025. Deliberately left
    unchanged — the alternative is `IND` (Sharkie functions as a community
    independent) and this is a modelling call, not a bug, that should be
    Pete's rather than a default nobody chose.
  - **WA's flow-matrix fault may be in the matrix, not the state**: it is
    keyed on party class and survivor SET, and a contest whose survivors are
    two LNP candidates should occupy its own cell rather than contaminating
    others. Predicted in advance, not run: conditioning on the survivor
    **multiset** should improve the forecast with WA excluded entirely — the
    one form of this test nothing so far can confound. Needs its own plan.
  - **The candidate model still cannot elect a new independent** (federal
    calibration slope 0.260) after the endogenous fixes were tried and
    refused. The next attempt is exogenous — a named list of confirmed
    independents, seat polls, or market odds — and odds specifically need
    Pete's call, since that is a different kind of input to the model than
    anything used so far.

## Sessions of 2026-08-19 to 2026-08-23 — moved out

Two journals hold the verbatim write-ups, conclusions all in `reviews/`,
`CONSTANTS.md` and the code:
[backlog/journal-2026-08-22-to-23.md](backlog/journal-2026-08-22-to-23.md) (AE
Forecasts benchmark, seat TCP, nomination zeroing of `IND`) and
[backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md)
(WA fetched, over-confidence fixed, One Nation seat allocation).

Still-live items pulled out of the moved block rather than duplicated:

- **After nominations close (12 noon, Monday 9 November 2026)**: probe VEC for
  the 2026 nomination list (the URL does not exist yet; reuse the HTML-table
  parser from `fetch_preferences_vic.R`), and revisit **candidate-count
  weighting** — the seat's previous count predicts the next one worse than
  assuming one candidate, so the remedy is worth nothing until the count is a
  fact (`reviews/candidate-count-weighting-blocked-2026-08-22.md`).
- **Victoria 2022 seat TCP ground truth is cached but unparsed**:
  `external/elections/cache/vec-2022-vic/*-results.html`, 87 files, two table
  shapes to branch on. Federal TCP truth already exists
  (`external/elections/aec-fed-tcp.csv`). Needed before our seat TCP can be
  scored against AE Forecasts' 3.69pp MAE.
- Two items from 2026-08-22/23 are **stale, not live**: the unattributed change
  to `output/seat-probs-vic-2026.csv` (the file has been regenerated many times
  since) and the overwritten `output/independent-federal-scores.csv` (output is
  gitignored; regenerate if the historical v4 scores are ever wanted).

## Done

Full write-ups moved to [docs/backlog/journal-2026-08.md](backlog/journal-2026-08.md) on 2026-08-15 — 11.5k characters of completed-stage narrative that every session in this repo was re-reading on every turn. Index of what is in there:

- 2026-08-15 (stage 8): Regional swing structure in the seat model
- 2026-08-15 (stage 7): Seat model — the pipeline is end to end
- 2026-08-15 (stage 6): Fundamentals + projection — it is a forecast now
- 2026-08-14 (session 2, stage 5): Parties folded into "Others" corrected
- 2026-08-14 (session 2, stage 4): Per-cycle volatility — the model now reproduces One Nation leading
- 2026-08-14 (session 2, stage 3): Logit-scale modelling — adopted per party, not globally
- 2026-08-14 (session 2): Hyperparameters estimated, not fixed
- 2026-08-14: Anchor model analysed; package skeleton; Jackman trend; federal and NSW cycles fitted


### Diagnosed 2026-09-08, not implemented: point-estimate shrinkage cannot fix the majors' floor seats

James-Stein shrinkage on the ratio-path cliff gives a real but tiny gain
(MAE 3.677 vs 3.710) and doesn't come from the majors - too few
observations per leave-one-out fold for any point-estimate trick to help.
**The next thing to try is widening the SIMULATED VARIANCE for these cells,
not moving the point estimate** - `sd_override` plumbing is the right tool
but needs threading into the WA harness (missing entirely) and a combination
rule with the salience sd source. Not started; needs its own
pre-registration. Full detail: `docs/backlog/journal-2026-09-08-to-16.md`.

### Diagnosed 2026-09-08: the personal-vote transfer helps Pilbara and hurts WA overall

Decoupled the WA harness's conditional-slope and personal-vote-transfer
gates (`AUSPOL_WA_TRANSFER`, byte-identical default). Pooled WA log loss:
transfer OFF beats transfer ON by ~0.005 regardless of slope mode - but it
rescues Pilbara 2001's independent from a 0-probability floor clamp (13.8
of log loss on that one seat). Net negative because it makes OTHER seats
worse broadly enough to swamp the rescue. Not shipped, one seed only - needs
seed-averaging and a check of which other seats `personal_prior_vote()`
fires on before acting. Full detail: `docs/backlog/journal-2026-09-08-to-16.md`.
