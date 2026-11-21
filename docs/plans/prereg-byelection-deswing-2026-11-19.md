# Pre-registration: de-swing a by-election before the half blend (2026-11-19)

Committed BEFORE any arm run, with the switch (`AUSPOL_BYELECTION_DESWING`, default "0").

## Why

`AUSPOL_BYELECTION_PRIOR=blend` (shipped 2026-09-18, `prereg-byelection-prior-2026-09-18.md`) makes a seat's
prior row half the previous general election and half the by-election. `fit_seats_full.R:1359` (and every
harness's base_pred) then swings that row by the FULL statewide change from the previous general election to
the target (`dev_slope(mat22, a22, state_mean)`). The by-election half already carries the statewide swing from
the general election to the by-election date, so that part is counted twice, at half weight.

Live case, Werribee: by-election 8 Feb 2025, ALP 28.9 / LNP 29.0; statewide swing to that date (90-day poll
mean minus vic2022) ALP -10.7, LNP +8.0, GRN +2.0 (2 polls). Half of it counted twice is about ALP -5.3,
LNP +4.0 in the seat's base. The 11:08am 19 Nov forecast: LNP 63%, ALP 10% (Sportsbet LNP ~22%).
Mulgrave is the other live vic2026 seat the blend applies to.

The 18 Sep prereg read full replacement's misses as "the by-election protest swing reverting" (Inala ALP 37
at the by-election, 47 at the general). A double count produces the same shape. A de-swung by-election was
never tested.

## Exploration already seen (disclosed, not the test)

Before this file: on `output/published-predictions.csv` (35 elections, the published path), the ALP and LNP
cells of the 62 backtest by-election seats where both majors stood. 14 have no polls in the 90-day window
(zero swing; the arm cannot move them). Three WA seats (Nedlands 2005, Victoria Park 2008, Rockingham 2025)
were dropped from the check for a fault in the check itself (zero test matrix, so the LNP baseline fell to 0).
On the remaining 82 cells / 42 seats, signed miss (actual - ours) regressed on minus half the swing:
slope 0.80, SE 0.28 (1.0 = the double count fully explains it). Mean absolute error 4.55 -> 4.28 if the
correction were applied directly to the published shares. This is a proxy (it ignores the xgb layer's
response to a moved base), which is why the test below is a rebuild.

## The change (one switch)

`AUSPOL_BYELECTION_DESWING=1`: in `byelection_prior()`, for each polled class that stood at the by-election
(ALP, LNP, GRN, ONP), subtract `.byelection_swing()` (the existing helper of the refused fill arm: 90-day poll
mean before the by-election minus the previous statewide share) from its by-election share, floor at 0,
renormalise to 100, then blend at the unchanged weight 0.5. A class with no polls moves 0. Log line `BYS1`.
Weight, window and everything else unchanged.

## How it runs

One full rebuild from stage 1 with the switch exported, `AUSPOL_PUBLISH` unset, against the most recent
full-rebuild snapshot at the same code minus this switch. (The harnesses read cached as-at tree predictions,
`AUSPOL_XGB_PRIMARY=1`, so a `quick_arm` screen cannot see a base change; the 2026-10-05 by-election arm was
measured the same way.) The arm must print `BYS1` with a non-zero count for the by-election pairs; Black
sa2026's ALP base before and after is printed. A run with zero changed cells on by-election pairs is a run
that did not apply, not a null.

## Criteria (all 35 scored elections)

1. **Primary**: squared error on every primary-vote cell of the by-election seats (both majors stood, swing
   non-zero), arm minus baseline, SE clustered on election. PASS if lower by more than 1 SE.
2. **Guard**: pooled seat log loss not worse by more than 1 SE (clustered on election).
3. **Leave-one-election-out**: the primary is still lower with any one election dropped.
4. **Unacceptable win**: the primary falls but the by-election seats' own seat log loss rises by more than
   1 SE. Then it goes to Pete as a split, not shipped.

## Decision rule

All pass: take to Pete with the live Werribee and Mulgrave rows walked in plain numbers; he decides
(`AskUserQuestion`). Primary fails: refused, `DECISIONS.md`, switch stays "0". The live diff (Werribee,
Mulgrave, expected seats) is reported with the result either way.

## Amendment 1 (19 Nov, before any run; implementation only, criteria above unchanged)

Pete chose "rebuild first" (19 Nov). The pair runs from a one-shot Scheduled Task `auspol-bys-rebuilds`, 20 Nov
01:00 (waits for 8 GB free, starts by 04:00 regardless): arm then base, each a full rebuild from stage 1 at e04b6e65
in its own worktree (`C:\dev\auspol-wt-rb1`, `-rb0`), never publishing. Markers and logs:
`deciding-runs/20261119-bys-rebuilds/`. The baseline is rebuilt too (not an old snapshot) so the code is identical but
for the switch. Scorer: `Rscript scripts/score_byelection_deswing.R C:/dev/auspol-wt-rb0/output C:/dev/auspol-wt-rb1/output`
(criteria 1, 3, 4; tested 19 Nov: refuses an identical pair with BDS2!, scores a doctored arm exactly), then
`scripts/compare_rebuild_scores.R` on the two `pooled-backtest.csv` files (criterion 2).

