# Pre-registration: fit the conditional slope constants from data, leave-one-election-out

Written 2026-09-09, **before any arm is fitted or scored**. Committed before
running.

## The defect

`conditional_slopes()` and `screened_slopes()` (`R/dev_slope.R`) carry eight
hardcoded numbers — a "same" and a "new" deviation slope for each of four
non-major classes:

```r
same = c(IND = 0.907, OTH_RIGHT = 0.891, GRN = 0.994, ONP = 0.610)
new  = c(IND = 0.326, OTH_RIGHT = 0.325, GRN = 0.880, ONP = 0.545)
```

There is **no committed script that produces them** — the same defect
`fit_defector_discount()` fixed for the defector discount earlier today, and
the one `~/.claude/CLAUDE.md` records as "a hardcoded constant with no
committed fitting script is probably leaked and possibly fitted on zero
observations".

Checked like-for-like on 2026-09-09 (each constant refit on cells matching its
own definition: "new" = no candidate of that class returned, "same" = at least
one did, which is what `candidate_returns()$same` means), pooled over all 22
pairs:

| class | tier | n | fitted | se | shipped | gap |
|---|---|--:|--:|--:|--:|--:|
| IND | new | 376 | 0.374 | 0.045 | 0.326 | +1.1 SE |
| IND | same | 215 | 0.882 | 0.034 | 0.907 | −0.7 SE |
| **OTH_RIGHT** | **new** | 1003 | **0.442** | 0.038 | 0.325 | **+3.1 SE** |
| **OTH_RIGHT** | **same** | 205 | **0.766** | 0.033 | 0.891 | **−3.8 SE** |
| GRN | new | 1724 | 0.912 | 0.013 | 0.880 | +2.4 SE |
| GRN | same | 289 | 1.020 | 0.017 | 0.994 | +1.5 SE |
| ONP | new | 447 | 0.592 | 0.028 | 0.545 | +1.7 SE |
| **ONP** | **same** | 51 | **0.449** | 0.059 | 0.610 | **−2.7 SE** |

IND's two constants — the ones the docstrings discuss most — are **fine**.
The defect is concentrated in **OTH_RIGHT**, whose two constants are wrong in
OPPOSITE directions: its true slopes are far closer together (0.442 / 0.766)
than shipped (0.325 / 0.891), meaning the model currently over-separates
returning from new OTH_RIGHT candidates. ONP's "same" is also off, on 51
observations.

**Correcting the record**: an earlier claim this session that the departed
slope "is badly wrong at ~0.575" was itself wrong — 0.575 came from a fit
pooled across all non-major classes and is not comparable to any single
class's constant. That is why this plan re-derives every constant on its own
definition rather than acting on the pooled number.

## The arm

Replace the eight hardcoded numbers with a **leave-one-election-out fit**,
exactly the pattern `fit_defector_discount()` uses: for the election being
scored, the slopes come from every OTHER pair in the corpus.

New `fit_conditional_slopes(target_election, corpus, pairs, min_n)` returns
the `same`/`new` vectors. A class/tier with fewer than `min_n = 40`
observations **falls back to the shipped constant** rather than fitting on
thin data — ONP "same" has 51 and would sit just above that floor, so the
floor is stated here and not chosen after seeing which cells it excludes.

Behind `AUSPOL_FIT_SLOPES` (default `0` = byte-identical), added to
`scripts/published_flags.R` in the same commit.

## What this plan does NOT do

It does not change the *structure* of the slope system — the binary
same/new tiers, the MP tier, and the salience screen all stay exactly as
they are. Only the eight numbers move. That is deliberate: the split-slope
arm refused earlier today (`prereg-partial-return-split-slope-2026-09-09.md`)
failed precisely because it replaced that structure, and the lesson recorded
there is to refine rather than replace.

## Primary metric

