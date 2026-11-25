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

## RESULT (deciding runs 26 Nov 2026, 1:00-2:15am A and 3:15-4:30am B; 35 elections, 5,000 sims, slots 1, no reuse, commit 5453c141)

Runs: `deciding-runs/20261125-2142-seat-type-A/` and `-B/` (this worktree; DONE markers; `score-totals.txt` in each).
Baseline = shipped config, cache 82a613cca0e0, identical in both runs and to the parent prereg's baseline
(235244214575 vs 82a613cca0e0: seat-total diff 0.0000 on every class). The pooled cell count differs by pair
(197 base-vs-base, 191 with A, 188 with B) because the scorable minor-class cells depend on both runs compared.

| measure (lower is better unless stated) | arm A `type` | arm B `both` |
|---|---:|---:|
| 1. seat-total log score, diff (SE, clustered on election) | 1.9259 -> 1.9188, -0.0071 (0.0174) = 0.41 SE | 1.9549 -> 1.9390, -0.0159 (0.0172) = 0.92 SE |
| 2. sign held, leaving any one election out | 32 of 35 | 35 of 35 |
| 3. RPS per seat, diff (SE) | -0.00010 (0.00016) | -0.00012 (0.00016) |
| 4. 90% coverage (target 0.90) | 0.895 -> 0.901 | 0.894 -> 0.904 |
| 4. 80% coverage (target 0.80) | 0.827 -> 0.843 | 0.824 -> 0.840 |
| 5. guard: seat-winner log loss (2,931 seats) | 0.3033 -> 0.3023, -0.0009 (SE 0.0007) | 0.3033 -> 0.3028, -0.0005 (SE 0.0008) |
| floor hits | 4 -> 4 | 4 -> 4 |
| ALP / LNP seat-total ls diff | -0.006 / -0.004 | -0.004 / -0.015 |

**Verdict under the rule: both REFUSED (clause 1 needs the pooled diff better by >= 1 SE).** Arm A is a clear null
(0.41 SE). Arm B misses by a hair (0.92 SE) and passes clauses 2-5, so per CLAUDE.md ("clause refusals go to Pete") the
split goes to Pete; recommendation: keep OFF for 28 Nov. Reasons: clause 1 fails; two arms were run (two chances at a
pass); and the "unacceptable win" clause above applies in spirit: the region arm (-0.0031) and type arm (-0.0071) are both
null while B, whose summed rho is larger (vic2022 region ~0.08 + type ~0.15-0.20 against ~0.17 for one factor), does
best, so B's edge may be "more total correlation" rather than seat type. Not explained away: B's sign holds in 35 of 35
and coverage moves toward nominal on both arms. Rescore on vic2026 after 28 Nov (adds one election to the 35).

Live effect (vic2026, switch 0 / type / both): NOT RUN (needs three 20k `fit_seats_full.R` runs on the live inputs; held
for Pete's call, since it decides nothing).

## Override 1 (added 26 Nov 2026; the clauses and RESULT above are unedited)

**Pete overrode clause 1 and shipped arm B**, 26 Nov 2026: *"let's implement region and seat type please it looks
great!"*. Arm B missed clause 1 (seat-total log score -0.0159, SE 0.0172, 0.92 SE; the rule wanted 1 SE) and passed
clauses 2-5. The recommendation above (keep it off) was mine; the decision is his. `AUSPOL_SEAT_CLUSTER_COR = "both"`
in `scripts/published_flags.R`, and the inline default of `seat_cluster_mode()` with it.

Two changes ship with it, both found while shipping:
- The daily runner has `output/census-features.csv` (from `shipped-models`) and not `census-features-vintage.csv`,
  so the type map would have stopped the forecast. `seat_cluster_census()` reads the plain file only for an election
  whose every census row predates it (vic2026: all 2016; the two files hold identical vic2026 and nsw2027 rows) and
  prints SCT2; anything else stops (SCT2!).
- The night state saves the factor and `night_run_update()` uses it, so the election-night page starts from the same
  seat ranges as the forecast. The `night_replay*.R` tools (replay only) do not carry it.

### Live effect, vic2026 (decides nothing)

`fit_seats_full.R`, 20,000 sims, seed 42, code = branch `seat-corr-main` (main plus this feature), inputs = the
`scenario-inputs` artifact of the 26 Nov 4:30am daily run (run 45665482641: its exact `output/` and `external/`,
seat-poll blend md5 f560c155), in a scratch copy. Point shares byte-identical between the two arms.

Chamber outcomes are probabilities; seat ranges are central intervals of seats won, of 88 (45 for a majority).

| | published 26 Nov (100,000 sims) | switch 0 (20,000) | `both` (20,000) |
|---|---:|---:|---:|
| P(Coalition majority) | 0.382 | 0.380 | 0.385 |
| P(Labor majority) | 0.003 | 0.002 | 0.005 |
| P(hung) | 0.615 | 0.617 | 0.609 |
| P(Coalition most seats, ties counted) | 0.846 | 0.847 | 0.827 |
| Coalition seats: mean, sd, 80%, 90% | 41.7, 9.96, 29-55, 26-59 | 41.7, 9.87, 29-55, 26-59 | 41.7, 10.36, 28-56, 25-59 |
| Labor seats | 23.5, 7.95, 13-34, 11-37 | 23.5, 7.84, 13-34, 11-37 | 23.4, 8.30, 13-35, 10-38 |
| One Nation seats | 15.9, 7.45, 7-26, 5-29 | 15.9, 7.59, 7-26, 5-30 | 16.1, 8.05, 6-27, 4-31 |
| Greens seats | 6.5, 1.95, 4-9, 4-10 | 6.5, 1.98, 4-9, 4-10 | 6.5, 2.06, 4-9, 4-10 |

Switch 0 reproduces the published run to Monte Carlo error (P(hung) 0.617 against 0.615; its SE at 20,000 sims is
about 0.004). Its point shares differ from the published ones in the fourth decimal: the trend is fitted as at
`Sys.Date()`, which was 25 Nov on the (UTC) runner and 26 Nov here. With `both`, each party's seat-total sd rises
about 5-6%, every chamber probability moves by under 2.1 points, and the largest seat-probability move is 0.015.
rho (vic2026): region 0.02 (ONP) to 0.11 (LNP), type 0.08 (IND) to 0.19 (GRN). Simulation time 26.5 s against
22.6 s at 20,000 sims.
