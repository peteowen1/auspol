# Pre-registration: do the seat-file fields we ignore predict seat swing?

Written 2026-08-19, **before** anything is measured. Committed before running.
Nothing beyond row counts has been looked at.

## What this is about

`load_seats()` reads five fields from the anchor's seat files and ignores six.
Among the ignored are four that Australian psephology treats as standard
seat-level predictors:

| field | Victoria 2022 | NSW 2023 | what it should mean |
|---|---:|---:|---|
| `fTransposedFederalSwing` | 88 | 92 | the federal swing in that area, mapped onto state boundaries |
| `bRetirement` | 18 | 21 | the sitting member is not recontesting |
| `bSophomoreCandidate` | 21 | 13 | first-term member defending for the first time |
| `bSophomoreParty` | 11 | 4 | the party gained the seat at the last election |

The seat model currently treats every seat's deviation from the statewide swing
as **noise**: `seat_swing_spread()` estimates a common spread and
`SEAT_SD = 3.5` applies it uniformly. If these fields carry signal, part of what
is modelled as noise is predictable.

## Why this is testable, unlike the last three things I tried

Both the predictors and the outcome are already in the anchor data, and they
join cleanly:

- **Predictors** come from the file written *before* an election
  (`2022vic.txt`, `2023nsw.txt`).
- **The outcome** — that election's actual per-seat two-party swing — is
  `fPreviousTppSwing` in the file written for the *following* cycle
  (`2026vic.txt`, `2027nsw.txt`).

88 Victorian and 92 NSW seats have both. **180 seats across two elections**, in
two different states, which is what makes a leave-one-election-out test possible
at all.

## Criterion, fixed now

**Out-of-sample mean absolute error of predicted seat swing**, leave-one-election
-out: fit on Victoria 2022 and score on NSW 2023, then fit on NSW and score on
Victoria. Report the pooled MAE across both held-out sets.

The baseline is what the model does today: **predict the statewide swing for
every seat**, i.e. a per-seat deviation of zero.

## Decision rule, fixed now

- **Adopt if the pooled out-of-sample MAE improves by more than 0.10 points.**
  Seat-swing residuals have a spread of about 4.2 points and a baseline MAE
  around 3.3, so 0.10 is roughly a 3% improvement — small, but this is a free
  predictor already sitting in a file we read.
- **Below 0.10** → do not adopt, and record the size so nobody re-opens it
  expecting more.

## Refusal section — what would make an apparent win unacceptable

- **R1 — one-state gains.** If the improvement appears in one held-out election
  and *reverses* in the other, refuse. With two elections that is the difference
  between a predictor and a coincidence, and pooling would hide it. Report both
  separately whatever happens.
- **R2 — backwards signs.** Retirement should *hurt* the incumbent party's
  swing; sophomore-candidate and sophomore-party should *help* it; the
  transposed federal swing should correlate *positively* with the state swing.
  If an adopted model gets a sign backwards, refuse — it is fitting noise, and
  a wrong-signed coefficient will do damage on a seat where it happens to be
  large.
- **R3 — spread inflation.** If including the predictors leaves the residual
  spread (`SEAT_SD`) unchanged or larger, refuse. The whole claim is that some
  of what is currently noise is signal; if the noise does not shrink, it was not.
- **R4 — the majors' seat counts.** If adopting moves ALP's or LNP's median seat
  count by more than 3, stop and explain before adopting. A 3% MAE improvement
  should not relocate the forecast.

## What the criterion cannot see

- **Nothing here touches minor parties.** The outcome is two-party swing, so
  this does not help the One Nation or independent threads at all, and must not
  be described as if it does.
- **Two elections is two.** Leave-one-election-out with n=2 means each fit is
  trained on a single state. A predictor that works in both is more credible
  than one that works in one, but neither is a general result.
- **`bConfirmedProminentIndependent` is excluded** even though Victoria 2022
  flags 14 seats, because the 2026 file does not carry it yet — so it cannot be
  used for the live forecast, and testing it here would tempt me to use it
  anyway.
- **The transposed federal swing is itself a modelled quantity** computed by the
  anchor, not a measurement. If it is wrong, this inherits that.
