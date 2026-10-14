# Overnight 2026-10-15 (autonomous, Pete asleep)

Pete, 00:10: "keep working through next steps on dev and making fixes and housekeeping ... if you need me for
something, save it for the morning and move onto something else". Nothing merges to main tonight.

## Status as it moves

- 8260e60 on dev: spread-table lag fix (stage 7 compares the refit with the table stage 6 read and reruns 6-7 once
  if any scored target's factor moved > 0.02; Pete chose rerun over warn), as-at checkpoints to .partial, census
  LOOKAHEAD by publication date. check_like_ci.R: 1980 passed, 0 failed (R CMD check skipped: no package file changed).
- Census regenerated: output/census-features.csv now applies the publication rule. Changed pairs exactly fed2022,
  sa2022, wa2017 (intended) plus nt2016 (2 rows) and qld2012 (8 rows) newly blanked by the same rule. qld2017 and
  sa2018 kept from the previous file (see the builder trap in NEXT-STEPS). Backup of the previous files in the
  session scratchpad only.
- FULL REBUILD running (no publish), started 00:07: `deciding-runs/rebuild-20261015-census-archive.log`. Carries the
  census blanking + publication rule, the pollster archive, and the BludgerTrack/section re-scores.
- REBUILD DONE 01:58, EXIT=0, not published (log above; snapshot `output/snapshots/20261015-0157-03c3d2b-from1`).
  The new spread check fired as designed: 13 of 35 targets' factors moved (largest sa2014 0.0585 > 0.02), stages
  6-7 reran (+31 min), the second check found 0 moved. Seat log loss, lower is better, against the published
  14 Oct run (snapshot 20261014-1833-12a0471-from6): all 35 elections 0.3337 -> 0.3340 (2,931 seats, +0.0003,
  flat); AEF-7 0.2662 -> 0.2646 vs AEF 0.2825 (681 seats). Best: nt2024 -0.017, wa2025 -0.008, vic2018 -0.006.
  Worst: qld2017 +0.014, wa2017 +0.009, nsw2019 +0.007, sa2018 +0.005. Primary RMSE like for like 4.713 vs AEF
  5.711.
- 9b6aeb5 on dev: NEXT-STEPS 12 Oct block collapsed (121 -> 91 items); 36 merged local branches deleted (plus
  af6920, whose commits are all on dev by patch id).
- Branch `wa-nt-screened-slopes` (worktree .claude/worktrees/wa-nt-screened), NOT yet on dev:
  - af23244 WA and NT harnesses wire screened_slopes(): they ran conditional-only under the published "screened"
    mode, so the salience screen, AUSPOL_HONOUR_DEPARTED and AUSPOL_DEPARTED_SUCCESSOR never reached 9 scored
    elections (wa2005-wa2025, nt2016-nt2024 have salience data).
  - a0bea48 test-candidate_returns: 6 PPV1! noise lines per test run removed.
  - Hare-Clark harness sources harness_defaults.R.
  Plan: Sonnet review (running), then quick_arm smoke run on one WA + one NT election after the rebuild frees
  output/, merge to dev, then a SECOND full rebuild as the arm (the xgb cache embeds base_pred, so a quick screen
  cannot measure it).
- Verified, closes a review-gate item: mp-slope-by-class.csv is time-forward for the live targets
  (scripts/fit_mp_slope.R:42 keeps only elections with counted votes).

## For Pete in the morning

1. Validation checks red since 8 Oct (NEXT-STEPS, "NEEDS PETE"): recommendation is SE-based tolerances.
2. Three OFF experiment branches from 6 Oct (+ departed-rate-refit): prereg or close.
3. Publish: the rebuild results, if better, need AUSPOL_PUBLISH=1 AUSPOL_REBUILD_FROM=9.
