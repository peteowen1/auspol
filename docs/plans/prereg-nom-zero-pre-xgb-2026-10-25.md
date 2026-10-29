# Pre-registration: live nomination zero before the trees (`AUSPOL_NOM_ZERO_PRE_XGB`), 2026-10-25

Audit F18 (`docs/reviews/audit-f8-f19-status-2026-10-25.md`, `docs/reviews/pipeline-overwrite-audit-2026-10-18.md`).
Written before any run of the switch. Nothing below has been measured.

## The problem, checked in code

The xgb primary trees train on a base that has had the nomination zero applied. The live forecast hands them a
base that has not.

**Training.** Stage 1 of `scripts/rebuild_forecasts.sh:245` runs the six harnesses with `AUSPOL_XGB_PRIMARY=0`
and forces ten post-xgb switches off, but not `AUSPOL_NOM_ZERO` (published `"2"`). `post_xgb_switches()`
(`R/new_ind_shrink.R:40-46`) does not list it either. Each harness writes its sharedetail from the final
`shares`, after its nomination zero. `scripts/fit_xgb_primary_v6.R:313` renames that `pred_share` to
`base_pred`, the feature and the `base_margin`. So every training row's base has exact zeros where a class did
not stand, with the freed share sent by the flow matrix (mode 2).

Order of the calls in each harness (line numbers on dev at 58e6740):

| Harness | override (`xgb_primary_override`, a no-op at stage 1) | "early" zero (off at the published `late`) | "late" zero | sharedetail written |
|---|---|---|---|---|
| vic | 795 | 803 | 970 | 1110 |
| nsw | 939 | 947 | 1085 | 1341 (file write) |
| qld | 922 | 930 | 1111 | 1275 (file write) |
| sa | 1107 | 1115 | 1296 | 1432 (file write) |
| wa | 652 | 660 | 707 | 898 |
| nt | 669 | 677 | 721 | 912 |
| fed | 1526 | 1590 (`zero_unnominated()`, runs in BOTH orders) | 1870 (`NZ1b`, a second pass) | 1983 |

The harnesses agree with each other: every one zeroes after the override, so at stage 1 the zero lands on the
base and the sharedetail carries it. The one difference is federal: it zeroes unconditionally at 1590 and again
at 1870 under `late`, where the state harnesses zero once. At stage 1 the result is the same: zeros in the base.

**Live.** `scripts/fit_seats_full.R` calls `xgb_primary_predict_live()` at line 1522 (1509 before this
change), whose `base_pred` is taken from `shares` (`R/xgb_primary_override.R:260`) and used as `base_margin`
(`:664-668`). The only nomination zero is `zero_unnominated_live()` at line 1609 (1596 before), after the
port, poll blend, demographic, leader and salience steps. So once nominations are loaded, a class that is not
standing still carries its share in the base the trees see, and the standing classes' bases lack the share
that training would have sent them.

**Where the live list stands today.** `AUSPOL_NOM_LIVE` is published `"auto"` (`scripts/published_flags.R:573`);
no workflow or script sets it. `live_nominations()` returns no list under `auto`, so the live zero is a logged
no-op (`NZL ... NOT applied (provisional list ...)`). `output/candidacies.csv` in the main checkout (16 Oct)
has 500 vic2026 candidacies against 731 for vic2022 (68%, under the 85% floor `=1` enforces), every one of 88
seats with at least one row. Classes standing in vic2022 but absent from the provisional list, counted by seat:
OTH_RIGHT 71, IND 47, ALP 8, LNP 8, OTH 7, GRN 3, ONP 1. Most of those are candidates not yet announced, which
is why the gate stays shut. The VEC final list is due after nominations close; `NOM_GATE_DATE` is 2026-11-10.

## What the switch does

`AUSPOL_NOM_ZERO_PRE_XGB` (default `"0"`, published `"0"`). At `"1"`, `fit_seats_full.R` calls
`zero_unnominated_live_pre_xgb()` (`R/nomination_zero.R`) just before `xgb_primary_predict_live()`. That is
`zero_unnominated_live()` itself: the same list, the same gate, the same `zero_unnominated()` rule and the same
live flow matrix `fm`. The post-xgb zero stays as the final guard (the trees write a prediction back into every
cell, zeroed ones included), and the cells zeroed before the trees join the final-write assertion. Log codes:
`NZP1` (on or off), then the `NZL` lines (cells changed and zeroed, per class) and `NZP2` (the zeroing line)
for the pre-xgb call. With the switch on, any failure stops the run, whatever `AUSPOL_NOM_LIVE` says.

At `"0"` the run is byte-identical. At `"1"` it is also byte-identical until `AUSPOL_NOM_LIVE=1`.

## Is there a backtest analogue? No

Every harness already zeroes AFTER the override, and the override substitutes cached tree predictions whose
`base_pred` came from the zeroed stage-1 base. The backtests therefore already serve trees a zeroed base: they
are the training-consistent case, and there is no `quick_arm.R` arm that reproduces the live mismatch. The
other fix, giving training the live order (`AUSPOL_NOM_ZERO=0` added to stage 1 at `rebuild_forecasts.sh:245`),
changes every training row and needs a full isolated rebuild from stage 1; it is not proposed here.

