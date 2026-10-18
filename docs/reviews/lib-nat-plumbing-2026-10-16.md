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

## 1,000-sim screens after Override 1 (2026-10-17): S and S2 on the 23 elections with split seats

`scripts/score_coalition_split.R` (the prereg's clauses; dry-run first on wa2013 + fed2019, where it reproduced
quick_arm's pooled 0.2721 -> 0.2523 and caught an `ifelse` bug in the gain shares). Seat-winner log loss, lower
is better, S minus A, SE clustered on election; floor 5e-4 (1,000 sims). Logs and scores:
`deciding-runs/quickarm-20261017-coalition-split*.log`, `deciding-runs/score-20261017-coalition-split*-1k.txt`.

| Set (seats, elections) | A | S (pooled f) | S2 (f by state) |
|---|---|---|---|
| PRIMARY: split seats (191, 23) | 0.4314 | 0.3793 (-0.0521, SE 0.0273) | 0.3736 (-0.0578, SE 0.0277) |
| Every seat in those elections (2,081) | 0.2950 | 0.2902 | 0.2897 |
| Non-WA split seats (92) | 0.3123 | 0.3410 (+0.029, SE 0.035) | 0.3361 (+0.024, SE 0.032) |
| Coalition won (117) | 0.1585 | 0.2735 | 0.2722 |
| Coalition lost (72) | 0.6757 | 0.3507 | 0.3378 |
| WA (99) | 0.5422 | 0.4149 | 0.4085 |
| fed (57) | 0.2664 | 0.2401 | 0.2402 |
| Vic (18) | 0.6102 | 0.8193 (+0.209, SE 0.127) | 0.7940 (+0.184, SE 0.116) |
| SA (15) | 0.1665 | 0.1899 | 0.1899 |

Every refusal clause passes at 1,000 sims for both (largest one-election share of the gain 0.36 / 0.37, wa2013).
Non-split seats: 0 moved. S2 is lower on the primary, so under Amendment 2 S2 goes to the 20k deciding run.

**Victoria gets worse under both.** vic2022: the Nationals won Mildura, Morwell and Shepparton (the model already
had them at 0.15-0.31; the split takes them to 0.06-0.14); vic2014 Ripon (Liberal held on a combined 51)
0.60 -> 0.25. Ripon is the one live vic2026 split seat. Victoria's own rate is 0.80, but on 17-22 exclusions it
only gets weight 0.26-0.59 against the pooled 0.71.

## The 20,000-sim deciding run (2026-10-17): S2 PASSES every pre-registered clause

`deciding-runs/20261017-0146-coalition-split-state/` (code f553cfc, 23 elections, slots 1, no reuse; DONE).
The cache copy missed the sa2026 arm (the run deleted its scratch seconds after the last election); it was
rerun at 20k from d586206 (harness code unchanged): the rerun's sa2026 BASELINE is byte-identical to the deciding
run's, so its arm stands in. `deciding_run.ps1` now keeps every election's files (d586206).
Scored by `scripts/score_coalition_split.R` (floor 1e-6): `prereg-score.txt` in that folder.

| Clause | Numbers | Verdict |
|---|---|---|
| Primary: split seats (191, 23 elections) | A 0.4946, S2 0.4412, -0.0533 (SE 0.0273) | **better by > 1 SE** |
| Guard | every seat in the 23: -0.0049 (SE 0.0031); the other 12 elections have no split seat, so the code path is the one-candidate count | passes |
| One election > half the gain | largest wa2013, 0.39 | passes |
| Non-WA split seats worse by > 1 SE | +0.0281 (SE 0.0329) | passes |
| Won traded for lost (reported) | won seats +13.7 seat-units worse, lost seats 23.9 better | primary passes anyway |
| Live: Ripon moves > 15 points | Coalition 0.145 -> 0.079 (6.6) | passes |
| Non-split seats moved | 0 | plumbing holds at 20k |

Reported: fed 57 seats -0.0243 (SE 0.0234); WA 99 -0.1291 (SE 0.0258); **Victoria 18 seats +0.1937 (SE 0.1174)**
(vic2022 +2.38 and vic2014 +0.97 seat-units); SA 15 +0.0308 (SE 0.0122); AEF-7 all seats +0.0004 (SE 0.0062).

**SHIPPED 2026-10-17: Pete chose "Ship now" with the Victoria result in front of him.** Original note:
**Not shipped yet: Pete's call in the morning.** The prereg says ship. Against it: Victoria is the live target and
its split seats get worse (about 1.65 SE), and the flag reaches the daily refresh from dev. To ship:
`AUSPOL_COALITION_SPLIT = "1"`, `AUSPOL_COALITION_SPLIT_F = "state"` in `published_flags.R` (and the inline
defaults), then a rebuild from stage 6 and Pete's publish.

Why Victoria loses (read-only, vic2022 transfer files): the real Coalition-to-Coalition rate in the seats that
got worse was Bass 68.8%, Shepparton 76.5%, Mildura 77.1%, Euroa 87.0%, Morwell 88.7% (S2 used 0.728). So f is
part of it, not all: Mildura, Shepparton and Morwell were three-way contests against a sitting or departing
independent that the model already rated poorly (Coalition 0.15-0.31), and any leak pushes them further down.
