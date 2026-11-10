# Election night: draws with a different final pair are never corrected (2026-11-10)

Read-only trace. No model change, no replay run (the deciding run had the machine).

## Where it happens

`night_apply_tcp()` (`R/night_update.R:315`). For a seat with a commission two-candidate count of pair
(a, b), the draws whose final two are (a, b) (`hit`) get their preference flow corrected by the count.
Every other draw is left exactly as it was. And if (a, b) is the final pair in under `pair_min = 0.2` of
draws (line 331), the count is ignored altogether and the seat is only flagged.

So the count's strongest message, "these are the final two", is never used. A seat whose draws mostly
have a different pair keeps its afternoon answer however much is counted.

## Monash fed2025: the case

- The AEC counted Labor v Liberal from 6:01pm and never changed it (`output/night-feed/division-progress-fed2025.csv`).
- The final two WAS Labor v Liberal; the Liberal won (`external/elections/aec-fed-tcp.csv`).
- The model ended the night at independent 0.99, so (Labor, Liberal) must have been the final pair in
  under 20% of draws and the count was thrown away (inferred from the code path; the per-draw pairs were
  not saved, so UNVERIFIED until a fed2025 replay prints `night_tcp`'s `pair_share` for Monash).

Melbourne fed2025 is a different failure: the AEC counted Greens v Liberal all night and the final two was
Labor v Greens, so the commission's pair was wrong there. The fix below must not trust the pair blindly.

## How often the commission's night pair is wrong

Last night pair in the feed against the final two-candidate pair, party classes matched (KAP, One Nation and
Centre Alliance mapped to our classes):

| Election | Seats | Night pair wrong | Which |
|---|---|---|---|
| fed2022 | 151 | 3 | Brisbane, Groom, Wannon |
| fed2025 | 150 | 14 | Bean, Farrer, Hunter, Newcastle, Watson, Brisbane, Griffith, Franklin, Calwell, Flinders, Fraser, Melbourne, Mayo, Fremantle |

17 of 301 (5.6%); the AEC changed no pair during either night (`tcp_pair_changed` all 0). 2025 was much
worse than 2022 (9.3% against 2.0%), so the rate varies by election. The VEC's rate is not measured yet
(vic2022 feed, `scripts/night_replay_vec.R`'s inputs).

## Proposed fix (not built; for Pete)

Treat the commission's pair as evidence with a measured reliability `r`, instead of all (pair matches) or
nothing (pair_min cliff):

- Prior: `p` = share of draws whose final two is the counted pair.
- Posterior: `q = p r / (p r + (1 - p)(1 - r) / K)`, where `K` is the number of other pairs the draws hold
  (or simply `(1 - p)(1 - r)` as a first version).
- Move a share `(q - p) / (1 - p)` of the other draws onto outcomes drawn from the corrected `hit` draws,
  updating `totals` and `win_prob` the way the flip loop already does. `pair_min` goes (no cliff).
- `r` fitted, shrunk toward the pooled rate (17/301 now; vic2022 from the VEC feed), not hard-coded.

Monash with `p = 0.1`, `r = 0.944`: `q = 0.65`, so most draws move to the counted Labor v Liberal contest
and the Liberal's chance rises with the count instead of staying near 0. Melbourne with the pair wrong:
the same step would push draws toward a Greens v Liberal contest that never happened. That is the cost,
and why `r` must be measured, and why the replays on fed2022, fed2025 and vic2022 decide it.
