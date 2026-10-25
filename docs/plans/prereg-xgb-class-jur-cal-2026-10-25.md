# Pre-registration: time-forward per-(jurisdiction, class) shift of the xgb layer (`AUSPOL_XGB_CLASS_JUR_CAL`)

Written in the 25 Oct night session (calendar date 26 Oct), before any screen of this switch has run. Pete chose
(25 Oct): pre-register and screen all four built-but-off experiment branches. Branch
`worktree-agent-a6d092f16127ab44a`, one commit `d2c47c2` (2026-10-06). Rules: `docs/PRE-REGISTRATION-RULES.md`
(the standard decision rule of 2026-10-18), the shrinkage and leakage rules in `CLAUDE.md`. Nothing in `R/` or
`scripts/` is edited by this plan and the branch is not merged by it.

## The question

The Victorian majors-shortfall review (`docs/reviews/vic-majors-shortfall-2026-10-06.md`) found the xgb seat layer
moves share from the majors to Independents in every Victorian election, over-calling Independents by 1.56 points a
seat (SE 0.31, n = 264). A blanket "undo the xgb shift" helps vic2022 and hurts elsewhere. Does a correction that
learns each jurisdiction's own lean per class, from EARLIER elections' as-at predictions only, and shrinks it toward
zero, predict seats better?

## What the branch does (read from the diff, `git diff origin/dev...worktree-agent-a6d092f16127ab44a`)

- `R/xgb_class_jur_cal.R` (new, 139 lines). For target T in jurisdiction J and class k: history = every election
  dated strictly before T in the as-at predictions file, seat-normalised to 100, mean signed residual
  `actual - predicted` per (election, class). `mu_j` = mean of jurisdiction j's election means; within variance
  `sigma2` pooled over jurisdictions with 2+ elections, `se_J^2 = sigma2 / k_J` (clustered on election);
  `tau2 = max(0, mean(mu_j^2 - sigma2 / k_j))` (between-jurisdiction variance about 0, floored at 0);
  `shift = tau2 / (tau2 + se_J^2) * mu_J`. Added to the class in every seat, floored at 0, each seat rescaled to its
  pre-shift total. No earlier election in J gives no shift. No `min_n`.
- Wired at all three xgb paths: `xgb_primary_override()` (the six harnesses; history from the full as-at file read
  BEFORE the base-delta step, shift applied to the overridden matrix), `scripts/build_forecasts_table.R`
  (`xcj_apply_asat()`, before nomination zeroing) and `xgb_primary_predict_live()` (the published forecast; reads
  `AUSPOL_XGB_PRIMARY_OOF`, default the as-at file). Prints one `XCJ1` line per (target, class).
- `scripts/published_flags.R`: `AUSPOL_XGB_CLASS_JUR_CAL = "0"` (off). Tests:
  `tests/testthat/test-xgb-class-jur-cal.R` (time-forward, tau2 = 0 gives no shift, shrinkage, totals preserved,
  switch-off identity).
- A post-xgb correction, so it is not a `base_pred` fix and the "base_pred AND xgb layer" rule does not apply: it
  acts on the xgb output in backtests and live alike.

## Merge state and cached files

