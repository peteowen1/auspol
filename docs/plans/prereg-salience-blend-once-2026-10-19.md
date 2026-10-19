# Pre-registration: the salience pull counted once, inside the trees' base (audit F5), 2026-10-19

Committed BEFORE the arm is run. Pete chose the design ("Apply it once, before trees (Recommended)", 19 Oct) over
gating the pull out of stage 1, which would need a full stage-1 retrain per arm. Decision rule: the standard rule at the
top of `PRE-REGISTRATION-RULES.md`, no departures.

## The defect (`reviews/pipeline-overwrite-audit-2026-10-18.md`, F5; re-checked against the code 19 Oct)

`blend_salience_shares()` (the salience point estimate: a governed candidate's cell pulled toward `surge_mu` with
weight `p_hat`) runs AFTER the xgb override in the fed, nsw, qld, sa and vic harnesses, ungated
(vic:902, nsw:1003, qld:1031, sa:1210, fed:1789). At stage 1 (`AUSPOL_XGB_PRIMARY=0`) it therefore lands in the
sharedetail that becomes `base_pred`, the trees' training base. At stage 6 the cached tree prediction (and the
`AUSPOL_XGB_BASE_DELTA` re-prediction, whose `base_old` holds the stage-1 pull, `R/xgb_base_delta.R:172`) already
carries the pull, and the harness blends again. Live (`fit_seats_full.R`) is the mirror image: `base_margin` is
pre-pull, so the trees are served a base lower than they trained on for those cells, and the pull is applied once,
after the trees. WA and NT have no salience blend.

## The arm (`AUSPOL_SALIENCE_BLEND_ONCE=1`, default "0")

- Harnesses: `blend_salience_post_xgb()` (`R/salience_surge.R`) skips the blend when the switch is on AND
  `AUSPOL_XGB_PRIMARY=1` (stage 6), printing `SB?1 <election>: ... SKIPPED ... n cell(s) would have moved, by up to x
  points`. Stage 1 is unchanged, so the xgb pool is not retrained and stays valid.
- Live: the blend runs on the shares served to `xgb_primary_predict_live()` (`SBL1`), and not after the trees (DS3b
  says so). A no-op for vic2026 until its salience corpus exists (`.hz` NULL), so the published forecast is
  byte-identical today; the change acts live from about 9 Nov.
- Not changed: the simulator's surge draw (`surge_h`) and the xgb salience features, the other two copies the audit
  names. ARCHITECTURE.md records the blend-plus-draw pair as a measured double count that was kept.
- Proof it acts: SB?1 lines in every harness election with a corpus; OFF is the shipped code path (the wrapper
  returns the plain blend), checked by `tests/testthat/test-salience-blend-once.R` (7 expectations).

## Measurement

1. Screen: `Rscript scripts/quick_arm.R "AUSPOL_SALIENCE_BLEND_ONCE=1" --pairs=all --slots=1`. This arm moves
   predicted shares (not only the tails), so the 1,000-sim screen is informative at share level; the seat verdict
   still waits for 20k.
2. Deciding run if the screen is not WORSE: `deciding_run.ps1 -Arm "AUSPOL_SALIENCE_BLEND_ONCE=1" -Label f5-once`.
3. Scored by `scripts/score_quick_targets.R <baseline cache> <arm cache> 20000` (committed with this plan; dry-run on
   the F9 deciding run reproduced quick_arm's Q3 exactly: -0.0001, SE 0.0001, 2,931 seats; per-election
   qld2017 -0.0031, nt2024 -0.0079).

## Decision (standard rule)

- Targets: seats with any cell whose predicted share moved by more than 0.05 points between baseline and arm (chosen
  from predictions, never outcomes).
- 1 Primary: target-seat log loss better by more than 1 SE (clustered on election). 2 Guard: all seats not worse by
  more than 1 SE. 3 Leave-one-election-out holds on the primary. 4 No election worse by more than 2 SE of its own
  seats. 5 Without the two largest-gain seats the target gain keeps its sign; non-target seats not worse by 1 SE.
- Reported, not voted: direction (cells moved down vs up; the arm removes a pull, so expect mostly down), squared share
  error on moved cells, the 1e-4 floor, each election's share of the gain, AEF-7.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the floor (report at 1e-4). (b) Governed WINNERS lose: the arm removes a pull the trees may
have partly learned away, so candidates who did surge (sa2026's One Nation winners, Shepparton's Sheed) could be
under-called. List every target seat the governed candidate won with p_win base and arm; a loss there is shown to
Pete even if the rule passes. (c) Live: vic2026 cannot be walked until its corpus lands (~9 Nov); the first run with a
corpus is walked with and without the switch and shown to Pete before it publishes.

## RESULT: screen (2026-10-19, 1,000 sims, all 35 elections, code 1866c58)

Not WORSE, so the deciding run went ahead (`deciding-runs/20261019-2303-f5-once`, 20,000 sims). The screen was killed
twice by the memory watchdog and resumed from its cache (70 runs, every one cached once).
- 5,621 of 19,616 cells moved in 24 elections (the post-tree blend removed, rows renormalised); squared share error on
  them +636.9 (+1%, SE 825.6).
- `score_quick_targets.R`: 1,528 target seats in 18 elections; primary -0.0009 (SE 0.0009), better by more than 1 SE
  only at rounding; guard -0.0005 (SE 0.0004) PASS; leave-one-out FAILS (10 of 18 drops); no election worse by 2 SE;
  not-one-seat PASS. fed2025 carries 61% of the gain; fed2022 +0.0038 and nsw2015 +0.0028 are the worst.
- Direction: 2,615 cells down, 3,006 up (removing the pull lowers the salience cells; renormalisation lifts the rest).
