# auspol — work queue

## 2026-09-16, continued: items 1-3 of the 5-item list resolved

Working the list Pete approved ("work your way through these - i trust your
triage"). Item 4 (per-seat `seat_sd`, by-election fetch generalisation)
explicitly needs Pete's design input, not solo work -- still open, see the
NSW variance-fault entry above. Item 5 is this hub trim.

**Item 1 -- major-party same/new conditional slopes: sized, built, tested,
NOT shipped.** `fit_major_conditional_slopes()` (leave-target-out, mirrors
the existing minor-party fitter): ALP same~0.92 new~0.90-0.92 (barely
differs), LNP same~0.91-0.92 new~0.826-0.831 (real ~9% relative reduction).
Wired into `backtest_candidate_nsw.R` behind `AUSPOL_MAJOR_SLOPES` (default
off). Tested base_pred layer (NSW, n=20000): Parramatta improved modestly
(LNP error -1.25, ALP error -1.06) but pooled ALP+LNP across NSW got
marginally WORSE (MAE +0.066). Not shipped, not ported to the other five
harnesses given NSW alone already misses do-no-harm.

**Item 2 -- AEF's own TCP prediction, parsed and shipped to the ledger.**
`scripts/build_aef_tcp.R` parses `seatTcpScenarios`/`seatTcpBands` out of
our own cached AEF summary JSON (previously unparsed). All 660 AEF-7 rows
matched. Published to the ledger artifact (v17) as a new "AEF final two"
column. Confirms the NSW pattern from a second angle: AEF's own simulation
correctly favoured ALP at Parramatta (52.6% TCP) while ours favoured LNP.

**Item 3 -- found and fixed a real bug while looking for the narrower
minor-defector fix.** `personal_prior_vote()`'s `transfer` column (how much
`remove_transferred_votes()` removes from the OLD class's seat base) was
falling back to the DISCOUNTED `own_prev_pcv` instead of the true full
amount -- under-removing from the old class and inflating its statewide
average at every OTHER seat it contests. Fixed (zero effect on the
currently published model, since `AUSPOL_MINOR_DEFECT` defaults off).
Re-tested Mirani with the fix: closer to correct than the bug, but
discounting Mirani specifically still moves it further from actual than no
discount at all at the base_pred layer -- the corpus-wide 49% retention may
just not fit this one seat. Full detail on all three:
`docs/reviews/base-pred-blind-to-tonights-fixes-2026-09-16.md`.

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

**NEXT: audit other 0-filled features for the same NA-fill fix**
(`seat_prev_pcv` at minimum uses the same `ifelse(is.na(x), 0, x)`
convention) — cheap, and could be a broader win than this one feature.

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

## OPEN, 2026-09-14: the model registry cannot see a harness that FORCES a switch

`scripts/backtest_candidate_fed.R:78-79` and `_nsw.R:41-42` set
`AUSPOL_SALIENCE_EXPECTED=1` and `AUSPOL_SALIENCE_EXP_SD=1` whenever they are
unset. `published_flags.R` ships both as **`0`**.

So federal and NSW backtest numbers describe a configuration that is not what
ships, and any pooled figure across the six harnesses silently mixes two
configurations. `published_flags.R`'s own promise — "a harness run with no
environment measures what ships" — is false for two of the six.

It was deliberate (`01c8e1c`, "Ship arm C (salience point estimate + variance),
scoped to federal and NSW"), so the code is not the bug. **The bug is that two
authoritative documents say otherwise and neither records the scoping**:

- `published_flags.R` lists both at `0` with no mention of the exception.
- `docs/MODEL-REGISTRY.md:103` states the arm is undecided "so the switch is
  off everywhere". It is on in two harnesses.

**The registry cannot catch this by construction.** It records whether a
harness *reads* a switch, so a harness that reads it and then forces a
non-shipped value scores a clean "yes". Reachability is not the same question
as value, and the registry only asks the first — which is why the thing built
to stop what-runs drifting from what-ships missed a five-day drift.

**Fix**: teach `scripts/build_model_registry.R` to detect a `Sys.setenv(AUSPOL_*)`
or `if (!nzchar(Sys.getenv(...))) Sys.setenv(...)` in a harness and report the
forced VALUE beside the honoured/not-honoured cell. Then reconcile
`published_flags.R` so the fed/NSW scoping is written down where the default
is. Do not "fix" the harnesses to match the flags file without checking
whether arm C is meant to be live there — the commit says it is.

**Known consequence, not yet sized**: every federal and NSW backtest number
since 2026-09-09 was measured with arm C on. Any comparison that pooled them
with vic/sa/wa/qld results compared two configurations.


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

## OVERNIGHT CONTINUATION, 2026-09-14 early morning — READ THIS FIRST

Pete went to sleep mid-session; this continued autonomously per
`~/.claude/CLAUDE.md`'s Autonomous Sessions rule. Nothing committed, nothing
destructive. Full writeup: `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`.

**The headline result**: traced sa2026's worst miss (One Nation) all the way
through the pipeline via SHAP, four separate seats/parties in a row, to the
same place — `base_pred` (the pre-xgboost seat-level forecast) dominates every
prediction (~89% of tree gain) and nothing downstream of it (census
demographics, retiring-MP tenure, a party-group-split model) can compete.
Traced ONP's `base_pred` formula by hand for Narungga and found the actual
bug: `dev_slope()`'s rank-preserving deviation model cannot express a seat
going from modestly-above-average to the state's strongest seat, which is
exactly what happened. **Found an existing, already-built fix
(`AUSPOL_ONP_CONC_SD`) sitting unused for sa2026** — tested it, confirmed a
real 18% log-loss improvement on the raw model, then verified it survives a
full retrain into the actually-shipped xgboost configuration (0.4339 -> 0.3577
seat log loss, 39/47 -> 41/47 seats called correctly). **UPDATE, full
six-harness sweep now done**: NSW/QLD/WA/FED all unaffected (noise-level),
but **VIC2022 is a real regression** (72/78 -> 69/78 seats, log loss +6.3%),
traced to the retrained model over-predicting IND broadly across VIC2022 --
the same "vic2022 IND/OTH_RIGHT degeneracy" pattern already named in
`fit_xgb_primary_v6.R`'s own diagnostics, now shown to interact with this fix.
**NOT a clean win — a real trade. Not ready to ship.** Full detail and
recommended next steps: `docs/reviews/sa2026-onp-base-pred-diagnosis-2026-09-14.md`.

**Renamed the confusing xgboost column names** (`level_now`->`level_pred`,
`pred_share`->`base_pred`, `x`->`seat_prev_pcv`) per Pete's request — verified
byte-identical behaviour before/after. Also fixed a real bug in
`fit_xgb_primary_v7.R`: a hardcoded arm-name list silently reported any new
arm as "did not run" even after it trained successfully.

**Not yet done, in priority order**:
1. Understand and fix the VIC2022/IND coupling before this can ship at all —
   see the review doc's Recommendation section for candidate approaches
   (regularisation, region-scoped IND feature, re-run the vic2022 IND SHAP
   breakdown against the retrained model).
2. MacKillop's federal/state boundary mismatch — its federal ONP vote ranks
   it 15th of 47 SA seats but its actual result is 2nd-highest; no CV setting
   fixes this, worth checking the actual boundary maps.
3. Once 1 and 2 are resolved, decide whether to default
   `AUSPOL_ONP_CONC_SD=9.18` in `published_flags.R`.
4. Review and commit: the rename (this session), the `ran`-list bug fix, and
   the still-uncommitted items from the evening before (NSW exhaust wiring,
   `build_level_components.R`, `build_retiring_mp_cases.R`).

## CURRENT STATE, 2026-09-13 evening session — START HERE

**Two real fixes shipped and composed correctly** (commits `75a5076`,
`8db4305`, `cea78e2`, `a8af56b`, `f3c4b3e`, `75462ea`): the Frome->Ngadjuri
seat-rename bug; the notional (redistribution-adjusted) prior for federal
seats, on by default now regardless of aggregate effect (Pete's call — "the
right thing to do... do the Antony Green ABC method"); and `ret_exp` (the
IND retention feature), confirmed real at two seeds before shipping. A bug
from composing the two carelessly (x_notional_adj leaked into ret_exp's
model as a jurisdiction label, tanking sa2026 to 0.5061) was caught and
fixed same session. **Current state: pooled log loss 0.2914 over 23 pairs
(was 0.2984); on the 7 AEF-comparable elections, ours 0.2743 vs AEF's 0.2851
(was −0.0049, now −0.0108).**

**Next queued: Pattern A from the worst-seats review below.** Full
five-pattern analysis of the current worst-15-vs-AEF table:
[reviews/worst-seats-five-patterns-2026-09-13.md](reviews/worst-seats-five-patterns-2026-09-13.md).
Pattern A — a SENIOR retiring MP (minister/leader) loses more personal vote
than the flat retirement discount assumes — explains 5 of 15 seats (Monaro/
Barilaro, Braddon/Pearce, Riverstone/Conolly, Richmond/Wynne, Parramatta/
Lee) and is the cheapest lever: a static, hand-curated feature, no new data
fetch, extends `fit_defector_discount()`/the MP-slope tier directly. **Size
it (case count, effect size) before building.** Other four patterns
(SA One Nation surge broader than known; a defecting incumbent fragmenting
the right three ways; a departed independent's vote reverting rightward,
untested direction for `ret_exp`; QLD optional-preferential flows against
the primary leader) are recorded in the review doc, not yet actioned.

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

## SESSION 2026-09-07: New South Wales 2019 scored, and four findings

Coverage reached 22 pairs / 2,050 seat-elections, pooled seat log loss 0.3454
(nsw2019, vic2014, qld2020 added; qld2020 second-pair took Queensland to
0.3294). Full write-up: `docs/reviews/nsw2019-and-seat-turnover-2026-09-07.md`.
`scripts/pool_backtests.R` (new that session) still produces the pooled table
on demand.

**Salience** — largely superseded 2026-09-10 (vic2026 corpus now built by
`scripts/build_vic2026_salience_corpus.R`). Still-live: Google Trends is
measured rural-blind ([reviews/salience-rural-blind-spot-2026-09-07.md]
(reviews/salience-rural-blind-spot-2026-09-07.md)); `wa1996`/`wa2001` predate
Trends and can never be fetched; three salience arms remain built,
Victoria-only, undecided (`docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`).

**OPEN QUESTION, parked**: is one party class one party? `classify_party()`'s
seven classes bucket Liberal/National/LNP together and Katter/Shooters/Family
First together, and pool state vs. federal Labor without having asked. Major-
party coding itself was checked 2026-09-07 and is sound — this is a
granularity question, not a correctness one.

**Housekeeping**: WA slope/transfer decomposition DONE (commit `6958430`), do
not re-open. Harness-unification plan not started, hard stop 30 September.

**THE RE-ENTRY PRIOR (arm D) — decision ready, still unshipped.**
`AUSPOL_REENTRY` stays 0. Seed-averaged at 20,000 sims, verdict genuinely
mixed: better on WA/SA/Federal 2007-2016, flat on VIC/Federal 2019-2025,
worse on NSW/Queensland (1-4 seats, traced to specific by-election seats, not
a jurisdictional weakness). Arm H (variance widening) was run and REFUSED by
its own pre-registered rule — stays 0. `protect_personal_vote_cells()` is
implemented and wired into all six harnesses but dormant (only fires when arm
D is on). Full evidence moved to
[backlog/journal-2026-09-07-to-08-reentry.md](backlog/journal-2026-09-07-to-08-reentry.md).

### Open, in the order I would do them

0. **PARKED IDEA, not scheduled: correlated seat draws and demographics.**
   `docs/plans/plan-correlated-seat-draws.md` (agent-written 2026-09-07).
   Read its headline before spending anything on this: between-seat
   correlation CANNOT move per-seat win probabilities, because no expression
   inside a seat reads another seat's state, so a variance-preserving
   correlation leaves every marginal unchanged and log loss is a mean over
   marginals. What it would change is the JOINT distribution -- the seat-count
   histogram and the majority probability, which are genuinely too narrow and
   which no harness scores. The version that could move a marginal is a
   cluster VARIANCE component, not a correlation.
   Two facts to keep: Dubbo had a 2015 minor-right share of 2.54% against
   Barwon 2.50%, Murray 1.40% and Orange 2.59%, so any similarity structure
   lowers Dubbo and the criterion must accept that in advance; and census
   coverage is NSW/VIC/SA only, 6 of 22 pairs and 23% of seat-elections, on
   one 2021 vintage against elections from 2010 to 2026.

1. ~~Seats that changed hands between elections are nearly invisible~~ —
   **WORKED THROUGH 2026-09-16.** `is_incumbent_party` classification bug
   found and fixed (small real gain) —
   `docs/reviews/incumbent-classification-bug-2026-09-16.md`. Orange/Wagga
   Wagga themselves still wrong by 30-50 points — `own_prev_pcv` is `NA` for
   both (by-election winners have no general-election match); a fallback fix
   was built, measured, and made things worse elsewhere, reverted —
   `docs/reviews/nsw-departed-member-opv-ruled-out-2026-09-16.md`. Needs a
   dedicated feature, not a fallback fill — open.
2. **The statewide covariance is settled for now.** Leakage closed
   (leave-one-out, effect nil), widened to 15 of the 21 pairs, and Western
   Australia deliberately excluded because cor(ALP, IND) flips sign on it.
   Both changes measured as ties. What is NOT settled is era: all pairs are
   pooled regardless of date and the party structure of 2001 is not that of
   2025. `docs/reviews/statewide-cov-loo-2026-09-07.md`.
3. **Western Australia has no surge-v2 hazard at all.** The other five harnesses
   do. A published switch a harness cannot honour is the failure recorded in
   `CLAUDE.md` for the missing SA `shrink`, and its numbers describe a different
   model from the rest of the table. **See `docs/MODEL-REGISTRY.md`** (new
   2026-09-09, generated by `scripts/build_model_registry.R` — rerun it, never
   hand-edit) for the full switch-by-switch parity table across all six
   harnesses and the published forecast: this is item 1 of 2 open gaps it
   records (the other is WA's screened slope mode only half-implementing what
   "screened" means elsewhere). Two more gaps it found and this session fixed:
   WA's seed was a hardcoded literal ignoring `AUSPOL_SEED`, and
   `AUSPOL_SEAT_SD_MULT`/`AUSPOL_FALLBACK_SMOOTH`/`AUSPOL_FLOW_SD` never
   reached `fit_seats_full.R` (the actual published forecast) at all.
4. **~~Two elections still unfound~~ — STALE, corrected 2026-09-11.** sa2018
   was fetched, verified against the anchor and wired in as a prior-only pair
   (`AUSPOL_SA_PAIR="2022"`) — see "Data coverage" at the top of this file.
   Only **fed2004** remains, and only as a scored TARGET rather than a prior;
   it already serves as a prior today. The Queensland recipe applies: the
   commission's old results site published a package per election and the
   archive kept it, which is what made qld2017 available after it had been
   written off. Parsers are the remaining work; the sources were located.

   *Left visible rather than deleted because this is the failure CLAUDE.md
   names — "we don't have X" gets written into a plan and then reasoned from.
   It had been stale for a day.*

### Closed this session

- Queensland's surge training list had `sa2026` replaced by `qld2024` in the
  copy that created the harness, so it trained without the four One Nation
  winners. Fixed; effect is **neutral** (log loss 0.3350 either way).
- Adding nsw2019 to the leave-one-out slope panel moved the fitted `also_ran`
  slopes by up to 0.092 and changed no harness output at all, because only
  `member` is consumed and nsw2019 contributes no returning members. `also_ran`
  is read by nothing outside its own fitting script.


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

- **PRs #5–#12 merged** (2026-08-17/18). Every one reviewed before opening,
  and every review caught something the tests could not: stale published
  figures, roxygen under the wrong argument, a correction pass that missed its
  own targets, a crash on a party absent from a seat, and a CI cache that could
  have switched the seat model off behind a green build. **Do not skip the
  gate, least of all on docs-only diffs.**
- ~~VEC data licensing~~ — **resolved 2026-08-18.** The fetched results live in
  `external/elections/`, gitignored beside the anchor clone, and nothing of
  either commission's is committed (verified: git reports the directory
  ignored and tracks none of it). The daily job refetches behind a cache. No
  decision needed; the question only existed while the data had no home.
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
- ~~Decide whether to transfer South Australia's allocation slope~~ —
  **resolved 2026-08-18, it survives.** Both pre-registered checks pass: the
  Greens-share ordering replicates with a negative coefficient in NSW,
  Queensland and WA, and the magnitude transfer sits at 1.41x against a 1.5
  bar. It beats a uniform allocation by only 0.122 MAE, so trust the One
  Nation **total** rather than any individual One Nation seat. See
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

- [backlog/journal-2026-08-22-to-23.md](backlog/journal-2026-08-22-to-23.md)
  (moved 2026-09-06): the AE Forecasts benchmark and the measurement gap it
  found in our harnesses, forecast mode refused, calibration knobs refused,
  gate 1 / refusal M2 / bucket narrowing / candidate-count weighting, the four
  independent refusals re-read and re-measured, the salience signal confirmed,
  seat TCP retained (shipped in `R/seat_sim.R`), nomination zeroing of `IND`
  (shipped in every harness).
- [backlog/journal-2026-08-19-to-23.md](backlog/journal-2026-08-19-to-23.md)
  (moved 2026-09-04): the Victoria 2026 target snapshot as of 2026-08-23 and the
  session write-ups from 2026-08-19 (WA fetched, over-confidence fixed, the
  Others-bias diagnosis, NL3, One Nation seat allocation) through 2026-08-22.

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
