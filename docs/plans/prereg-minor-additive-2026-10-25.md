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

## Result, federal screen (2026-10-25, quick_arm, 7 pairs, 1,000 sims, --reuse --slots=1): REFUSED on the primary

Run `deciding-runs/20261025-minor-additive-fed/results.txt` (exit 0, 611 s). HD1: the switch applied, nothing leaked.
Switch-off parity: the fed2025 canary re-ran byte-identical under the new code. Scored with
`scratchpad/score_minor_additive.R` (arm 022fac962142 vs baseline 40cea88204b7); targets are the 935 seats with any
IND/OTH_RIGHT/OTH cell moved by more than 0.05 points (1,604 cells).

1. Primary FAILS (just): target-seat log loss 0.2677 -> 0.2664 (-0.0014, SE 0.0015), better but not by 1 SE.
2. Guard holds: all 1,047 federal seats -0.0011 (SE 0.0014). AEF-7 subset (301 federal ledger seats) -0.0012, SE 0.0006.
3. Leave-one-election-out: sign kept in 7 of 7 (dropping fed2019 leaves -0.0000).
4. FIRES: fed2007 worse by 0.481 summed seat log loss against 2 SE = 0.450. fed2007 has the largest cut (x0.59).
5. Without the two largest gains (Indi and Wentworth, both fed2019): -0.0002, sign kept but near zero.
6. Direction: 424 IND cells moved, 168 raised, 256 lowered; squared error on moved minor cells 24,214 -> 24,293.
7. Does not fire: largest drop for a winning independent 0.044.
8. Holds: only fit_seats_full.R and backtest_candidate_fed.R read the switch.

Reading: neutral on the federal pairs. It helps a big returning personal vote (Indi 2019 IND 25.2 -> 34.9, actual
32.4) and hurts some seats where the independent faded (Sturt and Boothby 2019 12.5/11.9 -> 18.1/16.9, actual 2.6; who
the previous independent was in those seats NOT checked). Not decided here: the live forecast currently uses the multiplicative rule, which no state
harness measures; the 28 state elections' scores come from the additive one. That is a parity question for Pete.
