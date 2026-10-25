# Pre-registration: move the minor classes by points, not by a fraction (2026-10-25)

Written before any run of the arm.

## Why

The live forecast (`scripts/fit_seats_full.R`, minor-field block) MULTIPLIES every IND, OTH_RIGHT and OTH seat cell by
forecast others / 2022 others. For vic2026 that is about x0.61 (figure from `R/ind_return.R:7`, not re-printed here),
so Mildura's independent (Ali Cupper, 33.9 in 2022) enters at about 18.9 and is published at 17.6. A large personal
vote loses the same fraction as the whole minor field, though across 90 earlier returning independents their own vote
did not track the minor-field change (log-log slope 0.13, SE 0.16; `R/ind_return.R:8-9`).

The five state harnesses never take that path: each minor class has its own statewide level (bucket split) and every
seat moves by POINTS through `dev_slope()` (`scripts/backtest_candidate_vic.R:644-648`). Only
`scripts/backtest_candidate_fed.R` multiplies, like the live forecast. So 28 of the 35 scored elections already use
the additive form, and the state backtests have never scored the rule that publishes Mildura.

So the arm is a parity fix measured where it acts. 7 pairs is a thin base, and the state elections cannot speak to the
choice; that limit is stated with the result.

Not the IND_RETURN arm (refused twice, 25 Oct): that SET an independent's cell to their own record. This keeps the
shipped levels and slopes and changes only how a seat's cell reaches its class's level.

## The arm

`AUSPOL_MINOR_ADDITIVE=1` (default `"0"`): in `fit_seats_full.R` and `backtest_candidate_fed.R`, each scaled class keeps
its prior level as `dev_slope()`'s starting level and takes the scaled level as its target, so seat x moves to
`level_now + slope x (x - level_prev)` rather than `x x scale`. Class levels are unchanged. The five state harnesses
do not read the switch: they already behave this way.

## Where it can be measured

Only the 7 federal pairs (fed2007 x0.59, fed2010 x0.90, fed2013 x1.26, fed2016 x1.02, fed2019 x0.75, fed2022 x0.83,
fed2025 x0.83; baseline `BF0` lines). The other 28 elections are untouched (criterion 8). Screen: `scripts/quick_arm.R "AUSPOL_MINOR_ADDITIVE=1" --pairs=fed2007,...,fed2025`.

## Criteria (standard rule; SE clustered on election)

1. **Primary:** seat-winner log loss on the federal seats where any IND, OTH_RIGHT or OTH cell moves by more than
   0.05 points, better than shipped by more than 1 SE.
2. **Guard:** seat log loss over all seats of the 7 federal pairs not worse by more than 1 SE.
3. **Leave-one-election-out:** the primary keeps its sign with each pair dropped (7 pairs is too few for a 1 SE bar
   on every drop; each pair's share of the gain is reported).
4. **No pair materially worse:** no pair worse on the guard by more than 2 SE of its own paired seat differences.
5. **Not one seat's quirk:** the primary keeps its sign with the two largest-gain seats removed.
6. **Direction is reported:** IND cells raised vs lowered; squared primary error on moved cells.
7. **Unacceptable win (named in advance):** any independent who actually WON loses more than 0.10 win probability.
8. **Reaches nothing else:** no state harness reads the switch (`scripts/build_model_registry.R`'s parsed scan), so
   the 28 non-federal elections are untouched by construction and are not re-run in the screen.

Ship rule: ships only if 1 passes, 2-5 hold, 7 does not fire and 8 holds; then the full 20k deciding run on the 7
federal pairs. A clause refusing an otherwise-passing result goes to Pete with the split shown.

## Live walk (reported, not a criterion)

vic2026 with and without the switch: Mildura, Kew, Mulgrave, Shepparton, Benambra, and every seat whose IND share
moves by more than 2 points; statewide IND total before and after the row renormalisation.
