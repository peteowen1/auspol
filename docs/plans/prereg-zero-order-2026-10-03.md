# Pre-registration: run nomination zeroing AFTER the last step that can revive a zero (`AUSPOL_NOM_ZERO_ORDER = "late"`)

Registered 2026-10-03, before any harness run with the new order. DRAFT: written read-only
(no R run), so every number below marked UNCONFIRMED has to be filled or checked at the
first step of the run plan; nothing here has been measured.

## Why
v61 (`plans/prereg-nomination-zero-2026-10-03.md`) zeroes every class with no candidate
standing. Its harness call sits right after `xgb_primary_override()`. Several later steps
can write a share back into an already-zero cell, and the published script was already
fixed for that (`fit_seats_full.R`: zeroing after `blend_salience_shares`, branch
`nomination-zero-live`, PR #89, "Placed earlier (before the port), a positive adj revived
a zeroed Labor cell"). The six harnesses were not. The v61 numbers (primary RMSE 3.984 ->
3.774, log loss 0.3434 -> 0.3413) were therefore measured on a pipeline that partly
re-invents the phantom shares it removes, and the harnesses no longer measure what ships.
Rule applied: CLAUDE.md "A fix to one harness is a fix to ALL of them".

Revivers, read from the function bodies on 2026-10-03:
- `seat_swing_port_apply` (`R/seat_swing_port.R:131-132`): `pmax(0, ALP + adj)` and
  `pmax(0, LNP - adj)`. adj is mean-centred, so about half of the seats get a positive push
  into one of the two majors: a zeroed ALP cell is revived where adj > 0, a zeroed LNP cell
  where adj < 0. Fires on `AUSPOL_SEAT_SWING_PORT = "2"` (published) with
  `AUSPOL_XGB_PRIMARY = "1"`.
- `demographic_residual_apply` (`R/demographic_residual.R:219`, mode 2, ALP and GRN):
  `pmax(0, x + adj)`.
- `leader_seat_apply` (`R/leader_seat.R:122-130`, `.shift_cell`): the leader's class gains a
  bonus in the leader's seat. Can only revive the leader's own class in that one seat.
- `blend_salience_shares` (`R/salience_surge.R:436`): `(1-p)*share + p*surge_mu`, so any
  cell with p_hat > 0 and share 0 becomes positive. Whether the hazard table ever holds a
  cell for a class with no candidate is UNCONFIRMED.
Cannot revive: `seat_poll_blend_apply`, `departed_fed_apply` (touches only cells > 0;
`departed_fed_apply` also off, `AUSPOL_DEPARTED_FED = "0"`), `state_poll_pool_apply` and
`state_deviation_apply` (federal; both sit before the zero call already).

## Ordering in the six harnesses (file:line, at HEAD of dev, 2026-10-03)
Gate column: X = needs `AUSPOL_XGB_PRIMARY=1` (published 1); other gates named.

| step | fed | vic | nsw | qld | sa | wa |
|---|---|---|---|---|---|---|
| xgb override | 1464 | 746 | 838 | 801 | 969 | 620 |
| `zero_unnominated` (now) | 1520 | 749 | 841 | 804 | 972 | 623 |
| seat_swing_port | not called | 755 (X, PORT=2) | 847 (X, PORT=2) | 810 (X, PORT=2) | 978 (X, PORT=2) | not called |
| seat_poll_blend | 1474 (X) | 760 (X) | 852 (X) | 815 (X) | 983 (X) | 628 (X) |
| demographic_residual | 1495 (X, DEMO in 1,2) | 781 (same) | 873 (same) | 836 (same) | 1004 (same) | 649 (same) |
| leader_seat | 1500 (X) | 786 (X) | 878 (X) | 841 (X) | 1009 (X) | 654 (X) |
| departed_fed | not called | 788 (X, off) | 880 (X, off) | 843 (X, off) | 1011 (X, off) | not called |
| blend_salience_shares | 1752 (SURGE_V2, hz not NULL) | 870 (same) | 935 (same) | 956 (same) | 1108 (same) | not called (no WA salience corpus) |
| zero is before a reviver that fires | salience blend only | port, demo, leader, salience | port, demo, leader, salience | port, demo, leader, salience | port, demo, leader, salience | demo, leader only |
| LEAK? | possible, UNCONFIRMED (salience cell for a non-standing class) | YES (port is a certain reviver) | YES | YES | YES | possible, UNCONFIRMED (demo needs WA census rows for the pair; leader needs a WA leader row) |

