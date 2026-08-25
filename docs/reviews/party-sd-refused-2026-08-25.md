# `party_sd = 2.33` is measured, better on every score, and REFUSED

2026-08-25. Against `docs/plans/prereg-party-sd-from-data.md`, committed before
any arm was run.

## Result

All four harnesses, 5,000 sims, `fallback_smooth = 0.60`, `flow_sd = 3.65`,
`elastic_over = 1.5`, `shrink = 0`. Each pair is the same seats and the same
seed with one parameter changed.

| harness | acc 1.50 | acc 2.33 | slope 1.50 | slope 2.33 | slope move | score 1.50 | score 2.33 |
|---|---:|---:|---:|---:|---|---:|---:|
| SA 2026 | 39/47 | **38/47** | 0.389 | 0.518 | +0.129 toward | log 0.6826 | **0.5471** |
| Vic 2018→2022 | 80/88 | 80/88 | 0.561 | 0.662 | +0.101 toward | log 0.4002 | **0.3918** |
| Vic 2014→2018 | 65/78 | 65/78 | 2.272 | 2.600 | **+0.328 AWAY** | log 0.2723 | **0.2610** |
| NSW 2023 | 71/88 | 71/88 | 0.573 | 0.601 | +0.028 toward | Brier 0.1456 | **0.1424** |

NSW excluding IND wins: slope 0.810 → **0.953**, Brier 0.0952 → 0.0917.

**Log score and Brier improve in all four.** Accuracy is unchanged in three and
falls one seat in South Australia.

## The verdict: REFUSED

- **Criterion 1 FAILS.** Requires the slope to move toward 1 in at least 3 of 4
  — satisfied — **and to move away from 1 by more than 0.20 in none**. Victoria
  2014→2018 moves away by **0.328**.
- **Criterion 2 FAILS.** The four-harness accuracy total falls 255 → 254.
- **Criterion 3 PASSES.** No log score worsens; all four improve.

**The refusal does not rest on the underpowered clause.** `docs/plans/` already
records, written before Victoria and NSW ran, that clause 2 is sized in whole
seats rather than standard errors and can refuse on a one-seat flip that is
indistinguishable from noise. Set clause 2 aside entirely and **criterion 1
still refuses**, on a 0.328 slope movement that is large, well measured, and in
the wrong direction. That is a clean refusal, not a technicality.

## Why it was refused, and this is the finding

**Victoria 2014→2018 is under-confident. Every other harness is over-confident.**

| harness | baseline slope | direction |
|---|---:|---|
| SA 2026 | 0.389 | badly over-confident |
| Vic 2018→2022 | 0.561 | over-confident |
| NSW 2023 | 0.573 | over-confident |
| **Vic 2014→2018** | **2.272** | **under-confident** |

A slope below 1 means the forecast is too sure of itself; above 1 means it is
too hedged. Three harnesses sit at 0.39–0.57 and one sits at 2.27. **Widening
the statewide draw helps the first three and hurts the fourth, necessarily**,
because a single global parameter can only move all four the same way.

So the honest reading of this experiment is not "2.33 is wrong". The measurement
stands: 1.50 has no derivation anywhere in the repo, and the realised statewide
error over 139 party-cycles in 33 independent cycles is 2.33, which is 2.9 SE
away. The reading is that **uncertainty in this model cannot be a single global
constant**, which is exactly the question that prompted the work — whether
confidence should be conditional on how close the race is and how good the polls
are. This is the evidence that it must be.

## What was NOT claimed

- `shrink` is **not** replaced by an honest `party_sd`. On South Australia,
  widening to 2.33 moved the slope 0.389 → 0.518; adding `shrink = 0.10` moved
  it 0.518 → 1.249. `shrink` does the calibration work. The earlier framing of
  `shrink` as "a post-hoc patch for missing statewide uncertainty" was wrong:
  the missing uncertainty is real and measured, and fixing it leaves most of the
  over-confidence in place. The two are complements. Whatever the remaining
  over-confidence is, it is **not** statewide — it is seat-level or flows.
- Minor parties are **not** less predictable than majors: 2.31 vs 2.37, a fifth
  of one SE. Expected otherwise.
- South Australia is **not** less certain than Victoria despite fewer and
  smaller polls: realised 1.92 vs 2.19. Expected otherwise. n=14 for SA, so
  thin, but it points the opposite way to the hypothesis.

## Three bugs found while running this, all live before today

1. **`fallback_smooth` and `flow_sd` existed only in the SA harness.** Setting
   them in the environment for a cross-harness run silently did nothing in the
   other three. The first Victorian and NSW arms were run this way and were
   discarded. Ported; all four now print `BS1f` with what they applied.
2. **`backtest_candidate_nsw.R:115` was `N_SIMS <- 20000`, hardcoded**, while
   the other three read `AUSPOL_N_SIMS`. Every NSW run in this session ran at
   20,000 sims regardless of what was asked for, which is why single arms kept
   being killed. Asking for 100 sims returned metrics identical to four decimal
   places — accuracy 71/88, Brier 0.1455, slope 0.568 — the byte-identical
   output that reads as "this input does not matter". Fixed and **proved**: at
   100 sims it now runs in 4.3 s against 5m58s and returns slope 0.339, not
   0.568.
3. **Victoria and NSW never tagged `shrink`, `elastic` or (NSW) the sim count
   into the output filename**, so arms overwrote each other, and both NSW and SA
   printed a hardcoded filename in the log that named a file they had not
   written. All fixed.

## Next

The question this refusal poses is which harness is right about Victoria
2014→2018 — whether that election is genuinely a case where the model should be
hedged and the others are not, or whether its slope of 2.27 is an artefact of
something else in that pair. **Nothing should be adopted globally until that is
answered**, because every global uncertainty setting will keep trading it off
against the other three.
