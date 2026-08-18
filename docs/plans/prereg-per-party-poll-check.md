# Pre-registration: replace the endpoint-sum check with a per-party one

Written 2026-08-18, **before** the threshold is computed and before the check
is written. Committed before running.

## Why the current check is being replaced

`L3` / `FL3` / `NL3` require each cycle's fitted first preferences to sum to
100 ± 5. `NL3` fails at 94.1 and has kept the scheduled job red.

The diagnosis is in
[../reviews/nl3-sum-is-one-nation-2026-08-18.md](../reviews/nl3-sum-is-one-nation-2026-08-18.md).
Two things it established:

1. **The model does not promise the sum.** Each party is fitted independently
   with shrinkage toward its previous result. The coupling work measured that
   forcing the shares to sum costs **0.33 points of first-preference MAE**, so
   the untidiness is bought on purpose.
2. **The sum check pointed at the right cycle and the wrong quantity.** The
   shortfall is One Nation sitting 3–4 points below its own recent polling while
   every other party tracks within about a point. A sum can only say "something
   is off by 6"; it cannot say which party or by how much, and it stays silent
   when two parties err in opposite directions.

So the sum is a weak proxy for a question that can be asked directly: **is each
party's fitted endpoint close to the polls it was fitted to?**

## The obvious objection, stated first

This change makes a red build green, which is the single worst reason to change
a check. Three commitments against that:

- The threshold is **computed by a rule fixed here**, before anyone looks at
  whether the live cycles pass.
- The new check **must be shown to fail** on a deliberately broken input before
  it is trusted, per the standing repo rule.
- If the new check passes everything including cycles we already believe are
  wrong, **that is a failure of this plan** and the old check stays.

## What the new check asserts

For each fitted party in each cycle, compare the fitted endpoint against the
mean of that party's polls in the final `W` days of the cycle.

- `W = 90` days. Chosen to match the window already used in
  `scripts/test_others_bias.R`, not tuned here.
- Parties with fewer than `MIN_POLLS = 3` polls in that window are **reported
  but not asserted on** — there is nothing to be close to. The count of such
  parties is printed, so a cycle where the check is mostly vacuous is visible
  rather than silently passing. This matters: `all()` over an empty set is
  `TRUE`, which is exactly how a check in this repo has passed before.
- The assertion is `max |fitted − mean(polls in window)| <= BOUND`.

## How BOUND is chosen — the rule, fixed now

`BOUND` is **the 99th percentile of |fitted − mean(polls in final 90 days)|
over the historical record**, rounded UP to the nearest 0.5.

The historical record is the (cycle, party) rows already emitted by
`scripts/test_others_bias.R` into `output/others-bias-tests.csv`: complete
actuals only, six regions, 1990 onward. Those fits are endpoint fits produced
the same way the checks' fits are.

The 99th percentile, not the maximum: one pathological historical cycle should
not set a bound so loose that nothing can ever fail. Not the 95th: a check that
fails 1 cycle in 20 by construction is noise.

**I do not know whether Victoria 2026 or NSW 2027 passes this bound.** That is
the point of writing it down now.

## Decision rule, fixed now

- **Both live cycles pass and the broken-input test fails as designed** →
  adopt. Replace the sum assertion in `fit_vic.R`, `fit_federal.R` and
  `fit_nsw.R`; keep printing the sum as a reported number with no assertion, so
  it stays visible.
- **A live cycle fails** → adopt anyway, and the build stays red on a check
  that now names the party and the size of the gap. A red build with a precise
  message is strictly better than a red build with a vague one. Do **not**
  widen `BOUND` to clear it.
- **The bound comes out above 5.0** → do not adopt. A per-party tolerance
  looser than the old whole-cycle sum tolerance would be weaker than what it
  replaces, and this plan would have talked itself into a worse check.
- **The broken-input test does not fail** → do not adopt, and record why.

## Threats, stated before the run

- **The historical fits and the live fits are not identical objects.** History
  is scored at election day with the cycle complete; the live cycles are scored
  today with polling still arriving. The window is the same 90 days in both, but
  a live cycle's last 90 days may be thinner. The `MIN_POLLS` floor and the
  reported count of unasserted parties exist for this.
- **This checks the fit against the polls, not against the truth.** A cycle
  where the polls are badly wrong passes. That is deliberate — `T2` in the
  Others work established that the model tracking its inputs is correct
  behaviour — but it means this check cannot detect a polling failure, and
  nothing here should be read as claiming otherwise.
- **One Nation in Victoria is the case that motivated this**, at a gap of 3.15.
  If the computed bound lands just above 3.15 the check will look tuned even
  though the rule was fixed first. If that happens, say so plainly in the
  write-up rather than presenting it as a clean pass.
