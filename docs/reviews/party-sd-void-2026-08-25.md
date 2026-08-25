# `party_sd = 2.33`: the experiment was VOID, not refused

2026-08-25. Against `docs/plans/prereg-party-sd-from-data.md`, committed before
any arm was run. **This file replaces an earlier version that reported a
refusal. That refusal was wrong and the reasons are below.**

## What I got wrong, first

1. **I refused the change on a movement of 0.43 SE.** Criterion 1 bounded slope
   movement at 0.20 in absolute units. The calibration slopes here have standard
   errors of **0.18 to 0.87**, so 0.20 is somewhere between a quarter of one SE
   and one full SE depending on the harness. The clause could never have
   distinguished anything. That is the "tolerance not written in standard
   errors" failure for the **fourth** time in this repo, and the first time it
   has produced a wrong verdict rather than a wrong-but-harmless one.
2. **I named the wrong election.** The pair label is `vic{to}`
   (`backtest_candidate_vic.R:395`), so `vic2018` is 2014→2018 and `vic2022` is
   2018→2022. The hedged-looking pair is **2018→2022**, not 2014→2018 as the
   earlier version of this file and its commit message both said.
3. **The "one harness is under-confident" finding does not exist.** See below.

## The slopes, with their own standard errors

| harness | slope | SE | (slope − 1) | 95% CI |
|---|---:|---:|---:|---|
| SA 2026 | 0.389 | 0.186 | **−3.3 SE** | [0.02, 0.75] |
| NSW 2023 | 0.573 | 0.180 | **−2.4 SE** | [0.22, 0.93] |
| vic 2014→2018 | 0.561 | 0.266 | −1.7 SE | [0.04, 1.08] |
| vic 2018→2022 | 2.272 | 0.765 | +1.7 SE | **[0.77, 3.77]** |

