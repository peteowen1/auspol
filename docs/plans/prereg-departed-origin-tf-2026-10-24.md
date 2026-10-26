# Pre-registration: a departed defector's vote goes home, time-forward (2026-10-24)

Pete, 2026-10-24: *"Retiring members' vote going home (Morwell, and the same mechanism elsewhere). When a
member who left a party retires, send the released vote back to their former party first, instead of spreading it
across every party in proportion. Test it in both base_pred and the xgb layer."*

The mechanism already exists: `AUSPOL_DEPARTED_ORIGIN` (`route_departed_origin()`, `R/candidate_returns.R`), off
since `prereg-departed-origin-return-2026-09-18.md` fell 0.06 SE short on 15 cases. The investigation of
2026-10-24 (`docs/reviews/departed-vote-home-investigation-2026-10-24.md`) found two defects in its fit, both fixed
in the commit that adds this file, before any run:

1. **Leakage.** `fit_departed_origin_return()` was leave-target-out: it learned the go-home share from LATER
   elections. Now `fit_pairs_for()`, like every other fitted constant since 2026-09-28.
2. **A cliff.** Below 5 cases it fitted nothing; at 5 it believed the median outright. Now shrunk toward 0 by
   n / (n + 3) (`AUSPOL_DEPARTED_ORIGIN_SHRINK_K`, the same prior strength as `AUSPOL_CONSERVE_SHRINK_K`).

The corpus now gives about 40 cases across all elections (the 2026-09-18 run had 15), so it is worth
re-deciding. Both fixes reach the model only when the switch is on, so the shipped forecast is unchanged by them.

## Arms (part 1: base_pred)

Every axis but the one under test is the shipped configuration (`scripts/published_flags.R`).

| arm | setting | differs from baseline on |
|---|---|---|
| baseline | `AUSPOL_DEPARTED_ORIGIN=0` (shipped) | - |
| A | `AUSPOL_DEPARTED_ORIGIN=1` (median go-home share, shrunk, time-forward) | that switch only |
| B | `AUSPOL_DEPARTED_ORIGIN=mean` | that switch only |

Limiting case, stated before running: an election with no case before it (the earliest of each run of pairs) gets
no fitted share and must score byte-identical to baseline; quick_arm reports those as 0. An election with cases but
no departed defector of its own must also score identically.

Screen: `scripts/quick_arm.R "AUSPOL_DEPARTED_ORIGIN=1" --pairs=all` and the same for `mean`, common random
numbers against a shared baseline. The deciding run is `scripts/deciding_run.ps1` at 20,000 sims, all 22+ pairs.

## Criterion (the standard decision rule, unchanged)

1. **Primary:** squared primary-share error on the changed cells (the origin party and the departed class in each
   case seat), arm better than baseline by more than 1 SE, clustered on election.
2. **Guard:** seat log loss over every seat of every scored election, not worse by more than 1 SE.
3. Leave-one-election-out: the primary stays better by more than 1 SE with each election dropped.
4. No single election worse on seat log loss by more than 2 SE of its own paired seat differences.
5. Gain keeps its sign with the two largest-gain seats removed (Morwell 2022 is expected to be one).
6. Report how many case seats move toward the actual result.

**What would make an apparent win unacceptable:** a primary gain that comes with the origin party over-called in
seats it already led (the 2026-09-18 harm cases Hughes, Lyons, Frankston, Hillarys, Nedlands, Vasse 2008),
shown as more case seats moving away from the result than toward it (clause 6). If A and B both pass, A ships
(the median is less sensitive to the cases clipped at 0 or 1).

## Part 2: the xgb layer

The live forecast's xgb model (`xgb_primary_predict_live()`) takes `base_pred` as its `base_margin`, so a base_pred
change reaches the published number on the next run without retraining. Part 1 therefore tests the effect through
the trees as they are. A separate xgb FEATURE (`origin_released_i`: points of a departed defector's vote
attributable to the origin party) needs the as-at tree models retrained (rebuild stage 4), which quick_arm cannot
screen. It is run only if part 1 passes or comes within 1 SE, as an isolated stage-4 rebuild with its own
addendum to this file.

## RESULT, arm A screen, all elections (2026-10-26 01:29-02:05; appended, nothing above edited)

`quick_arm.R "AUSPOL_DEPARTED_ORIGIN=1" --pairs=all --no-reuse --slots=1`, 1,000 sims, code t181ee5f. Baseline
050d4221173d, arm 11424223b6df. Log `deciding-runs/quickarm-20261026-departed-origin-A-all.log`, score `...-all-score.txt`
(scorer `score_dep.R`, session e7e809d4 scratchpad). Arm B (`mean`) was not run, for time.

`BF0o` lines show the arm ran. Fitted, time-forward, shrunk go-home shares range from 0.041 (1 earlier case) to 0.451
(28 cases); 1 to 5 seats routed per election; 4 elections print `BF0o!` (0 cases, nothing routed), the limiting case.
Cells moved by more than 0.05 points: 176 of 19,616, in 21 of 35 elections.

**Approximation, stated:** the run log gives route counts but not seat names, so the primary is scored on every cell
that moved by more than 0.05 points. In practice that is the origin and departed cells of the routed seats, plus
whatever renormalisation and the trees moved alongside them. It is not a list frozen in advance.

| clause (lower is better; SE clustered on election) | n | change | SE | result |
|---|--:|--:|--:|---|
| 1 primary: share squared error on changed cells (points^2 per cell) | 176 cells / 21 el. | +1.3301 | 2.5571 | within 1 SE: NOT PASSED |
| 2 guard: seat log loss, every seat | 2,920 / 35 el. | +0.0001 | 0.0008 | holds |
| (quick_arm Q3 / AEF-7) | 2,931 / 681 | +0.0006 / -0.0002 | 0.0010 / 0.0035 | |
| 3 leave-one-election-out | 21 drops | never better by 1 SE; sign negative only without sa2026 | | FAIL |
| 4 no election worse by >2 own SE | | worst sa2026 z 1.21 | | holds |
| 5 without two largest-gain seats (Karama nt2020, Kavel sa2026) | | +3.1336 | 3.0087 | worse |
| 6 case cells moving toward the actual | | 109 toward, 67 away; 24 of 39 seats net better | | |

The large single-seat moves split both ways. Gains: Karama nt2020 -165, Kavel sa2026 -121, Waite sa2026 -90, Morwell
vic2022 -90 (the motivating case, better), Brennan nt2024 -85. Losses: Mount Gambier sa2026 +481, Hillarys wa2021
+210 (a named 2026-09-18 harm case, again), Cabramatta nsw2023 +203, Goyder nt2024 +95.

**Verdict: NOT PASSED.** The primary is within 1 SE but points the wrong way, and a few seats where the origin party
was over-called (Mount Gambier, Hillarys, Cabramatta) outweigh the cases it fixes, Morwell among them. That is the
unacceptable pattern this prereg named in advance, even though more cells move toward the result than away (clause 6).
Part 2, the xgb feature: the rule is "run only if part 1 passes or comes within 1 SE", and part 1 is within 1 SE, so
by the letter part 2 is eligible. It needs an isolated stage-4 rebuild and was not run. Whether to spend one on a
part 1 that leans worse is Pete's call.
