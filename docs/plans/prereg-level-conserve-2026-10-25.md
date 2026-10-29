# Pre-registration (FINAL, built, nothing run): make the seat layer conserve the statewide level

Written 2026-10-25, before any code exists. Source: `docs/reviews/wa-nt-seat-layer-trace-2026-10-25.md`
(the trace that found the seat layer adds about one point to EACH major party's implied statewide share
above the level it was handed). Rules: `docs/PRE-REGISTRATION-RULES.md`, the shrinkage, leakage and
"a fix to one harness is a fix to all of them" rules in `CLAUDE.md`.

Status: FINAL 2026-10-25. The switch is built (`AUSPOL_LEVEL_CONSERVE`, default "0", byte-identical when
off) and no arm has been run. The criteria below are the draft's, unedited; what the build fixed that the
draft left open, and the exact commands, are in "Finalised 2026-10-25" at the end. Every departure from the
draft text is listed there as a visible addition.

## The question

Every harness projects each class with `dev_slope()` around the statewide level, then renormalises each
seat's row to 100 (`backtest_candidate_*.R`, e.g. `_wa.R:614`, `_nt.R:647`), after zeroing independents
where none nominated (`_wa.R:603`) and, later, every class with no candidate (`zero_unnominated_at("late")`,
`_wa.R:677`). Share the level gave a class that cannot stand in a seat goes to whoever is left in that seat,
in proportion to their share there. The level of a class with no candidate anywhere is dropped from the
level vector before the seats see it (`R/forecast_statewide.R:382` thin cycle, `:403` published path), so
the row renormalisation hands it out the same way.

Measured (28 state elections, vote-weighted implied statewide share minus the level used): ALP +1.07 (SE
0.38), Coalition +1.09 (SE 0.36), 20 of 28 positive each. NT +5.7 / +4.4; WA +0.45 / +0.68.

Does forcing the seats' implied statewide share to equal the level (after nominations) predict seats better?

## The change (fixed now)

New switch `AUSPOL_LEVEL_CONSERVE` (default "0" = byte-identical), read by all six state harnesses, the
federal harness (national level) and `fit_seats_full.R`, added to `scripts/published_flags.R` in the same
commit, one shared function in `R/` (no per-harness copies).

