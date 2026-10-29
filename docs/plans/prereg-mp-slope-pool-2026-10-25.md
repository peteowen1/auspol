# Pre-registration: one partially pooled sitting-member slope rule, live and in every harness (2026-10-25)

Written before any screen. Switch `AUSPOL_MP_SLOPE_POOL`, published `"0"`.

## Why

The sitting-member slope tier (how much of a returning MEMBER's seat deviation carries forward, per class) is chosen
by two different rules for the same quantity (`reviews/unregistered-switches-2026-10-12.md`, item 1):

| where | table | rule |
|---|---|---|
| live, `scripts/fit_seats_full.R:959-976` | `output/mp-slope-by-class.csv` (all data, per class, raw fit) | keep a class only at `n_member >= 8`, then trust its raw slope fully; GRN dropped |
| seven harnesses (`backtest_candidate_{fed,nsw,nt,qld,sa,vic,wa}.R`) | `output/mp-slope-by-target.csv` (time-forward) | keep every class, slope shrunk toward the all-class slope by `n / (n + 10)`; GRN dropped |

So a slope the backtests score can be refused live, and the live `>= 8` is a `min_n` cliff (n = 7 ignored outright,
n = 8 believed outright). Dormant in today's live table (IND n=84, OTH_RIGHT 16, GRN 22 dropped anyway, ONP n=1 and OTH
n=0 dropped), but it is the rule that would decide as soon as a class sits near 8.

Pete, 2026-10-25: shrinkage with no cutoff, the same rule live and in all harnesses.

## The change (`AUSPOL_MP_SLOPE_POOL=1`)

`scripts/fit_mp_slope.R` writes `output/mp-slope-pooled.csv` (`--pool-only` writes only that file, leaving the three
shipped tables untouched). For every target election, on the same training rows as the shipped time-forward grid
(member rows from elections dated before the target), and for every live election (all counted elections before it):

- `est_i`: class i's slope through the origin, `sum(x y) / sum(x^2)`, defined from one row up.
- `se_i = sigma / sqrt(sum(x_i^2))`, `sigma^2` one within-class residual variance pooled over classes (a class's own
  residuals from two or three rows can look falsely precise).
- `tau^2`: DerSimonian-Laird between-class variance over the classes with rows, floored at 0; 0 with fewer than two.
- `mu`: the grid's own all-class member slope, shrunk toward 1.0 by `n/(n+10)` (unchanged, so a target with no
  earlier member rows gets 1.0 exactly as now).
- `member_i = mu + w_i (est_i - mu)`, `w_i = tau^2 / (tau^2 + se_i^2)`. No floor: a class with no rows gets `mu`.

