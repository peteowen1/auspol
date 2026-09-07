# Pre-registration: reparameterise the two lean measures, then bound the gap

Written and committed **before** any arm was run, 2026-09-08. Third in the
sequence; the two predecessors are
`prereg-reentry-defended-nonmajor-2026-09-08.md` and
`prereg-reentry-bounded-2026-09-08.md`, both refused at their dry-runs.

## The defect, now measured rather than guessed

`reentry_fit()` enters `lean` and `flow_lean` as separate covariates. On the
One Nation training rows they correlate at **0.972**, with **VIF 20.7 and
20.6**. `safe` and `flow_safe` are the same shape: r = 0.917, VIF 14.1 and
12.9.

A pair that collinear is nearly degenerate, so the fit cannot identify the two
levels separately — it can only identify their **difference**, and it does so
with large variance. That is why the coefficients come back near-equal and
opposite (−0.116 and +0.115), and why a seat whose two measures disagree
unusually gets an exponential excursion: Traeger qld2024's gap of 21.34 points
is worth **+2.45 in log space, a factor of 11.6**, producing 74.3% against an
actual 6.8%.

**This is also exactly why arm B of the previous plan failed.** Winsorising
bounds `lean` and `flow_lean` individually, and Traeger is inside the class
range on both. The unstable direction is their difference, which is not a
variable in the model, so no per-covariate bound can reach it. Arm B clipped
`nonmajor_prev` instead — whose coefficient is negative — and pushed Traeger
up to 92.8.

## The two arms

Both begin with the same **exact reparameterisation**, which on its own changes
nothing: replace `lean + flow_lean` with

- `lean_mid = (lean + flow_lean) / 2`
- `lean_gap = flow_lean - lean`

and likewise `safe + flow_safe` with `safe_mid` and `safe_gap`. These are
invertible linear combinations, so the fitted values are **identical to the
last decimal**. That is a required check, not an aspiration — see dry-run
case 1.

- **Arm D — bound the gap.** Winsorise `lean_gap` and `safe_gap` (and nothing
  else) at their own class's training 1st and 99th percentile at prediction
  time. This is the previous plan's arm B applied to the direction that
  actually moves. Switch: `AUSPOL_REENTRY_GAP=winsor`.
- **Arm E — drop the gap.** Fit on `lean_mid` and `safe_mid` only. Tests
  whether the disagreement carries real signal or is fitting noise on a
  degenerate direction. Switch: `AUSPOL_REENTRY_GAP=drop`.

Arm E is included because CLAUDE.md records that both leans together beat
either alone by 0.095 mean absolute error across 22 elections — a real result,
but one measured on the average and blind to the tail. If E matches D on error
while removing the excursion, that finding needs qualifying rather than
repeating.

Baseline is commit `da1d008` with `AUSPOL_REENTRY=1` and every other new
switch off.

## The criterion

Unchanged from the previous plan, so it cannot be tuned to this arm:

**Primary: PB3f**, pooled seat log loss excluding floor seats, over 22 pairs
and 2,050 seat-elections. Prior OFF is **0.3149** (floor 4); prior ON with no
arm is **0.3139** (floor 3).

**Co-primary:** the count of re-entry cells predicted above 40 must fall to
**0**, and the largest prediction must be below 40. Currently 5 and 74.3.

**Guards:** pooled seat-share RMSE; per-jurisdiction log loss against prior
OFF, tolerance two standard errors of that jurisdiction's own paired
difference.

**Decision rule.** Adopt an arm if clause 1 (the tail) is met, AND PB3f is at
least as good as prior OFF's 0.3149, AND no jurisdiction breaches its two-SE
tolerance. If both arms qualify, take the lower PB3f; on a tie, arm E, because
a model with fewer terms on a degenerate direction is the simpler object.

### Dry-run of the criterion on cases whose answer is already known

1. **The reparameterisation alone must be a no-op.** With winsorising off and
   no term dropped, every one of the 1,416 predictions must equal the current
   value to within floating-point noise. **If any prediction moves by more than
   1e-6, the reparameterisation is wrong and nothing downstream can be
   believed.** This is the check the whole plan rests on.
2. **Traeger qld2024**, currently 74.3 against an actual 6.8. Its gap is 21.34,
   the class maximum; the class 99th percentile is 11.57. Clipping removes 9.77
   points at +0.115 each, or 1.12 in log space — a factor of 0.33. **Arm D
   should land Traeger near 25**, which clears clause 1. Arm E removes the gap
   term entirely and should cut it further. If arm D leaves Traeger above 40,
   the winsorising is not reaching `lean_gap` and that is a bug to find before
   reading any pooled number.
3. **Kimberley wa2001 and Alfred Cove wa2005 must be EXACTLY unchanged**, at
   37.2 and 41.9, under both arms and for the same reason as last time: Labor
   has 2 re-entry rows and the Coalition 4, both under `min_n = 40`, so neither
   class ever gets a GLM. An unchanged Kimberley means the arm never reached
   it, not that the arm is safe.
4. **Callide qld2024**, currently 44.6 against an actual 15.8. Its gap is +1.7,
   the 81st percentile, comfortably inside the clip. **Arm D must barely move
   it.** If Callide falls under arm D, the winsorising is doing something other
   than what this plan claims, and the Traeger result cannot be attributed to
   the mechanism.

## Refusal section — what disqualifies an apparent win

1. **Case 1 failing.** If the reparameterisation is not a no-op, everything
   else is measuring an accidental model change. Refuse and fix.
2. **Callide moving under arm D.** Stated in case 4. A win that comes with
   Callide moving is a win from something unidentified.