Also in fed: `state_poll_pool_apply` 1472 and `state_deviation_apply` 1512 are before the
call and stay so. Published values read from `scripts/published_flags.R`: XGB_PRIMARY 1,
SEAT_SWING_PORT 2, DEMO_RESID 2, LEADER_SEAT 1, SALIENCE_SURGE_V2 1, SALIENCE_BLEND 1,
SEAT_POLL_BLEND 1, EDU_RESID 0 (so `education_residual_apply` is off), DEPARTED_FED 0.
Not read, so UNCONFIRMED: whether each harness's `shares` between the old and new call
sites is read by anything that needs the zeroed matrix (see "Placement").

## Change
1. New switch `AUSPOL_NOM_ZERO_ORDER`, `"early"` (today's behaviour) or `"late"`. Add it to
   `scripts/published_flags.R` in the same commit (CLAUDE.md rule). Measurement runs both
   arms from one code version, so the arms differ in one thing and the arm fingerprint in
   the output filename tells them apart.
2. `"late"`: call `zero_unnominated()` after the last reviving step, same position as
   `fit_seats_full.R:1216`. vic/nsw/qld/sa: straight after the whole `if (SALIENCE_SURGE_V2)`
   block, OUTSIDE it (a NULL `hz` or SURGE_V2 off must still zero), before the first reader
   of `shares` that builds sd matrices (vic `reentry_sd_matrix` at 913). wa: after
   `leader_seat_apply` (:654). fed: the salience blend works on `X$shares` in a later
   per-pair stage, so keep the existing :1520 call and add a second call on `X$shares`
   straight after the salience block (a repeat on already-zero cells changes nothing; it
   can only undo a revival). Needs that stage to have the pair's nominations table and flow
   matrix in scope: UNCONFIRMED.
3. In `"late"` mode the early call is skipped in the five non-fed harnesses.
4. Same commit, all six harnesses, plus an assertion at each harness's final write using
   `nomination_zeroed_cells()` / `assert_nomination_zeros()` (`R/nomination_zero.R`), the
   same check the live path has.

## What the v61 comparison was (so a re-measure compares like with like)
- Prereg criterion (v61): (1) PRIMARY final primary RMSE over the seats where any cell was
  zeroed improves, any amount; (2) GUARD 22-election log loss not worse by more than 0.0020;
  (3) GUARD no single election's seat log loss worse by more than 0.011. UNACCEPTABLE: it
  zeroes a class that DID stand.
- Mode 2 result (snapshot `20261003-0115-ca788a4-from6` vs v60): primary RMSE over 1,313
  affected seats 3.984 -> 3.774; 22-election log loss 0.3434 -> 0.3413; worst single
  election wa2017 +0.0025, best wa2001 -0.0305, nsw2019 -0.0145; 0 zeroed cells where the
  class stood; Victoria 0.2654 -> 0.2649, ledger 0.2686 -> 0.2677. Zeroed cells overall:
  2,125 above 0.5% in 22 elections (v59 sharedetail).
- The script that produced "1,313 seats" and the primary RMSE is NOT in the repo
  (no file found by grep for 3.984 or 1,313 outside docs): the affected-seat definition
  below is therefore a re-statement, and step 0 of the run plan checks it reproduces 3.774.
- A snapshot newer than the one above exists: `20261003-0143-48f0233-from6` (the merge of
  main into dev). Which of the two is the BEFORE baseline is UNCONFIRMED; step 0 settles it.

## Named cells (defined before the run)
Pair-seat-class cell `(pair, seat, class)` in `pooled-sharedetail.csv`
(`pair, seat, party, pred_share, actual_share`).
- GHOST cell: `actual_share == 0` and `pred_share > 0` (a class that did not stand but is
  forecast to get votes). `zero_unnominated` zeroes by the same test (`votes > 0` in the
  result table), so a correctly-ordered pipeline has NO ghost cells except classes absent
  from the result table (listed in the NZ1 log as "untouched").
- REVIVED set R: cells that are ghost cells in the `early` arm AND whose class was nonzero
  right after `zero_unnominated` (identified from the harness log or by pre-zero dump, see
  run plan 0b). If R cannot be built that way, the fallback is ghost cells in the `early`
  arm with `pred_share >= 0.5`.
- AFFECTED seats A: seats containing at least one cell of R. Expect A to be far smaller than
  the 1,313 v61 seats; size UNKNOWN until step 0b.

## Criteria
C0 (correctness invariant, PRIMARY for "does the code do what v61 says"): in the `late`
arm, zero ghost cells outside the "classes absent from the result table" list, in every one
of the 22 pairs; `assert_nomination_zeros()` never fires. No noise, no n. Fails if a single
cell is nonzero.

C1 (PRIMARY, scoped to the change): on the affected seats A, `late` vs `early`:
 (a) primary-share RMSE over the cells of R's seats (all classes in the seat, since the
     freed share moves the rest of the row), (b) seat log loss on A. State n = |A| and
     |R|. SE clustered on seat-election (one row per seat-election: mean squared share
     error per seat, and per-seat log loss); also report the SE clustered on election
     (22 clusters) as a sensitivity, because seats in one election share a statewide swing.
 Pass: both point estimates are not worse (delta <= 0) AND neither is significantly worse
 (delta > +1.645 SE, seat-election clustered). If delta <= 0 but |delta| < the MDE below,
 C1 reads "direction only" and the decision rests on C0 and the guards; it does not read
 "improves".

