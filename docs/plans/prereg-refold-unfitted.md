# Pre-registration: fold an unfitted party back into "Others"

Written 2026-08-19, **before** anything is built or run. Committed before
running.

## The defect

When a party is polled but not fitted — it fell under the inclusion floor —
`OTH` ends up meaning two different things within the same cycle:

- firms that **break the party out** report `OTH` *excluding* it;
- firms that **fold it in** report `OTH` *including* it.

The model fits `OTH` on that single column and cannot see the difference. It
absorbs some of it as a house effect, which is wrong: a definitional gap is not
a firm leaning.

Measured on NSW 2023 (2026-08-19), where One Nation has 7 polls against a floor
of 8 and so is not fitted:

- Morgan breaks One Nation out in all 7 of its polls (mean **5.07**); every
  other firm folds it in.
- Fitted Morgan house effect on `OTH`: **−0.28 points**, not the ~5 points
  actually at stake.
- Fitted `OTH` endpoint **15.30** against an actual of **17.96**.

`unfold_others()` already handles the opposite case — a party that IS fitted and
folded away — by imputing its share out of `OTH`. It cannot help here, because
imputing requires a fitted trend.

## Why not just fit the party

Tested and rejected:
[../reviews/inclusion-floor-2026-08-19.md](../reviews/inclusion-floor-2026-08-19.md).
Lowering the floor is monotonically worse — floor 7, the one that would fit One
Nation in NSW 2023, is **+0.023** total FP MAE and **+0.098** on `OTH`.

## What is proposed

The mirror of `unfold_others()`: for a party that is **not fitted**, ADD its
reported share back into `OTH` on the rows that break it out, so `OTH` means
"every minor party" for every firm in the cycle.

Identified arithmetically, exactly as `folded_rows()` does it in the other
direction: a row that reports the party separately AND whose first preferences
already sum to ~100 **with** it must have an `OTH` that excludes it. A row that
sums to ~100 *without* the party is already folded and is left alone.

This is the direction the recorded results point. NSW 2023's actuals carry no
separate One Nation line — the target is `OTH` at 17.96, meaning everything
minor together.

## Criterion, fixed now

**Total first-preference MAE against the eventual result**, over the same
33-cycle complete-actuals set used by
`scripts/calibrate_poll_tracking.R` and the inclusion-floor experiment, across
all fitted parties.

Two arms only: **off** (today) and **on**. No grid, because there is no
parameter to tune — the rows are identified arithmetically and `sum_range`
inherits `folded_rows()`'s existing `c(97, 103)` rather than being chosen here.

Reported alongside, not decided on: `OTH` MAE; how many rows are refolded in
each cycle; and the fitted house effect for the affected firms before and after.

## Decision rule, fixed now

- **Adopt on a gain over 0.02 MAE**, the bar every other constant here has been
  held to.
- **A gain on `OTH` while total MAE worsens is a REJECT**, not a partial win.
  Moving vote into `OTH` mechanically changes what `OTH` has left to get wrong,
  so `OTH` improving on its own is the expected shape of an artefact rather than
  evidence.
- **If it changes nothing** — fewer than 5 rows refolded across the whole
  record — report that and do not adopt. A correction that almost never fires
  is not worth the code that can go wrong.
- **If it makes things worse**, say so and stop. The defect is real either way,
  and the write-up should end by saying the defect is unfixed rather than
  quietly dropping it.

## Threats, stated before the run

- **The comparison is not paired the way the floor experiment needed.** Both
  arms fit the same parties on the same cycles; only the `OTH` column's values
  change. So n is equal by construction — but verify that rather than assuming
  it, since assuming it is exactly what went wrong last time.
- **`OTH` is both an input and a target here.** Refolding changes the fitted
  `OTH` and leaves the actual `OTH` alone, which is the point, but it means the
  improvement should show up mostly in `OTH` — while the decision rule above
  refuses to accept `OTH`-only evidence. If the total does not move, the honest
  reading is "too small to matter", not "works but the metric can't see it".
- **A row summing to ~100 with the party present does not PROVE `OTH` excludes
  it.** It is an inference from arithmetic, the same one `folded_rows()` already
  makes in the other direction. A poll that is simply 5 points over on its
  totals would be misread. Count how many rows sit near the edges of
  `sum_range`.
- **This affects only cycles with an unfitted, broken-out party.** That is rare;
  the effect on the published Victorian forecast is expected to be **zero**,
  because One Nation is fitted there. Do not present a historical-only fix as an
  improvement to the live forecast.
