# Narrowing the catch-all buckets is infeasible, and the polls say so

Written while starting a pre-registration for it. **No plan was written**,
because a constraint check killed the remedy in ten minutes.

## The remedy that was going to be planned

`reviews/m2-cell-thinning-2026-08-22.md` left two candidate remedies for the
finding that 44.5% of Victorian exclusion rounds have a class fielding more than
one candidate, dominated by the catch-all buckets:

1. **narrow the buckets** so `OTH_RIGHT` is not one class doing the work of six;
2. **weight by candidate count** inside the existing cell.

The first was the more attractive: it addresses the cause rather than
conditioning around it.

## Why it cannot be done

**The seat model needs a statewide vote share for every class it simulates, and
that share comes from polls.** Victorian polls in the live 2022–2026 cycle:

| party | polls reporting it | clears the inclusion floor of 8? |
|---|---:|---|
| ALP | 54 | yes |
| LNP | 54 | yes |
| GRN | 54 | yes |
| OTH | 54 | yes |
| ONP | 19 | yes |
| UAP | 0 | no |
| DEM | 0 | no |

**Five series exist. That is the whole list.** No Victorian pollster reports
Family First, Australian Christians, Legalise Cannabis, the Shooters, or any
other member of `OTH_RIGHT` and `OTH` separately. There is nothing to fit a
trend to, so a narrower class could not be given a statewide share, so it could
not be simulated.

The party inclusion floor exists for exactly this reason and is not the
obstacle — the obstacle is upstream of it. Lowering the floor would not create a
series that nobody collects.

`IND` is the same problem in a different shape: independents have no statewide
polling series by nature, which is why the repo has a separate line of work on
independent emergence rather than a class share.

## What this does and does not settle

It settles that **the flow matrix cannot be fixed by refining the classes**, at
least while the forecast is driven by published polling. The classification
scheme is coarse because the *inputs* are coarse, not because nobody thought
about it.

It does **not** settle that the finding is unimportant. 44.5% of Victorian
rounds still involve a class collecting several candidates' preferences, and the
matrix still reads that as the bucket being popular.

What it does is eliminate one of the two remedies, and it makes the surviving
one more interesting rather than less: **weighting by candidate count inside the
existing cell** needs no new class, no new polling series, and costs no
coverage.

## The honest difficulty with the surviving remedy, recorded now

Weighting has an estimation side and an application side, and only the first is
easy:

- **Estimating** is straightforward: the observed transfers already carry
  `to_n`, so a rate can be normalised by how many candidates earned it.
- **Applying** needs to know how many candidates each class will field in each
  Victorian seat in 2026, and **nominations have not closed.** The model
  currently assumes, implicitly, one candidate per class per seat.

The available predictor is the seat's own 2022 count, which is a real assumption
with a measurable error, not a free lunch. **Any plan for this remedy has to
treat the application side as the hard part**, and the estimation side as the
part that merely looks like progress.

Recorded before that plan is written, so the difficulty cannot be discovered
later and presented as a limitation nobody could have foreseen.

## Method note

The check was three queries against `load_polls("vic")`: which party columns
exist, how many non-missing rows each has in the live cycle, and how that
compares to the inclusion floor. Nothing was built and no plan was committed
first. **A pre-registration for an infeasible remedy would have been worse than
useless** — it would have made the infeasibility look like a result.
