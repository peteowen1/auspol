# Pre-registration: deliver the demographic correction in full (audit F7) (2026-10-19)

Committed BEFORE anything is built or run. Overnight queue (Pete: "keep working through next steps"); finding F7 of
`reviews/pipeline-overwrite-audit-2026-10-18.md`, verified 18 Oct.

## The defect

`R/demographic_residual.R` adds each seat's fitted correction to ALP and GRN, then rescales the WHOLE row back to its
total (lines ~316 and, on the daily run's frozen-table path, ~233). The adjusted cell is scaled with everyone else, so
an ALP cell near 40 keeps about 60% of its correction (40 + a -> (40 + a) * 100 / (100 + a)). The fit targets the
raw residual, so it assumes 100% delivery. Shipped vic2026 table: mean |adj| ALP 0.47 (max 1.42), GRN 0.39 (max 2.38).

## The change (`AUSPOL_DEMO_RESID_FULL=1`)

The adjusted classes keep their adjustment in full; the classes NOT adjusted give up the difference in proportion to
their shares (the rule `.shift_cell()` in `R/leader_seat.R` already uses). A row whose other classes cannot absorb it
falls back to the old rescale, counted and printed. Both paths (fit and frozen table).

## Measurement and decision (standard rule, `PRE-REGISTRATION-RULES.md`)

quick_arm screen, 1,000 sims, all elections (the correction touches every seat), then a 20k deciding run if it passes.
Primary: ALP and GRN seat-share RMSE on all cells, better by more than 1 SE (clustered on election) -- the change is
to shares, so shares are its targets. Guard: seat log loss, every seat, not worse by more than 1 SE.
Leave-one-election-out on the primary; no election worse on the guard by more than 2 SE of its own seats.

## RESULT (2026-10-25, screen; appended, nothing above edited)

`quick_arm.R "AUSPOL_DEMO_RESID_FULL=1" --pairs=all --sims=1000 --slots=1 --no-reuse` ran 16:45-17:54 (launched with
8,017 MB available), code t879bb22. Baseline cache e45826b00f56, arm cache 10f87212e9cb. Every harness output was written
by 17:49:50, which is before the 17:50 CI-fix merge (5dd64ec). Log `deciding-runs/quickarm-20261025-f7-demo-resid-full.log`,
score `deciding-runs/quickarm-20261025-f7-score.txt` (scorer `score_f7.R`, session 26f52d2d scratchpad). 35 elections.
Cells moved by more than 0.05 points: 5,629 of 19,616, in 28 elections.

| measure (lower is better; SE clustered on election) | n | change | SE | clause |
|---|--:|--:|--:|---|
| Primary: ALP + GRN squared share error per cell (points^2) | 5,862 cells / 35 el. | -0.0653 | 0.0499 | better by >1 SE: PASS |
| (ALP + GRN RMSE, points) | | 4.2676 -> 4.2600 | | |
| Guard: seat-winner log loss, every seat (floor 5e-4) | 2,921 seats | -0.0001 | 0.0006 | PASS |
| quick_arm Q3, same guard | 2,931 seats / 35 el. | 0.3085 -> 0.3084 | 0.0006 | |
| AEF-7 subset (reported) | 681 seats / 7 el. | 0.2644 -> 0.2625 (-0.0020) | 0.0015 | |
| quick_arm Q2, all-party share squared error on changed cells (reported) | 5,629 cells | +450.5 (total) | 485.9 | |

- Leave-one-election-out: FAILS. The primary stays better by more than 1 SE in 33 of 35 drops. Dropping nsw2023
  (-0.95 SE) or fed2019 (-0.98 SE) takes it just under the bar.
- No election worse by more than 2 SE of its own seats: FAILS on qld2020, +0.0052 (own SE 0.0024, z 2.15). Next are
  nt2024 (z 1.81) and nsw2015 (z 1.61).
- Per election, the primary gains most in nsw2023 (-0.68), nsw2019 and wa2025 (-0.38 each) and fed2019 (-0.36). It
  loses most in nt2024 (+2.04), nt2016 (+0.86), nsw2015 (+0.50) and vic2022 (+0.47). Seven elections are exactly 0.

Verdict under the rule: the headline primary PASSES, but clauses 3 (leave-one-election-out) and 4 (qld2020) refuse it.
Under rule 9 / `clause-refusals-go-to-pete`, the split goes to Pete, and no deciding run is started without his call.
Two further points: the guard is flat (-0.0001), and the all-party share error on changed cells is slightly worse
(Q2, within 1 SE). So the ALP and Greens gain comes partly at the other classes' expense.

### PETE'S OVERRIDE (2026-10-25 evening; recorded as an override of clauses 3 and 4)

Pete chose to override the two clause refusals above and go to the 20k deciding run. It is scheduled as a Task Scheduler
job at 03:15 on 26 Oct, at code 5dd64ec, 20,000 sims, all pairs, in folder
`deciding-runs/20261025-1801-f7-demo-resid-full`. The screen's refusals stand as measured; this is his decision, not
a pass under the rule.
