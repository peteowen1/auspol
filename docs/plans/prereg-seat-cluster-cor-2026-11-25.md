# Pre-registration: correlated seat draws within clusters (`AUSPOL_SEAT_CLUSTER_COR`)

Written 2026-11-25, BEFORE any screen of the arm was run. Pete asked for it that morning
(Victoria votes 28 Nov): "seats in the same region / of the same type should move together,
e.g. One Nation surging across regional seats at once." Design background:
`plans/plan-correlated-seat-draws.md` (7 Sep, never built), whose section 0 decides the metric.

## What the arm does

Each cell's simulated noise, `sd_cell * z`, becomes
`sd_cell * (sqrt(rho_k) * z_cluster + sqrt(1 - rho_k) * z_own)`, with one standard normal
`z_cluster` per (simulation, cluster, class) drawn on a separate RNG stream. Total variance of
every cell is unchanged; seats in one cluster now miss together.

- Clusters: vic = the 8 upper-house regions (`external/reference/vec/vic-district-regions.csv`,
  2022 boundaries: 66/79/79/88 of 88 seats matched for vic2010/14/18/22); nsw = the regions
  file (82-93 of 93 matched); federal = the division's state or territory (all matched);
  qld, sa, wa, nt = k-means on the projected primary shares, k = round(seats / 11) (no region
  file exists for them; this is a "seat type" grouping). Unmatched seats get no cluster term.
- rho_k: per-election intraclass correlation of standardised published-path misses within
  clusters (`scripts/fit_seat_cluster_icc.R`), pooled over elections dated BEFORE the target in
  the same group (federal / state), partially pooled across classes (DerSimonian-Laird).
  vic2026: ALP 0.172, LNP 0.172, GRN 0.145, IND 0.073, ONP 0.136, OTH 0.127, OTH_RIGHT 0.128.
  Federal targets get about 0.23 for every class.
- Off ("0", the shipped value) is byte-identical to the current model (unit test).

## Why seat log loss is NOT the metric

The split preserves every seat's marginal distribution (exactly for Gaussian noise; with
`AUSPOL_ERROR_DIST=1` the own part is the empirical quantile draw scaled by sqrt(1 - rho) and the
cluster part is Gaussian, so the variance is preserved exactly and the SHAPE is nudged toward
Gaussian by a share rho of the variance). So per-seat win probabilities move only by Monte Carlo
noise plus that shape nudge. What changes is the joint law: seat totals, P(majority), P(hung).

## Primary metric: the seat-total log score

`scripts/score_seat_totals.R` on the quick_arm caches (the harnesses' own `sim$totals`; WA and NT
now write theirs too). Per election and class with any seat possible: `-log P(simulated total ==
actual total)`, P floored at 0.5/N. Per election: mean over scored classes. Pooled: mean over
elections, SE = sd of per-election (arm - base) / sqrt(n elections). Lower is better.

Secondary (reported, decide nothing alone): ranked probability score of the seat total (lower is
better); coverage of the 80% and 90% central seat intervals over (election, class) cells (target
0.80 / 0.90); floor hits (classes whose actual total the simulation never produced).

**Looked at before writing this**: the newest cached baseline (25 elections with totals, 1,000
sims, 132 cells) scored 80% coverage 0.841 (111/132) and 90% coverage 0.909 (120/132): the cells
are NOT obviously under-covered in aggregate. Most cells are minor classes with near-deterministic
totals, so aggregate coverage is dominated by them; the arm's case rests on the major classes and
on the log score, and the result may well be a null or a loss. This is recorded so a loss is not
explained away afterwards.

## Screen

`scripts/quick_arm.R "AUSPOL_SEAT_CLUSTER_COR=1" --pairs=all --sims=5000` from the worktree
(baseline = the shipped configuration at the same seed and N). 5,000 rather than 1,000 because
the totals log score floors at 0.5/N. If time forces it, AEF-7 instead, said so.

## Decision rule (for recommending "ship" to Pete; Pete decides)

Recommend shipping only if ALL hold:

1. Pooled seat-total log score better (arm - base < 0) by at least 1 SE.
2. It stays better (sign holds) with any single election left out.
3. Pooled RPS not worse by more than 1 SE.
4. 90% interval coverage over all cells does not move further from 0.90 by more than 0.03.
5. Do-no-harm guard: quick_arm's pooled seat-winner log loss changes by less than 2 SE and by
   less than 0.003 in absolute value. A larger move means the marginals changed and the
   implementation (or the shape nudge) is not what is claimed: STOP, do not judge 1-4.

