# Statewide party correlation: time-forward (T) vs none (I) — result (2026-10-16)

Prereg: `docs/plans/prereg-party-cor-time-forward-2026-10-16.md` (33e2c4a), committed before any arm ran.
Deciding run: `deciding-runs/20261016-1323-cor-T-vs-I` (20,000 sims, code d6d40d2, `quick_arm --slots=1
--no-reuse`), base `AUSPOL_PARTY_COR=off`, arm `AUSPOL_PARTY_COR=shrunk AUSPOL_COV_TF=1`.

**Outcome: I ships. `AUSPOL_PARTY_COR="off"` in `scripts/published_flags.R` and both inline defaults in
`scripts/fit_seats_full.R` (the harnesses already read unset as off).**

## Which matrix the run applied

The per-harness logs (with the `COV` lines) were in the run's scratch dir, which the run removes when it
finishes. Evidence it ran time-forward instead:

- HD1: the arm saw `AUSPOL_COV_TF` and `AUSPOL_PARTY_COR`, and nothing else leaked in.
- The four elections with fewer than 3 earlier pairs (vic2010, nsw2011, qld2012, sa2010) are byte-identical to
  I. That is the time-forward identity limit. Leave-one-out would give them a full matrix.
- The 1,000-sim screen at the same code printed `time-forward` in every `COV` line.

## The clauses, in prereg order

Seat-winner log loss: the average of -log(probability given to the actual winner), so lower is better. SE is
clustered on election. 18 elections, 1,408 seats.

| Clause | Numbers | Outcome |
|---|---|---|
| 1. Primary, T vs I | I 0.2963, T 0.2960, T - I -0.0003 (SE 0.0003) | within 1 SE -> **I** |
| 2. Guard, all 35 | the matrix reaches only these 18 (fed, WA and NT never read it), so the other 17 are identical | passes |
| Refusal: one election > half the gain | T's net gain is -0.41 seat-units; qld2017 alone is -0.46 (110%) | **T refused** |
| Refusal: gain only through One Nation | qld2017 + qld2020 + sa2026 = 92% of the gain | **T refused** |
| Live: any vic2026 median moves > 2 | none moves (below) | passes |
| 3. Reported: L - I (the leak's worth) | deciding run `deciding-runs/20261016-1532-cor-L-vs-I` | see below |

Per election, T minus I, seat log loss (negative is T better), and the seat count:

| Election | Change | Seats |
|---|---|---|
| qld2017 | -0.0049 | 93 |
| sa2018 | -0.0026 | 40 |
| nsw2015 | -0.0006 | 93 |
| vic2018 | -0.0004 | 88 |
| vic2022 | -0.0002 | 88 |
| vic2014, qld2015 | 0.0000 | 88, 89 |
| qld2024, nsw2019, sa2022, qld2020 | +0.0002 to +0.0004 | 93, 93, 47, 93 |
| nsw2023, sa2026, sa2014 | +0.0007, +0.0008, +0.0011 | 93, 47, 46 |
| vic2010, nsw2011, qld2012, sa2010 | byte-identical | |

Without qld2017, T is slightly worse than I on the other 17.

**The screen's lead did not survive.** At 1,000 sims qld2015 was -0.0097 and 68% of T's gain; at 20,000 it is
0.0000. The screen floors winner probabilities at 5e-4, and qld2015's gain lived under that floor. This is the
CLAUDE.md caveat ("within 1 SE is not a clearance for anything that acts in the far tails") cutting the other
way: a tail effect read as a gain at low N.

AEF-7 subset (321 of 681 seats in these 18): T - I +0.0003 (SE 0.0002), worse by more than 1 SE.

## Live Victoria, I vs the shipped correlated forecast

`fit_seats_full.R` twice at the K=3 code (81aa560), 20,000 sims, output suffixed and moved out of `output/`
afterwards. The live forecast used the all-pairs matrix (nothing to leave out). Seat counts:

| Party | Median, correlated / off | 10th pct | 90th pct |
|---|---|---|---|
| ALP | 28 / 28 | 18 / 18 | 38 / 38 |
| LNP | 30 / 30 | 21 / 21 | 41 / 41 |
| ONP | 23 / 23 | 14 / 15 | 32 / 31 |
| GRN | 6 / 6 | 4 / 4 | 9 / 9 |

P(ALP 45+ seats) 1.43% -> 1.36%; P(LNP 45+) 5.67% -> 5.58%. The seat-count correlation between One Nation and
the Coalition is -0.505 correlated and -0.481 independent: almost all of it comes from the seats themselves
(they compete for the same seats), not from the statewide matrix.

## What this does not settle

- Whether the correlation was ever measured against a working "off" arm when it was adopted: the harnesses ran
  correlated under `off` until d6d40d2, so any earlier I-arm number in the harnesses was not I.
- Non-linear co-movement (One Nation's first points from the Coalition, later ones from Labor).
- `LAMBDA = 0.5` and `COV_TF_K = 5` are now unread at published flags.
