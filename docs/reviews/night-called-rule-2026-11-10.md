# Election-night "called" rule, tested on the simulated replays (2026-11-10)

The live page (`inthegame-blog/politics/live.qmd:202`) draws a seat as called when its leader is at
`CALLED_PROB = 0.99` or more with `CALLED_COUNTED = 10` % or more of the seat counted. That rule was a
placeholder from the prototype. This tests it.

Data: the seven simulated replays of 30 Oct (`docs/reviews/night-replay-*-seats-2026-10-30.csv`; fed2022,
fed2025, nsw2023, qld2024, sa2026, vic2022, wa2025; 681 seats). Each file gives the actual winner's
probability at each fraction of the seat's night vote counted. 1,000 simulations per fraction, so a
probability near 0.99 carries about +-0.003 of simulation noise. A seat counts as called wrong if, at any
fraction at or above the minimum, the actual winner's probability is at or below 1 - threshold (so some
other party is at or above the threshold).

| Threshold | Min share of night vote counted | Seats called right (ever) | Seats called wrong (ever) |
|---|---|---|---|
| 0.95 | 5% | 593 | 12 |
| 0.98 | 5% | 514 | 6 |
| 0.99 | 2% | 383 | 6 |
| 0.99 | 5% | 383 | 3 |
| 0.99 | 10% | 381 | 3 |
| 0.99 | 30% | 380 | 3 |
| 0.995 | 10% | 153 | 3 |

At 0.99 the three wrong calls are the same at every minimum from 5% to 30%, and stay at 0.995:

- **Melbourne fed2025** (wrong at the end of the count) and **Monash fed2025** (wrong from 10%): the open
  night-model defect "draws with a different final pair are never corrected" (`NEXT-STEPS.md`, NIGHT MODEL).
- **Mirani qld2024** (wrong at the end of the count only): not traced.

So the threshold is not what makes these calls wrong; a higher bar or a later start removes none of them and
only calls fewer seats. Below 5% counted, three more wrong calls appear (Higgins 2022, Holsworthy 2023,
Bundaberg 2024).

**Decision: keep 0.99 with 10% counted.** It is as safe as anything tested, and 10% gives a margin over the
5% point where early wrong calls stop. The page's `counted_pct` is the share of ALL expected votes, a little
below the replay's share of the night vote, so 10% on the page is slightly later than 10% here.

Caveats, not yet checked: these are simulated nights (booths in random order, indicative clock). The real
fed2022, fed2025 and vic2022 nights (`scripts/night_replay_feed.R`, `scripts/night_replay_vec.R`) need the
per-seat counted share added to their seat output and a harness night-state dump; each is a heavy R run.
Removing the remaining wrong calls means fixing the final-pair defect, not moving the threshold.
