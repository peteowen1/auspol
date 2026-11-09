# Pre-registration: the new-independent shrink, split by pre-election signal (2026-11-09)

Written BEFORE the arm ran. From `docs/reviews/newcomer-independents-walk-2026-11-09.md`: first-time independents with
a pre-election signal are under-called (Climate 200 +4.9, SE 1.7, n 23; Voices +5.7, SE 1.9, n 14; elected councillor
or mayor +3.8, SE 0.9, n 53), yet `AUSPOL_NEW_IND_SHRINK` (shipped 6 Oct) cuts every Victorian first-timer's base by
one factor (0.826 at vic2026), signal or not. Pete chose this lever first (9 Nov).

Arm: `AUSPOL_NEW_IND_SHRINK_SIGNAL=1`. The factor is fitted exactly as now (time-forward, ratio of sums, partially
pooled across jurisdictions, cap 1 unchanged), but separately for cells WITH a signal (`c200`, `voices`,
`council_elected` or `council_mayor` above 0) and cells without. Post-xgb like the shrink: stage 1 runs the shrink
off, so the as-at trees are unchanged.

Dry run (`new_ind_fit()`, 9 Nov, before any arm):

| Target | One factor (shipped) | Signal group | No-signal group |
|---|---|---|---|
| vic2014 | 1.000 | 1.000 (pooled k 1.92, n 13) | 0.875 |
| vic2018 | 1.000 | 1.000 (1.95, n 23) | 0.686 |
| vic2022 | 0.822 | 1.000 (2.83, n 41) | 0.600 |
| vic2026 (live) | 0.826 | 1.000 (2.55, n 70) | 0.575 |
| fed2022, fed2025, nsw2023, qld2017, sa2022, wa2025 | 1.000 | 1.000 | 1.000 |

So the arm acts in Victoria only: signal cells are no longer cut, no-signal cells are cut harder. Live vic2026: 2 of
15 cells carry a signal.

Baseline: the shipped configuration at the same seed and sims (`scripts/quick_arm.R`, common random numbers), all 35
elections. Screen at 1,000 sims; a pass goes to the 20k deciding run before shipping.

1. PRIMARY (targeted): published-share squared error on the changed cells falls by more than 2 SE (cells as units).
2. GUARD: 35-election seat-winner log loss rises by no more than 1 SE (SE clustered on election).
3. GUARD: AEF-7 ledger subset rises by no more than 1 SE.
4. DISQUALIFIER: any of vic2014, vic2018, vic2022 seat-winner log loss rises by more than 0.005.

Ship if 1 passes, 2 and 3 hold and 4 does not fire; otherwise off and to Pete with the cells that drove it.

Named in advance, so they cannot be invented after the result:
- The signal list is the four columns above, chosen from the walk-through's bias table before this run; search
  interest (`surge_h`, +1.6 SE 0.6 in its top third) is left out because it has no cut-off that is not fitted.
- The no-signal factor falls BECAUSE the signal cells left its fit. If the gain comes from cutting no-signal cells
  rather than from sparing signal ones, that is still this arm's mechanism and is reported as such, split by group.
- The signal group's own k is 1.8-2.8 everywhere, and the cap holds it at 1. Raising it (`AUSPOL_NEW_IND_SHRINK_CAP=0`
  for the signal group) is a separate arm, not this one.

## Result, screen (quick_arm, 1,000 sims, all 35, 9 Nov 4:17pm, code e8525f31): PRIMARY FAILS, stays off

Log `output/quick-arm-newind-signal-1109.log`. 329 of 19,616 cells changed, in 6 elections; 29 byte-identical.

1. PRIMARY: changed-cell squared error 4,633.4 -> 4,565.3 (-68.0, -1%), SE 75.9: FAIL (needs more than 2 SE).
2. GUARD: 35-election seat log loss 0.3005 -> 0.3005 (+0.0000): holds.
3. GUARD: AEF-7 0.2522 -> 0.2522: holds.
4. DISQUALIFIER: vic2014 -0.0004, vic2018 +0.0005, vic2022 +0.0001: does not fire.

Per election (squared-error change on changed cells; seat log loss change): vic2018 -59.1, +0.0005; vic2014 -28.2,
-0.0004; vic2022 +2.0, +0.0001; qld2015 +23.6, -0.0001; nt2020 -6.2, +0.0004; nt2024 0. Largest share move 1.82 points.
Not named in advance: qld2015 and the NT pairs moved too, where the no-signal fit fell below 1 once the signal cells
left it.

Why so small: the arm only stops a cut of at most 17% on the few Victorian signal cells (base level, before the
trees), and cuts the no-signal ones harder, where the trees and the post-xgb steps already land near the actual.
It cannot raise anyone: the signal group's own k (1.8-2.8) is held at 1 by the cap. Raising it is the separate arm
named above.
