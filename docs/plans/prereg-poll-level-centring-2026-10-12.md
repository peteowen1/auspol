# Pre-registration: where the day-before statewide level is centred (poll weighting, step 1)

Written 2026-10-12, before any arm is built. Pete chose "trend first" for the unified poll-weighting work
(2026-10-12). Evidence and inventory: `docs/reviews/poll-weighting-inventory-2026-10-12.md`.

## The question

The day-before level for ALP, LNP and GRN is the poll trend (`trend_as_at()`) blended toward recent polls
(`AUSPOL_LEVEL_RECENT=decay`, 20-day half-life). The blend constant k fits to its grid floor, so the
shipped level is about 100% the recent-poll average and the trend contributes almost nothing.

Diagnosis (`scripts/diag_trend_lag.R`, 36 cells): about half the trend's lag is how house effects are
centred. A poll-count-weighted sum-to-zero lets the most prolific firm define truth (Victoria 2022: Morgan's
13 of 31 polls).

Does a better-centred level predict the result better than what ships?

## Arms, one at a time, each against the shipped incumbent

Incumbent: shipped configuration (trend + 20-day decay blend, k fitted time-forward). Incumbent wins ties.

- **A. Firm-equal centring.** The soft sum-to-zero on house effects weights each firm once, not each poll.
  Then the blend k is refitted time-forward, as shipped.
- **B. Record centring.** Each firm's house-effect prior mean is its own past bias against RESULTS. That is
  the poll minus result at elections strictly before the cycle starts, shrunk toward 0 by pseudo-polls (as
  `firm_record_factors()` shrinks noise). The sum-to-zero weight is then judged on its own: kept at the
  shipped strength. Built only if A ran, whatever A's verdict.
- **C. Shared-miss correction.** Add a shrunk, time-forward mean of (result minus final poll average) by
  class, and by jurisdiction level (federal or state). Expectation: near zero, because the misses change
  direction (federal Labor over-stated 2019 and 2022, under-stated 2025).

Expectation, stated now: A small gain; B small or none (the noise version of the record refused on
2026-10-09); C none.

## Criterion and rule, fixed now

**Screen (primary):** day-before level RMSE against the actual statewide share.
- Scope: every scored pair's ALP, LNP and GRN cells. All 22 pairs, about 66 cells; wa2021 is skipped as
  in the rebuild.
- Everything time-forward.
- Paired difference to the incumbent, with the SE clustered on election (22 clusters).
- An arm passes the screen if RMSE improves by more than 1 clustered SE.

**Size check before running** (from the diagnosis):
- Raw-mean against trend differed by 0.17 RMSE.
- Re-centring against trend differed by 0.10.
- I will print the clustered SE of the incumbent-vs-raw difference first. If that SE exceeds 0.10, the
  screen cannot see arm A's expected effect. In that case I report the MDE to Pete before running any arm,
  rather than run a test that can only refuse.

**Ship (deciding):** an arm that passes the screen runs the full all-22 deciding run at 20,000 sims
(`scripts/deciding_run.ps1`). It ships if pooled seat log loss is no worse than +1 SE. Seat log loss is the
probability given to the winner, clustered on election; lower is better.

**Do-no-harm guards (any failure refuses):**
- ON and other classes' levels unchanged (the arms touch ALP, LNP and GRN only). Print the max absolute
  change.
- No single election supplies more than half of the RMSE gain. If one does, report it to Pete as a
  clause refusal and do not ship.
- `B2`/`B3` interval coverage in `scripts/fit_projection.R` still passes.

## Dry run, before committing (cases whose answer is known)

- **Victoria 2022 LNP:** trend 32.2, late firms 33.8, actual 34.4. Arm A must move it up. If arm A
  leaves it below 33, A is not doing what it claims; stop and check the code.
- **Federal 2019 LNP:** polls 38.3, actual 42.0. A and B must NOT fix it. A big gain here from A or B
  means leakage. Only C could move it, and only from 2016's miss.
- **SA 2026 ALP:** trend 39.5, raw 37.6, actual 37.6. This case favours the raw mean; arm A moved it 0.1
  in the diagnosis. Nothing should make it worse than 39.5.

## Leakage rules

- Firm bias (arm B) and shared misses (arm C) come from elections whose polling day is strictly before the
  target cycle's start, with an assertion. A deliberately leaked bias must fail that assertion in a test.
- The blend k refits time-forward under each arm, never shared across arms.
- vic2026 and nsw2027 are never scored.

## What would make a win unacceptable

- An arm whose level gain comes from moving GRN or minor classes against their polls.
- A gain at one horizon only (the day-before) while the published trend chart moves visibly away from the
  polls earlier in the campaign. Print the 7, 28 and 90 days-before levels too.

## What is not a criterion

That firm-equal centring is "fairer". That the chart looks smoother.

## Amendments

(none yet; any change is added below this line with the original text left as is)
