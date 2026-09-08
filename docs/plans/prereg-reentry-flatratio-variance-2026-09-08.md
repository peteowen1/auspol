# Pre-registration: widen simulated variance for the flat-ratio path

Written and committed **before** any arm is run, 2026-09-08. Successor to the
2026-09-08 shrinkage diagnostic recorded in `docs/NEXT-STEPS.md`, which tested
and refused a POINT-estimate fix for the same defect.

## The defect

Three classes never get a covariate GLM in `reentry_fit()` — they have too
few re-entry rows (`min_n = 40`): `GRN` (29 rows in the all-pairs fit), `LNP`
(4) and `ALP` (2). They fall back to a flat ratio, `mean(pcv)/mean(state_pcv)`,
or 1.0 below `min_ratio_n = 20`. Whatever that ratio predicts, the SIMULATED
UNCERTAINTY around it is untouched — the cell gets exactly the same
`level_sd` as a normal, well-supported prediction: `a + b*level_mult*
sqrt(p(1-p))`, a function of the projected share alone, blind to how many
observations the projection rests on.

**A point-estimate fix was tried and does not work.** Continuous James-Stein
shrinkage of the ratio toward 1, grid `k ∈ {3,5,10,20,40,80}`, gave a real but
tiny gain (LOO MAE 3.677 vs 3.710) that comes almost entirely from `GRN`, not
the majors: with 1-3 leave-one-out observations for `ALP`/`LNP`, the shrinkage
weight `n/(n+k)` stays near zero regardless of `k`, so the shrunk ratio stays
near 1 and Alfred Cove still predicts ~42 against an actual 22.8. **With this
little data, no point-estimate trick can locate the true value — the estimate
itself is irreducibly noisy**, and the simulator should say so rather than
pretend otherwise.

Currently these cells own **two of the arm-D floor seats** (Pilbara wa2001,
Alfred Cove wa2005 — see `prereg-reentry-lean-gap-2026-09-08.md`'s pooled
outcome) and the single largest remaining prediction anywhere in the corpus
(Churchlands wa2013, 53.2 against an actual 59.0).

## The fix

A per-cell `sd_override`, additive in quadrature with the existing `level_sd`
formula, sized by how little evidence backs the ratio:

```
extra_sd  = k_sd / sqrt(n)
new_sd    = sqrt(base_sd^2 + extra_sd^2)
base_sd   = a + b * level_mult * sqrt(p(1-p))      # unchanged, existing formula
```

`n` is the training-row count for that class in that fold (so it shrinks
toward zero extra uncertainty as `n` grows, and is largest for `ALP`/`LNP`).
`k_sd` is a single fitted constant, chosen from a small pre-registered grid.

This is a FULL replacement value passed through `sd_override`, matching the
existing contract (`R/seat_sim.R`'s `sd_override` replaces `sd_cell_pre[ok]`
wholesale, it does not add to it) — the quadrature combination happens before
the override is built, not inside `simulate_seat_contests()`.

### Prerequisite: WA has no `sd_override` plumbing at all

Five of six harnesses declare `SD_OVR <- NULL` and pass `sd_override = SD_OVR`
into `simulate_seat_contests()`, for salience. `backtest_candidate_wa.R:452`
does not — its call has no `sd_override` argument. Since Pilbara, Alfred Cove
and Churchlands are all Western Australian, this arm is a no-op there until
that gap closes. Closing it is scoped as part of this plan, not deferred,
because the plan cannot be tested on its own named cases without it — but it
is verified separately and first, with its own byte-identical parity check,
before any variance is actually added.

### Combining with the salience `sd_override`

A cell can in principle be claimed by both mechanisms (a governed candidate
re-entering a seat their party did not contest last time). Take the **larger**
of the two full `sd` values, not a further combination — the same rule as this
repo's existing "when in doubt, don't understate uncertainty" (recorded on the
absence-of-evidence hazard in `CLAUDE.md`). No new theory of how two
independent-but-unquantified uncertainty sources compose is needed if neither
is ever allowed to be understated by the other.

## The arms

- **Baseline**: arm D (`AUSPOL_REENTRY_GAP=winsor`) with no sd override, the
  configuration measured in `prereg-reentry-lean-gap-2026-09-08.md`.
- **Arm H**: the sd widening above, grid `k_sd ∈ {0, 2, 5, 10, 20}` in
  percentage points (`k_sd = 0` must reproduce arm D exactly — the dry-run
  case this rests on).

`k_sd` is chosen by the grid point that clears the decision rule with the
lowest PB3f; if none clears it, none is adopted and that is reported as
plainly as an adopted arm would be.

