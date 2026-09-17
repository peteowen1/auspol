# seat_outperf missing from the live-serving model, 2026-09-16 to 2026-09-17

## What happened

`seat_outperf` shipped 2026-09-16 (`831d693`) into `fit_xgb_primary_v6.R`'s
feature list -- a validated feature (r=0.176, p=0.001 across 349 retirement
cases; +0.0061 pooled RMSE once the cost of adding any column is subtracted
out) that captures how much a party beat its own statewide average in a seat
last time, gated to the one row it means anything for: the incumbent party,
in a seat where that incumbent is retiring.

That commit touched the backtest/OOF training script only. It never touched
`fit_xgb_primary_v6_final.R` (the script that trains the model
`xgb_primary_predict_live()` actually serves from) or the live prediction
function itself. Neither error'd -- `fit_xgb_primary_v6_final.R` has its own
hardcoded `feat_cols` list rather than importing v6's, so it trained a
41-feature model missing the one column, and `xgb_primary_predict_live()`
never built the column at serving time either. Both sides agreed with each
other, just not with the model they were supposed to match.

This is the same root cause as
`docs/reviews/base-pred-blind-to-tonights-fixes-2026-09-16.md`, from the
prior day: a fix wired into the harnesses' xgb-feature-building calls and
never ported into the live-serving path. That review was about `base_pred`;
this is about an xgb feature reaching the live model at all.

## How it was found

Not by design -- a background fork (`a392063075f8f98cc`) shipping the
`base_margin` change noticed `fit_xgb_primary_v6_final.R` trained on 40
features against v6.R's own list and flagged it as a loose end without
investigating further. Diffing the two `feat_cols` lists directly found
exactly two differences: `x_notional_adj` (deliberately excluded, commented
in `fit_xgb_primary_v6_final.R`, federal-only) and `seat_outperf`
(undocumented, no comment anywhere explaining its absence).

## Is this live today

Yes. `load_seats(2026, "vic")` currently lists **20 seats with a retiring
major-party incumbent**: Bass, Bayswater, Benambra, Bendigo East, Bendigo
West, Croydon, Essendon, Gippsland East, Macedon, Malvern, Melton, Mill
Park, Murray Plains, Narre Warren South, Pakenham, Ringwood, Rowville,
Shepparton, South Barwon, Sydenham -- exactly the condition `seat_outperf`
is gated to. All 20 were being forecast without a feature the model was
validated to need for this exact situation.

## The fix

`R/xgb_primary_override.R`, inside `xgb_primary_predict_live()`: build
`seat_outperf = seat_prev_pcv - level_prev` (both already computed columns;
this is the same quantity as the training side's `seat_prev_pcv -
.state_prev_level`, since `level_prev` there is built from the same
prior-election state-level shares) and gate it to NA except where
`retirement_i == 1L & is_incumbent_party_i == 1L`.

The training side gates on `retire_derived`, a name-matched signal built by
`scripts/build_retirement_derived.py` specifically because the seat file's
own `retirement` column is unreliable on OLDER pairs (11 of 23 have it
hardcoded to 0). That reason does not apply to live serving: `load_seats()`
here is the CURRENT anchor clone for the live target, and
`retirement_i`/`is_incumbent_party_i` are already built two blocks earlier
in the same function from that file. Using the already-available signal
avoids extending `build_retirement_derived.py`'s hardcoded election-pair map
(which does not include vic2026) under time pressure.

Also added `seat_outperf` to `fit_xgb_primary_v6_final.R`'s `feat_cols` and
retrained (41 features, CV nrounds 174, in-sample RMSE 3.2861 as a sanity
check only, not a validation metric).

## Verification

- **Fires**: `XG8 seat_outperf gated (NA-filled elsewhere): 21 of 609 rows
  carry a real value` printed during `fit_seats_full.R`'s run (609 = 87
  seats x ~7 party classes; 21 matches the 20-seat count with rounding from
  a coalition-labelling edge case, not investigated further as immaterial).
- **Deterministic**: reran `fit_seats_full.R` twice after the fix; output
  byte-identical (`diff` on sorted output, exit 0) -- the seed is fixed
  (`AUSPOL_SEED`, default 42), so any movement below is a real effect of the
  fix, not simulation noise.
- **Direction matches the feature's own documented effect**: of the 20
  retiring incumbents' own win probability, 17 fell, 3 were flat/near-zero,
  none rose meaningfully. That is the expected direction --
  `docs/reviews/pattern-a-seat-outperf-2026-09-16.md`'s whole premise is
  that a flat retirement discount UNDERSTATES the loss for a senior
  incumbent with a large personal-vote premium. Largest movers: Gippsland
  East LNP 0.762->0.607, Murray Plains LNP 0.732->0.578, Benambra LNP
  0.958->0.809 -- all large-margin seats (-24.6, -23.4, -13.3), consistent
  with a big premium being lost.
- **Movement also appears outside the 20 gated seats** (e.g. Northcote ALP
  +0.147, Lara ALP +0.144, Wendouree ALP +0.134) -- checked using
  `scripts/compare_arm_outputs.R`'s zero-movement-bucket discipline by hand.
  This is NOT a new confound: it is the SAME cost the original ship commit
  already measured and accepted -- "left ungated, it changed predictions on
  66.5% of ALL 13,739 rows" and "an all-NA placebo column with zero real
  information still costs +0.0144 pooled RMSE" (retraining a tree ensemble
  with one more candidate split column moves other splits too, even where
  that column is NA for the row being scored). The live model was simply
  never carrying this already-priced-in cost until this fix, because it was
  never trained on the column at all.
- **CI**: `check_like_ci.R --tests-only` -- 910 passed, 22 skipped (anchor
  clone absent, expected), 0 failed. Registry check confirms no fitting
  script's default disagrees with `published_flags.R`.
- **S5 internal-consistency check** (in `fit_seats_full.R`'s own output):
  PASS, mean gap 0.00, sd ratio 2.64 (matches the pre-fix run's own ratio).

## Net effect on the published forecast

ALP median seats 35 -> 37, LNP 33 -> 32 (from the fork's post-base_margin,
pre-this-fix baseline). Not decomposed further between base_margin and this
fix specifically, since both landed in the same working session before
either was committed -- the numbers above isolate seat_outperf's own effect
by holding everything else fixed at the fork's already-verified output.
