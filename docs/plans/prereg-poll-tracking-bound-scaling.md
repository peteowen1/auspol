# Pre-registration: should the poll-tracking bound scale with poll count?

Written 2026-08-25, **before** anything is fitted, computed or scored.
Committed before running.

## Why this is being asked

`NL3` breaches on NSW 2027: One Nation fitted **19.52 against 24.67** from
**3 polls** in the 90-day window, a 5.15-point deviation against
`POLL_TRACKING_BOUND = 2.5`. `fit_nsw.R` halts and the scheduled job is red.

The immediately preceding experiment
([prereg-nsw-onp-walk-threshold.md](prereg-nsw-onp-walk-threshold.md))
**aborted**: the model-side fix it proposed has one usable historical
observation and that one points the other way. So the model side is not where
this gets resolved, and what is left is the check itself.

## The mechanism, stated before measuring

`poll_tracking_check()` compares a fitted endpoint against `poll_mean`, the
**mean of the polls in a 90-day window**. That mean is itself an estimate with
its own sampling error, roughly `sd_obs / sqrt(n)` for `n` polls in the window.

So even a **perfect** fit produces a non-zero `|fitted - poll_mean|`, of
expected size proportional to `1 / sqrt(n)`. A single fixed bound therefore
does not hold every party to the same standard: it is structurally harsher on
thinly-polled parties, and its effective false-positive rate rises as `n`
falls.

The observed breaches are consistent with exactly that, which is what prompted
this:

| cycle | party | n in window | deviation | verdict at 2.5 |
|---|---|---:|---:|---|
| Victoria 2026 | ONP | 10 | 2.39 | passes |
| NSW 2027 | ONP | **3** | **5.15** | breaches |

`min_polls = 3L` means NSW 2027's One Nation is asserted on by **one poll's
margin** — at 2 polls it would be reported and not asserted at all.

**This is a hypothesis, not a finding.** The alternative is that One Nation
really is fitted too low in NSW 2027 and the check is doing its job. Both are
live and the analysis below is designed to separate them.

## The obvious objection, stated first

**This change makes a red build green, which is the worst possible reason to
change a check.** It is the same objection
[prereg-per-party-poll-check.md](prereg-per-party-poll-check.md) named when
this check replaced the sum check, and the same commitments apply:

1. The scaled bound is produced by a **rule fixed here**, applied to the
   historical record, **before** anyone looks at whether NSW 2027 passes under
   it. The script must compute and print the bound function first.
2. It **must be shown to fail** on a deliberately broken input before it is
   trusted, per the standing repo rule.
3. **If the new rule passes everything, including rows we already believe are
   wrong, that is a failure of this plan** and the fixed bound stays.
4. **If NSW 2027 still breaches under the correctly-derived scaled bound, that
   is the answer** and it will be reported as such. The purpose here is to find
   out whether the check is mis-specified, not to get NSW green.

## The data

`output/poll-tracking-calibration.csv`, produced by
`scripts/calibrate_poll_tracking.R`: 154 (cycle, party) rows over 33 cycles,
on the **same model path the checks assert on** (per-cycle sigmas, per-pollster
noise factors). Columns include `n` — the poll count in the window — which is
the variable this plan is about and which the original calibration recorded
but never used.

Regenerated rather than reused, so the row set is current.

## Clustering, settled BEFORE the criterion rather than after

The immediately preceding experiment aborted because its abort gate counted
rows while its standard error was clustered on cycles. That mistake is not
repeated here, so the unit is fixed now:

- **`n` varies WITHIN a cycle** (minor parties are broken out by fewer firms
  than the majors), so this question is not purely between-cycle and the
  effective sample is larger than 33.
- **But rows within a cycle share a fit and a poll set**, so they are not
  independent either.
- **Therefore: every standard error and every interval reported here is
  clustered on the cycle**, and the script must **print the number of cycles
  and the within-cycle spread of `n`** before any estimate is read.
- **Abort condition, fixed now: if fewer than 20 cycles contain at least two
  distinct values of `n`, stop.** Without within-cycle variation in `n`, the
  effect of `n` is not separable from the effect of the cycle, and any
  relationship found would be a cycle effect wearing a poll-count costume.

