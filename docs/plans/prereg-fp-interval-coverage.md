# Pre-registration: are our first-preference intervals calibrated?

Written 2026-08-19, **before** anything is measured. Committed before running.

## The question, and why it is asked this way

Our published first-preference intervals are much narrower than AE Forecasts'
— One Nation 18.7–22.8 against their 10.5–30.5, and similar ratios on every
party — while our **two-party** interval matches theirs almost exactly (10.0
points wide against 10.7).

**That comparison is a reason to look, not a reason to change anything.** A
forecast is not improved by resembling another forecast. The only thing that can
justify a change here is whether our intervals contain the truth as often as
they claim to, measured against actual results.

The repo already does this for two-party: 195 election-and-horizon pairs, 93%
coverage against a claimed 95%, reported on the page. **First-preference
coverage has never been measured.** That is the gap.

## The mechanism this is testing

Two suspects, and the test distinguishes them:

1. **The bands are the wrong quantity.** `build_page.R` takes `lo95`/`hi95` from
   the trend's own posterior at the last observed date. That is uncertainty
   about *where the party is now*, not about where it lands on election day.
   The two-party figure goes through `project_result()`, which inflates it by a
   measured projection error (`sd_err` ≈ 2.4–2.8 points). First preferences get
   no such inflation.
2. **The bands are simply too tight even for today.** The trend posterior could
   be over-confident about the present level irrespective of any projection.

Coverage measured **at the cycle endpoint against the actual result** cannot
separate these on its own, so both are reported: coverage of the raw trend band,
and coverage of the same band widened by the projection error.

## What is measured

Over the **33 completed cycles with complete actuals** (the set used by
`scripts/calibrate_poll_tracking.R`), for every fitted party:

- the fitted endpoint and its nominal 95% band;
- whether the actual first-preference result falls inside;
- the same for a nominal 50% and 80% band, since a single coverage number
  cannot tell a uniformly narrow interval from a badly-shaped one.

Reported per party class as well as pooled, because "Others" and a major party
have no reason to behave alike.

## Decision rule, fixed now

- **Coverage within 5 points of nominal** (i.e. 90–100% for a claimed 95%) →
  the intervals are fine. Report it, change nothing, and record that AE's wider
  intervals are not supported by this record.
- **Coverage below 90% for a claimed 95%** → the intervals are too narrow. Then
  and only then, test whether widening by the measured projection error brings
  coverage to nominal, and adopt only if it does.
- **Coverage above nominal** (too wide) → report; do not narrow. Over-wide
  intervals are the safer error and narrowing them needs its own case.

## Refusal section — what would make an apparent win unacceptable

- **R1 — no widening without a coverage deficit.** If coverage is already at
  nominal, do not widen anything, whatever AE publishes. This is the whole point
  of the exercise.
- **R2 — do not fix the pooled number by breaking a party.** If widening brings
  the pooled coverage to nominal while pushing any individual party class above
  nominal by more than 5 points, refuse: that is one party's deficit being paid
  for by another's excess.
- **R3 — the correction must be principled, not fitted.** If a widening factor
  is adopted it must be the **already-measured projection error** used for
  two-party, not a factor chosen to make coverage land on 95%. A number tuned to
  hit the target is not calibration, it is curve-fitting to the test.
- **R4 — endpoint coverage is not the same as the live 101-day-out claim.** The
  test measures the band at the cycle endpoint, where the polls are densest. The
  published Victorian interval is 101 days out. If a correction is adopted, say
  plainly that its calibration comes from the endpoint and the live horizon is
  longer, rather than implying the published band has been validated.

## What the criteria cannot see

- **Whether One Nation's Victorian primary is right.** This tests interval
  width, not central estimates. If our 20.7 is wrong, a wider band around it is
  still wrong in the middle.
- **Anything about seats.** Wider primary bands would flow into the seat model,
  but that consequence is not part of this test and must not be used to judge
  it — it is exactly the kind of downstream number that would tempt a
  post-hoc justification.
- **AE's calibration.** Nothing here says whether *their* intervals are right.
  They may be over-wide. This measures ours against results, and that is all.
