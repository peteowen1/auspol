# The "called" rule on the real nights (2026-11-17)

Follows `night-called-rule-2026-11-10.md`, which tested the live page's rule (a seat is called when its leader is at
0.99 or more with 10% or more counted) on simulated nights only. This checks it on the three real nights we can
replay: fed2022 and fed2025 (`scripts/night_replay_feed.R`) and vic2022 (`scripts/night_replay_vec.R`).

**Result: the rule makes one wrong call across the three real nights, Melbourne fed2025 (Greens, won by Labor).** That is
the known final-pair defect (draws with a different final pair are never corrected), and the same seat the simulated
test found. No threshold removes it. Decision unchanged: keep 0.99 with 10% counted.

## Runs

- Full nights: `deciding-runs/20261114-1700-replay-namecase/replay/*-split-seats.csv` (the live night model: class
  split on, the time-forward pair_cal of the 14 Nov run). These have no per-seat counted share, so they give the rule
  with NO counted gate, an upper bound on wrong calls.
- Early night with the counted share: the same arms rerun 17 Nov to 8pm (fed 18:00-20:00 every 15 min; vic2022 the
  6:03pm, 7pm and 8pm snapshots), after both scripts started writing `counted` (the seat's share counted) beside each
  seat's probabilities. Output in the session scratchpad; about 13 min per federal night, 7 min for vic2022.
  Winners: `output/published-predictions.csv` (`won == TRUE`).

## Wrong calls

Seats with any wrong call (the leader is at 0.99 or more and is not the winner), split arm:

| Night | No counted gate (full night) | With the 10% gate (to 8pm) |
|---|---|---|
| fed2022 | Fowler: Labor 0.993 at 6:45pm and 7pm, with 0.3% counted | none |
| fed2025 | Melbourne: Greens from 6:30pm to the end (0.995 at the close) | none to 8pm (Greens 0.980 at 7.3% counted) |
| vic2022 | Mildura: independent 0.993 at 7pm, with 0.9% counted | none |

Seats called right with the gate by 8pm: fed2022 91, fed2025 81, vic2022 39 (without it 106, 96, 60).

Melbourne fed2025 crosses 0.99 again after 8pm and is still called Greens at the close (14 Nov full run: 0.9947 at
3am, the count well past 10%), so it is a wrong call under the gated rule too. Fowler and Mildura are calls from the
pre-count model or the first booths, which the 10% gate exists to block; both were wrong leaders still at 8pm
(Fowler Labor 0.94 at 18% counted in 2022; Mildura independent 0.97 at 15%), but under 0.99.

Not checked: the 14 Nov arms ran with `--cand-ref` off; the live website source defaults it to "copy"
(`R/night_runner.R`). Its 11 Nov prereg was carried by Monash and Mirani; whether it moves these three seats was not
checked. The 25 Nov dress rehearsal runs with it on.
