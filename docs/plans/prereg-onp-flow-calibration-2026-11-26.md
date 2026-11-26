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

## RESULT: guard (seat-winner log loss), 26 Nov 2026 7:22-7:47pm; DECISION: REFUSED, kept off (Pete)

quick_arm `AUSPOL_ONP_FLOW_CAL=1` vs shipped baseline, 1,000 sims, slots 1, private quick dir; pairs qld2017,
qld2020, qld2024, sa2026, fed2025, fed2019, nsw2023, wa2025 (779 seats); caches fbdf69733ac2 (base) / 2207fcac2f9a (arm).

| election | seats | ll base | ll arm | change (lower is better) |
|---|---:|---:|---:|---:|
| sa2026 | 47 | 0.2220 | 0.2253 | +0.0033 |
| qld2020 | 93 | 0.1975 | 0.1981 | +0.0005 |
| fed2019 | 151 | 0.2203 | 0.2206 | +0.0003 |
| nsw2023 | 93 | 0.1943 | 0.1945 | +0.0001 |
| fed2025 | 150 | 0.2864 | 0.2865 | +0.0001 |
| wa2025 | 59 | 0.1920 | 0.1920 | 0.0000 |
| qld2024 | 93 | 0.2695 | 0.2692 | -0.0003 |
| pooled | 779 | 0.2800 | 0.2803 | +0.0003 (SE 0.0002, clustered on election) => WORSE by more than 1 SE |

The named risk happened: in the four SA 2026 seats One Nation WON, the arm lowered its probability in every one
(Hammond 0.65 -> 0.47, Ngadjuri 0.94 -> 0.88, MacKillop 0.37 -> 0.34, Narungga 0.32 -> 0.30). The primary TCP metric
improved (5.00 -> 4.62 on 28 seats) by fitting the seats One Nation lost better. Guard fails; per the clause-refusal
rule the split went to Pete, who chose to keep the current flows for 28 Nov (26 Nov ~7:55pm). Rescore after the
election with vic2026 added.

## AMENDMENT 1, 27 Nov 2026: Pete chose to ship, then a flow-only transfer test was run and it was NOT shipped

Added after the result; the clauses above are unedited. Pete asked (27 Nov) why the live Labor split between the
Coalition and One Nation is ~54% to the Coalition and chose to test and ship fixes. Two facts measured that morning:

- Why the trees give ~54%: for `ALP|LNP+ONP` the time-forward history rate is 62.9% to the Coalition but backed by
  2.7 effective events; the trees score each destination near 0.5 (Coalition 0.55, One Nation 0.47 in Ripon), the
  rescale gives 55.1% (median, 88 seats) and the 0.15 smoothing toward uniform about 54%.
  (`scratchpad/onpf/decompose_live.R`.)
- The offset the guard failure was blamed on is real: on the published path (output/published-predictions.csv,
  built 13 Nov) sa2026's One Nation primary is 2.9 points low on average over 47 seats, and in the seats it won
  Hammond -2.3, MacKillop -11.4, Narungga -8.8, Ngadjuri +0.7. With actual primaries the calibration is better
  (TCP error 5.00 -> 4.62, winners 32 -> 33 of 36); the generous flows had been covering for the primaries.

Live replay on the 27 Nov 7:39am state (20,000 sims): One Nation 18.5 -> 13.3 expected seats, Coalition 43.1 -> 45.3,
Labor 19.4 -> 22.5, P(Coalition majority) 43.4% -> 51.9%, P(hung) 56.3% -> 47.5%.

Pete chose "Ship it" (~9:10am), then asked whether a flow change should be judged on the flows themselves (transfer
log loss) rather than seat or primary metrics. That test, run before anything was pushed:

Transfer log loss (vote-weighted cross-entropy of the ACTUAL destination shares in every real exclusion with One
Nation alive, actual primaries, flows after the 0.15 smoothing; 1,948 events, 15 elections; per-election change vs
the trees, lower is better; `scratchpad/onpf/event_ksweep.R`):

