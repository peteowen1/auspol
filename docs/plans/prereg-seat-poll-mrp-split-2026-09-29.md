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

## RESULT (rebuild Q vs P = v50, 2026-09-29; the text above is unedited)

**Refused.** fed2025 (primary) 0.2957 -> 0.3400 (+0.0443, SE 0.0371): worse,
not better. Ledger 0.2719 -> 0.2788 (+0.0070): the guard fails too. fed2022
0.2611 -> 0.2517 (-0.0094) and sa2026 (Mount Gambier) -0.0132 improved;
unpolled elections byte-identical; TCP MAE 3.791 -> 3.774. Weights: fed2025
w_direct 0.768 / w_mrp 0.175; fed2022 0.450 both; sa2026 0.373 / 0.131.

Why: the high direct weight trusts campaign-commissioned polls. McMahon
(Labor won) 0.959 -> 0.030, Bullwinkel 0.504 -> 0.036, Ryan 0.729 -> 0.265;
against Braddon 0.035 -> 0.537 and Banks 0.270 -> 0.517 improving. fed2025
direct polls include Climate 200 (11 seats) and uComms (11), often for
advocacy clients. **v50 (mode 1) stays.** Next, registered separately: the
direct weight fitted on independent polls only, with commissioned polls
(client named, or a campaign pollster) either excluded or given their own
partially pooled weight.
