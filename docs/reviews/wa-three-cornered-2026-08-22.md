# The three-cornered diagnosis was right, and it still is not enough

Against `docs/plans/prereg-wa-three-cornered.md`, committed before any arm ran.
**Result: refused, and the question is closed.**

## The ladder

Three arms of the same question, in the order they were run:

| arm | t | improved in |
|---|---:|---:|
| WA minus Coalition-origin exclusions (the W2 fallback) | −2.23 SE | 1 of 9 |
| WA whole | −1.57 SE | 3 of 9 |
| **WA minus three-cornered seats** | **−0.49 SE** | **4 of 9** |

The pre-registered bar was **over 2.5 SE and positive in at least 6 of 9**. It
is not close.

**But read the ladder rather than the last row.** Dropping the three-cornered
seats recovered about **1.08 SE of the 1.57**, which says the diagnosis in
`wa-flows-2026-08-21.md` was substantially correct: Liberal-versus-National
contests really were most of the damage. They were not all of it, and what
remains does not point at another filter.

## T3 fired, as it was written down expecting to

`ALP → GRN` is 25.3% in Victoria and 16.0% in the current pool. This arm takes
it to **12.6%**, so the distance from the jurisdiction being forecast widens
from 9.3 to 12.7 points. Refusal T3 named that row in advance and said to stop
on it **even on a winning score**. The score did not win, so T3 is not what
decided this — but it fired, and it identifies the residue the seat filter does
not reach.

Why it is 0.0% in non-three-cornered Western Australian seats is worth stating
plainly: Labor is rarely excluded there, and when it is, the Greens are usually
already out. That is once again a fact about **which candidates survive**, not
about how anyone preferences.

## The prediction the plan made, and what it now means

The plan recorded a competing explanation before the result:

> The flow matrix is keyed on party class **and survivor set**. If that
> conditioning were fine-grained enough, a contest whose survivors are two LNP
> candidates would occupy its own cell and could not contaminate any other.

Every finding since is consistent with that reading and not with "West
Australians are unusual":

- the LNP artefact was a **survivor-set** artefact, and removing those seats
  recovered two-thirds of the loss;
- the residue is **also** a survivor-set artefact, in a different row;
- filtering seats treats each symptom one at a time and cannot reach the next.

So the plan's own words apply: this is **evidence, not a disappointment**. The
next work is on the conditioning, and it is a different question needing a
different plan.

## What is closed, and what that means

**Western Australia's transfers do not pool with Victoria's, and no fourth
filter should be tried.** Three arms have now been scored against a
pre-registered criterion; a fourth cut of the same data for the same decision
would be the multiplicity problem the last plan raised, not a new experiment.

`AUSPOL_WA_FLOWS` stays off by default. The Western Australian data stays
fetched and validated, and its first preferences remain untouched by any of
this — eight elections of district-level One Nation vote is worth having on its
own terms.

## Recorded for the next plan, not acted on here

The survivor-set hypothesis is testable: build the matrix conditioning on the
**multiset** of surviving classes rather than the set, so a contest whose
survivors are `{LNP, LNP}` cannot share a cell with one whose survivors are
`{LNP, ALP}`. If that is the fault, it should improve the forecast **with
Western Australia excluded entirely**, which is the version of the test that
cannot be confounded by anything above.

That prediction is written here before it is run, so a later result can be
checked against it.

## One defect found reviewing this change

`WF3b` counted exclusion events **before** wa2001 is dropped for exhaustion, so
it printed 558 of 1,910 where the shipped file holds 517 of 1,658. The filter
itself reads the file, not the log, so no result was affected — but a diagnostic
that reports something other than what ran is the exact failure refusal T2 was
written to prevent, and it appeared in the code written to satisfy T2. The count
now sits after the exclusion, where it describes the table that ships.

## Process note

Three experiments, three pre-registrations, three refusals, and nothing
invented after a result. The bar for this one was **raised** from 2 SE to
2.5 SE on multiplicity grounds and the earlier plan's "adopt anyway" escape
clause was deliberately dropped — both tightenings, decided before the number
existed. The arm came in at −0.49 SE, so neither change was what refused it.