## The question, and the test

**Does `dev` scale with `1 / sqrt(n)`?**

Estimate on the 154 rows, cycle-clustered:

- `dev ~ 1/sqrt(n)`, reporting the coefficient, its clustered SE, and the ratio
  between them.
- Reported alongside, not decided on: `dev ~ n` and `dev ~ log(n)`, so a
  relationship that is real but the wrong shape is visible rather than forced
  into the mechanism's preferred form.

## Decision rule, fixed now

**Adopt a scaled bound only if all three hold:**

1. The `1/sqrt(n)` coefficient is **at least 2 clustered SE from zero**. Two SE
   is this repo's standard bar.
2. `1/sqrt(n)` is **not beaten by `n` or `log(n)`** on the same clustered
   criterion. If a different shape fits better, the mechanism argued above is
   not the one operating and the bound should not be built on it.
3. The scaled bound is derived by the **same 99th-percentile rule** as the
   fixed one — the smallest `k` such that `dev_i <= k / sqrt(n_i)` holds for 99%
   of historical rows — **not** by any rule chosen after seeing which cycles it
   clears.

**Otherwise the bound stays fixed at 2.5**, `NL3` keeps breaching on NSW 2027,
and the honest conclusion is that the check is right and One Nation is fitted
too low there.

## Refusal: what would make an apparent WIN unacceptable

Named in advance, per `CLAUDE.md`, because this project has twice refused a
result on grounds invented afterwards.

- **R1 — the anchor must still breach.** Victoria 1992 ALP, deviation 5.05, is
  the one historical row the fixed bound catches. If the scaled bound clears it,
  refuse: a rule that catches nothing is not a check.
- **R2 — it must not be a uniform loosening.** If the scaled bound exceeds 2.5
  at **every** `n` present in the record, refuse. That is a loosening wearing a
  mechanism's clothes, and the mechanism predicts it should be *tighter* at
  large `n`, not merely looser everywhere.
- **R3 — it must not raise the historical breach count to zero.** The fixed
  bound breaches 1 row in 154 by construction. If the scaled bound breaches 0,
  refuse — the 99th percentile was chosen over the maximum precisely so that one
  pathological row cannot set a bound nothing can breach.
- **R4 — Victoria's live cycle must not silently flip.** Victoria 2026 currently
  passes at 2.39 on 10 polls. If the scaled bound makes it *breach*, that must
  be reported prominently and is a reason to stop, not an incidental side
  effect: the published forecast's own check changing state is exactly what
  nobody would notice.
- **R5 — `min_polls` must not move.** NSW 2027 One Nation is asserted on by one
  poll's margin (3 against a floor of 3). Raising `min_polls` to 4 would make
  the breach disappear by declining to look, and **that is forbidden here
  regardless of what the scaling analysis finds.** If it is ever worth doing it
  needs its own plan, argued on its own terms, not smuggled in beside this.

## What this cannot see, stated in advance

- **Whether One Nation is genuinely fitted too low in NSW 2027.** This plan can
  only say whether the *check's bound* is mis-specified. If the scaled bound
  clears NSW 2027, that does **not** establish the fit is good — only that this
  particular check can no longer distinguish it, which is a weaker claim and
  must be reported as such.
- **The 2027 cycle has no result** and cannot be scored against truth. Every
  number here is about the historical record.
- **`window = 90` is not tested.** A different window changes `n` for every row
  and might dominate the effect being measured. Fixed at 90 throughout; a
  window sweep would be a different plan.

## Prediction, written before running

Recorded so a result in the wrong place reads as a bug rather than a bonus.

Expect the `1/sqrt(n)` relationship to be **present and real** — it follows
from `poll_mean` being a mean, which is arithmetic, not a modelling
assumption — but the coefficient to be **imprecisely estimated**, because most
of the 154 rows sit at large `n` where the predicted effect is small and
nearly flat.

Expect **NSW 2027 One Nation to breach anyway.** A 5.15-point deviation is
large even against a `1/sqrt(3)`-scaled bound unless the fitted scale is
implausibly wide, and the repo's own record says this party is the one it
already over-states. **If NSW 2027 passes comfortably, be suspicious of the
derivation rather than relieved.**

