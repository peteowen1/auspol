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

## Amendment 1 (9 Nov, after the result above; Pete: "Go") -- the signal group uncapped

The clauses above are unedited. Arm: `AUSPOL_NEW_IND_SHRINK_SIGNAL=1` with `AUSPOL_NEW_IND_SHRINK_SIGNAL_CAP=0`: the
signal group's factor may rise to its own fitted value; the no-signal group keeps the cap of 1. Same baseline, same
four criteria, measured on the cells this arm changes. Post hoc: chosen after seeing the capped result, and marked so.

Dry run, signal factor uncapped (`new_ind_fit(group = "signal", cap = FALSE)`): fed2016 1.86, fed2019 1.85, fed2022
1.37, fed2025 3.09, nsw2019 1.79, nsw2023 3.02, qld2017 1.78, qld2024 3.72, sa2022 2.08, sa2026 2.44, vic2014 1.95,
vic2018 2.15, vic2022 1.89, vic2026 1.93 (live), wa2021 1.52, wa2025 1.46, nt2024 2.62. Training cells 13-70.

Named in advance:
- The factor is fitted against `base_pred`, and the trees then add their own correction on top of the raised base
  (Climate 200 SHAP +1.35 on the big first-timers), so this arm can OVERSHOOT. Over-calling the signal cells that
  flopped (Deakin 2025: Voices + Climate 200, ours 12.0, actual 7.1) is the failure to look for; the changed-cell
  squared error (clause 1) is where it shows.
- A pass here goes to the 20k deciding run before shipping, as above.

### Amendment 1 result (quick_arm, 1,000 sims, all 35, 9 Nov 4:57pm, code 0732f6e8): REFUSED, stays off

Log `output/quick-arm-newind-signalcap-1109.log`. 659 cells changed in 22 elections.

1. PRIMARY: changed-cell squared error 13,626.7 -> 13,525.4 (-101.3), SE 766.9: FAIL.
2. GUARD: 35-election seat log loss 0.3005 -> 0.3027 (+0.0022, SE 0.0018): FAILS (worse by more than 1 SE).
3. GUARD: AEF-7 0.2522 -> 0.2608 (+0.0087, SE 0.0075): FAILS.
4. DISQUALIFIER: vic2018 +0.0015, vic2014 -0.0002, vic2022 -0.0006: does not fire.

Worst elections: nsw2023 +0.0523, fed2025 +0.0118, sa2022 +0.0096; best fed2022 -0.0045. The overshoot named in
advance is what happened. It lifted cells the trees had already called well: Lane Cove 19.0 -> 34.5 (actual 20.4),
Vaucluse 21.3 -> 32.8 (17.1), Grey 16.0 -> 26.4 (17.5), Hammond 11.6 -> 25.7 (15.7). It also helped where we were
short: Pittwater 22.7 -> 31.8 (35.9), Bean 20.3 -> 28.3 (26.4), Blaxland 4.1 -> 9.0 (18.8).

Lesson for the next lever: a factor fitted on `base_pred` double counts, because the trees already add their own
signal correction on top of the base. Any lift for signal cells has to be fitted on what the model publishes (after
the trees), not on the base.
