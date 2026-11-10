# Pre-registration: night pair v2, a calibrated pair prior and draws built from the count (`pair_cal`)

Written 2026-11-11 8:20am, before any v2 code or run. Pete chose "Build v2" (11 Nov ~7:55am) after v1
(`prereg-night-pair-trust-2026-11-11.md`) FAILED without ever reaching Monash.

## Why v1 could not work, measured (probe replays 11 Nov, code 59dff525)

1. **The federal replay dropped Monash's count.** `scripts/night_replay_feed.R` kept a pair only if it matched
   the feed's LAST snapshot; the AEC flagged Monash maverick at 8:37pm and blanked it. Fixed in 59dff525
   (declared pair, as-at maverick). Coverage now fed2022 140 of 151, fed2025 127 of 150. All arms below rerun
   on the fixed replay, so v1's numbers are not reused.
2. **The model's own pair share is near zero where it matters.** Monash: Labor v Liberal held in 0.38% of draws
   at 7pm, 0.13% at 8pm (count: Labor 0.48, so the Liberal ahead). v1's posterior `q = p r / (p r + (1-p)(1-r))`
   with r = 0.964 gives q ~ 0.035-0.097: a model 99.6% sure of the wrong pair barely moves, because v1 treats
   that 99.6% as calibrated.
3. **v1 copied moved draws from the pair draws**, so with fewer than 2 pair draws (`R/night_update.R:372`) there
   was nothing to copy.

## What v2 changes (behind `pair_cal`, NULL = byte-identical to today)

In `night_apply_tcp()`, for every seat with a counted pair (a, b):

1. `h` = draws holding (a, b), `p_s = (h + 0.5) / (n + 1)` (no zero).
2. `q = plogis(alpha + beta * qlogis(p_s))`, the probability the counted pair is the final two given the model's
   pair share. `(alpha, beta)` come from `pair_cal` (fitted, below). `beta = 1, alpha = logit(r)` is v1's Bayes
   rule exactly; `beta < 1` says the model's pair share is over-confident.
3. The `h` draws are corrected as today (when `h >= 2`). Then `n_mv = round((n - h)(q - p)/(1 - p))` other draws
   (evenly spaced, no RNG) get the counted pair as their final two, with a's share
   `fp_a + f * rest`, `f` at the normal quantiles `(i - 0.5)/n_mv` of N(m, s): m = the corrected flow when `h >= 2`,
   else the count's own flow `obs$flow`; s = `obs$flow_se` floored at `flow_sd_floor`. Winner, runner-up,
   share, `totals` and `win_prob` updated through `move_draws()` as now.
4. With `pair_cal` set, `pair_min` and the `h < 2` skip no longer apply.

## Fitting `(alpha, beta)`, time-forward

Data: every division where the commission showed a pair, at the first replay time it shows: `p_s` of that
pair in the base replay's draws, and `y` = the pair is the declared final pair (by candidate for the AEC; by the
VEC's final pair for vic2022, the 15 Dec feed match already used for v1's r). Wrong pairs are included (their
`p_s` needs no booth votes).

MAP logistic regression on EARLIER nights only, priors alpha ~ N(logit(r_tf), 1) and beta ~ N(1, 0.5), r_tf as in
v1 (0.950 / 0.973 / 0.964 / 0.944 live). fed2022 has no earlier night: prior means, so v2 there = v1's q plus
part 3. vic2022 fits on fed2022; fed2025 on fed2022 + vic2022; live vic2026 on all three. Fitted values and their
n printed and written to `docs/CONSTANTS.md` before the arm runs.

## Known answers, stated before the runs

- Monash fed2025: the Liberal's probability must be higher in v2 than base at 7pm and 8pm (the times the pair is
  on screen). If not, the arm is broken.
- Melbourne fed2025 cannot be scored for this (its night pair was wrong, so it has no booth TCP and stays out of
  the observations); reported as untestable, not as a pass.
- Seats with `p` near 1 must be almost unchanged (max |win prob change| reported for p > 0.9).

## Runs

Fixed replay (59dff525 or later), 20,000 sims, same seeds, three real nights (fed2022, fed2025, vic2022), three
arms: base, v1 (`pair_r` at v1's r), v2 (`pair_cal` at the time-forward fit). v1 is rerun only so the comparison is
on the same replay; it is not up for shipping again.

## Decision rule (v1's, unchanged; v2 against base)

- Primary: night-average seat-winner log loss, pooled over the three nights, seats weighted equally (lower is
  better). SE clustered on seat.
- Ship (make it the `night_runner.R` default) if the pooled primary falls AND no night is worse by more than 0.005
  AND the Monash known answer holds.
- Unacceptable even if those pass: the pooled change with Monash removed worse by more than 0.002; any seat summing
  above 1.
- Reported, not decisive: v1 against base on the fixed replay; end-of-night seats wrong; Albert Park and Hawthorn
  vic2022 (v1's two worst seats, +0.27 and +0.15) under v2.
