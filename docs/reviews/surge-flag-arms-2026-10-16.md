# Surge flag arms S / N / T: result (2026-10-16)

Prereg: `docs/plans/prereg-surge-flag-time-forward-2026-10-15.md` (and its addendum).
Full rebuilds, stages 1-8, 20,000 sims, at fbae7ab on the restored `external/elections`:

| Arm | Snapshot |
|---|---|
| S (shipped, leaks; pre-restore data) | `output/snapshots/20261015-1317-20697de-from1` |
| N (`AUSPOL_SURGE_SOURCE=none`) | `output/snapshots/20261016-0348-fbae7ab-from1` |
| T (`AUSPOL_SURGE_SOURCE=forecast`) | `output/snapshots/20261016-0632-fbae7ab-from1` |

Scored by `scratchpad/score_surge.R`; 35 elections, 2,931 seats in every arm.

## The clauses, in prereg order

Seat log loss throughout; lower is better. SE clustered on election.

| Clause | Numbers | Outcome |
|---|---|---|
| 1. Primary, T vs N, 15 targeted elections (1,170 seats) | N 0.3713, T 0.3684, T-N -0.0030, SE 0.0031 (0.97 SE) | within 1 SE -> **N** |
| 2. Guard, all 35: winner (N) vs other (T) | N 0.3377, T 0.3349, N-T +0.0028, SE 0.0021 (1.3 SE) | **N FAILS the guard** |
| Refusal: >half of T's gain from one election | targeted gain -3.34 seat-units; qld2017 alone -3.41 (102%) | **T refused** |
| Nelson nt2020 IND < 45% (published path, `published-predictions.csv`) | S 53.9, N 37.7, T 38.4 (actual 29.6) | both pass |
| 3. Reported: S minus N, all 35 | S 0.3347 vs N 0.3377, -0.0030, SE 0.0055 | the leak was worth ~0.003, within noise |

(The pre-xgb `pooled-sharedetail.csv` puts Nelson IND at 44.99 under both N and T: also below 45.)

## Why the clauses disagree

T's advantage on all 35 is not mostly on the 15 elections where the flag differs. T changes
the xgb TRAINING features, so every election's xgb predictions move. On the 20 elections where
T and N flag identically, T is better by 0.0027 pooled, led by fed2013 (-0.033, 150 seats) and
nt2024 (-0.032); worst vic2022 +0.004, fed2019 +0.005, nt2016 +0.006. On the 15 targeted
elections the gain is qld2017 (-0.037, 93 seats) and nothing else net: without qld2017 T is
slightly WORSE there (qld2012 +0.005, wa2025 +0.004, qld2015 +0.003).

So T's measured benefit is one targeted election plus a diffuse retraining shift whose
mechanism is not the flag itself. The prereg anticipated neither the guard failing for the
default nor the refusal clause and the guard pointing opposite ways.

## What was done on Pete's behalf

The leak goes regardless (prereg). The rules' own outcome is N, and T is refused by the
one-election clause, so `AUSPOL_SURGE_SOURCE` ships as `"none"` (published flag and inline
defaults). Live is unchanged: live already ran as N (surge-live). The guard failure is
recorded here, not overridden.

**DECIDED 2026-10-16: Pete, "Keep N".** The question was: take T instead, on the all-35 guard (1.3 SE)? Recommendation: N. T's gain is
qld2017 plus a retraining shift on elections the flag does not touch, which is the shape the
one-election clause exists to refuse.
