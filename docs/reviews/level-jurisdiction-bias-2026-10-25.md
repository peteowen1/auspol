# Level jurisdiction-by-class bias correction: screen result, 2026-10-25

Prereg (written and saved before any arm ran): `docs/plans/prereg-level-jurisdiction-bias-2026-10-25.md`.
Screen script (scratchpad copy of `scripts/screen_level_share.R`, repo file not edited):
`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\e7e809d4-b07a-4695-a3bd-7e8f88a19663\scratchpad\screen_jur_bias.R`,
full output `...\scratchpad\jb_out.txt`. Runtime 20 s. Inputs: `output/level-recent.csv` (105 rows, 35 elections),
`output/published-predictions.csv` (19,616 seat cells, 35 elections, 2,931 seats; written 2026-10-21), reference
level the shipped `decay:20`.

## Verdict: REFUSED for all three decision arms (LNP, GRN, ALL). No quick_arm run recommended.

## What the shipped level actually misses (input, not an arm)

Mean shipped day-before level minus actual statewide share, points (positive = we over-call), with elections and
how many were positive:

| jurisdiction | ALP | LNP (Coalition) | GRN |
|---|---|---|---|
| fed | +1.48 (6 of 7) | -0.96 (1 of 7) | +0.26 (4 of 7) |
| nsw | -0.18 (1 of 4) | -0.36 (1 of 4) | +1.01 (4 of 4) |
| nt | -2.81 (0 of 3) | -2.59 (1 of 3) | +1.44 (3 of 3) |
| qld | -0.45 (1 of 5) | -0.29 (2 of 5) | +0.47 (3 of 5) |
| sa | -0.95 (0 of 5) | -1.70 (0 of 5) | +0.82 (4 of 5) |
| vic | -0.73 (1 of 4) | -0.92 (1 of 4) | +2.18 (4 of 4) |
| wa | +0.49 (5 of 7) | +1.97 (6 of 7) | -0.57 (2 of 7) |

Two findings before any arm:
- **NT's seat-level Coalition over-call (+3.61) is NOT a level miss.** The NT level UNDER-calls the Coalition
  (-2.59; misses -4.02, +5.32, -9.06). Whatever over-calls NT Coalition seats is in the seat layer.
- **WA's level miss is real but front-loaded**: wa2001 +3.85, wa2005 +4.91, then +0.34, -0.70, +1.82, +2.04, +1.50.

## Dry run (all as the prereg required)

