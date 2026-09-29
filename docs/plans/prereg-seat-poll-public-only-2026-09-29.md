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
