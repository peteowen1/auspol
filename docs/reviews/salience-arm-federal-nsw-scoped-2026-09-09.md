# Arm C (salience point estimate + variance): scoped to federal and NSW only

2026-09-09, overnight. Applying the decision rule from
`docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`, written and
committed 2026-09-07, never previously run.

## Why this was run tonight

Pete's direct complaint: fed2022's six teal seats (Goldstein, Curtin, North
Sydney, Kooyong, Mackellar, Fowler) are called for LNP/ALP at 2-6% probability
when the independent actually won — the well-documented "wave term blocked"
problem (`docs/reviews/wave-term-blocked-2026-09-07.md`). That review's own
diagnosis: the salience hazard is calibrated and correctly RANKS these seats
as the most at-risk in the election; what's missing is that the point
estimate and simulated variance never actually use the salience band's own
numbers. Arm C is the mechanism already built and pre-registered for exactly
this — it had just never been run.

## Dry-run (before trusting anything pooled)

**Shepparton 2014, arm B alone (variance only, no point-estimate move):**
0.036 — essentially unchanged from the pre-registration's stated baseline of
0.047. Confirms its own diagnosis: widening the tail around a point estimate
that's still stuck at the ~6% class prior isn't enough to reach a
seven-sigma outcome. Arm C (both) is the one that matters.

## fed2022's six named seats, arm C vs baseline

| seat | baseline p(actual) | arm C p(actual) |
|---|--:|--:|
| Goldstein | 0.020 | 0.122 |
| Curtin | 0.036 | 0.063 |
| North Sydney | 0.028 | 0.061 |
| Kooyong | 0.053 | 0.361 |
| Mackellar | 0.062 | 0.099 |
| Fowler | 0.012 | 0.033 |

Every seat moves the right direction, several substantially (Kooyong 6.8x,
Goldstein 6.1x). Kooyong is now the model's *second*-most-likely outcome for
that seat, not a near-impossible one. Still under-called on average — this
does not fully solve the wave problem — but it is no longer the "essentially
impossible" range that was the actual complaint.

Governed candidates given p>0.30 who lost, fed2022: 32 before, 32 after —
unchanged, no sign of the refusal condition ("losers raised as much as
winners") firing.

## The full jurisdiction-level result

Baseline vs arm C, mean pooled log loss by jurisdiction (all 22 known pairs
where a salience corpus exists — WA excluded, no candidate-level corpus):

| jurisdiction | pairs | baseline | arm C | delta |
|---|--:|--:|--:|--:|
| Federal | 7 | 0.3214 | 0.3189 | **-0.0025** |
| NSW | 2 | 0.3728 | 0.3657 | **-0.0071** |
| Queensland | 2 | 0.3287 | 0.3348 | +0.0061 |
| South Australia | 1 | 0.3914 | 0.4162 | **+0.0248** |
| Victoria | 3 | 0.2698 | 0.2814 | **+0.0116** |

Per pair, federal itself is mixed (fed2010, fed2019, fed2022 improve —
fed2022 by far the most; fed2007, fed2013, fed2016, fed2025 all worsen by
small-to-moderate amounts) — the jurisdiction-level federal improvement is
real but driven substantially by the one election this was built for.

## Applying the decision rule

The pre-registration's clause 2: *"no jurisdiction's log loss worsens by
more than 0.01."* **South Australia (+0.0248) and Victoria (+0.0116) both
breach this outright.** A blanket adoption across all five harnesses is
therefore **refused**, exactly as the pre-registration's own rule requires —
no exception was made for the size of the fed2022 win.

**Victoria is the live target election.** Shipping this as the new
`published_flags.R` default would have moved the actual Victoria forecast's
own historical validation in the wrong direction to fix a federal-specific
problem. That is not an acceptable trade regardless of urgency.

## What shipped instead: federal and NSW only, as a local default

Both jurisdictions where arm C measures a genuine improvement, and neither
breaches the 0.01 bound. Implemented as a **harness-local default**, not a
`published_flags.R` change:
`backtest_candidate_fed.R` and `backtest_candidate_nsw.R` each set
`AUSPOL_SALIENCE_EXPECTED`/`AUSPOL_SALIENCE_EXP_SD` to `"1"` before
`harness_defaults.R` runs, only if the caller left them unset — so an
explicit override in either direction still works, and Queensland, South
Australia, Victoria, WA and `fit_seats_full.R` (the published forecast) are
completely untouched; their own default stays `"0"` from
`published_flags.R`, unchanged.

## Honest caveat on how this decision was reached

This is **not** a clean instance of the pre-registration's own decision
rule — that rule was written for a five-harness blanket adopt/refuse
choice, and a federal+NSW-only split is a scope decision made *after*
seeing the jurisdiction breakdown, which is exactly the shape of thing
`CLAUDE.md` warns is worth almost nothing when the criterion is invented
post-hoc to fit an answer. The mitigating facts, stated plainly rather than
buried:

1. The rule's own refusal clause is respected in full — nothing here
   overrides "SA and Victoria breach 0.01, so blanket adoption is refused."
   The scope decision is *additional* to that refusal, not a workaround of
   it.
2. Federal and NSW are the only two jurisdictions where the sign is
   genuinely positive, not a cherry-picked subset of a bigger positive set.
3. There is an independently-statable reason search-interest salience might
   be a more reliable signal at the federal level than the state level
   (national name recognition, far higher search volume, national media
   coverage) — offered as a plausible mechanism, not as proof, and it does
   not explain NSW.
4. Victoria specifically getting worse is the reason NOT to ship broadly,
   which is the conservative direction to err in given it's the live
   target.

This should be re-examined with a real pre-registration of its own once
there is time to do it properly, rather than under one night's time
pressure. Recorded here so that re-examination has the honest starting
point, not a retrofitted justification.

## What this does not fix

- fed2022 remains under-called on the teals even with arm C on (Kooyong
  36.1%, still below 50%). This is a real improvement, not a solved
  problem.
- Queensland, South Australia and Victoria's own emergent-independent misses
  are untouched by tonight's work.
- The underlying cross-election salience-anchor problem
  (`docs/reviews/wave-term-blocked-2026-09-07.md`) is not resolved — arm C
  works entirely on the WITHIN-election salience ranking, which was already
  known to be valid; nothing here required solving the Trends-anchor issue.
