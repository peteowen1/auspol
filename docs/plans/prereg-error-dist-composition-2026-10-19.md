# Pre-registration: the error shape standardised by the composition factor too (audit F9), 2026-10-19

Committed BEFORE the switch is built or run. Pete: "go" (19 Oct, after the F5/F9 verification). Decision rule: the
standard rule at the top of `PRE-REGISTRATION-RULES.md`, no departures.

## The defect

`scripts/fit_error_distribution.R:35` standardises each cell's error as `z = err / (sdm x size_f)`, leaving out the
composition factor (`AUSPOL_COMPOSITION_SD=1`, shipped 2026-10-17 together with this table). The quantiles are then
rescaled to RMS 1 per class, so the table carries SHAPE only. But a pool of cells whose real widths differ by the
composition factor is a scale mixture, and a scale mixture has heavier tails than any one of its cells. The simulator
then draws `sd_cell x z` with `sd_cell` already multiplied by the composition factor (`R/seat_sim.R:1437-1442`), so
personal-vote seats get the widening twice in the tails: once in their own sd, once in the shared shape.

## The arm (`AUSPOL_ERROR_DIST_COMP=1`, default "0")

- `fit_error_distribution.R`: with the switch on, `z = err / (sdm x size_f x comp_f)`, `comp_f` from
  `composition_sd_factor()` on that pair's own predicted share matrix and that pair's own (time-forward) row of
  `output/spread-by-composition.csv` -- the factor the pair's run applied. Written to `output/error-quantiles-comp.csv`;
  the shipped `error-quantiles.csv` is untouched.
- `error_dist_args()` reads `error-quantiles-comp.csv` when the switch is on. Every harness and `fit_seats_full.R`
  reach it through that one function.
- Printed: pooled z RMS, robust sd and percent beyond 4 for both standardisations (ERC1), and the count of cells with
  `comp_f > 1`. Proof it acts: the two tables differ; OFF is byte-identical on vic2022 and fed2025.
- Not refitted: `shrink`, the size and composition tables, `level_sd`.

## Measurement

1. Screen `Rscript scripts/quick_arm.R "AUSPOL_ERROR_DIST_COMP=1" --pairs=all`, after the F4 deciding run has finished
   (never alongside it; both change the effective seat spread, so they are measured one at a time).
2. Deciding run only if the screen is not WORSE: `deciding_run.ps1 -Arm "AUSPOL_ERROR_DIST_COMP=1" -Label f9-comp`.

## Decision (standard rule)

The change reshapes every cell's draw, so the primary is ALL seats of all elections (seat-winner log loss, SE
clustered on election), better by more than 1 SE. Leave-one-election-out holds; no election worse by more than 2 SE of
its own seats. Reported, not voted: seats with any cell at `comp_f >= 1.2` (where the double count lives), Brier,
accuracy, floor counts.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the 1e-6 floor (report at 1e-4). (b) qld2017 carries most of it again: report each
election's share; not a refusal on its own (`no-one-election-share-refusal`), but leave-one-out must hold. (c) The
vic2026 live walk moves a favourite: shown to Pete before shipping. Known blind spot: the composition table was itself
fitted with z standardised the old way in mind; a joint refit is a separate prereg.