## Amendment 2 (19 Nov, 4:30pm): SHIPPED on Pete's override before the rebuild pair was scored

Pete, after the double count was explained with Werribee's numbers and the recommendation to wait for the
rebuild: "Let's fix it now, please. This is urgent." The switch ships at "1" (published_flags.R and the code's
own default). This is his override of the decision rule above, which said the pair is scored first. The pair still
runs at 1am 20 Nov exactly as in Amendment 1 (it was pinned to commit e04b6e65 with the switch set explicitly in
each arm, so this change cannot reach it), and its result is reported to Pete against the criteria above. If it
fails the primary or trips the unacceptable-win clause, that goes to Pete as a reason to turn it back off.
Evidence at ship time: the published-path proxy (slope 0.80, SE 0.28, 42 seats) and the live walk (Werribee
Liberal 63% to 28%, Labor 10% to 42%; Mulgrave and expected seats otherwise within 0.3).

## RESULT (22 Nov 2026): all four criteria PASS; the switch stays "1"

The pair ran from the Scheduled Task on its third night (22 Nov, 1:00am to 4:26am Sydney time, both arms rc 0, commit
e04b6e65, worktree preflight 0 external files missing). Two earlier nights failed before scoring anything (20 Nov the
machine slept; 21 Nov both arms died at stage 0 because the worktrees lacked gitignored inputs); no criterion was
changed between attempts. Scored from the main checkout with the two commands of Amendment 1. Evidence kept in
`deciding-runs/20261122-bys-rebuilds/` (`score-byelection-deswing.txt`, `compare-rebuild-scores.txt`, both
`pooled-backtest` files, both nsw2019 seat-probability files).

Checked that the arms differ only by the switch: the `BYS1` line is in 36 of arm 1's stage logs and in none of arm
0's. Arm 0's snapshot holds 27 fewer files (595 against 622): the as-at primary models of 9 early elections, which
arm 0 reused from the 13 Nov cache because their inputs were unchanged (`XA2 ... CACHED, inputs unchanged`, `XA3 9 of
35 targets reused`), while arm 1's inputs had moved and all 35 were retrained.

Scored set: 19,616 rows / 35 elections in each arm; 62 by-election seats with both majors standing in 25 elections; 57
scored (375 primary-vote cells, 23 elections), 56 of them moved by more than 0.05 points.

| criterion | measured | verdict |
|---|---|---|
| 1. Primary: squared error on the by-election seats' primary-vote cells, arm minus base | -248.9 of a base total 8,598.1 (SE 180.9, jackknife over 23 elections) | PASS (lower by more than 1 SE) |
| 2. Guard: pooled seat log loss | 0.3170 to 0.3164, change -0.0006 (SE 0.0016; 2,931 seats / 35 elections) | PASS |
| 3. Leave-one-election-out | still lower with any one dropped; worst -157.1 without nsw2015 | PASS |
| 4. Unacceptable win: the by-election seats' own seat log loss | -0.0305 per seat (SE 0.0237, 57 seats) | not tripped |

By election, the primary fell in 16 of 23 and rose in 7 (largest rises wa2025 +62.3, wa2005 +47.9, fed2010 +43.9;
largest falls nsw2015 -98.6, nsw2019 -68.4, qld2024 -58.2). AEF-7 seat log loss, square-root-of-votes weights: -0.0017
(SE 0.0009).

One election's seat log loss rose by more than 0.02: nsw2019, +0.0412 (0.3104 to 0.3516). All of it is one seat. In
Murray the Shooters, Fishers and Farmers won; the base gave them 1 win in 20,000 simulations and the arm 0, which
scores at the 1e-6 floor (9.90 against 13.82, a difference of 3.91 over 93 seats = +0.042). The other 92 seats
improved, 0.2062 to 0.2053. Murray's predicted Shooters primary is 4.0% in the base and 3.9% in the arm against an
actual 40.3%: a miss in both arms that the de-swing did not cause. CAUSE NOT TRACED: the half blend does read the
Shooters' 31.5% at the October 2017 by-election (`byelections_between("nsw2015", "nsw2019")` returns the row as
`OTH_RIGHT`, and the blend covers every class; only the de-swing is limited to ALP, LNP, GRN, ONP), so the share is
lost somewhere after the blend. Queued separately.

Decision: under Amendment 2 only a failed primary or a tripped unacceptable-win clause would have gone to Pete as a
reason to turn the switch off. Neither happened. `AUSPOL_BYELECTION_DESWING` stays "1".
