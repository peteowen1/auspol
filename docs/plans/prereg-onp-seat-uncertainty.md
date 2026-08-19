# Pre-registration: give an allocated seat share the uncertainty it deserves

Written 2026-08-19, **before** anything is measured or built. Committed before
running.

## The defect

`fit_seats_full.R` draws each seat's outcome with two sources of spread: a
statewide per-party sd (`psd`, from the trend's own posterior) and a single
within-region seat deviation, `SEAT_SD = 3.5`, **applied identically to every
party**.

That is wrong for One Nation, and only for One Nation. Every other party's seat
share starts from what it actually polled in that seat in 2022 and is moved by a
statewide swing. One Nation polled 0.22% statewide in 2022 and has nothing to
swing from, so its seat share is *constructed*: seats are ordered by Greens share
using a coefficient fitted federally, then quantile-mapped onto South Australia's
observed 2026 spread.

`fit_seats_full.R:90-96` says so plainly:

> Its allocation is the weakest part of this model … Its ordering beats a
> uniform allocation by only 0.122 MAE: trust the ONP TOTAL, not any one seat.

**And then the simulation treats it as exactly as certain as a measured share.**
A number the code says not to trust seat-by-seat carries the same 3.5-point seat
sd as a number measured in that seat.

## Why this is the blocker for two other threads

- [independent-projection-2026-08-19.md](../reviews/independent-projection-2026-08-19.md):
  the independents fix failed its gate because One Nation is projected at 26.7%
  in South-West Coast against the independent's 23.1%. With no uncertainty on
  that 26.7, the independent is behind in **every** draw.
- [independents-cannot-win-2026-08-19.md](../reviews/independents-cannot-win-2026-08-19.md):
  the same ordering puts One Nation above locally-measured independents in
  Mildura and Shepparton.

Neither is fixable on the independent side. If the model is not sure One Nation
will poll 26.7% in Warrnambool — and the code says it is not — then the
independent should win some of the draws.

## What is proposed

Give a party whose seat share is **allocated rather than measured** its own,
larger seat-level sd. Concretely: `SEAT_SD` stays 3.5 for parties projected from
their own 2022 seat result; One Nation gets `ONP_SEAT_SD`.

This changes **uncertainty, not the point estimate**. One Nation's statewide
total and its per-seat ordering are untouched. The claim being corrected is not
"One Nation will do worse" — it is "we do not know this seat by seat, and the
model should stop pretending otherwise".

## How ONP_SEAT_SD is chosen — the rule, fixed now

**The root-mean-square error of the existing allocation method, measured against
South Australia 2026, rounded up to the nearest 0.5.**

South Australia held its election in March 2026 and
`external/elections/ecsa-2026-sa-onp-shares.csv` carries One Nation's actual
first-preference share in all 47 districts. So:

1. Apply the current method to SA: order its districts by Greens share with the
   same federally-fitted coefficient, quantile-map onto the same spread.
2. Compare predicted against actual, per district.
3. `ONP_SEAT_SD` = RMSE of that comparison, rounded up to 0.5.

**Why this measures the right thing.** The quantile mapping forces the predicted
*marginal distribution* to match SA's by construction, so the magnitude cannot be
wrong — only the ordering can. The residual is therefore exactly the ordering
error, which is exactly the uncertainty currently missing.

**Refusal condition, fixed now:** if `ONP_SEAT_SD` comes out **below 3.5**, do
not adopt. That would mean the allocation is *more* precise than a measured
share, which would contradict the code's own assessment of it and is far more
likely to mean the test is in-sample than that the method is that good.

## Acceptance criteria, fixed now

- **B1** — ALP and LNP median seat counts move by **no more than 2** each. This
  is a change to how confident the model is about one party, not a re-forecast.
- **B2** — One Nation's **statewide seat median** must not move by more than 2.
  Widening a distribution should fatten its tails, not relocate it. A large move
  means the change is doing something other than adding uncertainty.
- **B3** — One Nation's 90% seat interval must get **wider**, not narrower. If it
  does not, the change has not taken effect and nothing downstream is meaningful.
- **B4** — the primaries still sum to 100 per seat and no party is negative.

**Deliberately NOT a criterion:** whether the independent in South-West Coast
reaches any particular probability. That is the outcome this work is motivated by,
and making it the acceptance test would be fitting to the case that prompted the
change. It is **reported** and not decided on.

## Decision rule, fixed now

- **All four pass and `ONP_SEAT_SD` ≥ 3.5** → adopt.
- **`ONP_SEAT_SD` < 3.5** → refuse, per the condition above.
- **B2 fails** → the change is shifting the forecast, not widening it.
  Investigate before adopting; do not accept a level change as a side effect.
- **B1 fails** → something outside One Nation moved. Do not adopt until
  explained.
- **B3 fails** → the wiring is wrong. Fix and re-run before judging anything.

## Threats, stated before the run

- **SA is one election.** An RMSE from 47 districts of a single state is a thin
  basis for a constant applied to Victoria, and no amount of the criteria passing
  changes that.
- **The measurement is partly in-sample.** The magnitudes were quantile-mapped
  onto SA's spread in the first place, so SA is not a clean holdout. The
  *ordering* coefficient is federal and so is out-of-sample, which is why the
  residual is still informative — but this should not be described as an
  out-of-sample test, and the refusal condition above exists partly to catch it.
- **Widening One Nation's seat uncertainty will let it win seats it currently
  cannot, as well as lose ones it currently wins.** Both directions are
  consequences of the same change and the write-up must report both, not just
  the one that helps independents.
- **This does not make the allocation correct.** It makes the model honest about
  not knowing. A genuinely better allocation — Victorian federal 2025 seat
  results mapped to state districts, say — is a different and larger piece of
  work, and this change should not be mistaken for it.

---

## Result, 2026-08-19: NOT ADOPTED, and reverted

[../reviews/onp-seat-uncertainty-2026-08-19.md](../reviews/onp-seat-uncertainty-2026-08-19.md).

The constant came out as the plan expected: RMSE **5.045** against SA's 47
districts → `ONP_SEAT_SD` **5.5**, clear of the 3.5 refusal floor. The ordering
beats a flat allocation by 2.5 RMSE (r = +0.779), so it carries real information
and is still far less precise than a measured share.

B1, B2 and B4 passed. **B3 failed** — and it was the wrong criterion. It assumed
the seat-COUNT interval widens when per-seat share uncertainty does. Across 88
seats the extra noise averages out of the total, so the interval shifted (0–7 →
1–8) rather than widening. The wiring is correct and tested.

**The reason not to adopt is one no criterion covered.** One Nation's win
probability rose in **71 of 87 seats and fell in 1**. Adding symmetric noise to a
party that is behind almost everywhere is a one-way ratchet: upside lets it cross
the threshold, downside costs nothing where it was already losing. "More honest
about uncertainty" came out as a systematic increase in its seat prospects, and
B2 passed only because that shift happened to be +1.

This plan half-anticipated it — it required the write-up to report that widening
"will let it win seats it currently cannot, as well as lose ones it currently
wins". **It does not lose them.** The plan assumed a symmetry that a
threshold-crossing quantity does not have.

Kept: the per-party `seat_sd` capability in `simulate_seat_contests()` with its
tests (a scalar behaves exactly as before, so the model is unchanged), the
calibration script, and the new all-party SA first-preference extract.
