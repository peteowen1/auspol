# Widening a losing party's seat share is a one-way ratchet. Not adopted.

Run 2026-08-19 against
[../plans/prereg-onp-seat-uncertainty.md](../plans/prereg-onp-seat-uncertainty.md),
committed before anything was measured.

**Not adopted; the adoption was reverted.** The measurement stands and the
mechanism it exposed is the reason.

## The constant came out where the plan expected

The rule fixed in advance: RMSE of the existing One Nation allocation against
South Australia 2026, rounded up to 0.5, refuse below 3.5.

| | |
|---|---:|
| RMSE against SA's 47 districts | **5.045** |
| → `ONP_SEAT_SD` | **5.5** |
| mean absolute error | 3.94 |
| worst district | 10.4 points |
| correlation, predicted vs actual | **+0.779** |
| RMSE of a flat allocation | 7.583 |

So the ordering carries real information — it beats a uniform allocation by 2.5
points of RMSE — and is still far less precise than a measured share. Exactly the
picture `fit_seats_full.R`'s own comment describes, now with a number on it.

The refusal condition did not fire: 5.5 > 3.5.

## Scores

| | criterion | result | |
|---|---|---|:--:|
| B1 | ALP/LNP medians move ≤ 2 | +0, +0 | pass |
| B2 | ONP median moves ≤ 2 | +1 | pass |
| **B3** | **ONP 90% seat interval must widen** | **7 → 7** | **FAIL** |
| B4 | primaries sum to 100, none negative | holds | pass |

## B3 failed, and it was the wrong criterion

The rule said a B3 failure means the wiring is wrong. It is not. The wiring is
correct and tested — a named per-party `seat_sd` matched by name, with a test
that fails if the matching is made positional. One Nation's per-seat
probabilities moved in 72 of 87 seats and no other party's distribution changed
materially.

**B3 measured the wrong quantity.** It assumed the width of the *seat-count*
distribution tracks the width of the *per-seat share* uncertainty. It does not:
across 88 seats, extra per-seat noise largely averages out of the total. The
seat-count interval moved 0–7 → 1–8, shifting rather than widening.

That is the second pre-registered criterion in three experiments that was
chosen honestly in advance and still could not see the thing it was meant to.

## The real reason not to adopt, which no criterion covered

| | before | after |
|---|---:|---:|
| ONP mean per-seat win probability | 0.0341 | 0.0442 |
| seats above 10% | 8 | **13** |
| **seats where ONP's probability rose** | | **71** |
| **seats where it fell** | | **1** |

**Adding symmetric noise to a party that is behind almost everywhere is not
neutral.** Upside noise lets it cross the winning threshold; downside noise costs
it nothing in a seat it was already losing. So "being more honest about our
uncertainty" came out as a systematic increase in One Nation's seat prospects —
its median rose from 3 to 4 and it cleared 10% in five more seats.

B2 passed only because that shift happened to be +1.

The plan anticipated the direction question and got it half right: it said the
write-up must report that widening "will let it win seats it currently cannot,
as well as lose ones it currently wins". It does not lose them. The ratchet is
one-way and the plan assumed a symmetry that a threshold-crossing quantity does
not have.

## What was kept

`simulate_seat_contests()` keeps the per-party `seat_sd` argument, with its
tests. A scalar behaves exactly as before, so the model is unchanged. The
capability is what a correctly-designed version of this would need, and it is
harmless sitting unused.

`scripts/calibrate_onp_seat_sd.R` is kept too: the 5.045 RMSE is the first
measurement of how good the One Nation allocation actually is, and it is worth
having whether or not it is used as an sd. The SA fetch now also writes
`ecsa-2026-sa-firstprefs.csv` — all-party first preferences across 47
districts — which is what made the measurement possible and will be reusable.

## What a correct version would have to do

Not "add uncertainty", but add it **without moving the expected seat count**.
Options, none attempted:

- Widen the allocation's *ordering* rather than its level — shuffle which seats
  get the high shares, preserving the statewide total exactly.
- Recentre after widening, so the expected number of seats won is unchanged and
  only the spread grows.
- Model the allocation error as what it is — a mis-ranking — rather than as
  independent per-seat noise, which is what makes it one-directional.

Each needs its own pre-registration, and the criterion must be one that can see
a level shift, since that is what this attempt produced and what B3 missed.
