# How a party class's national level reaches a seat, and where it stopped

2026-09-05. Pete: *"I just want consistency and mapping and traceable logic —
it seems all over the place at the moment."* Correct. Two silent
inconsistencies were found by writing this trace out, and fixing them moved
fed2025 seat log loss **0.3588 -> 0.3370** and accuracy **83.3% -> 85.3%**.

## The trace, in order, for one class in one seat

`scripts/backtest_candidate_fed.R`, forecast mode. Following `IND`:

| # | step | object | who sets it |
|---|---|---|---|
| 1 | prior election's seat shares | `mat[, "IND"]` | `dcast(fa, seat ~ party)`, from `aec-fed-firstprefs.csv` |
| 2 | prior national level | `st_a[["IND"]]` | same file, aggregated |
| 3 | class has no poll series -> folded | `unmodelled` | `FC$folded` |
| 4 | minor-bucket rescale | `scale_to` | `st_fc[["OTH"]] / base_share` |
| 5 | **national level re-forecast** | `sp`, applied to `mat` and `st_a` | `AUSPOL_IND_SALIENCE` |
| 6 | statewide draw column | `sw_draws[, "IND"]` | `oth_draw * ratio[["IND"]]` |
| 7 | forecast level | `st_fc[["IND"]]` | `<- st_a[["IND"]]` |
| 8 | per-seat personal override | `.own_x()` | `personal_prior_vote()` |
| 9 | per-seat slope | `.fed_slope()` | `screened_slopes()` |
| 10 | projection | `dev_slope(x, prev, now, slope)` | `R/dev_slope.R` |
| 11 | nomination gate | zero where nobody stood | `fb` |
| 12 | renormalise | `100 * shares / rowSums(shares)` | |

## Inconsistency 1: the re-forecast level did not survive step 8

Step 5 scales `mat[, "IND"]`. Step 8 then **replaces** that value, for any
seat where the independent personally returns, with `own_prev_pcv` taken
straight from `personal_prior_vote()` — which knows nothing about step 5.

So the national uplift was applied to every seat and then **discarded in
exactly the sitting-independent seats it exists to help**. That is why the
harness gained only 0.3588 -> 0.3567 while the same national level scored in
isolation gave 0.3259.

**Fixed** by carrying a per-class `lvl_scale` and applying it to the override:
`dev_slope(.own_x(p, seats, mat[, p] / s) * s, ...)`. Dividing before and
multiplying after leaves un-overridden seats untouched and scales the
substituted personal vote by the same factor. **0.3567 -> 0.3371.**

## Inconsistency 2: the draws described the old level

Step 6 builds `sw_draws[, "IND"]` from the PRIOR election's ratio within the
minor bucket. Step 5 then moves the level without touching the draws, so the
point estimate said 6.37 while its uncertainty was scaled to 4.68 — the same
class described two different ways inside one object.

**Fixed** by scaling the draw column with the level. Effect on score is
negligible (0.3371 -> 0.3370) because `simulate_seat_contests()` centres
`statewide_draws` on their own column means, so only the spread was ever
carried — but the object is now internally consistent, and the next person
reading it will not have to re-derive that.

## Inconsistency 3, NOT fixed: two definitions of "independent"

`output/candidacies.csv` and `external/elections/aec-fed-firstprefs.csv`
disagree about who is an independent — the Nick Xenophon Team is IND in the
first and not the second, which is the whole 2016 gap (4.66 vs 2.81; NXT was
1.85% of the national vote). Re-classifying the raw AEC file with today's
`classify_party()` gives 4.45, so the cached extract is **stale**, not
differently-specified: written before the classifier learned that label, and
never rebuilt because `grab()` skips files that already exist.

Worked around, not fixed: the level model is fitted on the basis its
predictor (salience) uses, and applied as a **ratio**, which is invariant to
which basis the harness itself is on. Full detail in
`party-class-consistency-2026-09-05.md`.

**Regenerating that artifact is still an open decision** — it would move class
levels for every federal election and therefore every published backtest
number.

## The remaining unexplained 0.011

Harness 0.3370 against 0.3259 for the same national level scored in a
standalone simulation. Known differences not yet reconciled: the harness uses
`statewide_draws` where the standalone used a flat `party_sd`, and applies
the step-11 nomination gate and the surge mechanism. Recorded as open rather
than closed, because the last two times a gap like this was chased it turned
out to be a real inconsistency rather than noise.

## The rule this keeps demonstrating

Every one of these was invisible in aggregate metrics and obvious the moment
the transformation chain was written down in order. A class's level passes
through twelve steps and any step that reads a stale copy silently undoes an
earlier one.
