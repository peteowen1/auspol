# Pre-registration: NSW exhaustion in the simulation plus OPV-basis anchoring (2026-11-07)

Pete's goal (7 Nov): two-candidate-preferred (TCP) mean absolute error below AEF's on AEF-7
(ours 3.68, AEF 3.63 on the ledger's own seat sets). Research and the reasoning for this arm:
`docs/reviews/tcp-mae-vs-aef-2026-11-07.md`. Committed BEFORE any arm run.

**What the change does, in plain words.** NSW lets voters stop numbering boxes (optional
preferential voting), so many minor-party votes never reach either finalist. The published
model treats NSW like a full-preference state, which makes its NSW final-two margins too
narrow: the real margins are 1.41 times ours. `AUSPOL_NSW_EXHAUST=1` lets those votes exhaust
inside the seat simulation; `AUSPOL_ANCHOR_EXHAUST=1` makes the statewide two-party anchoring
use the same exhausted basis. Both switches exist and are off (`scripts/published_flags.R`).

**Arm:** `AUSPOL_NSW_EXHAUST=1 AUSPOL_ANCHOR_EXHAUST=1` against the published configuration.
Pairs: nsw2019 and nsw2023. Every other pair must be byte-identical.

## Metrics

TCP error is scored from the harness's own `backtest-<pair>-ourtcp*.csv`: per seat, our
predicted final two is the most frequent simulated pair (`freq`), and our TCP is that pair's
`f1_tcp_pct`, oriented to the real winner's side. A seat is scored only where that pair equals
the real final two at class level. Real final twos: nsw2023 from
`output/aef7-final-two-and-tcp-reference.csv`; nsw2019 from `output/nsw2019-tcp-official.csv`
(`scripts/build_nsw2019_tcp_official.R`, NSWEC's own pages, 93 of 93 seats, built today).

1. **Primary (decides):** nsw2023 TCP MAE on seats where the baseline's, the arm's and AEF's
   final two all match the real one. Pass: the change is negative and at least 1 SE from
   zero (SE of the mean per-seat paired difference, seats as the unit). Seat-set changes are
   reported.
2. **Second:** nsw2019 TCP MAE on seats where both baseline and arm match the real final two.
   Reported; it decides only through guard 1 and guard 4 below.

## Guards (refuse even if the primary passes)

1. Seat log loss on nsw2019 or nsw2023 worse by more than 1 SE (clustered on seat), on either.
2. TCP MAE on marginal seats (baseline predicted margin under 6 points) worse on either pair.
3. Any non-NSW pair not byte-identical.
4. Mean absolute ALP primary miss on nsw2019 above 1.547 (the refused 2026-09-27 anchoring arm).

**Amendment (7 Nov, before any arm result was read; the clause above is unedited).** The
1.547 in guard 4 is the 2026-09-27 STATEWIDE audit figure: nsw2019 mean |miss| over the ALP,
LNP and GRN statewide first preferences (baseline 1.027), from
`scripts/audit_statewide_forecast.R`, not a per-seat ALP mean. Guard 4 is scored on that
measure: the same audit run with the arm's two switches, `AUSPOL_AUDIT_TAG` set.
`score_tcp_arm.R` also prints a per-seat ALP primary miss; it is reported, not a guard.

## Predicted result, written before running

nsw2023 ALP v LNP TCP MAE 5.06 to about 4.5; slope of actual on predicted ALP TCP 1.41 to
about 1.27; 0-4 favourite flips in nsw2023. nsw2019: unknown sign; the earlier anchoring-only
arm hurt it.

## Procedure

1. Screen: `Rscript scripts/quick_arm.R "AUSPOL_NSW_EXHAUST=1 AUSPOL_ANCHOR_EXHAUST=1"
   --pairs=nsw2019,nsw2023` (default sims). A WORSE on any guard stops it here.
2. If it passes: the deciding run at 20,000 sims via `scripts/deciding_run.ps1`, all 22, with
   the same criteria. Only that run can ship it, and shipping goes to Pete with the split.

## RESULT

**Screen, 7 Nov 7:20pm** (1,000 sims, `quick_arm.R`, code ta1bc4f4; run once before
`dfd991ee`, both arm runs died on `exhaust names no party in shares: NAT`, fixed by dropping
the NAT entry, rate 0, from the harness). Baseline cache `ae3bb06e516f`, arm `a455afe21c3f`;
scored with `scripts/score_tcp_arm.R`.

TCP mean absolute error, points, lower is better (diff = arm - base, SE over seats):

| pair | set | n | base | arm | diff | SE |
|---|---|---|---|---|---|---|
| nsw2023 | **ours + AEF match real (primary)** | 79 | 4.906 | 4.561 | **-0.345** | 0.171 |
| nsw2023 | ALP v LNP | 65 | 5.059 | 4.735 | -0.324 | 0.199 |
| nsw2023 | marginal (base margin < 6) | 27 | 3.863 | 3.796 | -0.067 | 0.337 |
| nsw2019 | ours match real | 83 | 4.166 | 3.606 | -0.560 | 0.138 |
| nsw2019 | ALP v LNP | 72 | 4.025 | 3.413 | -0.612 | 0.155 |
| nsw2019 | marginal | 22 | 4.875 | 4.090 | -0.785 | 0.238 |

Slope of actual on predicted ALP TCP (1 = right width): nsw2023 1.412 -> 1.268 (predicted
1.27), nsw2019 1.111 -> 1.015. Favourite flips: 4 (nsw2023), 3 (nsw2019). Final-two set
changes: Heffron and Sydney (nsw2023), Lismore (nsw2019, arm now right).

- Primary: PASS in the screen (-0.345, 2.0 SE).
- Guard 1 (seat log loss): BETTER, nsw2023 0.1870 -> 0.1840, nsw2019 0.2711 -> 0.2647; pooled
  0.2290 -> 0.2243 (SE 0.0017).
- Guard 2 (marginal seats): both improve.
- Guard 3 (non-NSW byte-identical): by construction, `AUSPOL_NSW_EXHAUST` is read only by
  `scripts/backtest_candidate_nsw.R` (grep of R/ and scripts/).
- Guard 4: PASS outright. 0 of 1,302 predicted primary shares moved.

**Finding: `AUSPOL_ANCHOR_EXHAUST` is inert in what ships.** The live recipe does not anchor
the level (`R/forecast_mode.R:371`, `LR1 ... level NOT anchored` in every run log), and
Victoria's flows carry no exhaust (`scripts/fit_seats_full.R:1827`). The whole effect is the
simulation's exhaustion. The "pulls Labor down" concern was about anchoring and does not apply.

**Amendment (7 Nov, after the screen, visible):** the deciding run covers nsw2019 and nsw2023
only, not all 22. Guard 3 holds by construction (above), and rerunning 20 untouched elections
cannot change them.

**Deciding run, 7 Nov 7:15pm** (20,000 sims, `deciding-runs/20261107-1839-nsw-exhaust`, commit
a29cc7f3, 2,144 s). Seat log loss, lower is better: nsw2023 0.1891 -> 0.1846, nsw2019 0.3344 ->
0.3287; pooled 0.2618 -> 0.2566, change -0.0051 (SE 0.0006): guard 1 BETTER. 0 of 1,302
primary shares moved (guard 4). **The primary metric could not be scored at 20k:**
`deciding_run.ps1` copied back only allprobs/sharedetail before deleting its scratch, so the
TCP scenarios were lost (fixed for the next run). The TCP result stands on the screen above
(1,000 sims; a baseline-vs-baseline control on the AEF-7 pool moves 0.002).

AEF-7 TCP mean absolute error with the screen's nsw2023 swapped into the ledger (points, lower
is better): common seats (n 583) ours 3.6225 -> 3.5851, AEF 3.5925; headline ours 3.6788 (n 610)
-> 3.6359, AEF 3.6347 (n 600).

**Primary metric at 20k, published path (7 Nov 10:05pm).** The 8pm stage-6 rebuild's nsw2023
(`a592d60-g4d0be17`) and nsw2019 (`ac509c4-g4d0be17x`) ourtcp files against the pre-ship ones of
12:06-12:11pm, scored with `score_tcp_arm.R`: nsw2023 ours+AEF-matched (n 79) 4.919 -> 4.573,
**-0.346 (SE 0.172): PASS**; ALP v LNP -0.314; marginal -0.072; slope 1.412 -> 1.268. nsw2019
(n 83) 4.180 -> 3.608, -0.572 (SE 0.139); slope 1.113 -> 1.017. Matches the screen.
