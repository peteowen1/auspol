# Pre-registration: booth-pattern features (`AUSPOL_XGB_BOOTH = "1"`)

Registered 2026-10-02 before any rebuild with it on. Pete's request: "same for
polling booths ... (test usefulness for every party)".

## Evidence (v58's remaining error; not a test)
State rows, controlled for the predicted share, election-clustered SE:
One Nation early-vote gap -1.25 per point (t -5.4, 3 of 4 elections); Labor
spread -0.19 (t -1.9, negative in 11 of 12); Greens early gap +0.16 (t +2.1).
Other classes and features: nothing.

## Change
`booth_spread` and `early_gap` from the previous election, every state and
federal row (scripts/build_booth_features.py, R/booth_features.R); NA where no
prior booth data. Rebuild from stage 3 against v58
(`output/snapshots/20261002-1435-0a481f6-from3`), same seeds.

## Criteria
1. PRIMARY (targeted): primary RMSE on One Nation, Labor and Greens rows that
   carry a feature value: per-seat change in summed squared error < 0 by more
   than 1 SE (clustered on seat).
2. GUARD: 22-election per-election log loss not worse by more than 0.0020 (the
   ensemble's measured seed range).
3. GUARD: Victoria seat log loss not worse by more than 0.0018 (the ensemble's
   seed range).
4. GUARD: primary RMSE, all rows, not worse by more than 0.01.
UNACCEPTABLE: the targeted classes improve while the other classes in the same
seats get worse by more than the targeted gain.

## RESULT, 2026-10-02 15:40: REFUSED (criteria 1 and 2 fail)

`output/snapshots/20261002-1529-14a2f2f-from3` against v58.
1. Targeted (One Nation, Labor, Greens with a feature, n 3,993): RMSE 4.063 ->
   4.063, per-seat +0.014 (SE 0.111) -- FAIL. One Nation 3.707 -> 3.737.
2. 22-election log loss 0.3444 -> 0.3469 (+0.0025 > 0.0020) -- FAIL. Driven by
   Barwon nsw2019 alone (log loss 9.9 -> 13.8, the 1e-6 floor; nsw2019 +0.064);
   10 of 22 elections better.
3. Victoria 0.2696 -> 0.2623 -- passes, and better.
4. Primary RMSE all rows 4.0946 -> 4.0610 -- passes, and better.
The gain landed on the NON-targeted classes in the same seats (4.131 -> 4.080),
not where the evidence pointed. Not shipped: an effect found after seeing the
results is not a pre-registered pass. A re-test would be a second attempt on
the same backtests and must be reported as such.

Barwon has now decided two verdicts in one day (the ensemble baseline and this):
the model gives some minor-party wins essentially zero probability, so the
22-election log loss is hostage to whether one seat lands at the floor.
