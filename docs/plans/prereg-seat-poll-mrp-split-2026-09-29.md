# Pre-registration: separate seat-poll weights for MRP and direct polls (`AUSPOL_SEAT_POLL_BLEND=2`)

Written 2026-09-29, before running. Follows v50 (`prereg-seat-poll-blend-2026-09-29.md`),
where one pooled weight helped fed2022 (-0.0443) and hurt fed2025 (+0.0095, SE
0.0068). fed2025's cells are 85% MRP, and the TCP MAE rose from 3.68 to 3.79.

## The change

- **Poll type by structure, not by name.** A release (pollster + fieldwork dates) covering at
  least 20 seats of one election is `mrp`; anything else is `direct`. Names are
  unreliable: YouGov's 2022 MRP is labelled plain "YouGov". The seat, class and
  window rules are unchanged from v50. Each (seat, class) gets a mean over direct
  polls and a mean over MRP releases, each or both present.
- **Blend:** `share += w_d * (direct - share) + w_m * (mrp - share)`, with a
  missing type contributing 0. Only classes with share above 0; rows renormalised.
- **Weights for target T,** from earlier elections' cells only:
  - Pooled `w` exactly as v50: the prior.
  - Per type, the single-regressor estimate `b_t` (SE `se_t`, clustered on
    seat-election) on that type's own cells.
  - Partial pooling: `w_t = w + k_t * (b_t - w)`, with
    `k_t = tau^2 / (tau^2 + se_t^2)` and
    `tau^2 = max(0, (b_d - b_m)^2 / 2 - (se_d^2 + se_m^2) / 2)`. A type with no
    earlier cells gets `w_t = w`. So fed2022's MRP weight equals its pooled
    weight, because there is no earlier MRP.
  - Clamp each weight to [0, 1].

## Decision rule (against v50, rebuild P)

- **Primary:** seat log loss on fed2025 (the election v50 hurt), paired by seat.
  **Ship if** it improves by more than 1 SE,
- **and** fed2022 does not worsen by more than 1 SE,
- **and** the ledger does not worsen.
- **Reported:** TCP MAE, primary RMSE, `w_d` / `w_m` / `k_t` per target.
- **Unacceptable:** any unpolled election moving.
