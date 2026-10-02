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