C2 (GUARD, election-wide, `late` vs `early`, all 22 pairs, log loss clamped at eps = 1e-6
before the log): pooled seat log loss not worse by more than 0.0020 (carried over from v61;
its size in SE of the per-pair differences is computed from the v60 -> v61 contrast and
written in the addendum before the first run). Then Brier, then reliability by tail bands
(0.9, 0.95, 0.99, 0.999) with COUNTS via `scripts/compare_arms.R`; calibration slope
reported, never decisive. Not decisive: Brier and reliability are reported; only log loss
gates.

C3 (GUARD): no single pair's seat log loss worse by more than 0.011 (carried over from v61).

C4 (INVARIANT, the v61 unacceptable clause): 0 zeroed cells where the class stood.

## MDE sizing (computed BEFORE the first run, from existing files only)
Per-seat difference d_i for a seat-election in A is MSE_late(i) - MSE_early(i) (mean over
classes of squared share error) and, separately, LL_late(i) - LL_early(i).
 MDE = (1.96 + 0.84) * SE(mean d), SE clustered on seat-election, 80% power, two-sided 0.05.
 sd(d) cannot be measured before the run; use as the proxy sd of the per-seat differences
 in the v60 -> v61 contrast on the same seats (read from the two snapshots' sharedetail,
 no R model run). Then fill in:
   |A| (zeroed cells that are later revived) = ____   (from run plan 0b; UNKNOWN now)
   proxy sd(d) = ____    SE = sd/sqrt(|A|) = ____    MDE (MSE units) = ____
 Plausible effect, an UPPER bound only: v61's whole gain on its 1,313 seats was MSE
 15.87 -> 14.24 (-1.63 per seat, from 3.984^2 and 3.774^2). The revived cells are a subset
 of that, so the expected effect is a fraction of 1.63. A rough way to see the power: the
 v61 effect over 1,313 seats is detectable only if sd(d) is below about 1.63*sqrt(1313)/2.8
 = 21 (MSE units); for |A| of 100 the same effect needs sd(d) below about 5.8.
 Rule: if MDE > the expected effect, C1 is reported as direction only (above) and C0 plus
 the guards decide. That is stated now so it cannot be invented at scoring time.
 Per-pair zeroed-cell counts feeding |A| (UNKNOWN; read off each pair's NZ1 log line in
 step 0b): fed 7 pairs, vic 3, nsw 2, qld 2, sa 2, wa 6 (7 minus wa2021, skipped; total 22).