**Victoria 2018→2022 is not detectably hedged.** Its confidence interval
contains 1. A slope of 2.272 with an SE of 0.765 is what a calibrated model
looks like on 78 seats — the estimate is noisy, not anomalous. The earlier
version of this file built a whole finding on that number ("uncertainty cannot
be a single global constant, and here is the harness that proves it") and the
finding was an artefact of reading a point estimate without its SE.

What survives is simpler and points the other way: **SA at −3.3 SE and NSW at
−2.4 SE are genuinely over-confident, Victoria 2014→2018 is borderline at
−1.7 SE, and no harness is detectably hedged.** The model is over-confident
broadly, not conditionally.

## Paired per-seat scores, 1.50 → 2.33

Same seats, same seed, one parameter changed. Negative is better.

| harness | Δ log | t | Δ Brier | t |
|---|---:|---:|---:|---:|
| vic 2014→2018 | −0.0084 | −1.17 | −0.00114 | −1.01 |
| vic 2018→2022 | −0.0113 | −2.14 | −0.00495 | −2.89 |
| NSW 2023 | −0.0478 | −2.32 | −0.00319 | −2.40 |
| SA 2026 | −0.1354 | −1.20 | −0.00322 | −1.78 |

**4 of 4 improved, on both scoring rules.** Two of four clear 2 SE on log and
two on Brier.

**Two limits, stated rather than implied.** Seats within one election share a
statewide draw, so they are not independent and these per-election t-statistics
are inflated. And the sign test across the four elections gives **p = 0.125**,
which is the floor for 4-of-4 — with four clusters no result can reach 0.05.
The evidence is consistent in sign and modest in size; it is not conclusive on
its own.

## Verdict: VOID

The pre-registration says explicitly: *"the measurement is the justification.
The backtest is a check that adopting the honest value does not break something,
not a search for the value that scores best."* The three clauses were meant to
operationalise "degrades".

- **Criterion 1: no power.** Bound of 0.20 against SEs of 0.18–0.87.
- **Criterion 2: no power.** Bounded in whole seats; the arms are paired, so the
  test is McNemar on discordant seats, and one seat flipped. Recorded as
  underpowered **before** Victoria and NSW ran.
- **Criterion 3: passed.** No score worsened anywhere; all four improved.

**Two of three clauses were arithmetically incapable of producing information,
so the experiment did not adjudicate in either direction.** Calling this a
refusal was wrong, and calling it an adoption would be equally unearned.

## What I am NOT doing

Re-pre-registering on the same data. The results are known, so any criterion
written now is chosen with the answer in hand and is worth nothing. That door is
closed for this dataset.

## Recommendation, flagged as the pattern to be suspicious of

Adopt 2.33 **on the measurement**, not on the backtest. The measurement never
depended on the backtest: 1.50 has no derivation anywhere in the repo, and the
realised statewide first-preference error over 139 party-cycles in 33
independent cycles is 2.33, which is 2.9 SE away. The backtest's honest summary
is "nothing degraded detectably, and all eight score comparisons moved the right
way."

**Be suspicious of this recommendation.** It is me re-reading my own criterion
after seeing results, in a direction that favours the change — structurally the
same move CLAUDE.md records twice as a rationalisation. Two things distinguish
it, and they should be weighed rather than accepted: the powerlessness of
clauses 1 and 2 is computable from `n` alone and was provable before running,
and clause 2's defect was written down before two of the four harnesses had run.
That is a reason to take it seriously, not a reason to skip the check. **The
call is Pete's.**

## What this experiment did establish, independent of the verdict

- **`shrink` is not replaced by an honest `party_sd`.** On SA, 2.33 moves the
  slope 0.389 → 0.518; `shrink = 0.10` then moves it 0.518 → 1.249, roughly
  twice as close to nominal. `shrink` does the calibration work. Framing it as
  "a patch for missing statewide uncertainty" was wrong — the missing
  uncertainty is real and measured, and fixing it leaves most of the
  over-confidence in place. **So the remaining over-confidence is seat-level or
  flows, not statewide.**
- **Minor parties are not less predictable than majors**: 2.31 vs 2.37, a fifth
  of one SE. Expected otherwise.
- **South Australia is not less certain than Victoria** despite fewer and
  smaller polls: 1.92 vs 2.19. Expected otherwise; n = 14 for SA so thin, but it
  points against the hypothesis.
- **The conditional-uncertainty question is not blocked by a Victorian
  anomaly**, because there is no Victorian anomaly. But it is also less
  supported than it looked: three of four harnesses are over-confident in the
  same direction, which argues for a general fix ahead of a conditional one.

## Three bugs found while running this, all live before today

1. **`fallback_smooth` and `flow_sd` existed only in the SA harness.** Setting
   them for a cross-harness run silently did nothing in the other three. The
   first Victorian and NSW arms were run that way and discarded. Ported; all
   four now print `BS1f` with what they applied.
2. **`backtest_candidate_nsw.R:115` was `N_SIMS <- 20000`, hardcoded**, while
   the other three read `AUSPOL_N_SIMS`. Every NSW run this session ran at
   20,000 regardless of what was asked, which is why single arms kept being
   killed. Asking for 100 sims returned metrics identical to four decimals —
   accuracy 71/88, Brier 0.1455, slope 0.568 — the byte-identical output that
   reads as "this input does not matter". Fixed and **proved**: 100 sims now
   takes 4.3 s against 5m58s and returns slope 0.339, not 0.568.
3. **Victoria and NSW never tagged `shrink`, `elastic` or (NSW) the sim count
   into the output filename**, so arms overwrote each other; NSW and SA both
   printed a hardcoded filename naming a file they had not written. All fixed.

## Next

The powered signal is that **SA (−3.3 SE) and NSW (−2.4 SE) are over-confident**
and `shrink` is what corrects it. `shrink = 0.10` is a published constant that
has never been fitted. That is the thing worth a properly sized experiment —
with tolerances in standard errors this time, and accuracy clauses sized on
discordant pairs.
