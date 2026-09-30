# Pre-registration: two-party seat-poll figures from DIRECT polls only (`AUSPOL_SEAT_POLL_TPP_SOURCE=direct`)

Written 2026-09-30 13:20, before building. **Suggested by a result**: the
joint blend (J4, `prereg-seat-poll-joint-fp-tpp-2026-09-30.md`) helped where
polls are few and direct (nsw2023 -0.20, fed2019 -0.12, qld2020 -0.05) and
hurt where MRP releases dominate (fed2025 +0.046, fed2022 +0.013). An arm
chosen after seeing that split needs a guard against simply fitting it.

## The change

Mode 3 (joint primary + two-party weights) with the two-party figures taken
only from direct polls: a release covering fewer than 20 seats and without
"MRP" in its name. Primary figures still come from every poll, as in v50.
Weights refitted jointly on earlier elections as before; flows by date.

## Decision rule (against v53 = output/rebuild-V53, rebuild from stage 6)

1. **Primary: seat log loss on polled seat-elections** (all polls, the same
   357 seat-elections as J4), paired by seat. Must improve by more than 1 SE.
2. **Guard against fitting J4's split: fed2022 and fed2025 polled seats
   together must not worsen by more than 1 SE.**
3. Guard: pooled seat log loss (CR2) and primary RMSE not worse by more than
   1 SE.
4. Reported: weights per target, nsw2023 Parramatta and Penrith, ledger.