## Evaluation: a live walk, because nothing can be scored before polling day

### Walk 1, now, on a SYNTHETIC list (mechanics only)

The provisional list is incomplete, so it cannot be used as the real list. The walk uses a synthetic one, built
in a scratch copy of `output/` (never the main checkout's):

- S = the provisional vic2026 candidacies, plus ALP, LNP and GRN rows in every one of the 88 seats (Labor will
  contest all 88; the Liberal/National and Green gaps in the provisional list are unannounced, not decisions).
- If S is under the 85% floor, pad with vic2022 OTH rows carried forward in seats where the provisional list
  has no OTH, until it clears. Record the final row count and per-class seat counts (the `NZL` class line).
- What S zeroes is then mostly OTH_RIGHT and IND where they stood in 2022 and have not been announced.

Run the published forecast twice in that scratch copy with `AUSPOL_NOM_LIVE=1`: arm A `AUSPOL_NOM_ZERO_PRE_XGB=0`,
arm B `=1`. Same seed. Diff the seat share matrix and the seat win probabilities.

Predictions, written before the run:

1. **Unaffected seats.** A seat where S zeroes nothing has the same shares in A and B to 1e-9. (If not, some
   tree feature reads other seats' base shares, and that has to be explained before anything else.)
2. **Counts.** The pre-xgb zeroed count in B (the `NZL` line under `NZP1`) equals the post-xgb `NZL` zeroed count in A, less any cell the trees
   predicted as exactly 0. B's post-xgb `NZL` line zeroes only cells the trees revived (positive tree
   predictions on a zero base), and the final-write assertion passes.
3. **Per affected seat.** The zeroed class is 0 in both arms. The share it frees goes to the same standing
   classes in both arms (by flows). The difference is the trees' response to the standing classes' higher base,
   so the SIGN for each recipient is not predicted. The SIZE is: under 1 point on every standing cell in at
   least 90% of affected seats, and under 3 points on every cell. The largest recipient in each affected seat is
   listed with its A and B values.
4. **Winners.** No seat changes its most likely winner unless its top two are within 2 points in A.

A failure of 1 or 2 is a bug and stops the walk. A failure of 3 or 4 is a finding: walk the seat with Pete
(base, freed share, flows, tree prediction, final) before going on.

### Walk 2, once the VEC final list is loaded (expected from 10 November)

The same A/B pair on the real list, from the real `output/candidacies.csv`, `AUSPOL_NOM_LIVE=1`, as part of the
November procedure in `docs/PIPELINE.md` section D. Same predictions 1-4.

### Decision rule

There is no outcome to score before 28 November, so the choice rests on consistency, not on a metric. The
trees were fitted on a zeroed base; `"1"` gives them one. So:

- **Ship `"1"`** (set it in `published_flags.R`) if Walk 2 passes predictions 1 and 2, and every cell over the
  prediction 3 size, or every winner flip under 4, has been walked with Pete and explained by the tree response
  to the redistributed base rather than by a mechanics fault.
- **Keep `"0"`** if a mechanics check fails and cannot be fixed before the forecast freezes, or if Pete, shown
  the walked seats, prefers the current order.
- Either way, after 28 November score both arms on vic2026 (seat log loss and share RMSE on the affected seats,
  primary; all seats as the do-no-harm guard). One election cannot decide it, but the result is recorded beside
  this file.

Nothing in this plan is a measured result. The size of the effect is unknown until Walk 1 runs.

## Amendment 1 (2026-10-29, before any run; nothing above edited)

1. **The padding rule cannot clear the floor.** The floor counts ROWS (`live_nominations()`, `R/nomination_zero.R`:
   `nrow(now) / nrow(prv)`), and vic2022 has 731. The provisional list has 500; adding ALP/LNP/GRN where missing
   gives 519; only 7 of 88 seats lack an OTH row, so the rule as written reaches 526 of the 622 needed. Change:
   after the 7 seats, keep carrying vic2022 OTH rows forward into seats that ALREADY have an OTH row, until the
   list clears. Zeroing keys on whether a class has any candidacy in a seat, so an extra OTH row where OTH already
   stands zeroes nothing new: what S zeroes is unchanged by this padding. Final counts go in the result.
2. **Where the list lives.** The live list is read from the fixed relative path `output/candidacies.csv`
   (`R/nomination_zero.R:218`), and a full scratch copy of `output/` is 9.4 GB. Instead of copying it, a test-only
   override `AUSPOL_NOM_LIVE_FILE` (default unset = that path, byte-identical) points the nomination reader alone at
   the synthetic file in the scratchpad. Every other input is the real `output/`, which the A/B shares. Both arms
   write with `AUSPOL_OUT_SUFFIX` and the walk files are moved out of `output/` afterwards, as the 28 Oct walk did.
