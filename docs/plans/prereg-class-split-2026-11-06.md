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

## RESULT (2026-11-06 2:58pm, 1,000 sims, all 35 elections, code 4d765927): REFUSED on both guards; primary a tie in the wrong direction. Not shipped; Pete decides what next.

Seat-winner log loss, lower is better (`scripts/score_class_split.R`, baseline cache 8c13eaa5fec0, arm 6afcc6757e4c):

| Set | Seats (elections) | Base | Arm | Arm - base (SE) | Verdict |
|---|---|---|---|---|---|
| PRIMARY: 2+ of one minor class at 5%+ | 78 (24) | 0.4990 | 0.5094 | +0.0104 (0.0169) | within 1 SE |
| Guard 1: every split-active seat | 1,600 (34) | 0.3303 | 0.3343 | +0.0040 (0.0024) | WORSE >1 SE |
| Guard 2: all seats | 2,931 (35) | 0.3042 | 0.3064 | +0.0022 (0.0013) | WORSE >1 SE |
| AEF-7 subset (quick_arm Q4) | 681 (7) | 0.2581 | 0.2591 | +0.0011 (0.0033) | within 1 SE |

- Applied: CS1 printed per election; split active in 1,600 seats; 6 of the 84 primary seats are in elections no harness scores.
  Guard 2 per election: fed2007 worse by more than 2 SE of its own seats (+0.0012, SE 0.0005); 19 of 35 worse, 15 better, wa2001 unchanged (no split).
- The known answers held: IND win probability fell in all four walkthrough seats (Morphett 0.798 -> 0.669, Waite 0.757 -> 0.647,
  Monash 0.634 -> 0.486, Calwell 0.033 -> 0.018). Those three wrong calls gained -1.22 of log loss between them.
- The loss is in seats an independent WON: Mildura 2018 +0.74, Alfred Cove 2005 +0.69, Mount Gambier 2026 +0.51, Calare 2025 +0.31.
  Splitting takes votes from the winner every draw. Where the per-candidate model has the order wrong (Alfred Cove: Jackson
  predicted 23.7 against Woollard 18.8; actual 6.8 and 24.0, Woollard won) or the junior is big (Calare: Hook 15.8 beside Gee 23.7),
  the winner is too often excluded or starved.
- Unacceptable-win line: not triggered (no gain came from seats with a junior under 2%: -0.0003, SE 0.0026). The loss sits in
  seats with a real second candidate (+0.0082, SE 0.0044).
- Leave one election out, primary: +0.0010 to +0.0178, never negative.

- By who won (split-active seats): the split class won 35 seats: +0.4151 (SE 0.0718); someone else won 1,560: -0.0052 (SE 0.0018,
  better by more than 1 SE). By class: IND 374 seats +0.0145 (SE 0.0104); OTH 372 +0.0008 (SE 0.0015); OTH_RIGHT 854 +0.0007 (SE 0.0008).

Reading: the mechanism does what it should on the cases it was built for, but the junior fractions it is fed are not good enough
(fraction error about 0.2-0.3; see the spread row in `docs/CONSTANTS.md`). It costs the model its correct independent wins more
than it saves on the wrong ones.

## Amendments

### Amendment 1 (2026-11-06 ~3:25pm, after the RESULT above, before any rescreen): the same split fed better predictions

Pete, 6 Nov 3:05pm: keep the split off and fix the per-candidate predictions first, then rescreen. Built:
`AUSPOL_MC_EXTRA=sal` in `scripts/fit_minor_candidates.R` (campaign search interest from `output/salience-v6.csv` as
the candidate's share of the seat's jump and a percentile among the election's non-zero jumps, and a Climate 200 /
Voices independent in the seat; 31 features against 26). Out of fold (`output/minor-candidate-oof-resid-v2-sal.csv`):
candidate RMSE 5.212 -> 5.135 points over 10,762 rows; independents 7.86 -> 7.57; the bigger of two same-class
candidates picked right in 66% of the 146 pairs whose class total is over 20% (58% before); junior-fraction error 0.216
-> 0.222 over all 2,500 pairs, 0.321 -> 0.308 on the 146 big ones. Holmes-Ross and Jones unchanged (low search interest).

Arm A1: `AUSPOL_CLASS_SPLIT=1 AUSPOL_CLASS_SPLIT_SRC=minor-candidate-oof-resid-v2-sal.csv`, same screen, same
primary, guards and decision rule as above, unedited. Expectation stated now: a smaller loss on the seats the class won,
not a pass; Alfred Cove's order is still wrong (Jackson 23.9 against Woollard 19.0). This arm is the one rescreen Pete
asked for; another amendment after it would be tuning to the outcome.