**Pooled seat log loss across all 22 pairs.** This is a GENERAL change — it
moves every non-major class in every seat, not a named subset — so per
`CLAUDE.md`'s targeted-vs-general table the election-wide metric is primary
and slices are secondary. That is the opposite ordering to the split-slope
plan, and deliberately so.

Baseline: **0.3365** pooled over 2,050 seat-elections (accuracy 0.8717,
Brier 0.0959). Paired per-pair deltas, clustered on the 22 pairs, bar
**2.08 SE** (t, 21 df).

**MDE:** the paired sd cannot be known before the run. It will be reported
with the result, and if it exceeds the observed effect the finding is "this
test could not see it", not a pass.

## Decision rule, fixed now

Same shape as the split-slope plan, since Pete's "better in 9 of 10, use
common sense" instruction (2026-09-09) still governs.

**Ship if BOTH:**

1. Pooled seat log loss improves at ≥ 2.08 clustered SE.
2. Of this 10-metric panel, **≥ 6 better and ≤ 3 worse** (|Δ| < 0.0005 is
   unchanged and counts as NOT an improvement):
   pooled log loss; pooled Brier; pooled share RMSE (all cells); per-jurisdiction
   seat log loss for fed, nsw, qld, sa, vic, wa; and the count of floor seats
   (actual winner given ≤ 1e-4).

**Catastrophic-break floor:** refuse regardless if any jurisdiction's seat log
loss degrades by more than **0.02**, or pooled by more than **0.01**.

**Victoria is the live target** and any regression is reported prominently.

## Refusal: what would make an apparent WIN unacceptable

- **R1 — it must not be an OTH_RIGHT-only effect masquerading as general.**
  OTH_RIGHT carries the largest gaps and 1,208 of the fitted observations. If
  the pooled gain disappears when OTH_RIGHT's constants alone are left at
  their shipped values, then this is a one-class fix and should ship as one,
  with the other six constants left alone. Report that ablation.
- **R2 — thin cells must not drive it.** ONP "same" (n=51) is the thinnest
  fitted cell and has the second-largest gap. Report the result with ONP
  held at its shipped constant; if the gain depends on ONP, it rests on 51
  observations and must be escalated rather than shipped.
- **R3 — no free lunch from refitting alone.** GRN's fitted values are within
  0.03 of shipped in absolute terms despite clearing 2 SE (n is large). If the
  pooled improvement is smaller than the sd of a re-run with a different
  `AUSPOL_SEED`, it is simulation noise, not the constants. Report a
  seed-variation control.
- **R4 — the published Victorian forecast's seat totals must not move by more
  than 2 for any class**, or it escalates rather than shipping as a side
  effect.

## What the criterion cannot see

- It cannot tell whether the *binary* same/new structure is right — only
  whether these eight numbers are the best values for it. The structural
  question is the refused split-slope plan's, not this one's.
- The identity matching underneath is unchanged and inherits its known
  false-positive weakness on common surnames.
- Fitting on deviation-from-statewide assumes the statewide level is right;
  where the poll trend is off, these slopes absorb some of that error.

## Dry-run of the criterion on a case whose answer is known

If the fit reproduces the shipped constants closely (as it does for IND: 0.374
vs 0.326, 0.882 vs 0.907), then the arm should be **near-neutral** on any pair
where IND dominates the non-major vote, and should move most on pairs with
heavy OTH_RIGHT presence. If instead the largest movers are IND-dominated
pairs, the wiring is wrong and the result should be discarded rather than
interpreted.

## Prediction, written before running

Expect a **small** pooled improvement — the two genuinely wrong constants
belong to OTH_RIGHT, which is a minor class in most seats, and IND (the class
that decides the most marginal seats) is already correct. Expect R1 to be the
binding refusal: this may well be an OTH_RIGHT fix rather than a general one,
in which case the honest outcome is to ship it as an OTH_RIGHT correction and
leave the other six numbers alone.

---

## Result, 2026-09-09: REFUSED — and the reason points somewhere better

