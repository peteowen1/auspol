# Pre-registration: does the flow estimator survive a clean target set?

Written 2026-08-18, **before the re-run**. Committed before any result.

## The question

`scripts/backtest_flows.R` chose "mean of last 5" over ten alternatives by
temporal backtest, and check `G3` re-confirms it every pipeline run. The audit
in [../reviews/flow-record-integrity-2026-08-18.md](../reviews/flow-record-integrity-2026-08-18.md)
found that **22 of its 118 targets (19%) are exact copies of the preceding
value in their own series** — carried-forward placeholders recorded as
observations.

A target that copies a prior input rewards persistence estimators for free and
penalises anything that moves away from the last value. The top three methods
are all persistence forms separated by 0.2 MAE. **The ranking may be an
artefact of the contamination, or may survive it. That is the question.**

## What will be run

`scripts/backtest_flows.R` unchanged in every respect except the target set,
scored three ways:

- **A — as now.** All 118 targets. The incumbent result, for reference.
- **B — clean only.** Drop every target identical to the immediately preceding
  value in its own region-party series. ~96 targets remain.
- **C — clean, and drop the duplicated INPUTS too.** A carried-forward value is
  also a bad *predictor*: averaging 81.94 twice double-weights one observation.
  B removes contaminated targets; C additionally de-duplicates the history each
  method reads.

C is the honest version of the question and the most disruptive, so it is named
in advance rather than reached for if B is inconclusive.

## Criterion

Mean absolute error across the surviving targets, same as the original.
Reported for all eleven methods in all three variants.

## Decision rule, fixed now

1. **If "mean of last 5" still wins under both B and C**, the choice stands and
   the contamination is recorded as a caveat that did not change the answer.
2. **If a different method wins under B or C**, do not adopt it on this
   evidence alone. The clean sets are smaller and the differences were already
   inside 0.5 MAE. Instead: re-register a head-to-head between the incumbent
   and the new leader, and require the challenger to beat the incumbent by
   **more than 0.15 MAE** — the same tolerance `G3` already uses so ordinary
   jitter does not cause churn.
3. **If the ranking is unstable between B and C**, report that as the finding
   and change nothing. Instability across two reasonable cleanings means the
   103-election record cannot separate these methods, which is itself worth
   knowing and is a stronger statement than either ranking.
4. **`G3`'s tolerance and adopted method are not touched** by this run under any
   outcome. Changing the check in the same pass that questions its inputs would
   remove the only thing currently detecting drift.

## Threats, stated before the run

- **The clean set is smaller**, so MAE differences are noisier. A rank change
  on 96 targets is weaker evidence than the same change on 118 would be, which
  is why rule 2 requires re-registration rather than adoption.
- **Duplicate ≠ wrong.** A genuinely stable flow can repeat to two decimals by
  coincidence. Only one of the 29 duplicates has been checked against a real
  count (Victorian 2022 Greens: recorded 81.94, measured 79.2). Dropping all of
  them may discard real observations along with placeholders. **This is the
  main way variant B could mislead**, and it cuts toward the incumbent, since
  discarding true persistence cases penalises persistence methods.
- **De-duplicating inputs in C changes what "last 5" means**, so C is not
  strictly the same estimator family. Named as a separate variant for that
  reason rather than folded into B.
- The measured Victorian 79.2 is **not** substituted into the record for this
  run. Correcting the record is a separate decision from choosing the
  estimator, and doing both at once would leave neither attributable.
