# Pre-registration: a candidate's vote belongs to the person, not the class

Written and committed 2026-09-06 evening BEFORE the arm is run. P1 of
`plan-miss-patterns-2026-09-06.md`. Baseline is the published configuration
(`scripts/published_flags.R`), fingerprints `a9e3*` (fed) from the same day.

## The two defects, with the trace that found them

Both come from the class-level prior matrix treating a class's previous vote
as the class's property when it was one person's.

**D1 — a permit overrides a departed leader.** `screened_slopes()` gives a
new, screen-permitted candidate slope 1.0 ("uniform swing") on the class's
whole seat base. That was designed for Goldstein 2022: a 1.3% independent
class plus a permitted newcomer, where the surge hazard supplies the jump.
New England 2013 is the other case: Tony Windsor's 61.9% (scaled 1.5x by the
national minor-vote multiplier to 93.2) is the base, Jamie McIntyre is
permitted, slope 1.0 carries the whole thing, and the model gives an
independent 0.995 against Barnaby Joyce, who won with 54%. Lyne 2013 (Oakeshott
retired, 47.1% base, screen refuses, slope 0.326) lands at 0.631 through the
same base plus a 0.24 surge hazard; Kennedy 2013 at 0.603 (see D2).

**D2 — a class switch counts the vote twice.** `personal_prior_vote()` gives
a returning candidate their own prior vote as the base for their NEW class,
and leaves it in the OLD class too. Trace values into the simulator:

| seat | old class keeps | new class gets | one vote |
|---|--:|--:|--:|
| Hunter 2022, Bonds ONP → IND | ONP 17.6 | IND 24.3 | 21.6 |
| Kennedy 2013, Katter IND → OTH_RIGHT | IND 70.4 (scaled) | OTH_RIGHT 46.7 | 46.7 |

## The change (one arm, both rules together)

1. `candidate_returns()` also reports, per (seat, class), whether the PRIOR
   election's leading candidate of that class stands in the seat at the target
   election under any label (`prior_leader_returns`). When they do not, the
   permit in `screened_slopes()` does not override the fitted new-candidate
   slope: `ifelse(!is_same & permit & prior_leader_returns, 1.0, base)`.
   A departed leader's vote decays at the fitted `new` slope (0.326 for IND,
   which is the retention New England actually showed: 20.4 / 61.9).
2. `personal_prior_vote()` also reports `prev_party` and `transfer` (the
   amount it moved), and a new `apply_personal_prior(mat, own_prev)` applies
   the substitution AND subtracts `transfer` from the old class in the same
   seat (floored at 0). Every script that had its own `.own_x()` copy uses
   this one function: the four harnesses that had it and `fit_seats_full.R`.
   WA never had the mechanism and is unchanged.

Not in this arm, recorded so they are not confused with it: the national
minor-vote multiplier (`scale_to`) that turns 61.9 into 93.2, the surge hazard
regressing on the seat's prior independent vote (0.73 for New England 2013),
and the screen defaulting a seat with no salience row to "permitted". Each is
its own experiment.

## Targets (primary), all at the published baseline

| seat | now | what a fix must do |
|---|--:|---|
| New England 2013, winner LNP | p(IND) 0.995, p(LNP) 0.005 | p(LNP) rises above 0.5 |
| Kennedy 2013, winner OTH_RIGHT (Katter) | p(IND) 0.603, p(OTH_RIGHT) 0.306 | p(OTH_RIGHT) rises above p(IND) |
| Hunter 2022, winner ALP | p(ALP) 0.715, p(ONP)+p(IND) 0.255 | p(ALP) rises; the two carry-forwards fall |
| Lyne 2013, winner LNP | p(IND) 0.631 | expected roughly unchanged (D1 does not apply: screen refused); reported, not scored |

Dry run of the criterion on cases whose answer is known: Clark 2022 (Wilkie
returning, `same` TRUE, prior leader returns) must be untouched by rule 1 and
has no class switch for rule 2, so its 0.996 must not move; Calare 2025
(Gee, NAT → IND, the defector floor) must keep its IND base and now also
lose the transferred amount from LNP, so p(IND) may fall a little and p(LNP)
rise a little — recorded as expected, not a failure.

## Guards (do no harm), six federal pairs + the four state harnesses

- Six-pair mean log loss must not exceed the baseline 0.3717 by more than
  one standard error of the paired per-pair difference; Brier likewise
  against 0.0976. Report the per-pair table; a win carried by one pair is
  reported as such.
- Every seat an independent WON with a returning incumbent (Clark 2022 and
  2025, Mayo 2019/2022/2025, Warringah 2022/2025, Indi 2016–2025, Wentworth
  2025, Kennedy 2010, Denison 2013/2016) must not lose more than 0.02.
- State harnesses: Victoria, NSW, SA re-run; log loss within one seat's worth
  of the baseline (0.3218/0.2466, 0.3251, 0.3865). WA unchanged by
  construction and is not re-run.

## Refusal, decided in advance

Refused if any guard fails, or if the targets move the right way only
because a third mechanism (the surge hazard, the scaling) changed — the
trace lines for the target seats are printed and read before the score is.
An apparent win that comes with a returning-incumbent independent losing
more than 0.05 anywhere is refused regardless of the mean.

## Command

Bare harness runs at published defaults, one pair per launch:

```
AUSPOL_FED_PAIRS=<year> Rscript scripts/backtest_candidate_fed.R
Rscript scripts/backtest_candidate_{vic,nsw,sa}.R
```
