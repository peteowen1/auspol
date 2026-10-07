# Pre-registration: release-relative seat-poll blend (2026-10-07)

Written and committed before any result of this arm is read.

## Why

fed2025 seat polls had Labor too low across the board: over the 94 Labor-won
AEF-7 seats with a seat poll in the 90-day window, the flat poll mean was
**-6.81 points** from actual (RMSE 7.98); latest-poll-only -5.38 (7.19). The
blend (`AUSPOL_SEAT_POLL_BLEND="1"`) reads polls as absolute levels, so a
release's overall level error lands in every seat it covers: Hunter, Bruce,
Macarthur, Greenway, Holt, Chifley, Shortland, Lingiari and McMahon each moved
4-12 points away from the result after the xgb stage. Filtering by pollster
(`AUSPOL_SEAT_POLL_SOURCES=public`) was screened the same day and refused
(AEF-7 ledger +0.0093, SE 0.0087; fed2022 +0.0389): the polls carry seat
information worth keeping.

## Arm

`AUSPOL_SEAT_POLL_RELATIVE="1"` (new; default "0"). For each MRP release
(a release covering >= 20 seats, the existing structural test), each class's
poll figure is shifted by that release's mean gap to OUR pre-blend share over
the seats it covers:

    poll_adj[s, c] = poll[s, c] + mean_{s' in release, our[s', c] > 0}(our[s', c] - poll[s', c])

so a release only contributes how a seat differs from the release's other
seats. Direct (single-seat) polls are unchanged. "Our" is `xgb_pred_seat`
in the time-forward weight fit (`seat_poll_weight()`) and the pre-blend
`shares` matrix in `seat_poll_blend_apply()`, the same quantity the blend
moves. The weight is refitted on the adjusted cells (printed).

Only fed2022 (1 release) and fed2025 (6) have MRP releases; vic2026 has none,
so the live forecast changes only through the refitted weight. The arm is
backtest-only until the live path (shipped `seat-poll-blend-vic2026.csv`) is
wired; with the flag on and the poll sources absent the code stops.

## Screen and criterion

`scripts/quick_arm.R "AUSPOL_SEAT_POLL_RELATIVE=1" --pairs=fed2022,fed2025,nsw2023,sa2026`
(every pair whose cells or weight the arm can move; the public screen changed
only these plus fed2019, which has no MRP release and precedes both).

- **Primary (targeted):** share-level squared error on changed cells in
  fed2025 and fed2022, lower is better.
- **Guard:** seat-winner log loss, pooled over the screened pairs and on the
  AEF-7 ledger subset; WORSE by more than 1 SE on either stops the line.
- Within 1 SE or better on both guards with a lower primary -> full 20k arm
  before any ship decision, then Pete.

## What would make an apparent win unacceptable

- The gain comes only from fed2025 while fed2022 log loss is worse by more
  than its own SE (a fix for one year's polling miss, not a better blend).
- fed2022 independents (Goldstein, Kooyong, Curtin, Wannon, Mackellar) lose
  their pull: YouGov 2022 filed them under OTH and the release-mean shift
  for IND/OTH must not wipe them out. Report those seats' winner primary
  before and after.
- The refitted weight moving by more than 0.15 from the shipped weight
  without the per-pair numbers explaining it.
