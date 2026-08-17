# The flow estimator survives a clean target set

Run 2026-08-18 against
[../plans/prereg-clean-flow-backtest.md](../plans/prereg-clean-flow-backtest.md),
committed as `b45499f` before the run.

## Verdict: `mean_last5` wins all three variants. Nothing changes.

Decision rule 1 applies as written — the choice stands and the contamination is
recorded as a caveat that did not change the answer.

| rank | A: as now (n=103) | B: clean targets (n=84) | C: clean targets + inputs (n=84) |
|---:|---|---|---|
| 1 | **mean_last5** 4.815 | **mean_last5** 5.237 | **mean_last5** 5.003 |
| 2 | last_in_region 4.863 | mean_last3 5.413 | mean_last3 5.214 |
| 3 | mean_last3 5.027 | mean_last8 5.719 | mean_last8 5.552 |
| 4 | mean_last8 5.174 | half_trend 5.786 | half_trend 5.683 |
| 5 | half_trend 5.198 | trend 5.856 | last 5.962 |
| 6 | trend 5.282 | **last_in_region 5.964** | **last_in_region 5.964** |

Every MAE rises on the clean set, which is the expected direction: a
carried-forward target is trivially predictable, so removing those makes the
task harder for every method at once.

Corrected contamination figures, using the package's own
`is_observed_election()` filter rather than the raw file: **29 of 205 observed
rows (14%)**, and **20 of 121 rows from 2004 on (17%)**. The earlier audit said
19% of 118 by counting unobserved rows the backtest never uses.

## The mechanism was real, and it was hitting a different method

The pre-registration predicted that carried-forward targets flatter persistence
estimators. They do, and the effect is large — but it landed on
`last_in_region`, not on the adopted method:

| | A | B | C |
|---|---:|---:|---:|
| `last_in_region` rank | **2** | **6** | **6** |
| `last_in_region` MAE | 4.863 | 5.964 | 5.964 |
| gap behind winner | 0.048 | 0.727 | 0.961 |

On the contaminated set it was within 0.05 MAE of the winner — close enough
that a small data change could have flipped the adopted estimator. On clean
targets it is nearly a full point behind and drops four places. **The
second-place finish was substantially an artefact**, and had the ranking gone
one notch differently in 2026-08-16's run, the project would have adopted a
method whose apparent strength was carried-forward data.

## What I got wrong

The audit speculated that contamination might explain a puzzle already in the
queue — that the linear trend placed sixth *"though the trends are real and
strong"*. **It does not.** The trend goes 6 → 5 → 7 across the variants and is
no better on clean targets. That hypothesis is withdrawn; the trend's poor
showing needs a different explanation, and the existing one in `NEXT-STEPS.md`
(leave-one-out let a later election inform an earlier prediction) stands
unchallenged.

## What still needs fixing, independent of this result

The estimator is vindicated. **The input record is not.**

`2022,vic,GRN FP,81.94` remains a carried-forward copy of the 2018 value, and
the actual 2022 count gives **79.2** across 29 districts and 211,842 ballots
([vic-preference-flows-2026-08-18.md](vic-preference-flows-2026-08-18.md)).
That is a wrong observation feeding a correct estimator, and correcting it
would move the 2026 Victorian Greens estimate and therefore the published
two-party figure — sized at **0.564 points**.

Twenty-eight other duplicates remain unverified. Only the Victorian 2022 Greens
figure has been checked against a real count. Western Australian Nationals at
exactly 5.0 for ten consecutive elections is the least plausible of them and
has not been checked.

**Correcting the record is a separate decision from choosing the estimator**,
which is why the pre-registration deliberately excluded substituting 79.2 into
this run. Doing both at once would have left neither attributable.

## Status of check G3

Unchanged, as the pre-registration required. It re-runs variant A every
pipeline run and still confirms the same winner, so it is not currently
misleading — but it has been passing partly because 17% of its targets are
free. Worth revisiting once the record is corrected rather than now.
