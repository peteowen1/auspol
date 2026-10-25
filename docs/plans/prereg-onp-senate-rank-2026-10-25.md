# Pre-registration: order One Nation's seats by its Senate vote, keep the spread (`AUSPOL_ONP_ORDER = "senate_rank"`)

Written 2026-10-25, before any harness or live run of the arm. Step 1 below was run first, while writing this file,
and is exploratory: it decides only whether steps 2 and 3 are worth running. It is not a ship criterion.

## Why

`docs/reviews/market-disagreement-vic2026-2026-10-25.md` (main checkout, uncommitted when this was written): the live
forecast ranks seats for One Nation on the 2025 federal HOUSE One Nation vote in their booths. That vote depends on
who else stood. In Maribyrnong and Corio no other right-wing minor stood in 2025, so One Nation collected that vote
(Maribyrnong 2.4% with 7.5% other-right in 2022, 6.9% with none in 2025); in Bendigo a first-time Nationals candidate
squeezed it. The Senate ballot is the same in every seat. Re-ranked on the 2025 Senate One Nation vote, Niddrie falls
from rank 73 of 88 to 48, Essendon 46 to 20, Lara 87 to 72, Geelong 70 to 49, and Bendigo West rises 29 to 50.

This is NOT the refused `senate` value (`prereg-onp-senate-2026-10-01.md`). That rule replaced both the ordering and
the spread (Qld 2017's log curve instead of SA 2026's quantile map), and it was refused on SA 2026 seat log loss, where
House and Senate rankings agree at Spearman 0.986. The refusal therefore says nothing about the ordering by itself.

## The arm

`AUSPOL_ONP_ORDER=senate_rank` (default stays `"federal"`; `federal|greens|senate` untouched). Shared code
`R/onp_order.R`: `onp_senate_key()`, `onp_rank_reassign()`, `onp_senate_rank_apply()`.

- **Live** (`scripts/fit_seats_full.R`, the `ord <-` line in stage 4): `ord <- order(senate share)` from
  `output/onp-senate-vic2026.csv` (88 of 88 seats match; it ships with the models, and `scripts/promote_rebuild.R`
  now requires it for this value too). Everything after is unchanged: SA 2026's quantile ratios, `AUSPOL_ONP_CV`
  0.365, the cap and the fill. Prints `ONR1` with the rank correlation against the House ordering (0.897 for vic2026).
- **Harnesses** SA, Qld, NSW (which read the switch already) and WA (new): keep the harness's own One Nation values
  over the seats One Nation contests and re-assign them by Senate rank. SA: after the BS1c concentration arm (whose
  spread is House-ranked, like live). Qld/NSW/WA: their values are the swing off the previous state election. SA, Qld
  and WA renormalise every row afterwards as their shipped paths do (`refill = "none"`); NSW's rows already sum to 100
  at that point, so the other classes give way in proportion (`refill = "prop"`). Prints `ONR1` (or `ONR1!` when it
  does not apply, with the reason).
- **Not fed, not vic, intentional:** the federal harness predicts the House vote from its own history; One Nation was
  negligible in vic2014-2022. Recorded in `scripts/build_model_registry.R`.
- **Time-forward:** the Senate table row for a target names its federal election, and `onp_senate_key()` errors unless
  `elections_before("fed<year>", target)` holds (tested with a deliberately later table). Sources: sa2022 fed2019,
  sa2026 fed2025, qld2017 fed2016, qld2020 fed2019, qld2024 fed2022, nsw2019 fed2016, nsw2023 fed2022, wa2001 fed1998,
  wa2005 fed2004, wa2017 fed2016, wa2025 fed2022, vic2026 fed2025. All seats match in every one of these.

**What each harness can and cannot say.** Only the SA harness's spread is House-ranked like the live rule, so only
sa2026 compares the live question directly (House rank v Senate rank), and there the two rankings agree at 0.986. In
Qld, NSW and WA the ordering being replaced is One Nation's own previous state result, a different question. In
qld2017 the harness's One Nation values are close to uniform (One Nation stood in few seats in 2015), so re-ordering
them moves little: the harness cannot reproduce the qld2017 gain step 1 finds. The harness screen is a do-no-harm
check on the switch, not a validation of the live change. Step 1 is the direct evidence for the live ordering.

## Step 1 (RUN, exploratory): allocation only, ordering only

`scripts/onp_order_loo.R` (output in the scratchpad when run for this file; rerun it to reproduce). Over the seats One
Nation contested, each rule is given the election's TRUE One Nation mean. House One Nation by district is rebuilt
from the AEC House booth files through the same booth maps as the Senate table; anchor check against
`external/elections/federal-transposed-to-state.csv`: r 1.0000 on sa2026 (47 seats, max difference 0.01 points) and
nsw2023 (17 seats, 0.06). Two spreads, the SAME for both orderings: "pooled" = the other four elections' sorted
ratios averaged and forced to CV 0.365 (leave-one-out, not time-forward; this only sets the shape, identically for
both orderings) and "oracle" = the target's own sorted actual shares (isolates the ordering completely).

RMSE of the allocated One Nation share against the actual, in points; lower is better. n = contested seats.

| election | n | uniform | House rank, pooled spread | Senate rank, pooled spread | House rank, oracle spread | Senate rank, oracle spread | House v Senate rank corr |
|---|---:|---:|---:|---:|---:|---:|---:|
| sa2026 | 47 | 7.71 | 4.23 | 4.13 | 2.70 | 2.66 | 0.986 |
| qld2017 | 61 | 5.88 | 6.15 | 4.87 | 5.31 | 3.67 | 0.620 |
| qld2020 | 90 | 4.67 | 2.71 | 2.75 | 1.91 | 2.05 | 0.948 |
| qld2024 | 93 | 4.36 | 3.00 | 2.98 | 3.32 | 3.52 | 0.782 |
| nsw2023 | 17 | 2.96 | 2.09 | 1.85 | 1.74 | 1.38 | 0.968 |

