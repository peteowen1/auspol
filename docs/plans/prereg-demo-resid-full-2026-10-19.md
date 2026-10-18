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
