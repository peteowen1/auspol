# Pre-registration ADDENDUM: seat-TYPE clusters, and region + type together

Addendum to `prereg-seat-cluster-cor-2026-11-25.md` (same day; its region arm was a null,
refused). Written 2026-11-25 about 9pm, BEFORE any screen of either arm below was run. Branch
`seat-corr-type`, off `seat-corr-regions` (c6ada8b0).

## Why

The first arm clustered vic, nsw and federal seats by GEOGRAPHY only (upper-house regions; the
state). Pete's example was by KIND of seat: One Nation over-performing in all outer-suburban and
regional seats at once, wherever they are. That was never tested for vic, nsw or federal, nor a
version with both factors.

## Arms (one quick_arm launch each)

- **A, `AUSPOL_SEAT_CLUSTER_COR=type`**: every jurisdiction clusters by seat type (below). For
  qld, sa, wa, nt this changes the type definition from the first arm's shares-only k-means.
- **B, `AUSPOL_SEAT_CLUSTER_COR=both`**: two independent factors per cell, region and type:
  `noise = sd_cell * (sqrt(rho_r) z_region + sqrt(rho_t) z_type + sqrt(1 - rho_r - rho_t) z_own)`,
  so each cell's total variance is unchanged. Region = the first arm's clusters (vic regions,
  nsw regions, federal state). qld, sa, wa, nt have no region file: there B is type only, with
  the type-only rho (identical to arm A for those elections).

`"0"` stays the shipped value and must be byte-identical (unit test); `"1"` is unchanged.

## Seat type, built time-forward

Per election, k-means (k = round(seats / 11), nstart 20, fixed seed on a separate stream) on a
feature vector per seat, every column z-scored across that election's seats:

- the projected primary shares the simulator is given (the model's own pre-election input), and
- the seven census features in `output/census-features-vintage.csv` (`yr12_pct`, `born_aus_pct`,
  `indig_pct`, `over55_pct`, `under35_pct`, `lang_other_pct`, `edu_25plus_pct`), whose vintage is
  the latest census before polling day (lookahead rows are blanked in that file). A seat with no
  census row, or a blanked one, gets 0 (the election mean) on those columns, so it is typed by its
  shares alone; the coverage is printed (SCT1). wa2001 and wa2005 have no census at all and are
  typed on shares only.

Nothing from the target election's results enters the types. The 2022-results profile was not
used: projected shares already carry each seat's previous result, and they are complete.

## Rho, time-forward (reuses `scripts/fit_seat_cluster_icc.R`)

`fit_seat_cluster_icc.R --scheme=type` writes `inst/extdata/seat-cluster-icc-type.csv`, one row
per (election, class), measured on the published-path misses exactly as the first arm:

- `icc_type`: one-way intraclass correlation within type clusters (arm A's rho source);
- `icc_r2`, `icc_t2`: the region and type variance shares from a crossed random-effects fit
  (`lme4::lmer(z ~ 1 + (1|region) + (1|type))`, REML) on seats with both ids (arm B). For
  jurisdictions with no region, `icc_r2` is NA and `icc_t2 = icc_type`.

Each is pooled by the unchanged `seat_cluster_rho()`: only elections dated before the target, in
the same group (federal / state), partially pooled across classes. In arm B, if rho_r + rho_t
exceeds 0.9 for a class both are scaled down proportionally to sum 0.9 (printed). The first
arm's `seat-cluster-icc.csv` is not touched, so `"1"` reads the same numbers.

## Metric, screen, decision rule

All exactly as the parent prereg: `scripts/quick_arm.R "AUSPOL_SEAT_CLUSTER_COR=type"` (then
`=both`) `--pairs=all --sims=5000`, baseline = the shipped config at the same seed and N; scored
by `scripts/score_seat_totals.R` (seat-total log score primary; RPS, 80/90% coverage, floor hits
secondary). Recommend shipping only if all five clauses of the parent hold (log score better by
at least 1 SE clustered on election; sign holds leaving any one election out; RPS not worse by
more than 1 SE; 90% coverage not moving further from 0.90 by more than 0.03; seat-winner log
loss guard < 2 SE and < 0.003). Refuse if clause 1 fails; split goes to Pete.

Each arm is judged on its own against the baseline. Two arms means two chances: a pass by one at
just over 1 SE is weaker evidence than the rule's wording, and is reported as such.

## What would make an apparent win unacceptable

As the parent: a win made only of baseline floor hits disappearing, or only of minor classes with
totals 0 or 1. Report ALP and LNP separately. Added here: arm B "winning" while arm A is null and
the region arm was null would mean the gain is from the crossed-fit rho being larger, not from
type; report the mean rho_r + rho_t against the first arm's rho.

## Live effect (reported, decides nothing)

`fit_seats_full.R` vic2026 in a scratch copy, 20,000 sims, seed 42, switch 0 vs type vs both:
P(Coalition majority), P(Labor majority), P(hung), seat sd and 80%/90% ranges for LNP, ALP, ONP.

## RESULT

(to be filled after the screens)
