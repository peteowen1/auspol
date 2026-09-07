# Pre-registration: stop the re-entry prior producing impossible forecasts

Written and committed **before** any arm was run, 2026-09-08. Successor to
`prereg-reentry-defended-nonmajor-2026-09-08.md`, whose dry-run refused it and
whose diagnosis this plan is built on.

## The defect

`reentry_fit()` is a quasipoisson GLM with a log link and an offset of
`log(state_pcv)`. It is **unbounded**, and its response is a share of 100.

Five of 1,416 re-entry cells are predicted above 40%, and the worst is
Traeger qld2024 at **74.3% against an actual 6.8%**.

The cause is not the non-major covariate — that was tested and refused. It is
that `lean` and `flow_lean` enter with near-equal, opposite coefficients
(−0.116 and +0.115 for One Nation), so the model effectively uses the
**disagreement between the two lean measures** at about +0.115 per point.
Traeger's gap is 21.34 points, the largest in the class, worth +2.45 in log
space — a factor of 11.6, and the whole of the blow-up.

Two things follow, and they suggest different fixes:

- The **response** is unbounded when it should be a share.
- The **covariate** is extrapolating: Traeger is at the 100.0th percentile of
  its class's gap distribution and Hill at the 99.7th.

## The three arms

Separated because they act on different things and are not assumed additive.

- **Arm A — bounded link.** Refit as `quasibinomial(link = "logit")` on
  `pcv/100` with offset `qlogis(state_pcv/100)`. A prediction above 100 becomes
  impossible by construction. At small shares the logit offset behaves like the
  log one, so the proportionality that made the offset beat a fitted term in
  South Australia is approximately preserved; at large shares it saturates.
  Switch: `AUSPOL_REENTRY_LINK=logit`.
- **Arm B — bounded covariates.** Keep the log link, but winsorize every
  covariate at its own class's training 1st and 99th percentile **at prediction
  time only**. The fit is untouched; the model is simply not asked to
  extrapolate past the data it saw. Switch: `AUSPOL_REENTRY_WINSOR=1`.
- **Arm C — both.**

Baseline is the re-entry prior as it stands at commit `13e856f`, with
`AUSPOL_REENTRY=1` and both new switches off.

## The criterion

**Primary: PB3f, pooled seat log loss excluding floor seats**, over all 22
pairs and 2,050 seat-elections. Two reference points, both measured 2026-09-08:

| configuration | PB3f | floor | PB3 |
|---|--:|--:|--:|
| prior OFF (shipped) | 0.3149 | 4 | 0.3412 |
| prior ON, no arm | 0.3139 | 3 | 0.3337 |

**Co-primary, specific to this defect:** the count of re-entry cells predicted
above 40 (currently **5**) and the largest single prediction (currently
**74.3**).

**Guards:** pooled seat-share RMSE, and per-jurisdiction log loss for all six.

**Decision rule.** Adopt an arm if all of:

1. the count of predictions above 40 falls to **0**, and the largest prediction
   is below 40; AND
2. PB3f is at least as good as **prior OFF** (0.3149) — the point is to make
   the prior shippable, so beating the plain prior is not sufficient; AND
3. no jurisdiction's log loss worsens against prior OFF by more than **two
   standard errors of that jurisdiction's own paired difference**, computed at
   scoring time and reported.

If two arms qualify, take the lower PB3f; on a tie there, the simpler arm (A or
B over C).

Clause 3 is written in standard errors because its flat-0.01 predecessor
refused the prior on South Australia's +0.0162, which is 0.63 SE on 47 seats.
The SEs measured on the prior-on arm were sa 0.0257 and qld2024 0.0079, so the
thresholds this implies are roughly 0.051 and 0.016 respectively.

### Dry-run of the criterion on cases whose answer is already known

1. **Traeger qld2024**, predicted 74.3, actual 6.8. Arm B caps its gap at the
   class 99th percentile of 11.57, cutting 9.77 points × 0.115 ≈ 1.12 in log
   space, a factor of 0.33 — so roughly 25, still far too high but no longer
   impossible. Arm A should cut it further because 74.3 is deep into the
   saturating region. **If either arm leaves Traeger above 40, clause 1 fails
   and that arm is refused.**
2. **Kimberley wa2001 and Alfred Cove wa2005 must be EXACTLY unchanged.**
   Labor has 2 re-entry rows in the corpus and the Coalition 4, both under
   `min_n = 40`, so neither class ever gets a GLM — they fall back to the flat
   ratio of 1.0, which is why Kimberley's prediction is precisely Labor's
   statewide 37.2. Neither arm touches the ratio path. Stated in advance so
   that an unchanged Kimberley is read as "the arm never reached it", **not**
   as evidence the arm is safe. If either seat MOVES, the arm is touching the
   fallback path and that is a bug to find before reading any pooled number.
3. **Callide qld2024**, predicted 44.6, actual 15.8. Its gap is at the 81st
   percentile, inside the winsorising range, so **arm B should barely move it**
   while arm A should pull it down. This is the case that separates the two
   arms, and if B fixes Callide the winsorising is doing something other than
   what this plan claims.

## Refusal section — what disqualifies an apparent win

1. **Arm A destroying the South Australian behaviour.** The log offset's
   proportionality is what let One Nation's 2.6% → 22.9% surge carry into the
   seat predictions; a logit offset only approximates it, and worse as shares
   grow. sa2026 is 22.9% statewide, high enough for the approximation to bite.
   Report sa2026's mean predicted One Nation share against the actual 19.7 in
   every run. **If it moves by more than 3 points, arm A has broken the thing
   the offset was adopted for**, and no pooled gain rescues it.
2. **A tail fixed by making everything timid.** Report the mean and median
   prediction alongside the maximum, and the leave-one-out MAE (currently
   3.198 against 5.27 for predicting zero). If MAE worsens while the maximum
   falls, the model has bought the co-primary by getting worse at its job.
3. **Winsorising as a general anaesthetic.** Arm B bounds every covariate, not
   just the lean gap. Report how many cells have ANY covariate clipped. If that
   is more than about 5% of cells, arm B is not a tail fix, it is a different
   model, and it should be argued as one.
4. **A gain confined to Queensland.** Four of the five worst predictions are
   Queensland One Nation cells. Queensland is 186 of 2,050 seat-elections; if
   PB3f improves there and nowhere else, this is a three-seat patch and must be
   described as such rather than adopted as a general improvement.

## What the criterion cannot see

- Whether Labor and the Coalition should have a covariate model at all. They
  fall back to a flat ratio of 1.0 on 2 and 4 rows, so Kimberley's 37.2 and
  Alfred Cove's 41.9 are both just the statewide share, and Alfred Cove's
  actual was 22.8. Neither arm addresses that, and it is the second-largest
  source of error in the tail.
- Whether the lean gap should be a covariate at all, as opposed to a symptom
  of `classify_party()` filing KAP as `OTH_RIGHT` while the flow positions
  place it near the centre.
- Era, redistributions, and everything else the predecessor plans already list.
