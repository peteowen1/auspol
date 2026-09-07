# The statewide covariance: leakage closed, widening refused

Against `docs/plans/prereg-statewide-cov-loo-2026-09-07.md`, committed before
either arm ran.

## C1, the leakage — ADOPTED, and its effect is nil

`output/statewide-cov.rds` held one correlation matrix of statewide
first-preference changes. Every harness read it, including when scoring a pair
that was in the fit, so nsw2023 was correlated using nsw2023's own swing.
`statewide_cor()` now returns a leave-one-out matrix for a target inside the
fit, the all-pairs matrix for one outside it, and the all-pairs matrix for the
live forecast — which predicts an election that has not happened, so there is
nothing to leave out. The choice is returned as an attribute and every harness
prints it.

**The matrix moves a lot and the forecast barely notices.** Holding sa2026 out
of its own matrix moves cor(ONP, LNP) from −0.42 to −0.17 shrunk (−0.83 to −0.35
raw), which is the largest move of any pair and confirms refusal V3 of the
original covariance plan: One Nation's column was South Australia and little
else. Measured on identical data, with `AUSPOL_COV_LOO` switching only this:

| pair | in sample | leave-one-out |
|---|--:|--:|
| sa2026 | 0.3233 | **0.3229** |
| vic2018 | 0.3218 | 0.3219 |
| vic2022 | 0.2507 | 0.2508 |
| nsw2023 | 0.2963 | 0.2964 |
| fed2010 | 0.3270 | 0.3270 |
| fed2013 | 0.3863 | 0.3863 |
| vic2014 (control, not in the fit) | 0.4662 | 0.4662 |

The largest effect is 0.0004, in South Australia, in the right direction. The
control landing byte-identical is what confirms the switch does only what it
claims.

**It ships regardless**, as the pre-registration said it would. A correctness
fix refused for making a contaminated benchmark look worse is the leak
defending itself. In the event there was nothing to refuse.

## C2, the widening — REFUSED by its own refusal clause

The fit used 10 of the 21 pairs the corpus holds. The widened version was built
and run. **Refusal 1 fired**: `cor(ALP, IND)` is **−0.16 with Western Australia
in the fit and +0.43 without it**. A correlation that changes sign on one
jurisdiction is describing that jurisdiction, and independents are the class
this model cares most about.

The cause is visible in the data. Seven of the twelve pairs C2 would add are
Western Australian; that Assembly has almost no independents, and its statewide
Labor swings are enormous — +12 in 2017, +18 in 2021, −18 in 2025. A near-zero,
unmoving IND column paired with very large ALP moves manufactures a negative
correlation that has nothing to do with independents.

The refusal was written before the run and is honoured rather than rewritten,
which is the entire point of writing it first.

**What is not settled.** Widening to the non-WA pairs alone — fed2007, nsw2019,
vic2014 and the two Queensland pairs — is a different change that refusal 1 does
not implicate. It needs its own pre-registration and is the obvious next
experiment, not something to smuggle in on the back of this one.

## The criterion was the wrong instrument, and that is worth more than the result

The pre-registration made pooled seat log loss primary and sized its MDE against
the between-pair spread. That sizing missed the thing that actually dominates
the metric.

Pooled log loss moved 0.3433 → 0.3452 across this work. **All of it is one
seat.** Barwon in nsw2019 went from 0.000050 to 0.000001 — across the `1e-6`
floor — which costs 0.0426 on that pair and 0.0019 pooled, exactly the whole
move. The cause was not C1 at all: it was the covariance being rebuilt on
federal first preferences corrected by the Democratic Labour fix earlier the
same day.

So a metric with a 0.002 decision bar is being driven by a single hopeless seat
crossing an arbitrary constant. **A criterion that a floor-crossing moves twenty
times more than the effect it is meant to resolve cannot decide anything**, and
the repo's own rule — dry-run the criterion on cases whose answer you already
know, before committing it — would have caught this had it been applied to the
floor rather than only to the spread.

Two things follow, neither of them attempted here:

1. Pooled log loss needs a companion that is not hostage to `eps`: the count of
   seats at the floor, reported alongside, so a move can be attributed rather
   than assumed to be about the model.
2. The seats at the floor are the real finding. Every one is an emergence the
   model gives essentially nothing — Barwon, Shepparton, and the seats behind
   wa2001 and wa2008. That is where the log loss actually lives.

## Position after this work

22 pairs, 2,050 seat-elections, accuracy 87.2%, Brier 0.0945, pooled log loss
0.3452 — the 0.0019 against the morning's figure being Barwon alone.

| jurisdiction | pairs | seat-elections | accuracy | Brier | log loss |
|---|--:|--:|--:|--:|--:|
| federal | 7 | 1,036 | 86.9% | 0.0963 | 0.3237 |
| Western Australia | 7 | 361 | 87.3% | 0.0995 | 0.4074 |
| Victoria | 3 | 239 | 90.0% | 0.0780 | 0.3427 |
| New South Wales | 2 | 181 | 89.0% | 0.0817 | 0.3697 |
| Queensland | 2 | 186 | 85.5% | 0.1036 | 0.3295 |
| South Australia | 1 | 47 | 78.7% | 0.1129 | 0.3233 |
