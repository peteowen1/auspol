# Lib-vs-Nat as two candidates: plumbing checks (2026-10-16). STOPPED

Prereg: `docs/plans/prereg-lib-nat-two-candidates-2026-10-16.md` (7d901c4). Its rule: "any failure stops,
nothing is scored". One check failed, so the screen's log-loss numbers below are NOT a result.

Run: `quick_arm.R "AUSPOL_COALITION_SPLIT=1" --pairs=wa2013,fed2019 --sims=1000` (baseline = shipped).

## The checks

| Check | Result | Verdict |
|---|---|---|
| Every seat without both a Liberal and a National is byte-identical | sharedetail identical in both elections; every seat whose win probabilities moved is a split seat (wa2013 16 of 17, fed2019 10 of 11; Murray-Wellington and Barker did not move) | pass |
| Albany wa2013: Coalition win probability falls from 0.97 | 0.975 -> 0.868 | pass |
| Bass fed2019 (National 1.4%): moves by less than 0.01 | 0.083 -> 0.026 (moved 0.057) | **FAIL** |
| Each run prints split-seat count, f, mean r | `LN1` line per election | pass |

Coalition win probability, base -> split, in the split seats (1,000 sims; lower is not better or worse by itself):

| wa2013 | | | fed2019 | | |
|---|---|---|---|---|---|
| Albany | 0.975 | 0.868 | Bass | 0.083 | 0.026 |
| Collie-Preston | 0.878 | 0.675 | Braddon | 0.300 | 0.136 |
| Kimberley | 0.925 | 0.802 | Gilmore | 0.561 | 0.294 |
| Mandurah | 0.425 | 0.228 | Indi | 0.892 | 0.776 |
| Pilbara | 0.920 | 0.789 | Pearce | 0.638 | 0.481 |

## Why Bass failed

A seat with no split at the previous election gets the pooled junior fraction (0.27 at fed2019, sd 0.14). The
junior's actual share is two-humped: a token candidate or a real contest. Junior fraction of the Coalition vote,
all split seat-elections:

| Jurisdiction, earlier split in seat | n | mean | share under 0.10 |
|---|---|---|---|
| fed, no | 43 | 0.204 | 33% |
| fed, yes | 24 | 0.205 | 33% |
| sa, no | 14 | 0.116 | 79% |
| wa, no | 47 | 0.259 | 11% |
| wa, yes | 62 | 0.311 | 8% |
| vic, no | 30 | 0.262 | 20% |

Bass's National (1.4% of the vote, junior fraction about 0.035) was simulated at about 11 points, and 29% of
that leaked past the Liberal. Nothing in the prereg's predictor separates a token National from a real one.

## What was built (kept, off)

`simulate_seat_contests(coalition_split=)` in both engines (byte-identical R vs compiled, tests in
`tests/testthat/test-coalition-split.R`), `R/coalition_split.R` (time-forward fit), wired into the six
harnesses, NT and `fit_seats_full.R`. `AUSPOL_COALITION_SPLIT = "0"`.

## Amendment 1 rerun (ridge predictor of the split; prereg Amendment 1, 33c031c)

Same run, same checks. Unsplit seats byte-identical (pass; every moved seat is a split seat). Albany 0.975 ->
0.867 (pass). **Bass 0.083 -> 0.053 (moved 0.030; FAIL again).** Bass's junior centre fell 0.27 -> 0.15, but
with an out-of-fold sd of 0.19 the draws still put a real National in Bass a fair share of the time.

Why no pre-election predictor can pass it: at fed2016 the Nationals stood in no Tasmanian seat. At fed2019 three
stood from that identical position: Bass 1.4%, Braddon 2.4%, Lyons 15.7% (the Liberal was disendorsed
mid-campaign). Every feature in the amendment is the same for Bass and Lyons. A 0.01 limit on Bass requires
knowing in advance that the National would be a token candidate.

| fed2019 seat | Coalition win probability, base | amended split |
|---|---|---|
| Bass | 0.083 | 0.053 |
| Braddon | 0.300 | 0.222 |
| Lyons | 0.158 | 0.095 |
| Gilmore | 0.561 | 0.221 |
| Eden-Monaro | 0.175 | 0.036 |

OPEN, for Pete: override the Bass clause (recorded as an override) and score on the unchanged criterion, or stop.