## The criterion

**Primary: PB3f**, pooled seat log loss excluding floor seats, over all 22
pairs and 2,050 seat-elections, against **arm D** as the baseline (not prior
OFF — this plan is downstream of arm D, not a replacement for it, and arm D
itself remains unshipped pending seed-averaging per `docs/NEXT-STEPS.md`
item 2; whatever `AUSPOL_N_SIMS` that seed-averaging settles on is the one
this plan measures at, so the two results are comparable).

**Co-primary, specific to this defect:** the probability given to the actual
winner in each of the five named cells (Kimberley wa2001, Alfred Cove wa2005,
Armadale wa2005, Churchlands wa2001, Churchlands wa2013, Richmond vic2022) —
report all five in every run, not a summary.

**Guards:** pooled seat-share RMSE (a variance change should not move the
point estimate at all — if it does, something leaked into the mean); pooled
calibration slope, never decisive alone but a fall below 0.5 is a refusal per
this repo's standing rule; per-jurisdiction log loss against arm D, tolerance
two standard errors of that jurisdiction's own paired difference.

**Decision rule.** Adopt the best-scoring `k_sd > 0` if:
1. PB3f improves or is unchanged within 0.001 against arm D; AND
2. none of the six named cells' individual log loss worsens by more than it
   would from `-log(0.5)` of headroom (i.e. the actual winner's probability
   must not fall below where it already sat, halved) — a concrete, checkable
   bound rather than a vague "must not get worse"; AND
3. pooled calibration slope stays at or above 0.5; AND
4. no jurisdiction breaches its two-SE tolerance.

### Dry-run of the criterion on cases whose answer is already known

1. **`k_sd = 0` must reproduce arm D exactly, to 1e-6.** Same shape as the
   lean-gap reparameterisation's case 1, and for the same reason: if the
   plumbing is not a true no-op at zero, nothing measured at `k_sd > 0` can be
   trusted to be measuring the intended thing.
2. **The WA `sd_override` plumbing, in isolation, with `k_sd = 0` and no
   salience active, must leave WA's pooled log loss identical to its
   pre-plumbing value.** Checked before the plan's own grid is run at all.
3. **`GRN` (n≈29, near `min_n`) should get a SMALL sd bump; `ALP`/`LNP`
   (n=1-4 per fold) a LARGE one**, by construction of `k_sd/sqrt(n)`. Report
   the extra sd applied to at least one `GRN` cell and one `ALP`/`LNP` cell at
   the chosen `k_sd`, to confirm the mechanism is doing what it says rather
   than applying a flat bump that happens to average out right.
4. **A seat with NO ratio-path cell at all** (the large majority of seats)
   must be byte-identical to arm D regardless of `k_sd`, since `sd_override`
   is `NA` there and `level_sd` alone governs. If any such seat moves, the
   override matrix is misaligned with `shares`' dimnames.

## Refusal section — what disqualifies an apparent win

1. **Case 1 or 2 failing.** As always in this sequence, a non-zero-default
   plumbing bug invalidates everything measured on top of it.
2. **The gain is entirely a wider-tail-catches-the-winner-by-luck effect on
   ONE of the six named cells, with the other five unchanged or worse.**
   Report all six every time; a win described as "the named cases improved"
   when it is really one cell is the same shape of overclaim CLAUDE.md already
   records for the salience precision criterion.
3. **Calibration slope falling below 0.5.** Widening variance can buy log
   loss by making the model uselessly vague; this repo's rule that the slope
   is never decisive but is a hard floor stands.
4. **A gain confined to Western Australia.** Five of the six named cells are
   WA's; Queensland's `qld2024` also has ratio-path `GRN`/`ONP`-adjacent cells
   in principle (not confirmed) and every jurisdiction has *some* small-n
   class. Require the sign to hold, or at minimum not reverse, in at least
   three jurisdictions.

## What the criterion cannot see

- Whether `k_sd` should vary BY CLASS rather than being one constant across
  `GRN`/`ALP`/`LNP`. A single grid point is chosen for simplicity; a
  class-specific constant is a natural extension if the pooled grid result is
  ambiguous.
- Whether the majors deserve a covariate model of their own built from a
  DIFFERENT kind of evidence than re-entry rows — e.g. a general incumbency /
  personal-vote model that does not require the party to have been literally
  absent last time. That is a larger project and out of scope here.
- Whether `level_mult` (currently off by default, `AUSPOL_LEVEL_MULT_IND`/
  `_OTH`) should also apply to the ratio-path classes; this plan leaves it at
  whatever the caller has already set and does not interact with it beyond
  the formula's existing `level_mult` term.