- Zero arm: primary change exactly 0, proxy 0. Passed.
- Leaked arm (target's own miss; level made exact): level RMSE 2.315 -> 0.000, proxy seat log loss -0.0136
  (SE 0.0053). The time-forward assertion stops on a set including the target. Passed.
- Every jurisdiction's first election gets correction 0. Passed.
- **Power: the screen is underpowered on its primary.** The leaked arm moves seat primary MSE only -0.26 pts^2
  (SE 0.78), and it makes WA seats WORSE (+2.71) and NT seats much worse (+18.3, nt2024 alone +42). Making the
  statewide level exact does not make the seats right, because seat primaries do not follow the level one for
  one. Per the prereg, a primary refusal therefore reads "not shown", not "no". It is the secondary (level RMSE)
  and the guards that make this a refusal, below.

## Arms

Change, arm minus shipped, over all 35 elections and 19,616 seat cells. Seat primary MSE in points squared, level
RMSE in points over the 105 statewide ALP/LNP/GRN cells, seat log loss proxy in nats per seat; negative is better
for all three. SE clustered on election. "LOEO worst" is the pooled primary change after dropping the one election
that helps most (the guard needs it below 0). Primary spec (eb0) decides; the other two are sensitivity only.

| arm | spec | seat primary MSE change (SE) | seat RMSE | level RMSE | proxy log loss (SE) | ledger 681 seats (SE) | LOEO worst | max correction |
|---|---|---|---|---|---|---|---|---|
| LNP | **eb0** | +0.249 (0.233) | 4.113 -> 4.143 | 2.315 -> 2.482 | +0.0026 (0.0035) | +0.0033 (0.0032) | +0.322 | 4.28 (wa2008) |
| LNP | ebpool | +0.841 (0.540) | -> 4.214 | -> 2.644 | +0.0111 (0.0087) | +0.0037 | +0.950 | 4.38 |
| LNP | k3 | +0.052 (0.129) | -> 4.119 | -> 2.339 | +0.0005 (0.0019) | +0.0047 | +0.101 | 1.75 |
| GRN | **eb0** | -0.007 (0.092) | -> 4.112 | -> 2.319 | +0.0001 (0.0004) | -0.0006 (0.0005) | +0.068 | 3.19 (vic2018) |
| GRN | ebpool | +0.024 (0.104) | -> 4.116 | -> 2.331 | -0.0000 (0.0004) | -0.0009 | +0.099 | 3.16 |
| GRN | k3 | -0.041 (0.050) | -> 4.108 | -> 2.290 | -0.0001 (0.0002) | -0.0005 | -0.003 | 1.43 |
| ALL | **eb0** | +0.395 (0.304) | -> 4.161 | -> 2.472 | +0.0046 (0.0033) | +0.0079 (0.0049) | +0.494 | 4.28 (wa2008) |
| ALL | ebpool | +0.928 (0.410) | -> 4.224 | -> 2.683 | +0.0073 (0.0039) | +0.0079 | +1.113 | 4.38 |
| ALL | k3 | +0.148 (0.237) | -> 4.131 | -> 2.356 | +0.0036 (0.0030) | +0.0097 | +0.218 | 2.13 |
| ALP (not decisive) | eb0 | +0.108 (0.183) | -> 4.126 | -> 2.419 | +0.0051 (0.0042) | +0.0048 | +0.201 | 3.97 |

Verdict per arm, by the prereg:
- **LNP: refused.** Primary not below 0 (point estimate worse); level RMSE worse (+0.80 MSE, SE 0.67); G3 fails;
  max correction 4.28 breaks the "over 4 points" unacceptable clause. Within WA it helps the three latest
  elections (wa2017 -1.27, wa2021 -0.81, wa2025 -0.39 pts^2) but wa2008's 4.28 correction after the two big early
  misses costs +10.66, and NT costs +1.69 (nt2020: correction -2.10 into a +5.32 miss).
- **GRN: refused.** Primary -0.007 against an SE of 0.092: nothing. Level RMSE +0.02. The persistent Greens level
  over-call is real (Vic 4 of 4, NSW 4 of 4) but correcting it does not move the seats or the level error; the
  k3 sensitivity is the only spec below zero on every metric and is within 1 SE everywhere.
- **ALL: refused.** Worse on every metric; WA seats +2.96 (SE 1.70); G3 fails; 4.28 correction.

Live vic2026 correction under eb0, information only: ALP +0.07, LNP +0.34 (raise the Coalition), GRN -1.64.

## Recommended next step

Do not run quick_arm for any of these. The diagnosis the screen points to instead:
1. The seat errors in WA and NT are not the statewide level's. Even the exact level makes WA and NT seats worse
   under pass-through 1, so the published seat mean departs from the level somewhere between `level_recent_apply`
   and the seat primaries (the open WA 2017 item: level ALP 36.4, published seat mean 41.2). Trace one WA seat
   from level to published primary, per the model-design rule, before designing any jurisdiction correction.
2. If a jurisdiction correction is still wanted, fit it on SEAT primary errors (time-forward, same eb0
   shrinkage) and test it with quick_arm, because the level screen cannot see a seat-layer change. Its command,
   once such a switch exists (say `AUSPOL_SEAT_JUR_BIAS=1`), would be
   `powershell.exe -Command 'Rscript "scripts/quick_arm.R" "AUSPOL_SEAT_JUR_BIAS=1"'` (AEF-7 by default), then
   `--pairs=all` for the shipping decision.
3. Greens: leave parked. The level bias is consistent but does not reach the seats.

Unverified: the 17 Oct seat-level numbers (NT +3.61 etc.) were taken from the queue entry, not recomputed here.
