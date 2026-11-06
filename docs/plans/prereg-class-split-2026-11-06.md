# Pre-registration: two candidates of one minor class counted separately (`AUSPOL_CLASS_SPLIT`)

Written 2026-11-06 ~1:30pm, before any code or screen. Pete chose "Split now" in the design walk
(`docs/reviews/two-candidates-one-class-2026-11-06.md`), with the newcomer under-call as a separate item.

## What it changes

The seat count runs one runner per class, so two independents on 14% and 12% contest a seat as one candidate on 26%
(Waite 2022: IND class 0.734 to win; no independent passed 19.7%, Labor won on 26.6). The switch extends the existing
Coalition split (`coalition_split`, shipped 2026-10-17) to IND, OTH and OTH_RIGHT: in a seat where a minor class has two
or more nominated candidates, the class's simulated share is divided in each draw between a senior and a junior
candidate, who are excluded and counted separately. A win by either is a win for the class (output stays per class).

- **Junior fraction `r`**: second-largest per-candidate prediction divided by the sum of all the class's candidates'
  predictions in that seat (`pred_xgb`, `output/minor-candidate-oof-resid-v2.csv`, time-forward). The senior holds the
  rest (third and later candidates stay lumped with the senior: a known residual of the old bug, version one).
- **Spread**: a Beta around `r`, sd = RMSE of (actual junior fraction - predicted) over EARLIER elections' split seats.
- **`f`**: the share of an excluded same-class candidate's votes that go to the other while both are in the count, from
  the transfers files' same-class rows (`from == to`), earlier elections only, shrunk by jurisdiction as `coalition_f()`.
- **One split per seat.** Where the Coalition split is active it keeps precedence (5 of the 84 primary seats: Mallee
  fed2019, Narungga sa2022, Flinders sa2026, Morwell vic2018, Kimberley wa1996). Otherwise the minor class whose junior
  has the largest predicted share is split.
- Elections without per-candidate predictions (vic2026, nsw2027, wa1996, wa2001) get no class split, printed.

## Known answers, stated before the screen

- Waite sa2022: IND win probability must fall well below 0.734 (Duluk's share of the split ~25.7 against Labor).
- Monash fed2025: IND must fall below 0.635. Morphett sa2018: below 0.806.
- Calwell fed2025: IND stays low (0.032 now); the split cannot raise it much.
- A seat with no minor class of 2+ candidates and no Coalition split is byte-identical (published flow noise is 0).
- Applied check: the run must print, per election, how many seats got a class split, by class, and the 5 skipped.

## Screen

`scripts/quick_arm.R "AUSPOL_CLASS_SPLIT=1" --pairs=all --sims=1000`, baseline the shipped configuration, common random numbers.

- **Primary: seat-winner log loss (lower is better) over the 84 seat-elections with two or more candidates of one minor
  class on 5%+**, SE clustered on election. This set is defined by the OUTCOME (actual shares), which favours the arm;
  that is why the guards below are prediction-defined and election-wide.
- Guard 1: log loss over every seat where the split was active (about 2,500, defined from nominations), not worse by more than 1 SE.
- Guard 2: pooled log loss over all elections not worse by more than 1 SE, and no election worse by more than 2 SE of its own seats.
- Reported: the four walkthrough seats' IND probabilities before and after; leave-one-election-out on the primary.

## Decision rule (standard, `docs/PRE-REGISTRATION-RULES.md`)

- Primary better by more than 1 SE and both guards hold: recommend the 20,000-sim deciding run, then shipping.
- Primary within 1 SE: a tie; goes to Pete with the split by seat.
- A guard fails: goes to Pete with the split; not shipped on my call.

What would make a win unacceptable: the gain coming from seats where the class did NOT have a real second candidate
(junior actual share under 2%), which would mean the split is acting as generic IND deflation, not as the fix.
Reported as its own line.

Live forecast: not reached until per-candidate predictions exist for vic2026 (a separate step after the 10 Nov
nominations rebuild); stated to Pete with the result.

## RESULT

(not run)

## Amendments

(none)
