# Pre-registration: trust the commission's two-candidate pair on election night (`pair_r`)

Written 2026-11-11 before any code or run. Pete chose "Build, fitted trust" (10 Nov 11:35pm).
Evidence and the Monash trace: `docs/reviews/night-final-pair-2026-11-10.md`.

## What it changes

`night_apply_tcp()` (`R/night_update.R`). Today: draws whose final two are the commission's counted
pair get their flow corrected; all other draws are untouched; and if the pair is the final two in under
`pair_min = 0.2` of draws the count is ignored. New, behind an argument `pair_r` (NULL = today's
behaviour, byte-identical):

1. `p` = share of draws whose final two is the counted pair.
2. Posterior share `q = p r / (p r + (1 - p)(1 - r))`, `r` = the commission's night-pair reliability.
3. The `hit` draws are corrected exactly as today. Then a share `(q - p) / (1 - p)` of the other draws
   is moved onto outcomes resampled from the corrected `hit` draws (winner, runner-up, share), with
   `totals` and `win_prob` updated the way the flip loop does now.
4. `pair_min` no longer applies (no cliff); with `p = 0` there is nothing to resample from and the seat
   is flagged as today.

`r` is fitted TIME-FORWARD per night: Beta prior mean 0.95 with weight 50 seats, updated with every
EARLIER night's count of pairs right / wrong (night pair = last pair in the feed before 3am; final pair
= the declared two-candidate result). fed2022 (21 May 2022): prior only, r = 0.95. vic2022
(26 Nov 2022): + fed2022 (148 of 151 right). fed2025: + fed2022 + vic2022. Live vic2026: all three.
The prior (0.95, 50) is a constant and goes in `docs/CONSTANTS.md`.

Counts (measured 10-11 Nov, before any arm ran): fed2022 148 of 151 right; vic2022 82 of 87 right (VEC feed,
last pair at 2am 27 Nov against the 15 Dec feed, matched by candidate id); fed2025 136 of 150 right. So
r = 0.950 (fed2022 night), 0.973 (vic2022), 0.964 (fed2025), 0.944 (live vic2026).

## Known answers, stated before the runs

- Monash fed2025 (AEC pair Labor v Liberal, right; the model ended at independent 0.99): the Liberal's
  probability must rise by the end of the night. If it does not, the arm is broken, whatever the totals say.
- Melbourne fed2025 (AEC pair Greens v Liberal, wrong): expected to get no better and possibly worse.
- A seat whose counted pair is already the draws' main pair (p near 1) must be almost unchanged.

## Runs

Real-night replays at 20,000 sims, baseline (`pair_r` NULL) against arm, same seeds:
fed2022 and fed2025 (`scripts/night_replay_feed.R`), vic2022 (`scripts/night_replay_vec.R`), with the
31 Oct shipped night settings (surge fade on, flow floor 0.01, median centre).

## Decision rule

- Primary: night-average seat-winner log loss (mean over replay times with anything counted, lower is
  better), pooled over the three nights, seats weighted equally.
- Ship (make it the `night_runner.R` default) if the pooled primary falls AND no night is worse by more
  than 0.005 AND the Monash known answer holds.
- Reported, not decisive: end-of-night seats wrong per night, and the per-time curve.

## What would make an apparent win unacceptable

- The whole gain coming from Monash while the other changed seats are worse on balance: report the
  pooled change with Monash removed; if that is worse by more than 0.002, do not ship.
- Any seat summing above 1 or a `totals` row not summing to the seat count (both asserted in the code).

## RESULT (11 Nov 7:40am; `deciding-runs/20261111-0020-night-pair/results.txt`, code 2b69cca1, 20,000 sims)

Night-average seat-winner log loss, pair minus base (lower is better), 389 seats over three real nights:

| night | seats | base | pair | diff | SE |
|---|---|---|---|---|---|
| fed2022 | 151 | 0.07439 | 0.07283 | -0.00156 | 0.00109 |
| fed2025 | 150 | 0.14451 | 0.14323 | -0.00128 | 0.00109 |
| vic2022 | 88 | 0.06287 | 0.06834 | +0.00546 | 0.00357 |

Pooled +0.00014 (SE 0.00101). Rule: pooled falls FALSE; no night worse by > 0.005 FALSE (vic2022 +0.0055,
Albert Park +0.27 and Hawthorn +0.15); Monash rises FALSE; without-Monash not worse by > 0.002 TRUE. **FAIL: not shipped,
`pair_r` stays NULL in `night_runner.R`.**

Caveat, recorded so this is not read as "trusting the counted pair does not work": Monash, the case the design
was built for, did not move at all (Liberal 0.00535 in both arms at every time). `night_apply_tcp()` skips a seat
when fewer than 2 draws hold the counted pair (`R/night_update.R:372`, `length(hit) < 2L`), and `pair_r` copies its
moved draws FROM those pair draws, so where the prior gives the counted pair ~0 draws there is nothing to copy.
Likely cause, not traced draw by draw (the replay does not save `night_tcp`). The version tested cannot reach its
own flagship case.
