# Pre-registration: MRP seat pattern with its own half-life (2026-11-23)

Written and committed before any result of this line is read. Successor to
`prereg-seat-poll-relative-2026-10-07.md`, which was refused before its screen;
that file is left unedited.

## Why

Pete, 23 Nov 2026, after an MRP sweep for vic2026: the only Victorian MRP with
per-seat primaries is YouGov for Common Threads (16 Jun-10 Jul 2026, n 4,003,
88 seats). The shipped blend halves a poll's weight every 21 days (fitted,
`seat_poll_decay_params("vic2026")`), so at 141 days out it would pull a seat
about 1% of the way to its number. Pete chose to test it as a seat PATTERN:
how a seat differs from the release's other seats, re-centred on our own
level, with the MRP's age mattering less.

## What changed since the 7 Oct refusal

- That refusal had two grounds. (1) fed2025's release offsets against our
  level were small (-0.85 to +1.84 points), so re-centring changed little
  there. vic2026 is different: July had L/NP 26, against 31 to 33 in November
  polls. (2) The fed2022 YouGov IND offset wiped out Goldstein and Kooyong.
  Since then MRPs no longer vote on independents (SPN2, "MRPs do not vote on
  independents"); stage 0 reports which classes an MRP still votes on.
- New here: the MRP half-life is fitted separately, so age is a measured cost.

## Stage 0: does an old MRP's seat pattern predict? (scratch script, no R/ change)

For each fed2025 MRP release (and fed2022's one) and each class among ALP,
LNP, GRN, ONP, over the seats it covers where our pre-blend share is above 0:

    x = (poll - release mean) - (ours - our mean over the same seats)
    y = actual - ours

with `ours = xgb_pred_seat` from `output/forecasts.csv`. Fit `y ~ x` per
release (pooled over classes, class fixed effects) and by age band, slope with
SE clustered on seat. n cells and n seats printed for every row.

Known-answer checks, run first: the final YouGov release (fieldwork ending 29
Apr 2025, days before polling day) should show a clearly positive slope; the
same release with x shuffled across seats within class should show about 0.

**Decision rule.** The releases more than 140 days out are three, all
Accent/RedBridge, all fed2025: one pollster, one election. If their pooled
slope is within 1 SE of 0, stop and take the table to Pete; nothing is built.
If it is positive beyond 1 SE, build the arm below.

## Stage 1 (only if stage 0 passes): the arm

`AUSPOL_SEAT_POLL_MRP_PATTERN="1"` (new; default "0"):

- Each MRP release's figure for a class is re-centred on our pre-blend share
  over the seats it covers, in both the time-forward fit and the apply (the
  7 Oct formula), so a release contributes only its seat pattern.
- MRP polls get their own half-life, fitted time-forward on the re-centred
  errors with the existing prior (`SEAT_POLL_HALFLIFE_PRIOR`, 60 days, log sd
  0.7). Printed.
- The pull for a July-age cell must not exceed the stage-0 slope for that age
  band; printed beside it.
- The July YouGov rows go in a gitignored file read beside `seat_polls.csv`.

Screen: `scripts/quick_arm.R "AUSPOL_SEAT_POLL_MRP_PATTERN=1"` (AEF-7). Guard:
pooled seat log loss not worse by more than 1 SE, and no election worse by more
than its own SE. A screen reading 0.0000 is NOT a pass: fed2025's fitted
half-life is prior-dominated and vic2026 is not scored. The deciding evidence
is stage 0 plus a live with/without walk of vic2026 (seat totals, mean shift
per class, which must be about 0 by construction, and the ten largest moves).

## What would make an apparent win unacceptable

- The stage-0 slope at 140+ days comes from one release only.
- The live walk shows a non-zero mean shift per class (the re-centring failed).
- The July pattern contradicts a fresh direct seat poll (Pakenham, Hawthorn)
  and outweighs it.

Ship goes to Pete with these facts beside it: the release was commissioned by
Common Threads, a pro-Treaty group; its fieldwork predates the change of
premier and the close of nominations; and the shipped
`seat-poll-blend-vic2026.csv` on the public release would carry its 88 seats.
