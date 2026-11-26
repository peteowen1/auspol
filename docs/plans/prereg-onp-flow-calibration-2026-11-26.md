# Pre-registration: One Nation pairwise flow calibration (`AUSPOL_ONP_FLOW_CAL`), 2026-11-26

Written and committed BEFORE any arm is run. Pete chose to fix the One Nation flow gap (26 Nov, about 6:50pm).

## What was found (measured before this file, nothing fitted)

After YouGov's seat primaries were loaded, the live forecast (run 45772760059) gives One Nation 19.5 expected seats.
In the 29 seats where YouGov's final two includes One Nation and our forecast has that pair, the share of the
OTHER candidates' votes that ends with the Coalition rather than One Nation (backed out of the TCP and the two
primaries; `scripts/measure_onp_flows.R` for real counts):

| Final two | ours (live, median) | YouGov (median) | real counts, whole count |
|---|---|---|---|
| One Nation v Coalition (14 seats) | 48 | 79 | sa2026 66.5 pooled (4 seats, 62.7-68.6); fed/qld 49-58 (1 seat each) |
| One Nation v Labor (15 seats), % to Labor | 41 | 54 | sa2026 56.4 pooled (25 seats, 37.8-70.3); qld2020 36.6 (2) |

Per key, printed from the live override (`night-state-vic-2026.rds`, the object the simulation takes), Ripon:
Labor between Liberal and One Nation 53.3% to Liberal; Greens with Labor, Liberal, One Nation alive 54.5 / 16.6 / 28.9
(Liberal 36% of the Liberal + One Nation part); Liberal between Labor and One Nation 21.6% to Labor; Greens between
Labor and One Nation 61.1% to Labor. Measured pairwise (all earlier exclusions where both were alive, vote-weighted):
Labor 60.6% to Liberal over One Nation (11 exclusions, 5 elections); Greens 54.7% (292, 16); Greens 82.6% to Labor over
One Nation (306, 16); Liberal 29.3% to Labor over One Nation (68, 10).

## The change (one switch, default "0" = byte-identical)

`AUSPOL_ONP_FLOW_CAL=1`, in `onp_flow_cal()` (`R/onp_flow_cal.R`), called at the end of
`xgb_flow_conditional_override_for()`, so all six harnesses, the oracle scorer and `fit_seats_full.R` get it with no
per-harness edit. For every per-seat key whose survivors include One Nation and a party X in {ALP, LNP, NAT}, and whose
excluded class is neither: the tree's pairwise split X : ONP is moved toward the measured history rate for that
excluded class and that X,

    r_new = r_tree + w (r_hist - r_tree),   w = E / (E + k),   k = AUSPOL_ONP_FLOW_CAL_K (default 3)

- `r_hist`: from the flow-feature rows of elections BEFORE the target only (`elections_before()`), every exclusion
  where X and One Nation were both alive; per-election rate, then a recency-weighted mean across elections
  (half-life `AUSPOL_FLOW_RATE_HL`, shipped 2 years). E = number of elections with such exclusions. Shrinkage by
  election count, not exclusion count, because the spread is election-wide.
- Applied as an odds multiplier on X's entry, then X and One Nation are rescaled to their original total; every other
  survivor's entry is unchanged.

Differs from the refused 24 Nov `AUSPOL_ONP_FLOW_KEYS` arms: those used the exact (from, survivor-set) key, 6-14 rows
mostly from sa2026 itself; this pools every survivor set by excluded class (hundreds of exclusions over up to 16
elections) and shrinks.

## Measurement

1. **Primary (flow only, primaries taken out):** `scripts/score_onp_flow_cal.R`. For each election with any final
   count between One Nation and Labor or the Coalition (fed2016, fed2019, fed2025, nsw2023, qld2020, qld2024, sa2026),
   each seat's ACTUAL primaries are run through the count with the per-seat flows at switch 0 and 1. Metric: absolute
   error of One Nation's final share in seats whose actual final two was One Nation v X (TCP error, points, lower is
   better), mean over seats, with SE clustered on election. Secondary: event-level error on One Nation keys.
2. **Guard (seat model):** `scripts/quick_arm.R "AUSPOL_ONP_FLOW_CAL=1" --pairs=qld2017,qld2020,qld2024,sa2026,fed2025,fed2019,nsw2023,wa2025`
   at 1,000 sims, seat-winner log loss, SE clustered on election. Needs 8,000 MB free memory; if it cannot run tonight
   that is reported, not skipped silently.