Run across all 22 pairs at 20,000 sims with `AUSPOL_FIT_SLOPES=1`, scored
against the criterion above. **Nothing adopted; the flag stays at `0`.**

| test | value | bar | verdict |
|---|---:|---:|---|
| criterion 1 — pooled seat log loss | 0.3365 → **0.3393**, t = +1.21, better in 11 of 22 | improve at ≥ 2.08 SE | **FAIL** |
| criterion 2 — 10-metric panel | **2 better, 6 worse, 1 unchanged** | ≥ 6 better, ≤ 3 worse | **FAIL** |
| catastrophic floors | worst jurisdiction qld +0.0075; pooled +0.0028 | 0.02 / 0.01 | not breached |
| Victoria (live target) | 0.2693 → **0.2676** | — | improved |

Unlike the split-slope arm, this one is not harmful — it is **inert almost
everywhere and wrong in two places**.

### The test could not resolve it, by its own sizing

Observed pooled effect **+0.0028** against a realised **MDE of 0.0032**. The
plan said in advance that an effect smaller than the MDE is reported as "this
test could not see it", and that is the honest reading of the primary. What
decides the refusal is that the panel leans worse and there is no evidence of
benefit — not that harm was demonstrated.

### 20 of 22 pairs are a dead heat; two outliers carry the whole result

Excluding **fed2013 (+0.0303)** and **qld2020 (+0.0123)**, the mean per-pair
delta is **+0.00003** — an exact wash. Every other pair moves by less than
0.003, which is noise at this sample size.

### Why fed2013, and why it matters more than the refusal

fed2013 is Palmer United's debut. OTH_RIGHT's statewide vote went **3.93%
(sd 1.65) → 10.58% (sd 5.79)** across 124 seats, and the correlation between
the seat pattern before and after is only **0.371**. The prior seat pattern
barely predicted the new one.

The shipped `new = 0.325` shrinks a seat hard toward the statewide level,
which is **the right behaviour when a class is surging into territory it has
no history in**. The fitted `0.442` shrinks less, preserving a prior pattern
that did not persist — so it is better on ordinary elections and clearly
worse on the surge, and the pooled fit averages the two into a constant that
suits neither.

**So the constant is not the problem; conditioning on a single binary
same/new flag is.** OTH_RIGHT's correct slope depends on whether the class is
surging, and this repo already HAS that concept — `surging_parties()` and
`AUSPOL_SALIENCE_SURGE_V2`. The next hypothesis is therefore:

> condition the deviation slope on surge status as well as candidate return:
> a surging class's prior seat pattern carries far less information, so it
> should shrink harder, and a stable class's should shrink less.

That is a structural refinement (it adds a condition, it does not replace the
tier system), and it needs its own pre-registration.

**This matters directly for the live target.** Victoria 2026 is forecast with
One Nation near 21% — a surging right-wing class with little Victorian seat
history, which is structurally the fed2013 situation, not the ordinary one.
Getting the surge case right is worth more here than the average case.

### R1/R2/R3 as required by the plan

- **R1 (OTH_RIGHT-only ablation)** is moot: there is no pooled gain to
  attribute, so there is nothing to hold out.
- **R2 (thin ONP cell)** likewise moot for the same reason. ONP "same" was
  fitted on 51 observations and moved 0.610 → ~0.44; that it did not produce
  a visible pooled effect is consistent with ONP being a small class in most
  of the corpus, and is not evidence the fitted value is right.
- **R3 (seed control)** was not needed to reach the verdict — the effect is
  below the MDE and the panel leans worse regardless — but it remains the
  correct control for any future arm whose effect lands in this range.

### Kept at default 0

`fit_conditional_slopes()` and the `AUSPOL_FIT_SLOPES` wiring stay in the
tree, inert (verified: flag unset reproduces sa2026 at 0.3951/0.1297
exactly). The surge-conditioned hypothesis above needs the same fitting
machinery, and the like-for-like constant table in this plan is the reference
a future attempt starts from.