Spearman rank correlation of each ordering with the actual One Nation shares (higher is better; spread-free):

| election | House | Senate |
|---|---:|---:|
| sa2026 | 0.939 | 0.946 |
| qld2017 | 0.544 | 0.772 |
| qld2020 | 0.896 | 0.904 |
| qld2024 | 0.805 | 0.819 |
| nsw2023 | 0.814 | 0.863 |

Senate minus House, per election (negative RMSE is better), SE clustered on election (n = 5):

- pooled spread: nsw2023 -0.24, qld2017 -1.27, qld2020 +0.04, qld2024 -0.03, sa2026 -0.09; mean **-0.32, SE 0.24**
  (1.3 SE); better in 4 of 5.
- oracle spread: -0.36, -1.65, +0.14, +0.20, -0.04; mean -0.34, SE 0.34 (1.0 SE); better in 3 of 5.
- Spearman: higher in **5 of 5**, mean +0.060, SE 0.042.

Reading: the Senate ordering is never materially worse (largest loss +0.20 points, qld2024 oracle, where its Spearman
is still higher) and is much better where the two rankings disagree most (qld2017, rank corr 0.62). Most of the mean
gain is qld2017; without it the pooled-spread mean is -0.08. That is the expected shape (rankings agreeing at 0.95+
cannot differ much) and it is why Victoria matters: vic2026's House and Senate rankings agree at 0.897, between
qld2024 (0.782) and qld2020 (0.948). Spearman numbers match the market-disagreement review's independently built
panel to three decimals. Verdict: worth running steps 2 and 3.

## Step 2: quick screen on the One Nation pairs

```
Rscript scripts/quick_arm.R "AUSPOL_ONP_ORDER=senate_rank" --pairs=sa2026,qld2017,qld2020,qld2024,nsw2023
```

Then step 3, the same arm with `--pairs=all` (22 elections), and the deciding 20k run
(`scripts/deciding_run.ps1 -Arm "AUSPOL_ONP_ORDER=senate_rank" -Label onp-senate-rank`) only if 2 and 3 pass.

### Dry-run on cases whose answer is known (check BEFORE reading any metric)

1. Every pair outside the SA, Qld, NSW and WA harnesses scores exactly 0 (common random numbers; the switch is not
   read there). A non-zero fed or vic pair means the arm leaks.
2. `ONR1` prints for every scored SA/Qld/NSW/WA pair where One Nation stood in at least three seats, with "same
   values" (mean unchanged) and the count of seats moved more than 1 point. sa2018 (One Nation absent) prints `ONR1!`.
3. sa2026: few seats move (rank corr 0.986). A large sa2026 change means the arm is doing more than re-ordering.
4. qld2017: few seats move more than 1 point (near-uniform harness values). If many do, the reading above is wrong.

### Criteria (SE clustered on election throughout)

1. **Primary (targeted):** One Nation share RMSE over contested seats, xgb layer, pooled over the five One Nation
   pairs: falls by more than 1 SE.
2. **Guard (5 pairs):** seat-winner log loss over all seats of the five pairs not worse by more than 1 SE.
3. **Guard (all 22, step 3):** pooled seat log loss not worse by more than 1 SE; no pair worse by more than 2 SE of
   its own paired seat differences.
4. **Leave-one-election-out:** the primary keeps its sign with each of the five pairs dropped. No refusal because one
   election carries most of the gain (expected: qld2020/qld2024/nsw2023 here, since qld2017 barely moves).
5. **Unacceptable win, named in advance:** (a) the share RMSE falls but sa2026 or qld2024 seat log loss rises by more
   than 1 SE (the clause that refused `senate`); (b) any seat One Nation actually won loses more than 0.10 of its
   One Nation win probability (sa2026: Ngadjuri and the other three; qld2017: Mirani).
6. **Reported, not decisive:** Brier, reliability by band, base_pred share RMSE, per-pair seat log loss.

Ship rule: 1 passes, 2-4 hold, 5 does not fire, then the deciding run on all 22. A clause refusing an
otherwise-passing result goes to Pete with the split shown. Because the harnesses mostly test a different ordering
(own history, not House), a harness REFUSAL on Qld/NSW pairs refuses the harness wiring; Pete decides whether the live
ordering ships on step 1 plus the sa2026 harness row plus the live walk.

## Live walk (reported, not a criterion)

```
$env:AUSPOL_ONP_ORDER="senate_rank"; $env:AUSPOL_OUT_SUFFIX="-onr"; Rscript scripts/fit_seats_full.R
```

against the published run, for Niddrie, Essendon, Lara, Geelong, Bendigo West, Box Hill, Ashwood and Glen Waverley:
One Nation share (allocated and published), each class's win probability, and the final-pair split. Expected
direction from the review's arithmetic (same spread, Senate rank): One Nation target Niddrie 30.4 -> 22.9, Essendon
21.7 -> 14.7, Lara 35.9 -> 29.0, Geelong 27.4 -> 23.3 (all fall), Bendigo West 17.0 -> 23.6 (rises). Box Hill,
Ashwood and Glen Waverley are reported for the fill question (`prereg-onp-fill-uniform-2026-10-25.md`); their
direction under this arm is not predicted. If any of the five predicted directions comes out reversed, the walk has
found a wiring fault: stop and trace it before reading anything else. Also report the statewide One Nation seat
count distribution and expected seats by party.
