# The MAJ-only defector discount excludes minor-to-minor switches, and it shouldn't

2026-09-16, following Mirani (`docs/reviews/mirani-party-defection-2026-09-16.md`).
`personal_prior_vote()`'s defector discount (`fit_defector_discount()`) is
deliberately restricted to `MAJ <- c("ALP", "LNP", "NAT")` defectors — the
comment justifies this: "switching FROM an already-minor label... is a much
smaller behavioural jump for voters and is not excluded." Stephen Andrew
(One Nation -> KAP, Mirani) contradicted that on one case (31.66% -> 25.0%).
This sizes it across the whole corpus before anyone touches `MAJ`.

## Method

Reused the exact identity-matching logic `personal_prior_vote()` itself uses
(`surname_of()`, `given_of()`, `match_key(..., "initial")`, leading row per
`(seat, .k)`) across all 21 pairs, filtered to candidates whose party
changed between a non-major class and a different non-major class (both
`prev_party` and `now_party` outside `MAJ`).

**66 raw matches.** Mean and median ratio disagreed sharply (1.326 vs.
0.729) — the signature of ratio noise on tiny denominators (`prev_pcv` as
low as 0.17%, 10th percentile 1.0%). Floored to `prev_pcv >= 5` to exclude
cases where a small absolute change produces a huge, meaningless ratio,
leaving **33 cases** with a real prior vote to lose.

## Result

| | n=66 (unfloored) | n=33 (`prev_pcv >= 5`) |
|---|--:|--:|
| mean ratio | 1.326 | 0.829 |
| median ratio | 0.729 | 0.390 |
| mean log-ratio (geometric mean retention) | 0.776 | **0.490** |
| t-test on log-ratio vs. 0 | p=0.062 | **p=0.0003** |
| Wilcoxon vs. ratio=1 | p=0.749 | **p=0.037** |

On the clean 33, minor-to-minor defectors retain a **geometric mean of 49%**
of their prior personal vote — real, significant, and far from the "not
excluded" (100% retained) treatment they currently get. It's smaller than a
typical major-party sitting-MP defector's collapse in the specific cases
this repo already has calibrated (McBride 24%, though Ward held at 72% —
the code's own comment says the spread there is real too) but it is
unmistakably a real loss, not the "smaller jump" the code assumes.

## Individual cases, for a sense of the shape

Mirani sits almost exactly at the geometric mean (ONP 31.7% -> KAP 25.0%,
ratio 0.79 — actually slightly ABOVE the median 0.39, so it is not even the
worst example). Some defections collapse hard (Mount Ommaney ONP->IND 7.3%
-> 0.6%, ratio 0.08; five WA 2005 cases where "OTH" candidates moved to ONP
all lost 70-90%). Some genuinely gain (Fremantle 2008 IND->GRN, 5.8% ->
27.6%, ratio 4.79 — almost certainly a different kind of event, a strong
Greens brand pulling in a previously-marginal independent, not vote decay).
The spread is real, same shape as the code's own MAJ-defector comment
already documents for major-party cases.

## What this does not establish

- **Not a single universal rate.** 33 cases across 21 pairs, mixed
  directions (ONP->IND, GRN->IND, IND->OTH_RIGHT, and reverses) is enough to
  reject "no discount," not enough to fit a rate as finely-calibrated as
  `fit_defector_discount()`'s major-party version (14+ cases feeding ONE
  direction of transition).
- **Not why some cases gain and some collapse.** Same open question the
  major-defector comment already names for its own cases: "what separates
  them... is not in any column this repo has."
- **Not measured against the model.** This is a corpus-level sizing check
  only, same stage Pattern A was at before it was built and retrained. The
  actual model effect (pooled RMSE, targeted seats, NA-fill vs 0-fill for
  the discount factor — apply the same lesson from tonight's `seat_outperf`
  work) is not yet tested.

## Recommendation

The evidence clears the bar Pattern A needed before building: real,
significant, sized on the full corpus, not the one case that found it. Next
step, if this gets built: extend `personal_prior_vote()`'s discount logic to
cover minor-to-minor transitions — either folding them into the existing
`MAJ` set's mechanism (risk: their retention scale may differ from
major-party defectors' 0.14-0.28, so a shared rate could be wrong for both)
or fitting a separate minor-to-minor rate the same way
`fit_defector_discount()` fits the major-party one. Needs a design decision
before building, not a default.
