# Pre-registration: seat polls from public pollsters only (`AUSPOL_SEAT_POLL_SOURCES=public`)

Written 2026-09-29 18:20, before running. Follows the refused MRP/direct split
(`prereg-seat-poll-mrp-split-2026-09-29.md`): its 0.77 direct weight trusted
campaign polls (McMahon 0.96 -> 0.03, Bullwinkel 0.50 -> 0.04). Pete chose
the definition of "independent" (quiz, 2026-09-29): an allowlist of public
pollsters, with no sponsor recorded.

## The change

`seat_poll_shares()` keeps a poll when `AUSPOL_SEAT_POLL_SOURCES` is `"all"`
(v50/v51) or, under `"public"`, when it is:

- an MRP release (covers >= 20 seats, as before, or "MRP" in the name), or
- a direct poll by an allowlisted pollster (`PUBLIC_SEAT_POLLSTERS`:
  YouGov/Galaxy, Newspoll, RedBridge, DemosAU, Freshwater, EMRS, Resolve,
  Ipsos, Essential, Roy Morgan) **and** with no sponsor in `client`
  (recovered from Wikipedia footnotes, `8465ef8`).

Out: uComms, Climate 200, Utting, Compass, Insightfully, JWS, ER&C, unions,
campaign firms, "Unnamed". The filter sits in the one function both the
time-forward weight fit and the application read, so they cannot disagree,
and it reaches all six harnesses and the live run.

Known limit: fed2022's Wikipedia page records no sponsors, so its allowlisted
polls are kept on the pollster's name alone.

## Arms (one rebuild each, against v51 = rebuild R)

- **S (primary):** `AUSPOL_SEAT_POLL_BLEND=2` + `public`: the separate direct
  weight the queue asked for, now fitted on public direct polls only.
- **T (reported):** `AUSPOL_SEAT_POLL_BLEND=1` + `public`.

## Decision rule

- **Primary:** fed2025 seat log loss, paired by seat. Ship if it improves by
  more than 1 SE,
- **and** fed2022 does not worsen by more than 1 SE,
- **and** the ledger does not worsen.
- If both arms pass, ship the lower ledger. If neither, v51 stays.
- **Reported:** McMahon, Bullwinkel, Ryan winner probability; weights per
  target; polls kept/dropped per election; TCP MAE, primary RMSE.
- **Unacceptable:** any unpolled election moving (fed2007-2016, state pairs
  with no seat polls must be byte-identical).

## RESULT, arm S (rebuild S vs v51 = rebuild R, 2026-09-29 18:26; the text above is unedited)

**Refused on all three conditions.** Seat log loss, lower is better; SE paired by seat.

| check | v51 | S | change | SE | condition |
|---|--:|--:|--:|--:|---|
| fed2025 (primary) | 0.3061 | 0.2935 | -0.0126 | 0.0132 | better by > 1 SE: fails (0.95 SE) |
| fed2022 | 0.2638 | 0.2784 | +0.0146 | 0.0107 | worse by <= 1 SE: fails (1.4 SE) |
| AEF-7 ledger | 0.2760 | 0.2775 | +0.0015 | | not worse: fails |

Unpolled elections byte-identical (0 seats moved in 14 of 16). Primary RMSE
4.882 -> 4.975, TCP MAE 3.79 -> 3.82. Polls kept: fed2019 9/11, fed2022
159/182, fed2025 490/514, sa2026 0/1.

Weights: fed2025 w_direct 0.412 / w_mrp 0.186 (the refused all-polls split had
0.768 / 0.175, so the campaign polls were what inflated the direct weight);
fed2022 0.672 both (no earlier MRP), learned from 9 fed2019 polls in 6 seats.

The filter fixed what it targeted: McMahon 0.958 -> 0.964 (0.030 in the
refused split), Bullwinkel 0.465 -> 0.445, Ryan 0.733 -> 0.627. The new cost
is fed2022, where the higher weight pulled Kennedy (Katter) 0.82 -> 0.44 and
the teal seats (Goldstein 0.34 -> 0.19, Curtin 0.24 -> 0.13) toward an MRP
that under-rated them. That weight rests on 9 polls.

## RESULT, arm T (rebuild T vs v51, 18:36) and the decision

**Refused: fed2025 passes, fed2022 and the ledger fail.**

| check | v51 | T | change | SE | condition |
|---|--:|--:|--:|--:|---|
| fed2025 (primary) | 0.3061 | 0.3023 | -0.0038 | 0.0018 | better by > 1 SE: passes (2.1 SE) |
| fed2022 | 0.2638 | 0.2794 | +0.0156 | 0.0101 | worse by <= 1 SE: fails (1.5 SE) |
| AEF-7 ledger | 0.2760 | 0.2797 | +0.0037 | | not worse: fails |

Weights: fed2025 w 0.195 (se 0.045, 899 cells in 2 elections); fed2022 w
0.672 (raw 0.737, se 0.228, 22 cells in 1 election). McMahon 0.958 -> 0.962,
Bullwinkel 0.465 -> 0.534, Ryan 0.733 -> 0.773: all three better.

**Neither arm ships; v51 stays.** Both fail on the same thing: fed2022's
weight comes from fed2019 alone, and removing two sponsored fed2019 polls
moved it from 0.45 to 0.67. The filter helps fed2025 (T: 2.1 SE, all three
named seats better) but the fed2022 weight is too unstable to carry it. Next
lever, not tested here: shrink that weight harder when it rests on one
earlier election (the current shrink `w^3/(w^2+se^2)` barely moves 0.737 at
se 0.228), then re-run T. That is a new prereg, not an amendment.