`R/mp_slope_pool.R`. Live (`fit_seats_full.R`) and every harness then read this table for their target, GRN still
excluded (the harnesses' `AUSPOL_MP_SLOPE_GRN` still applies), and print `MPP1` with the file read. `"0"` is today
exactly: proved by `tests/testthat/test-mp-slope-pool.R` (each entry point's own MP block run on a fixture) and by
running every entry point's old (origin/dev) and new block on the real tables for every target (see the commit).

Which layer it reaches: it changes `base_pred` (`conditional_slopes()` / `screened_slopes()` `same_mp=`). The
harnesses carry a `base_pred` change into the xgb layer through `AUSPOL_XGB_BASE_DELTA=1` (shipped); live carries it
through `base_margin` (`xgb_primary_predict_live()`). No xgb retrain is involved, so both layers see it on the next run.

## Arms

| arm | setting | differs from baseline on |
|---|---|---|
| baseline | shipped (`AUSPOL_MP_SLOPE_POOL=0`) | - |
| P1 | `AUSPOL_MP_SLOPE_POOL=1` | the MP tier values only (every seat-class with a returning sitting member of a non-GRN minor class) |

No grid: `tau^2` and `se_i` are estimated, not tuned. Nothing to pick, so nothing to fit to the answer.

## Criterion

Screen (needs `output/mp-slope-pooled.csv` in the checkout first; see the commands at the end):

1. **Primary: pooled seat log loss on AEF-7** (minus log of the probability given to the actual winner, averaged over
   seats; lower is better), SE clustered on election, from `scripts/quick_arm.R`. **Departure from the standard rule,
   stated:** the arm is not expected to gain beyond 1 SE. It swaps one shrinkage rule for another on a few dozen
   seat-classes per election, and the harness table already shrinks. The case for it is the rule Pete chose (no
   cliff, one rule live and in backtests), as with `AUSPOL_CONSERVE_SHRINK_K` (shipped 2026-10-16 on the no-cliff rule
   at +0.0001, SE 0.0001). So the primary decides as a do-no-harm bar: **not worse than shipped by more than 1 SE**.
   A gain beyond 1 SE is reported as one. The screen prints the SE; the MDE is about 2.8 SE, larger than the expected
   effect, which is why the bar is do-no-harm and not "better by 1 SE".
2. **Targeted: the changed cells.** Squared primary-share error on the cells quick_arm reports as changed (the
   returning-member seat-classes), not worse by more than 1 SE. Named and reported individually: every changed cell
   in AEF-7 of class OTH_RIGHT or ONP (the thin classes, where the two rules differ most) and the five largest IND
   moves, with predicted share before and after and the actual.
3. **Guard, every election:** no AEF-7 election worse on seat log loss by more than 2 SE of its own paired seat
   differences. Leave-one-election-out on the primary: with each election dropped in turn the primary stays not worse
   by more than 1 SE.
4. **It ran:** `MPP1` printed in every election's log, and changed cells > 0 in at least one election. Zero changed
   cells everywhere means the table did not reach the tier, not that the rule is neutral.
5. **Live walk** (not scored, vic2026 has not happened): `fit_seats_full.R` at `"0"` and `"1"`, report the class slopes
   before and after (live today: IND 0.9391 only; pooled adds OTH_RIGHT and ONP), every vic2026 seat with a returning
   non-GRN minor sitting member, its predicted primary and win probability before and after.
6. **Ship decision on all 35 elections** (`--pairs=all`), outside the session, same clauses 1-4.

**What would make an apparent win unacceptable, in advance:**
- the log-loss gain arrives while the changed cells' share error gets worse beyond 1 SE (a gain that is not through
  better shares on the cells the arm touches);
- the outcomes contradict the direction: the arm pulls thin classes (OTH_RIGHT, ONP) toward the all-class slope, and
  those moved cells score worse on share error in most elections where they moved;
- clause 4 fails (it did not run).
A large gain in one election is not on this list (standard rule 3).

**What the criterion cannot see:** quick_arm floors winner probabilities at `0.5/N`, so a move confined to seats under
~1/N is invisible; and the live change (clause 5) has no outcome to score until 28 November.

## Dry run on cases with a known answer

- `AUSPOL_CONSERVE_SHRINK_K` (2026-10-16; seat log loss +0.0001, SE 0.0001; share error on 77 changed cells -4%, SE 4%):
  clause 1, worse by exactly 1 SE, not more, so passes; clause 2 within 1 SE, passes. Verdict "ship on the rule",
  which is what was decided. Correct.
- `AUSPOL_SLOPE_SHRINK` (rebuild J, 2026-09-29; ledger elections = AEF-7, +0.0056, SE by election 0.0035): 1.6 SE worse,
  clause 1 fails. Verdict "refuse", which is what was decided. Correct.
- A switch whose table equals the old one (a no-op): quick_arm refuses identical environments, and with a different
  switch name it scores exactly 0 with zero changed cells, so clause 4 fails and the arm is not cleared as neutral.
  Correct: a no-op is not evidence.

## Decision rule

Clauses 1-4 pass on AEF-7: run the 35-election screen. Clauses 1-4 pass there and clause 5 shows no live seat moving
against the direction of its own backtest cells: recommend shipping to Pete as the no-cliff rule. Any clause failing
on a result otherwise passing goes to Pete with the split shown (standard rule 9).

## Screen commands (after 02:15, from the main checkout)

```
powershell.exe -Command 'Rscript scripts/fit_mp_slope.R --pool-only'
powershell.exe -Command 'Rscript scripts/quick_arm.R "AUSPOL_MP_SLOPE_POOL=1"'
```

The first adds `output/mp-slope-pooled.csv`, which changes quick_arm's input signature, so the AEF-7 baseline is
rebuilt once (about 7 minutes) before the arm runs.

## Screen results (appended 2026-10-29; nothing above edited)

**AEF-7 (1,000 sims, code ffeed87c, after `fit_mp_slope.R --pool-only`): PASSES clauses 1-4, goes to all 35.**
Clause 4: MPP1 printed in all 7 elections; 110 changed cells in 6 (wa2025 none). Clause 1: seat log loss 0.2634 ->
0.2636 (+0.0001, SE 0.0002): not worse by 1 SE. Clause 2: share squared error on the 110 changed cells 2,574.0 ->
2,556.6 (-17.4, SE 38.9). Clause 3: no election worse by 2 SE of its own seats (worst vic2022 +0.0016, SE 0.0011);
leave-one-election-out on the pooled change, computed from the per-election rows rounded to 4 dp: -0.00007 to
+0.00024 against SE about 0.0002 (dropping fed2022 is the borderline one; the all-35 run decides). Pooled weights:
tau^2 = 0 for vic2022 and vic2026, so every non-GRN minor class takes the all-class slope (vic2026 0.960; live was
IND 0.939 with n 84). Largest moves: losses in vic2022 Mildura 0.175 -> 0.162 and Shepparton 0.143 -> 0.134 (the
returning independents), gains in nsw2023 Kiama 0.520 -> 0.534 and sa2026 Stuart 0.705 -> 0.722.

**All 35 (1,000 sims): clauses 1, 2 and 4 pass; clause 3 fails by a hair, to Pete (decision rule).** Clause 4: MPP1 in
all 35, 356 changed cells in 30. Clause 1: seat log loss 0.3062 -> 0.3064 (+0.0001, SE 0.0002; exact from the seat
files over 2,921 matched seats: +0.00014, SE 0.00020). Clause 2: share squared error on the 356 changed cells
15,261.0 -> 15,179.0 (-82.0, SE 168.3). Clause 3: no election worse by 2 SE of its own seats (pass); leave-one-
election-out on the pooled change, exact: dropping wa2008 gives +0.00022 (SE 0.00018) = 1.25 SE worse, over the
1 SE limit; every other drop under 0.9 SE (nt2016, fed2010 +0.85). On the 106 targeted seats: +0.0038 (SE 0.0054).
