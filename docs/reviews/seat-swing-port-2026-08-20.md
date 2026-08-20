# The port works, changes nothing measurable, and cannot be tested on more data

Run 2026-08-20 against
[../plans/prereg-seat-swing-port-to-candidate.md](../plans/prereg-seat-swing-port-to-candidate.md),
committed before the port was written.

**Verdict per the rule: KEEP A. The Brier difference is −0.04 SE against a 2 SE
bar.** Not adopted.

## What was built

`seat_swing_adjustment()` now has a path into the candidate model, behind
`AUSPOL_SEAT_SWING_PORT` (default off). It applies the adjustment as a transfer
between the two majors in each seat.

**The conversion turned out not to be a free parameter at all.** A vote moved
from the LNP primary to the ALP primary was an LNP first preference contributing
1 to the Coalition's two-party total, and is now an ALP first preference
contributing 1 to Labor's. So shifting *x* points of primary shifts Labor's
two-party share by exactly *x* — one-for-one. `fit_seats_full.R` already relies
on this: its statewide anchoring moves `d` points from LNP to ALP and then
asserts the two-party mean matches the projection to within 0.3. M2's worry
about deriving a conversion factor dissolved.

## The result

NSW 2023, 88 seats, flow matrix from 2019, truth from the NSWEC's declarations:

| | arm A (as published) | arm B (with the port) |
|---|---:|---:|
| winner accuracy | 71/88 | **72/88** |
| Brier | 0.1468 | 0.1464 |
| calibration slope | 0.541 | 0.338 |

**Paired Brier difference: −0.0004, SE 0.0099 → −0.04 SE.**

That is as close to exactly nothing as a result gets. The adjustment itself is
not small — mean 0.000, **sd 2.564**, range −7.70 to +6.46 points — so it is
genuinely moving the primaries. It simply does not move enough *seats*: a two
or three point shift changes the winner only in a seat that was already close,
and there are few of those.

## The part that cannot be fixed by trying harder

**This is the only test that exists.**

- **Federal cannot test it.** `fed_swing` is empty in every federal seat file,
  correctly — there is no separate federal swing at a federal election. The M1
  gate would pass trivially because the adjustment would be zero everywhere,
  which tells us nothing.
- **Victoria 2022 cannot be backtested at all.** It needs 2018 seat-level first
  preferences, which do not exist in the repo and are not available from the VEC.

So the evidence is 88 seats, one election — precisely the sample size that today
said the independent model improved by 1.46 SE when six elections said it
degraded by 2.52. M4 pre-committed to reporting a single-election pass as weak.
This is not even a pass; it is a null.

## The tension worth deciding deliberately

Two true things point opposite ways:

- **`fed_swing` is the best-validated seat-level signal in this repo.** On the
  two state elections it cuts held-out seat-swing MAE from **3.9476 to 3.3655**,
  a 15% reduction, at t = 8.46. It predicts where a seat departs from the
  statewide swing better than anything else measured here.
- **The candidate model — the one that publishes every number — ignores it
  entirely**, and the only available test cannot detect whether including it
  helps or hurts seat outcomes.

Keeping it out means a validated signal is absent from the published forecast
because an 88-seat test could not see its effect. Putting it in means adding an
untested path to the published model on the strength of a null result.

**The rule says keep A, so arm A stands and nothing was changed.** The port is
committed but inert, and it is a one-line environment variable away from being
measured again the moment a second state election with seat-level first
preferences exists.

## What would settle it

Victoria 2018 or an earlier NSW pair — either would give a second election with
both `fed_swing` and seat-level first preferences. Victoria 2018 is documented
as unavailable from the VEC; earlier NSW elections are on the same
`pastvtr.elections.nsw.gov.au` system that yielded 2019 and 2023 today, under
different codes, and are the cheaper route.