Refuse if 1 fails. If 1 passes but 2-4 fail, report the split and leave it to Pete.

## What would make an apparent win unacceptable

- It comes from floor hits disappearing at low N (the floor at 0.5/N): report floor hits per arm;
  a win made entirely of baseline floor hits is "wider tails", not "better joint law".
- It comes only from minor classes whose total is 0 or 1 (no information about co-movement):
  report the major classes (ALP, LNP) separately; if they get worse, say so.

## Live effect (reported, not part of the rule)

`fit_seats_full.R` (vic2026) in a scratch copy, same seed, switch off vs on: P(Coalition
majority), P(Labor majority), P(hung), and the 80%/90% seat ranges of ALP and LNP.

## RESULT (screen run 2026-11-25 11:23am-12:08pm; 35 elections, 5,000 sims, baseline = shipped config)

Command: `scripts/quick_arm.R "AUSPOL_SEAT_CLUSTER_COR=1" --pairs=all --sims=5000` from commit
a84a2903 (worktree `seat-corr-regions`), inputs copied from `C:/dev/auspol/output` (13 Nov rebuild
vintage). Scored with `scripts/score_seat_totals.R` (caches 235244214575 = baseline, 39ea9af9f4e8 = arm).

Applied: every arm log prints SCC1/SCC2 and the `B*5k` line; fed2007 and the first state election
of the corpus get rho 0 (no earlier election), as designed.

| measure (35 elections, 195 election-class cells) | baseline | arm | diff (SE, clustered on election) |
|---|---:|---:|---:|
| seat-total log score, lower is better | 1.8792 | 1.8761 | -0.0031 (0.0147) |
| seat-total RPS / seats, lower is better | 0.01702 | 0.01691 | -0.00011 (0.00018) |
| 80% interval coverage, target 0.80 | 0.831 (162) | 0.836 (163) | |
| 90% interval coverage, target 0.90 | 0.897 (175) | 0.913 (178) | |
| floor hits | 4 | 4 | |
| seat-winner log loss (guard), 2,931 seats | 0.3033 | 0.3031 | -0.0002 (0.0007) |

Clauses: (1) FAILS: -0.0031 is 0.2 SE, not 1 SE. (2) FAILS: the sign holds in 32 of 35
leave-one-out (range -0.0080 to +0.0071). (3) passes. (4) passes within tolerance, but both
coverages move AWAY from nominal (90%: 0.897 -> 0.913; 80%: 0.831 -> 0.836). Baseline intervals
already cover at or above nominal (ALP and LNP 0.91 at 90%): these 35 elections do not show the
seat ranges as too narrow.
(5) guard passes: seat log loss within 1 SE, every point share byte-identical (max share diff 0),
largest seat-probability move 0.026 (Monte Carlo plus the error-quantile shape nudge).

By class: ALP -0.037 (SE 0.051), LNP +0.017 (0.033), GRN -0.019 (0.011), IND +0.029 (0.031).
The mean simulated sd of a class's seat total rose about 5% (federal 5.51 -> 5.73 in fed2010):
the statewide draw already carries most of the seat-total spread, so the cluster term adds little.

**Verdict under this rule: REFUSE as a backtest improvement (a null, not a loss).** The arm
widens seat ranges slightly and does no measurable harm; the 35 elections cannot tell it from
the baseline. Shipping it for Victoria would be Pete's call on the face-validity argument.

### Live effect, vic2026 (fit_seats_full.R in a scratch copy, 20,000 sims, seed 42, inputs = main checkout output/ of the 13 Nov rebuild, NOT the live release)

Probabilities of each chamber outcome, and seat ranges (80% / 90% central intervals of seats won, of 88):

| | switch off | switch on |
|---|---:|---:|
| P(Coalition majority, 45+) | 0.298 | 0.296 |
| P(Labor majority) | 0.008 | 0.010 |
| P(hung) | 0.694 | 0.694 |
| Coalition seats: sd, 80%, 90% | 9.49, 28-52, 25-56 | 9.61, 27-52, 25-56 |
| Labor seats: sd, 80%, 90% | 7.85, 16-37, 14-39 | 7.99, 16-37, 13-40 |
| One Nation seats: sd, 80%, 90% | 7.03, 6-24, 4-27 | 7.17, 6-24, 4-27 |

The statewide draw already
gives a 9.5-seat sd for the Coalition, so the regional term adds about 1-2% to seat-total sd.
Live, it is close to invisible.
