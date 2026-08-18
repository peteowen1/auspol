# The party-inclusion floor stays at 8, and both directions were wrong

Run 2026-08-19 against
[../plans/prereg-party-inclusion-floor.md](../plans/prereg-party-inclusion-floor.md)
by `scripts/test_inclusion_floor.R`. **Nothing changed.**

## What was being asked

Which parties get fitted at all is decided by a per-cycle poll count — 8 in the
state scripts. One Nation has 7 polls in the NSW 2023 cycle and is excluded by
one poll. The hypothesis, written down first, was that this is too strict: the
excluded party's support stays inside `OTH`, `unfold_others()` cannot run on it,
and `OTH` ends up fitted across two definitions of itself.

That hypothesis is **wrong**, and so is its opposite.

## Lowering the floor makes the forecast worse

Scored on the 125 (cycle, party) rows every floor fits, so no arm can win by
declining to predict:

| floor | FP MAE | vs 8 | OTH MAE |
|---:|---:|---:|---:|
| 5 | 1.885 | +0.069 | 2.741 |
| 6 | 1.855 | +0.039 | 2.614 |
| 7 | 1.840 | +0.023 | 2.551 |
| **8** | **1.816** | — | **2.453** |
| 10 | 1.811 | −0.006 | 2.430 |
| 12 | 1.791 | −0.025 | 2.348 |
| 15 | **1.756** | **−0.061** | **2.200** |

Monotonic. Fitting *more* thinly-polled parties is worse on total first
preferences **and** worse on `OTH` — the party the mechanism was supposed to
help. Paired against floor 8, floor 5 is +0.069 worse (sd 0.405, p=0.06).

## Raising it clears the bar and is still refused

Floor 15 beats 8 by 0.061, three times the 0.02 adoption bar the plan fixed in
advance, monotonically rather than as an isolated spike. By the letter of the
decision rule it should be adopted.

**It is refused on an anchor.** One Nation polls **21.0% in the NSW 2027 cycle
on 8 polls**. A floor of 15 excludes it. A model that cannot represent a party
polling in the low twenties is broken whatever it does to historical error, and
this is the same defect the seat rebuild existed to fix.

| live cycle | party | polling | polls | fitted at 8 | fitted at 15 |
|---|---|---:|---:|:--:|:--:|
| Victoria 2026 | ONP | 22.4% | 18 | yes | yes |
| federal 2028 | ONP | 21.8% | 144 | yes | yes |
| **NSW 2027** | **ONP** | **21.0%** | **8** | **yes** | **no** |

## Why the criterion could not see this

The recorded results mostly do not break out minor parties — 21 fits at floor 8
have no line in the actuals to score against at all. So `OTH` in the historical
targets means "every minor party lumped together", and a model that also lumps
them together matches it better. **Floor 15 wins by matching the granularity of
the historical record, not by forecasting better.**

That is invisible to first-preference MAE against those records, and it points
the wrong way for the live cycles, where the whole point is resolving One Nation
as its own party that can win seats.

**So the pre-registered criterion was inadequate for this decision.** It was
chosen honestly and in advance, and it still could not see the thing that
decides the answer. Recorded rather than quietly swapped for one that gives a
nicer result.

## A confound in the first run, and it was mine

The plan named one version of this trap — scoring `OTH` alone would reward a
floor for moving vote out of `OTH` and having less left to get wrong — and
missed the same trap in a larger form.

The first analysis compared raw MAE across arms. But each arm fits a different
number of rows:

| floor | rows fitted | cycles |
|---:|---:|---:|
| 5 | 149 | 35 |
| 8 | 139 | 33 |
| 15 | 125 | 30 |

A higher floor declines to fit exactly the thinly-polled minor parties that are
hardest, so its mean error falls for that reason alone. The raw table showed a
clean monotonic "improvement" that was substantially an artefact. The script now
prints it labelled as confounded, above the paired comparison, so the shape of
the mistake stays visible.

The verdict logic was wrong too: it reported "isolated spike in a non-monotonic
curve" for a curve that is monotonic. The test was written as "is the winner
clearly lowest", which is true of any clear winner. Rewritten.

## What is actually still wrong with NSW 2023

Unchanged by this and worth keeping on the record. Morgan reports One Nation
separately in all 7 of its NSW 2023 polls; every other firm folds it into `OTH`.
The model cannot see that the two `OTH` columns mean different things — its
fitted Morgan house effect on `OTH` is **−0.28**, not the ~5-point definitional
gap — and `OTH` is fitted at **15.30** against an actual of **17.96**.

Fitting One Nation there would not fix it: floor 7, which does fit it, is
**0.023 worse** on total first preferences and **0.098 worse** on `OTH`. The
problem is real; lowering the floor is not the remedy. A remedy would have to
reconcile the two `OTH` definitions directly, which is a different piece of work
and is not queued yet.