## Dry run of the criteria on cases with a known answer (do before committing)
D1 Narracan vic2022, Labor (the case that started v61, zeroed to 0 by v61). The criterion
   must say: `late` arm pred_share for ALP = exactly 0 (C0). Record the `early` arm value
   too: Narracan is a positive control for the fix ONLY if `early` is > 0 (port adj > 0 there
   revives it). If `early` is also 0 the case does not discriminate; pick the first
   vic/nsw/qld/sa ghost cell in the `early` arm instead and say so in the result.
D2 A seat where nothing is zeroed (no ghost cell in the `early` arm, every class with
   pred_share > 0 has actual_share > 0): `late` point estimates (sharedetail pred_share)
   byte-identical to `early`. Reason it should hold: zeroing is row-wise (`tot[k]/rs[k]` is
   exactly 1 on an untouched row) and the port, demographic cache, leader and salience steps
   do not read other rows' shares; UNCONFIRMED for the salience blend and demographic
   fit path (both use whole-matrix helpers). Seat probabilities may NOT be identical: the
   statewide draw is anchored to the whole matrix, so one changed seat can move another's
   probability by simulation noise; do not use probabilities for this test.
D3 A pair where nothing can be revived (expected: some wa pairs, if demographic and leader
   do not fire on a zeroed cell, UNCONFIRMED): the full sharedetail and seat-probability
   files must be byte-identical between arms (same seed). If they are not, the arms differ
   in something other than the order and the run is invalid.
D4 Break it on purpose: run `late` with `AUSPOL_NOM_ZERO=0` and confirm C0 fails (ghost
   cells appear). A check that cannot fail is not a check.
Step 0 also: the `early` arm must reproduce 3.774 (affected-seat primary RMSE) and 0.3413
(22-election log loss) against the baseline snapshot to within the rounding shown, else
the affected-seat definition or the baseline is wrong and nothing downstream is read.

## REFUSAL section (named before any result)
A win on C0-C4 is NOT accepted if any of these holds. They are the reasons a "pass" would
still be wrong, written down because both earlier refusals in this repo came from
something invented after the result.
R1 Floor events. Any seat-election whose actual winner gets probability at the 1e-6 floor
   in `late` but not in `early` (the Barwon nsw2019 pattern, which sank mode 1). Count
   must be 0.
R2 One-way bias. Mean signed primary error (pred - actual) on the cells of A, per class
   (ALP, LNP, GRN, ONP, IND, other): refuse if any class's absolute bias on A grows by more
   than 2 SE from `early` to `late`. v61 mode 1 showed ALP bias -0.10 -> +0.61 while the
   RMSE passed; this clause exists for that.
R3 One-way winner flips. Count seats where the leading class changes between arms.
   Flips where the zeroed class was the leading class in `early` are expected (a party that
   did not stand cannot lead) and are reported separately, not counted here. For the
   remaining flips, refuse if >= 8 flips and a two-sided binomial test (p0 = 0.5) rejects
   at 0.05 that they go to one party (the One Nation rule of 2026-08-19: 71 of 87 up, 1
   down, was refused on direction).
R4 Port shape. The port is mean-centred statewide; zeroing after it removes its effect in
   zeroed seats and the freed share goes by flows. Refuse if the statewide mean
   ALP-minus-LNP shift of the port (SP2 log line) changes sign or its seat-level sd falls by
   more than half in `late`; that would mean the zeroing is overwriting what the port
   learned, not just the ghost cells.
R5 A class that DID stand zeroed anywhere (C4), or the "classes absent from the result
   table, untouched" list growing relative to v61.
R6 Federal arm moves for a reason that is not nominations. If `late` changes any fed cell
   whose class is not in R (a cell with actual_share > 0), refuse until explained: the fed
   change should be salience-only.
R7 A pair is scored on fewer seats in `late` than in `early` (count the elections AND the
   seats before any metric: "Count the elections").

What the criteria cannot see, said now:
- Wrong nomination data: a class recorded as not standing that did stand is zeroed
  correctly by the rule and wrongly by the world (C4 catches it only through the result
  table, which is the same source).