---

## Result, 2026-08-25: ABORTED at the separability gate, by one cycle

Run by `scripts/test_bound_scaling.R`. **No coefficient was estimated, no
bound was derived, and NSW 2027 was never examined.** The gate is the first
thing the script does and it stopped there.

| | |
|---|---:|
| rows | 154 |
| cycles | 33 |
| cycles containing >= 2 distinct values of `n` | **19** |
| pre-registered floor | **20** |

Nineteen against twenty. The data was regenerated first and reproduces the
original calibration exactly (99th percentile 2.429 → bound 2.5, one breaching
row: Victoria 1992 ALP at 5.05 on n=10), so this is not a data problem.

### The floor was NOT lowered to 19, and that is the whole point

One cycle short is the single most tempting moment to move a threshold, and
moving it is the rationalisation pattern this repo records twice already:
`min_n` was not lowered to rescue refusal M2, and `EXHAUST_LIMIT` was not
raised to admit WA 2001 — *"moving a threshold to admit the one election that
failed it is choosing the number after seeing the answer."*

Everything downstream of that gate would be worthless if the gate were moved
now, because the criterion would have been chosen to admit this data.

### Where this plan was genuinely weak, recorded rather than acted on

**The floor of 20 was not derived from a power calculation.** It was chosen as
a round number that felt sufficient. That is a real weakness — the same class
of weakness as the row-versus-cluster mix-up in the preceding plan — and the
correct response is to write better floors in future plans, **not** to treat
this one as soft because it was arbitrary. An arbitrary floor still binds; it
just should not have been arbitrary.

For a future attempt: derive the floor from the power to detect a `1/sqrt(n)`
coefficient of the size the mechanism predicts, and do it before looking at
how many cycles qualify.

### Two consecutive aborts is itself the finding

[prereg-nsw-onp-walk-threshold.md](prereg-nsw-onp-walk-threshold.md) aborted on
6 clusters against a floor of 10. This one aborts on 19 cycles against 20.
**Both were well-posed questions and neither can be answered from this
corpus.**

That is worth stating plainly rather than treating as two pieces of bad luck:

- The **model-side** question (should a thin, fast-moving party estimate its
  own volatility?) has **one usable historical observation**, and it points
  against the change.
- The **check-side** question (should the bound scale with poll count?) needs
  within-cycle variation in `n` that this record barely has, because most
  cycles poll every party on the same polls.

So **`NL3`'s breach on NSW 2027 cannot be resolved by measurement on the
available record**, from either direction. Anyone who tries a third variant of
either question should expect the same and should say so in advance.

### What must NOT happen next

- **`POLL_TRACKING_BOUND` must not be raised** to clear NSW. It was derived by
  a rule fixed in advance and re-derives to the same 2.5 today.
- **`min_polls` must not be raised from 3 to 4.** NSW 2027's One Nation is
  asserted on by exactly one poll's margin; raising the floor makes the breach
  vanish by declining to look. Forbidden by this plan (R5) and still forbidden
  now that the plan has aborted.
- **The gate floor of 20 must not be quietly lowered** in a later run of the
  same script.

### What is left, and it is a judgement rather than a measurement

`fit_nsw.R` halts, the scheduled job stays red, and the honest position is that
**One Nation may well be fitted too low in NSW 2027 and this record cannot
settle it.** The remaining options are decisions, not experiments, and belong
to Pete:

1. **Leave it red.** The breach is information; a red build that means
   something is better than a green one that does not.
2. **Let `fit_nsw.R` report the breach instead of halting**, as `fit_vic.R`
   already does for the live target cycle (`fit_vic.R` writes `L3-BREACH.txt`
   and continues, so the forecast still publishes and `run_all.R` fails at the
   end). This changes *what halts*, not *what is asserted* — the breach stays
   visible and nothing is silenced. It is the only option here that does not
   touch a calibrated threshold.
3. **Accept that NSW 2027's One Nation trend is unreliable** and mark it as
   such wherever it is used, rather than trying to fix the fit or the check.