- **Targets.** The level vector `sb` restricted to classes with at least one candidate, rescaled to sum to
  100 over them (a class with no candidate anywhere gives its level up pro rata to the others' LEVELS).
- **Weights.** Each seat's formal vote at the PREVIOUS election (knowable before polling day); a seat with
  no previous figure gets the median weight.
- **Rake.** Iterative proportional fitting on the seat x class matrix after nomination zeroing: columns to
  the targets (vote-weighted), rows to 100, cells at 0 stay 0, 50 iterations or max column gap < 0.01.
- **Strength.** Final shares `= (1 - lambda) * current + lambda * raked`. Primary spec `lambda = 1`.
  Sensitivity `lambda = 0.5`, and `lambda` fitted time-forward as the least-squares coefficient of
  (actual implied minus current implied) on (raked implied minus current implied) over earlier elections,
  shrunk toward 0.5 with `w = tau^2 / (tau^2 + se^2)`. Sensitivities are never decisive.

Arms (each must be measured; CLAUDE.md "test base_pred AND the xgb layer"):

| arm | where | reaches |
|---|---|---|
| `base` | on `base_pred`, just before `xgb_primary_override()`, with the target's nomination zeroing applied first so the targets are the standing classes | the xgb layer through `AUSPOL_XGB_BASE_DELTA` re-prediction |
| `final` | after `zero_unnominated_at("late")`, the last step before simulation | the published shares directly |
| `both` | both positions | |

## Dry runs (before any decision run, results written here first)

1. `AUSPOL_LEVEL_CONSERVE=0` scores exactly 0 on every pair.
2. Leaked check: with the oracle level (`AUSPOL_FORECAST_MODE=0`), `final` must make the implied statewide
   share exact (max gap < 0.05 points) and must IMPROVE pooled seat primary MSE. The 2026-10-25 screen found
   the exact level made WA and NT seats worse because the seat layer added its own point on top; if
   conservation does not reverse that, the mechanism is not what this prereg says and it stops here.
3. Print per pair: dropped level mass, implied minus level before and after, for ALP and Coalition.

**Dry run 1 RESULT (2026-10-29, quick_arm 1,000 sims, all 35 elections, code t6fd672d): PASS.** 0 of 19,616
cells changed in 0 of 35 elections; seat log loss 0.3062 -> 0.3062 (2,931 seats), AEF-7 0.2634 -> 0.2634.

**Dry run 2 RESULT (2026-10-29, `final` at `AUSPOL_FORECAST_MODE=0`, 1,000 sims, all 35, code 7c279fc4): PASS.**
The first attempt crashed on every election (`weights * M`: non-conformable arrays; the corpus weights were
tapply's 1-d array), fixed in 7c279fc4 before any number was read. Exactness: max |implied - level| after the
rake is 0.000 in all 35 (before 0.32-4.21; qld2017 drops 0.27 points of level). Primary MSE on the 13,974
changed cells: 241,856 -> 219,350, change -22,506 (-9.3%), SE 6,169 clustered on election, so better by 3.6
SE (quick_arm's own Q2 label says "FAIL / not clear" only because its generic bar also asks for -10%; this
clause asks for an improvement). Worse in 6 of 35 (nsw2011 +533, wa2005 +138, vic2014 +103, fed2010 +80,
sa2014 +71, fed2019 +8). The WA/NT reversal holds: NT better in 3 of 3, WA in 6 of 7. Seat log loss here is
LEAKED (oracle level) and is not a result: 0.2890 -> 0.2810 pooled, worse in 19 of 35.

## Decision (all on `quick_arm.R --pairs=all`, 20,000-sim deciding run before shipping)

SE clustered on election throughout.

- **Primary**: pooled seat log loss change (arm minus shipped) below 0 by more than 1 SE.
- **Secondary** (reported, must not be worse by more than 1 SE): ALP and Coalition seat primary MSE, pooled.
- **Targeted** (the cells the fix is for): ALP and Coalition signed seat error, mean by jurisdiction; NT and
  WA Coalition must move toward 0.
- **Guards**: leave-one-election-out worst case still below 0 (no one-election share refusal, per memory
  rule); no jurisdiction's log loss worse by more than 2 of its own SEs; AEF-7 ledger subset reported.

**Unacceptable even if the primary passes**: any election's implied ALP or Coalition error made worse by
more than 3 points; a raked cell above 0 where the class has no candidate; any change to a pair whose
targets were already met within 0.05 (should be byte-identical).

Choice between arms: the one with the lower pooled log loss, provided it passes; if `base` and `final` are
within 1 SE, prefer `base` (one mechanism, xgb sees it).

## What would make a win suspicious

- Gain concentrated in nt2024 (its dropped 14.8-point Territory Alliance level is a level-model problem, the
  thin cycle carrying a party that did not stand): report the arm with NT excluded; it must still pass.
- WA 2017 / 2021, where the level under-called Labor by 4.0 and 6.9 points: conservation will make Labor
  worse there. That is expected, not a reason to refuse, provided the guards hold.

## Finalised 2026-10-25 (added when the switch was built; nothing above edited except the status line)

### Premise, re-checked in the code before building

Confirmed at these lines (current `dev`, 434c801 plus this change): each harness renormalises every row after
`dev_slope()` and the independent zero (`_wa.R:623`, `_nt.R:647`, `_fed.R:1495`, `_vic.R:701/719`,
`_nsw.R:798`, `_qld.R:836`, `_sa.R:991`; live `fit_seats_full.R:1382`), and the level loses any class with no
candidate in the target table before the seats see it (`R/forecast_statewide.R:382` thin cycle, `:403`
published path, both `keep <- intersect(..., names(st_b))`, with no rescale). No harness vote-weights
anything at the seat layer today; the weights below are new.

### What was built

One function, `level_conserve_apply()` in `R/level_conserve.R` (with `level_conserve_rake()`, the IPF), called
at the same two points by every entry point. Values of `AUSPOL_LEVEL_CONSERVE`: `"0"` (default, byte-identical:
the call returns its input before reading anything), `"base"`, `"final"`, `"both"`. It is listed in
`post_xgb_switches()`, so a stage-1 run that records the base-delta reference refuses to run with it on.
Prints one `LCV1` line per call: weight source, level mass dropped (classes with no candidate), per targeted
class the implied statewide share before -> after against its target, and the worst departure before and after.

| entry point | level vector | `base` call (just before the xgb override) | `final` call (after the last nomination zero) | standing classes from |
|---|---|---|---|---|
| `backtest_candidate_fed.R` | `st_fc` (forecast mode) else `st_b`, NATIONAL | `:1506`, before `xgb_primary_override()` | `:1853`, after the `NZ1b` late zero, on `X$shares` (scored seats only) | `fb` |
| `backtest_candidate_vic.R` | `sb` | `:774` | `:952` | `fb` |
| `backtest_candidate_nsw.R` | `state_tgt` | `:915` | `:1064` | `fp_tgt` |
| `backtest_candidate_sa.R` | `st_b` | `:1080` | `:1272` | `fb` |
| `backtest_candidate_wa.R` | `sb` | `:633` | `:691` | `fb` |
| `backtest_candidate_qld.R` | `st_b` | `:900` | `:1092` | `fb` |
| `backtest_candidate_nt.R` | `sb` | `:657` | `:712` | `fb` |
| `fit_seats_full.R` (live vic2026) | `.level_split` (the per-class split the trees are served; `AUSPOL_LIVE_LEVEL_SPLIT=1`, shipped), else the seat layer's own targets (`state_mean`, `a22 * scale_to`) | `:1477`, before `xgb_primary_predict_live()`, so the raked base is the trees' `base_margin` | `:1574`, after `zero_unnominated_live()` | the live nomination list when `AUSPOL_NOM_LIVE=1` opens it, else every class with share |

Both placements are supported at every entry point. In the backtests `base` reaches the xgb layer only
through `AUSPOL_XGB_BASE_DELTA=1` (shipped): the frozen as-at trees re-predict a cell from cached
`base_pred` + (this run's share - the stage-1 share). Live, `base` reaches the trees directly as
`base_margin`. `final` touches the shares the simulation reads at every entry point.

### Details the draft left open, fixed now (visible additions)

1. **`base` adds the CHANGE, not the raked matrix.** At the base point the nomination zero has not run yet
   (it runs after the override). So `base` zeroes the non-standing cells, renormalises pro rata, rakes that,
   and adds (raked - zeroed) to the standing cells of the unzeroed shares; the non-standing cells are left
   for the later zero. Reason: the cached `base_pred` the base-delta path adds to is already after the
   nomination zero, so passing the zeroing itself through would count it twice. Consequence: under
   `AUSPOL_XGB_BASE_DELTA` the base the trees see is the raked matrix (to the extent the stage-1 zeroing by
   flows matches pro rata); at `AUSPOL_XGB_PRIMARY=0` the later zero by flows leaves the match approximate.
   The `LCV1` line reports the raked base. A standing cell the addition takes below 0 is set to 0 and its
   row rescaled; the count is printed.
2. **Held cells.** The departed-hold cells (`HELD`, `AUSPOL_DEPARTED_HOLD`) are never adjusted; they count
   toward their class, whose other cells make up the rest. A standing class with no level is held whole. A
   row with nothing adjustable is left alone (printed). This is the only "held" notion wired; the Victorian
   harness's `ELASTIC` pins are a different mechanism and are not read.
3. **Weights**: as the draft (formal votes at the previous election, median for an unmatched seat), read from
   `output/candidacies.csv`; the previous election is the latest one of the same region with an earlier year.
   With no corpus the weights are equal and the line says so.
4. **Tolerance.** The draft said "50 iterations or max column gap < 0.01". Built: iterate to a worst gap below
   1e-8 points (at most 10,000 sweeps; each is microseconds) and REFUSE with `stop()` if the gap is still
   above 0.01, the draft's own tolerance. Refused up front too: a class whose held cells already exceed its
   target, or one with a positive target and nothing adjustable. A refusal stops that harness run; it is
   loud by design, and a refused pair is reported, not dropped. Live, the same: with the switch on, any
   failure (the refusal included, or a nomination list asked for with `AUSPOL_NOM_LIVE=1` that cannot be
   read) stops `fit_seats_full.R`; a forecast asked to conserve the level is never published without it
   (review fix, 2026-10-25; the first build caught the error and published unconserved shares).
6. **Fed seat sets differ between the two placements.** The federal `final` rake runs on `X$shares`, already
   cut to the divisions with a declared winner (`keep`), while `base` rakes every division, so the national
   weights cover slightly different seat sets at the two points.
5. **Lambda.** `AUSPOL_LEVEL_CONSERVE_LAMBDA` (default 1) gives the 0.5 sensitivity. The time-forward fitted
   lambda is NOT built as a switch: it is computed afterwards from the `LCV1` lines (current and raked
   implied share per class and election) and the actual statewide shares, earlier elections only, shrunk to
   0.5 as written above. It stays a sensitivity, never decisive.

### Exact commands (run from the auspol root; none has been run)

Screen on AEF-7 first (the default pair set), one arm per launch:

```
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=base"
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=final"
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=both"
```

Then all elections (includes nt2016, nt2020, nt2024), same three arms:

```
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=base"  --pairs=all
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=final" --pairs=all
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=both"  --pairs=all
```

Dry runs, before reading any arm:

```
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=0" --pairs=all                                   # dry run 1: every pair exactly 0
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=final" --base="AUSPOL_FORECAST_MODE=0" --pairs=all  # dry run 2: oracle level
```

Sensitivity on the chosen arm, and the deciding run (20,000 simulations, detached, all elections):

```
Rscript scripts/quick_arm.R "AUSPOL_LEVEL_CONSERVE=<arm> AUSPOL_LEVEL_CONSERVE_LAMBDA=0.5" --pairs=all
powershell.exe -File scripts\deciding_run.ps1 -Arm "AUSPOL_LEVEL_CONSERVE=<arm>" -Label level-conserve-<arm>
```

Read each run's `LCV1` lines first: dropped mass per pair and the worst departure before -> after (dry run 3).
A pair whose departure was already under 0.05 must score exactly 0 (the "unacceptable" clause).

### The nt2024 caveat (said before any run)

nt2024's level carries Territory Alliance's 14.1 forward as OTH 14.8 (thin cycle, no OTH polls), the party
did not stand, and the level is dropped. Under conservation that 14.8 goes to the other classes by their
LEVELS, so the CLP target is about 39.6 / 85.2 x 100 = 46.5 against the 49.1 the seat layer gives it now and
an actual 48.9: conservation is expected to make nt2024's CLP seats WORSE. That is a level-model fault (a
dead party's share carried forward), not a reason to refuse this arm and not a gain it can claim. Report every
arm three ways: all elections, NT excluded (`--pairs=` naming every pair but nt2016, nt2020, nt2024), and
nt2024 alone; the "gain concentrated in nt2024" clause above is judged on the NT-excluded run.

## Screen results (appended; nothing above edited)

**`base` on AEF-7 (2026-10-29, 1,000 sims, code 7f3aa024): WORSE, stopped here (not run on all 35).** Seat log
loss 0.2634 -> 0.2697 (+0.0063, SE 0.0041, clustered on election; 681 seats, 7 elections). Exact at the rake
(max |implied - level| 0.53-2.01 -> 0.000 in all 7), so the mechanism ran. Share squared error on the 3,325
changed cells +193 (SE 1,096): no gain. By election (log loss base -> arm; squared-error change): vic2022
0.2643 -> 0.2953 (+649), nsw2023 0.2053 -> 0.2138 (+273), fed2025 0.3605 -> 0.3678 (+15), wa2025 0.1915 ->
0.1927 (-700), fed2022 0.2194 -> 0.2192 (+184), qld2024 0.2876 -> 0.2864 (-42), sa2026 0.2504 -> 0.2455 (-186).
Raking the base before the trees does not survive them; `final` (after the last nomination zero) is next.

**`final` on AEF-7 (2026-10-29): NOT PASSED.** Seat log loss 0.2634 -> 0.2705 (+0.0070, SE 0.0202), within 1 SE
but the wrong sign; share squared error on 3,747 changed cells +9,907 (+20%, SE 5,649). By election: fed2022
0.2194 -> 0.2970, nsw2023 0.2053 -> 0.2134, wa2025 0.1915 -> 0.1951, qld2024 0.2876 -> 0.2871, sa2026 0.2504 ->
0.2469, vic2022 0.2643 -> 0.2349, fed2025 0.3605 -> 0.3267.

**`both` on AEF-7 (2026-10-29): NOT PASSED.** 0.2634 -> 0.2708 (+0.0074, SE 0.0200); share error +10,346
(+21%, SE 5,579). Same pattern as `final` (fed2022 0.2968, vic2022 0.2400, fed2025 0.3267).

**Why (traced, fed2022 under `final`).** The level puts IND at 2.72 while the seats imply 4.55, and teal
independents won. Raking to the level cut the winners: Goldstein 0.476 -> 0.111, Kooyong 0.690 -> 0.172,
Curtin 0.527 -> 0.139, North Sydney 0.190 -> 0.072, Warringah 0.731 -> 0.348. Eight teal seats carry +8.02 of
fed2022's +11.71 summed log-loss change (151 seats). The rake imports the level's misses into the seats, and
independents, whose vote is the candidate's, are where the level is weakest. None of the three arms is shipped;
`AUSPOL_LEVEL_CONSERVE` stays "0". A variant holding IND cells (and any class without a polled level) out of
the rake would be a NEW arm and needs its own amendment before it is run.

## Amendment 1 (2026-10-29, Pete chose it after the three arms above; written before any run of it)

A visible addition; nothing above is edited. It answers the one failure the trace found.

- **Change.** New switch `AUSPOL_LEVEL_CONSERVE_HOLD` (default `""` = byte-identical): a comma list of
  classes removed from the rake's targets. Their cells are held at their value (the rake already holds a
  class with no level), and the other targeted classes fill the rest of each election's vote in proportion
  to their levels. The arm is `AUSPOL_LEVEL_CONSERVE=final AUSPOL_LEVEL_CONSERVE_HOLD=IND`. IND only, fixed
  now: no other class is tried under this amendment. Why IND: its vote is the candidate's, the level model
  cannot see candidates, and fed2022's teal seats are where all three arms lost.
- **Screen.** AEF-7 first (`quick_arm.R`, 1,000 sims), then `--pairs=all` if not worse, under the
  Decision section above unchanged (pooled seat log loss better by more than 1 SE; the guards as written).
- **Known answers, checked before reading the pooled number.** fed2022 must come back near the baseline
  (0.2194; under plain `final` it was 0.2970); Kooyong, Goldstein and Curtin must keep their baseline
  probabilities to within 0.05, since IND is held. If they do not, the hold did not apply and the run is void.
- **What would make a win unacceptable.** The gain sitting entirely in vic2022 (plain `final` already moved
  it 0.2643 -> 0.2349 for reasons not traced): report the pooled change with vic2022 left out, and if it is
  then worse than 0, show Pete the split rather than calling it a pass.

**Amendment 1 arm (`final`, HOLD=IND) on AEF-7 (2026-10-29, 1,000 sims, code 1829af06): NOT WORSE, goes to all 35.**
Validity checks first: "holding IND" printed in all 7 elections; the teal seats kept their baseline probabilities
(Kooyong 0.690 -> 0.716, Goldstein 0.476 -> 0.501, Curtin 0.527 -> 0.540; all within 0.03). Seat log loss
0.2634 -> 0.2619 (-0.0015, SE 0.0079); share squared error on 3,444 changed cells +1,068 (+3%, SE 2,432). By
election: fed2022 0.2194 -> 0.2356, nsw2023 0.2053 -> 0.2174, wa2025 0.1915 -> 0.1952, qld2024 0.2876 ->
0.2897, vic2022 0.2643 -> 0.2595, sa2026 0.2504 -> 0.2436, fed2025 0.3605 -> 0.3323. vic2022 out (seat-weighted
from those rows, recomputed): -0.0010 over 593 seats (-0.0014 over all 681 from the same rounded rows), so the gain is not vic2022's; it is mostly fed2025. fed2022 is still +0.016,
now from Coalition seats (Bass 0.291 -> 0.170, Longman 0.461 -> 0.270): the level had ALP 34.9 -> 37.2 there.

**Amendment 1 arm on all 35 (2026-10-29, 1,000 sims, code 1829af06): REFUSED.** Seat log loss 0.3062 -> 0.3209
(+0.0147, SE 0.0058, clustered on election; 2,931 seats), worse in 23 of 35 elections; NT excluded +0.0124
(2,857 seats). Share squared error on 12,377 changed cells +44,110 (+18%, SE 21,310): worse by more than 2 SE.
Largest losses: nt2020 0.6176 -> 0.8293, qld2017 0.5752 -> 0.6784, qld2015 0.3275 -> 0.4137, nsw2011 0.2459 ->
0.3003, fed2019 0.2102 -> 0.2637, wa2017 0.3766 -> 0.4403. The AEF-7 tie (-0.0015) did not hold outside those
seven elections.

**Verdict for the whole prereg: level conservation is closed, not shipped.** `AUSPOL_LEVEL_CONSERVE` stays "0"
and `AUSPOL_LEVEL_CONSERVE_HOLD` "". With the exact (oracle) level it helps seat primaries (dry run 2: -9.3%);
with the forecast level it imports that level's misses into the seats, and the seat layer's own departures from
the level are, on balance, information rather than error. The majors' +0.6-0.8 tree overshoot this prereg was
written for is therefore not fixed by forcing the seats onto the level; it would need a better level.