- Classes absent from the result table are untouched by design; any leak there is invisible.
- Stage 1 (`AUSPOL_XGB_PRIMARY=0` base_pred, the xgb training input) also runs the
  zero call; `late` moves it after the salience blend there too (the blend is not gated on
  XGB_PRIMARY). The as-at xgb models were trained on the `early` base_pred. A stage-6-only
  measurement keeps those models; whether to refit from stage 1 is a separate step, not
  decided here.
- `salience_sd_matrix(shares, hz)` (`AUSPOL_SALIENCE_EXP_SD`, default 0, published value
  UNCONFIRMED) is computed inside the salience block, before the new call, so with it on
  it would read unzeroed shares.
- wa2021 (skipped) and the live path (`fit_seats_full.R`, PR #89).

## Decision rule
Ship `late` (flip `AUSPOL_NOM_ZERO_ORDER` to `late` in `published_flags.R`, update
DECISIONS and NEWS) only if C0, C1 (not significantly worse, direction recorded), C2, C3,
C4 pass and none of R1-R7 fires, on the DECIDING 20,000-sim run. A result that is
inconclusive on C1 but clean on C0, C2-C4 and R1-R7 ships on correctness grounds with the
direction-only status recorded visibly, not as "improved". Anything else goes to Pete with
the split table; clause refusals are his call (`clause-refusals-go-to-pete`).

## Run plan (commands only; NOT executed). One harness-set per launch.
All from `C:\dev\auspol`, each launch as a single command, nothing else running (memory
watchdog: do not run beside R CMD check; check free GB first). Never edit scripts while a
run is in flight. Hand reruns can contaminate `output/`: the rebuild script snapshots to
`output/snapshots/<time>-<git>-from6`, and `scripts/restore_snapshot.sh <snapshot>` puts the
baseline back before anything is published.

Step 0 (read-only, no model runs): confirm the baseline and the affected-seat definition.
  0a. Pick the baseline snapshot (`...0115-ca788a4-from6` or `...0143-48f0233-from6`) and
      rebuild the v61 headline from its `pooled-sharedetail.csv` / seat files:
      expect 3.774 and 0.3413. `Rscript scripts/pool_backtests.R` prints per-pair numbers.
  0b. Per pair, record from the `NZ1` log lines how many cells are zeroed; fill |A| and the
      MDE block above. If a pair has no zeroed cell, say so.
  0c. Add the switch and the six edits (separate commit, reviewed), then continue.

Exploratory arms (`AUSPOL_N_SIMS=5000`, both arms at the same sims, same seed; sharedetail
point estimates do not depend on sims, log loss does, so the exploratory BEFORE is rerun at
5000 rather than compared against the 20,000 baseline):
  export AUSPOL_N_SIMS=5000 AUSPOL_REBUILD_FROM=6 AUSPOL_POOL_MIN_SIMS=5000
  launch 1: AUSPOL_REBUILD_ONLY=vic bash scripts/rebuild_forecasts.sh        # vic, 3 pairs
  launch 2: AUSPOL_REBUILD_ONLY=nsw bash scripts/rebuild_forecasts.sh        # nsw2019, nsw2023
  launch 3: AUSPOL_REBUILD_ONLY=qld bash scripts/rebuild_forecasts.sh        # qld2020, qld2024
  launch 4: AUSPOL_REBUILD_ONLY=sa  bash scripts/rebuild_forecasts.sh        # sa2022, sa2026
  launch 5: AUSPOL_REBUILD_ONLY=wa  bash scripts/rebuild_forecasts.sh        # wa, 6 pairs
  launch 6: AUSPOL_REBUILD_ONLY=fed bash scripts/rebuild_forecasts.sh        # fed, 7 pairs
  Each launch twice: first with `AUSPOL_NOM_ZERO_ORDER=early`, then `=late`; copy
  `output/backtest-<h>*-sharedetail-*.csv` and the seat-probability files aside to the
  scratchpad between arms, then restore the baseline snapshot. UNCONFIRMED: `reuse_check`
  may refuse to reuse a 20,000-sim result next to a 5,000-sim run; if it does, run the
  launches without REBUILD_ONLY or run the harnesses directly with the same env.
Compare: `Rscript scripts/compare_arms.R <early.csv> <late.csv> <label>` per pair;
  C0, C1, R1-R7 from sharedetail by a new read-only script (written and committed before
  the deciding run, not edited after).

Deciding run (`AUSPOL_N_SIMS=20000`, the default; `late` only, against the 20,000-sim
baseline snapshot from step 0a, which is the `early` arm at 20,000):
  export AUSPOL_REBUILD_FROM=6
  AUSPOL_NOM_ZERO_ORDER=late AUSPOL_REBUILD_ONLY=vic,nsw,qld,sa bash scripts/rebuild_forecasts.sh
  AUSPOL_NOM_ZERO_ORDER=late AUSPOL_REBUILD_ONLY=wa  bash scripts/rebuild_forecasts.sh
  AUSPOL_NOM_ZERO_ORDER=late AUSPOL_REBUILD_ONLY=fed bash scripts/rebuild_forecasts.sh
  (the first command is about the size of the cap; split it per harness if the 10-minute
  background limit bites, as CLAUDE.md says: one arm per launch.) Then
  `Rscript scripts/pool_backtests.R` for the 22-pair table and `scripts/compare_arms.R`.
No `AUSPOL_PUBLISH=1` from any of these.

## Result
(not run)

## Addendum 2026-10-03 (after step 0; the clauses above are NOT edited)

Written BEFORE any arm of this change has run. Source: `docs/reviews/zero-order-step0-2026-10-03.md`
(read-only, no harness run).

1. **Baseline restated.** Use snapshot `20261003-0143-48f0233-from6` (identical to `0115-ca788a4`:
   same backtest CSV hashes). 22-pair log loss reproduces: 0.3434 -> 0.3413 (2,120 seat-elections).
   Affected-seat primary RMSE does NOT reproduce to the rounding shown: 3.961 -> 3.767 over 1,311
   seats, against the registered 3.984 -> 3.774 over 1,313. The definition was not changed to force
   a match. Step 0's gate "to the rounding shown" therefore FAILS on RMSE and is recorded as failed;
   the restated figures are the baseline for any comparison here.
2. **Wrong file named above.** `pooled-sharedetail.csv` in the from6 snapshots is the stale stage-2
   xgb-off pool. Use the per-pair `backtest-<h>*-sharedetail-*.csv` files.
3. **Size of the effect.** Only 2 cells are revived in the final output: Narracan vic2022 ALP
   (33.37 -> 0.645) and Giles sa2022 IND (2.03 -> 0.43). 1,855 of 1,857 zeroed cells stay zero.
   Federal has 0 ghost cells. So |A| = 2 cells in 2 seats; the MDE for C1 (22.7 MSE units) is far above
   any plausible effect, so C1 is DIRECTION-ONLY by this prereg's own rule, and C2/C3 cannot falsify
   anything with 2 changed seats. The decision rests on C0, C4 and R1-R7. This is a correctness and
   live-path-parity change, not an accuracy claim.
4. **Reduced run scope (an amendment; why stated, not left silent).** The exploratory arms for all six
   harnesses are not run for accuracy: there is nothing to measure at 2 cells. Instead, at the same
   sims and seed: (a) both arms (early, late) on vic (3 pairs) and sa (2 pairs), the harnesses with
   the two revivals: C0 (zero ghost cells outside the by-design absent-class list) and the two named
   cells must read 0 in `late` and be unchanged in `early`; (b) the D3 byte-identical check
   (sharedetail and seat probabilities identical between arms) on one pair with no revival in each of
   nsw, qld, wa and fed; D3 failing means the arms differ in something other than the order and the
   run is invalid. The deciding 20,000-sim run is then `late` on the same harness set only if (a)
   and (b) pass. Anything not run is listed as not run in the Result section.
5. **Not covered, said now.** The simulation draws can still revive a zeroed cell (`R/seat_sim.R:1229`);
   this change does not touch that. Which step revived Narracan and Giles is unconfirmed (needs a
   pre-zero dump); `late` is expected to fix both by construction, and (a) tests exactly that.