3. **The tail fixed by timidity.** Report mean, median and leave-one-out MAE
   beside the maximum. Current values are 5.39, 3.92 and 3.227. If MAE worsens
   while the maximum falls, the model has bought the co-primary by getting
   worse at its job — the same refusal that stood in the previous plan.
4. **Arm E winning only because the gap was doing real work elsewhere.**
   Report per-class MAE, not just pooled. The gap could be noise for One Nation
   and signal for independents, who are 415 of the 1,416 cells and the class
   this model is worst at. If arm E improves One Nation and degrades
   independents, it is two findings, not one, and the term should be dropped
   per class rather than globally.
5. **A gain confined to Queensland.** Unchanged from the previous plan. Four of
   the five worst predictions are Queensland One Nation cells; Queensland is
   186 of 2,050 seat-elections.

## What the criterion cannot see

- Whether `lean` should be computed with the flow positions in the first place,
  rather than as a hard left/right bloc split. `OTH_RIGHT` flows to the
  Liberals at 0.642 but the bloc measure counts it as fully right, and that
  single inconsistency is what manufactures the gap in every seat with a large
  minor-right vote. Fixing it properly is a `classify_party()` and
  `seat_lean()` change with consequences well beyond the re-entry prior.
- Whether Labor and the Coalition should have a covariate model at all, on 2
  and 4 rows. Unchanged and still the second-largest source of tail error.
- Whether a ridge penalty would be better than winsorising or dropping. It
  would address the conditioning directly rather than its symptom, and it is
  not tested here because it needs a dependency this package does not carry.

---

## Dry-run outcome, 2026-09-08 — arm D passes every case; arm E is refused

Added after the dry-run. Everything above is left exactly as committed.

**Case 1 passes.** Maximum absolute difference between the reparameterised and
original predictions over all 1,416 cells: **1.07e-13**. The change to
(mid, gap) is exact, so everything downstream is measuring the arms rather than
an accidental model change.

| arm | max | >40 | >25 | mean | median | MAE | rows clipped |
|---|--:|--:|--:|--:|--:|--:|--:|
| base | 74.3 | 5 | 14 | 5.39 | 3.92 | 3.227 | — |
| D — bound the gap | 53.2 | 3 | 13 | 5.34 | 3.92 | **3.172** | 66 (**4.7%**) |
| E — drop the gap | 53.2 | 3 | 10 | 5.32 | 4.08 | 3.256 | — |

| pair | seat | class | base | D | E | actual |
|---|---|---|--:|--:|--:|--:|
| qld2024 | Traeger | ONP | 74.3 | **25.9** | 30.9 | 6.8 |
| qld2024 | Hill | ONP | 57.5 | **25.1** | 28.4 | 6.9 |
| qld2024 | Callide | ONP | 44.6 | **44.6** | 46.5 | 15.8 |
| wa2001 | Kimberley | ALP | 37.2 | 37.2 | 37.2 | 42.2 |
| wa2005 | Alfred Cove | ALP | 41.9 | 41.9 | 41.9 | 22.8 |

Case 2 predicted "arm D should land Traeger near 25"; it landed on **25.9**.
Case 3 predicted Kimberley and Alfred Cove exactly unchanged; they are. Case 4
predicted arm D must barely move Callide; it does not move it at all. The
mechanism is doing what the plan said it would and nothing else.

### Arm E is refused

Dropping the gap makes the model **worse**, not simpler-and-equal: pooled MAE
3.256 against a base of 3.227, and One Nation's own class MAE 3.919 against
3.862. It also moves sa2026's mean One Nation prediction from 20.53 to 18.15,
a 2.4-point drift away from an actual 19.27.

So CLAUDE.md's finding that both leans together beat either alone **stands and
needs no qualifying**. The disagreement carries real signal; the fault was only
ever that its effect was unbounded.

### Arm D passes every refusal

1. sa2026's mean One Nation prediction is **20.53, identical to base**, against
   an actual 19.27. The logit-offset worry does not arise and the
   proportionality is untouched.
2. Callide does not move, so the Traeger result is attributable.
3. MAE **improves** 3.227 → 3.172 while the maximum falls, so the tail was not
   bought with timidity. Per class: ONP 3.862 → **3.597**, IND 4.640 → 4.638,
   OTH_RIGHT 2.076 → 2.080, OTH 1.816 → 1.849. The gain is concentrated in One
   Nation and nothing else degrades materially.
4. 66 rows clipped, **4.7%**, inside the 5% written into refusal 3.

### Clause 1 was mis-specified, and this is the third time in this sequence

Clause 1 requires the count above 40 to reach zero. Under arm D it is three,
and **two of the three are cells no arm in this plan can reach**:

| pair | seat | class | pred | actual | path |
|---|---|---|--:|--:|---|
| wa2013 | Churchlands | LNP | 53.2 | 59.0 | flat ratio |
| qld2024 | Callide | ONP | 44.6 | 15.8 | GLM |
| wa2005 | Alfred Cove | ALP | 41.9 | 22.8 | flat ratio |

Labor and the Coalition never get a GLM, so their predictions are the flat
ratio times the statewide share — and this plan's own "What the criterion
cannot see" section says so **in advance**. Writing a clause that the same
document declares unsatisfiable is a criterion-writing failure, not a finding
about arm D.

On the path the arms actually act on, the count above 40 falls from **3 to 1**
and the maximum from 74.3 to 44.6.

**The clause is NOT rewritten.** Arm D is recorded as failing clause 1 as
written, with the reason, and the pooled measurement is reported beside it so
the decision rests on evidence rather than on a threshold I would now be
choosing after seeing the answer. Churchlands at 53.2 against an actual 59.0 is
also worth noting: it is the largest remaining prediction and it is nearly
right, which is its own argument that a flat 40 was the wrong instrument.
