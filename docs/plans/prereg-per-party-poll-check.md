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

---

## Amendment, 2026-08-18: the first execution used the wrong fits

Found in review, after the check was written and run.

This plan says the historical record for the threshold is the rows emitted by
`scripts/test_others_bias.R`, and asserts that "those fits are endpoint fits
produced the same way the checks' fits are". **That is false.**
`test_others_bias.R` calls `trend_as_at()` with its defaults —
`sigmas = "default"`, `weights = "equal"`. The checks run on fits from
`fit_cycle_unfolded()` with **per-cycle sigmas and per-pollster noise factors**.
`CLAUDE.md` is explicit that these are two different model paths and that which
one is in play must be stated whenever either is touched. The plan asserted the
question away instead of checking it.

It is not a small difference. On the three cycles where both paths can be
compared, the fuller path's worst per-party deviation is **1.64× to 3.12×** the
default path's:

| cycle | fuller path | default path | ratio |
|---|---:|---:|---:|
| NSW 2023 | 0.81 | 0.26 | 3.12 |
| Victoria 2018 | 0.60 | 0.29 | 2.10 |
| Victoria 2022 | 1.50 | 0.91 | 1.64 |

So `BOUND = 2.5`, derived from default-path deviations, is far stricter than
this plan intended once applied to fuller-path fits — and both live "breaches"
it reported may be artefacts of that mismatch rather than real gaps.

**The rule is unchanged and stays as fixed above**: 99th percentile of
|fitted − mean of the final 90 days of polls|, rounded up to 0.5, refuse above
5.0. Only the data it is computed over is corrected, by
`scripts/calibrate_poll_tracking.R`, which refits the historical record with
`sigmas = "per_cycle"`, `weights = "firm_factors"`. This is fixing an execution
error, not choosing a new criterion.

**Read the corrected bound sceptically anyway.** A recalibration that loosens a
threshold and thereby clears a breach on the published forecast is exactly the
shape of a result that should not be taken at face value, however sound the
reasoning. The ratios above were measured before the recalibration ran and are
recorded here so the direction of the correction was on the record in advance.

## Amendment: two blind spots this check has, stated plainly

Neither was in the plan's original threats section. Both were found in review.

1. **Correlated small drift across every party.** The old sum check would catch
   five parties each off by a point in the same direction, because the sum
   would move 5. The per-party check cannot: each party is compared only to its
   own polls, and nothing looks at any cross-party quantity. The sum is still
   printed (`L3a`/`FL3a`/`NL3a`) but asserted on nothing, so this failure mode
   is now **reported and not guarded**. That is a genuine trade, not a strict
   improvement, and the original framing of this plan was wrong to imply
   otherwise.
2. **A party dropped from the fit entirely.** Both checks iterated only over
   fitted parties, so a party falling under a script's `n >= 8` / `n >= 25`
   inclusion floor was invisible to both. **Fixed**: `poll_tracking_check()` now
   iterates the union of fitted and polled parties and treats a polled party
   missing from the fit as a breach in its own right. This matters immediately —
   One Nation has exactly 8 polls in the NSW 2027 cycle against a floor of 8.

## Amendment: the recalibration ran, and the bound did not move

`scripts/calibrate_poll_tracking.R`, refitting the historical record with
`sigmas = "per_cycle"` and `weights = "firm_factors"` — the path the checks
actually assert on:

| | rows | cycles | 99th pct | BOUND |
|---|---:|---:|---:|---:|
| original (wrong path) | 138 | 33 | 2.478 | 2.5 |
| **corrected** | **154** | **33** | **2.429** | **2.5** |

**Unchanged at 2.5.** One historical row breaches (Victoria 1992 ALP, 5.05),
0.6% of the record. Victoria 2026 (2.78) and NSW 2027 (5.15) both still breach.

So the concern recorded above — that the live breaches might be artefacts of the
calibration mismatch — **was wrong, and is retracted**. The three-cycle ratio
that suggested it was computed on the *maxima of very small deviations* (0.26
against 0.81, and so on), where a ratio is noise rather than signal. The
99th percentile over 154 rows is the stable quantity and it barely moved.

Two things worth keeping from this anyway:

- The mismatch was real and was found by **review, not by this plan**. The plan
  asserted the two paths were the same instead of checking, and that assertion
  was false. It happened not to matter; the next one might.
- Sizing a discrepancy from three hand-picked comparisons produced a confidently
  wrong estimate of its direction and magnitude. The cheap check would have been
  to note that all three had deviations under 1.5, far below the percentile the
  bound is drawn from.