## Decision rule

- **Ship candidate** if the primary TCP error falls by more than 1 SE, and the guard is not worse by more than 1 SE.
- **Known risk, stated now:** the 24 Nov arms made sa2026 seat log loss WORSE on the seats One Nation won (trees'
  lean offsetting under-called One Nation primaries). If the primary passes and sa2026 seat log loss gets worse, that
  split goes to Pete with both numbers; it is not auto-refused and not auto-shipped. Live, the primaries now come
  from seat polls, so the offset argument is weaker there; that is a reason for Pete, not a measurement.
- **Unacceptable even if the primary passes:** any live key's pairwise split moving outside the range of the measured
  per-election rates for that class.
- **Power, stated now:** only sa2026 has more than two One Nation final counts (29); the others have 1-2 each. The
  primary is effectively an sa2026 measurement with a handful of other seats.
- No 20,000-sim deciding run before 28 Nov (time).

## RESULT (26 Nov, evening)

### Primary: flow-only One Nation TCP error (`scripts/score_onp_flow_cal.R`, actual primaries)

36 One Nation final counts in fed2016, fed2019, fed2025, qld2020, qld2024, sa2026; 28 scored (the actual final pair
comes out of the count under both arms; the 8 others, e.g. Maranoa, finish Labor v Coalition under both). Absolute
error of One Nation's share of the final two, points, lower is better:

| election | final two | seats | switch 0 | switch 1 | bias 0 | bias 1 |
|---|---|---|---|---|---|---|
| sa2026 | ALP v ONP | 23 | 4.18 | 3.80 | -0.96 | -1.44 |
| sa2026 | LNP v ONP | 4 | 5.14 | 4.66 | +0.28 | -0.57 |
| qld2020 | ALP v ONP (Mirani) | 1 | 23.29 | 23.33 | -23.29 | -23.33 |
| **pooled** | | **28** | **5.00** | **4.62** | -1.58 | -2.10 |

Change -0.38 points. SE: 0.12 paired over seats (18 better, 10 worse); the election-clustered SE (0.03) rests on two
elections and is not meaningful. Winners reproduced from actual primaries: 32 -> 33 of 36 (Light, SA: now Labor, as
happened). Passes the primary by about 3 seat-level SE. It is effectively an sa2026 result, as stated in advance.
Bias: switch 1 leaves One Nation slightly UNDER its real final share in sa2026 (-1.4), so the calibrated flows are
not too far the other way there.

### Unacceptable clause: live splits inside the measured ranges

Every live vic2026 split after calibration sits inside the range of the per-election measured rates for its class
(e.g. Labor between Coalition and One Nation 58.6% to Coalition, measured 53.9-67.0; Greens between Labor and One
Nation 80%, measured 75.3-94.1). Clause not triggered.

### Live effect (replay of `night-state-vic-2026.rds` from run 45772760059, 20,000 sims)

Switch 0 reproduces the published forecast (One Nation 19.5 expected seats; Ripon One Nation 52.6 v Coalition,
published 52.5).

Expected seats and chances (88 seats, majority 45; a replay, same primaries and draws as the published run):

| | switch 0 (published) | switch 1 |
|---|---|---|
| One Nation expected seats | 19.5 | 14.2 |
| Coalition | 41.8 | 44.1 |
| Labor | 19.8 | 22.8 |
| Greens | 6.6 | 6.5 |
| P(Coalition majority) | 39.1% | 47.6% |
| P(hung parliament) | 60.6% | 51.8% |

One Nation's share of the final two against the Coalition (median over runs with that pair), points, against YouGov:

| seat | switch 0 | switch 1 | YouGov |
|---|---|---|---|
| Ripon | 52.6 | 50.5 | 41 |
| Eildon | 45.6 | 44.7 | 35 |
| Shepparton | 43.0 | 42.7 | 35 |
| Morwell | 50.5 | 49.1 | 40 |
| Lowan | 50.2 | 49.8 | 47 |
| Ovens Valley | 50.1 | 49.5 | 44 |

The calibration closes 1-2 points, under a fifth, of the TCP gap to YouGov in these seats; most of the remaining gap is YouGov's
own assumption (about 79% of the other candidates' votes to the Coalition, above every real count on disk: sa2026
62.7-68.6% in four such seats). Seat counts move more than TCPs because many seats sit near 50.