- **Merges cleanly onto `origin/dev`** (`git merge-tree --write-tree origin/dev worktree-agent-a6d092f16127ab44a`
  returned a tree with no conflicts, 26 Oct). The branch is 761 commits behind `origin/dev`, so it must be screened
  MERGED, never as it stands (its 6 Oct code with today's inputs would measure neither model).
- **No xgb retrain is needed.** The correction is fitted from `output/xgb-primary-asat-predictions.csv` (the as-at
  file the harnesses already read; each row was predicted by a model trained only on earlier elections), so the
  history is time-forward by construction. If the as-at file is retrained before the deciding run, the history
  changes with it and the screen must be rerun. The flag's own comment: the deciding arm starts at rebuild stage 6.
- `docs/MODEL-REGISTRY.md` and `docs/CONSTANTS.md` were not updated on the branch (no new constant beyond the
  computational floor tau2 >= 0). Both are part of the merge if it ships, not of the screen.

## Evidence already on file (read before the screen, not a result of it)

The 6 Oct follow-up in the shortfall review ran this correction as a dry run on the published as-at table (an
estimate, not a harness run): mean squared share error +0.29 points^2 (SE 0.15), worse; 11 of 18 elections shifted,
only fed2022 better (-0.76); qld2024 +2.07, fed2025 +1.38, fed2019 +0.95, nsw2023 +0.77; Victoria flat (vic2018
+0.03, vic2022 +0.08). Pooling across jurisdictions shrinks the Victorian Independent lean to about 0 (tau2 0.02 at
vic2022), and the shifts that do fire (ALP, GRN, ONP) are taken back off the Coalition by the seat rescale. So the
prior expectation is a refusal, and the mechanism the branch was built for (Victorian IND) barely fires. The screen
measures seat log loss, which that dry run did not.

## Arm

| arm | switch | rule |
|---|---|---|
| shipped | `AUSPOL_XGB_CLASS_JUR_CAL=0` | as published |
| XCJ | `AUSPOL_XGB_CLASS_JUR_CAL=1` | the branch's rule above, nothing tuned |

No grid: the rule has no free parameter (tau2 and the weight are estimated; the floor at 0 is computational). No
sensitivity specs are added after seeing a result.

## Screen and criterion

Instrument: `scripts/quick_arm.R` from a scratch worktree holding `origin/dev` with this branch merged, AEF-7
default pairs (fed2022, fed2025, nsw2023, qld2024, sa2026, vic2022, wa2025; 681 seats), `--sims=1000`, baseline the
shipped configuration. Both runs at the same seed and N (common random numbers), so an untouched election is
byte-identical and scores 0.

- **Primary**: Q3, pooled seat-winner log loss on AEF-7, arm minus shipped, SE clustered on election. Better means
  below 0 by more than 1 SE.
- **Targeted** (the change's own cells, chosen from predictions, never outcomes): Q2, squared share error on the
  changed cells (|predicted share moved| > 0.05 points), SE clustered on election; and seat-winner log loss on the
  seats holding a changed cell, computed from the cached baseline and arm `allprobs` (quick_arm does not print it).
  Named cells read individually: Victorian IND cells in vic2022 (the case the branch was built for).
- **Guards** (each can refuse):
  - G1 every seat: Q3 not worse by more than 1 SE.
  - G2 no AEF-7 election worse by more than 1 SE of its OWN paired seat differences (from the cached
    `allprobs`). This is stricter than standard clause 4 (2 SE) because the brief for tonight's screens sets it; a
    screen can only stop an idea, and per standard clause 9 a refusal from G2 alone on an arm that otherwise passes
    goes to Pete with the split.
  - G3 leave-one-election-out: with each AEF-7 election dropped in turn, the pooled change stays below 0 by more
    than 1 SE (applies only to an arm that passes the primary or the targeted route). Each election's share of the
    gain is reported, never a refusal.
  - G4 the two largest-gain seats removed, the gain keeps its sign.
- Q4 (AEF-7 ledger subset) and Brier are reported, never counted as votes.

**Decision rule.** Passes the screen if (a) the primary is better by more than 1 SE, or (b) the primary is within
1 SE AND the targeted seat log loss is better by more than 1 SE (standard clause 1 makes the change's own targets the
primary; tonight's brief makes the pooled number primary; either route is allowed because a change that moves `k` of
`n` seats needs about `n/k` times the effect to show in the pooled number), and in both cases G1 to G4 hold and
nothing below is unacceptable. Worse by more than 1 SE on the primary: STOPPED, stays off. Anything else: "not shown
at the screen", stays off, numbers to Pete. A pass is NOT a ship: it earns the deciding run (all elections, 20,000
simulations, `scripts/deciding_run.ps1 -Arm "AUSPOL_XGB_CLASS_JUR_CAL=1" -Label xcj`) under the standard rule.

### What would make an apparent win unacceptable (named now)

- Any single (jurisdiction, class) shift larger than 3 points in absolute value at any target. A seat-layer lean of
  that size learned from a handful of elections means the shrinkage did not hold.
- A gain that comes from shifts the OUTCOMES contradict: the moved cells of a class scoring worse while the seat
  log loss improves through the rescale of other classes (standard clause 6). Reported per class with counts.
- The Independent shift stacking on `AUSPOL_NEW_IND_SHRINK` (shipped 2026-10-06, post-xgb, also aimed at the
  Victorian IND over-call). The history residuals are from the RAW as-at xgb predictions, before that shrink, so in
  Victoria the two corrections can double-count. If the arm's Victorian IND cells move further down than their
  realised error justifies (the moved IND cells score worse), the win is refused even if the pooled number improves.
- A live vic2026 walk (with and without the switch) that moves any seat's favourite: goes to Pete before shipping.

### What the criterion cannot see

- Seats whose winner sits below the 0.5/N floor (5e-4 at 1,000 simulations); a "within 1 SE" screen does not clear
  anything that acts in the far tails.
- The 28 elections outside AEF-7, which hold most of the history the fit learns from; the deciding run covers them.
- The history averages residuals over every seat, including seats where a class did not stand (half of all IND rows
  have actual 0; their as-at prediction averages 0.02, so the dilution is small but real): a contested seat gets the
  seat-average lean, not the contested-seat lean.

## Dry run of the criterion on known cases (prose, before any screen)

- **Switch off** (`=0`, the baseline itself): every election byte-identical, Q1 "byte-identical 7 of 7", Q3 change
  exactly 0. The branch's test `switch off (the default) returns inputs untouched` covers the code path.
- **wa2025 and the earliest election of each jurisdiction**: the fit uses every earlier election in the as-at file,
  so wa2025 has prior WA history and CAN shift; the first election of a jurisdiction in the file (no earlier one)
  must print shift 0 for every class on its `XCJ1` lines. If a first election shows a non-zero shift, the
  time-forward filter is broken and the screen is void.
- **vic2022 IND**: the 6 Oct dry run found tau2 about 0.02 and a shift near 0. The `XCJ1 vic2022 IND` line should
  show a small weight; if it shows a shift above 1 point, the screen is reading a different history than the dry run
  and that difference is reported before the verdict.
- **A deliberately leaked version** is not built for this screen; the branch's test `history uses only elections
  dated strictly before the target` (a vic2022 residual of 50 must not enter vic2022's own fit) is the broken-input
  check and must pass in the merged worktree before the screen (`devtools::test(filter = "xgb-class-jur-cal")`).

## Leakage

History rows are as-at predictions (each from a model trained before its own election) for elections dated strictly
before the target, from `election_dates()`. What happens to an as-at row whose election is missing from
`election_dates()` was NOT checked (an NA date would drop it from every fit, an error would stop the run); the
`XCJ1` k counts show which. vic2026 is never scored.

## Amendments

(none yet; any change is added below this line with the text above left as is)