| arm | change | SE | better / worse |
|---|---|---|---|
| k 3, every class (this switch) | -0.0002 | 0.0016 | 8 / 7 |
| k 1 | +0.0014 | 0.0019 | 7 / 8 |
| k 0.25 | +0.0026 | 0.0023 | 7 / 8 |
| k 10 | -0.0013 | 0.0011 | 9 / 6 |
| k 30 | -0.0012 | 0.0007 | 13 / 2 |
| Greens only, k 3 | -0.0001 | 0.0009 | 8 / 5 |
| k per class chosen leave-one-election-out | +0.0001 | 0.0007 | 7 / 7 |

Two-way split to the non-One-Nation major (trees / k 3 / actual): minor right 48.1 / 50.1 / 36.8 (786 events), other
minors 43.1 / 45.3 / 37.2 (611), independents 45.2 / 49.7 / 44.8 (266), Greens 50.0 / 56.5 / 54.4 (266). Labor
exclusions with the Coalition and One Nation alive: 3 events, unmeasurable.

DECISION (Pete, 27 Nov ~9:40am, "go" on the recommendation): NOT shipped. No arm beats the trees on transfers by more
than its noise, and the commonest cases (minor right, other minors) get worse. The local merge to dev was undone
before any push. Open after 28 Nov: the trees over-send minor-right preferences to the Coalition (48 vs 37); a
pairwise flow target; the One Nation primary under-call; rescore with vic2026's own counts added.

## AMENDMENT 2, 27 Nov 2026 ~9:55am: k = 20, criterion written BEFORE its runs

Pete, seeing the sweep above: "k = 20 maybe, in between k = 10 and k = 30 which both look good". Leave-one-election-
out choice of a single k picks 10 (13 elections) or 30 (2): -0.0009, SE 0.0009, 9 better / 6 worse. k = 30 live
replay (27 Nov state): One Nation 18.5 -> 16.4, Coalition 43.1 -> 44.0, Labor 19.4 -> 20.6, P(Coalition majority)
43.4% -> 47.1%. k = 20 was not in the grid; it is chosen by Pete between two grid points, not fitted.

Ship `AUSPOL_ONP_FLOW_CAL=1, AUSPOL_ONP_FLOW_CAL_K=20` only if BOTH:
1. Transfer log loss (same scorer, same 15 elections): per-election mean change below 0 AND at least 10 of 15
   elections better.
2. Guard, seat-winner log loss (quick_arm, 1,000 sims, the same 8 pairs as the 26 Nov guard): pooled change not
   worse than +1 SE (clustered on election).
Either fails: not shipped, and the split goes to Pete as before.

### AMENDMENT 2 RESULT (27 Nov ~9:50am): k = 20 PASSES both criteria, SHIPPED

1. Transfer log loss: -0.0013 per election (SE 0.0008), 11 of 15 better (worse: fed2022 +0.0057, fed2025 +0.0012,
   fed2010 and qld2020 +0.0000). Passes (mean below 0, at least 10 better).
2. Guard, quick_arm `AUSPOL_ONP_FLOW_CAL=1 AUSPOL_ONP_FLOW_CAL_K=20`, 1,000 sims, 779 seats, 8 elections: seat-winner
   log loss 0.2800 -> 0.2801, +0.0001 (SE 0.0001) => within 1 SE. Passes. By election: sa2026 +0.0008, qld2020
   +0.0006, nsw2023 +0.0001, fed2019 0, wa2025 0, fed2025 -0.0001, qld2024 -0.0003. AEF-7 ledger subset 442 seats
   0.2440 -> 0.2440. HD1 verified (both switches applied, none leaked).
Shipped: `AUSPOL_ONP_FLOW_CAL = "1"`, `AUSPOL_ONP_FLOW_CAL_K = "20"`.
