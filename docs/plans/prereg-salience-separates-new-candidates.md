# Pre-registration: can salience separate a new candidate who wins from one who doesn't?

2026-08-27, written before nsw2023 and sa2026 salience exist. Supersedes C2 of
`prereg-salience-emergence-gate.md`, which was thrown away for scoring win/lose
against a vote-share model.

## The question, which arm C defined

`docs/reviews/arm-c-conditional-slopes-2026-08-27.md` refused conditional slopes
and produced the reason: candidate identity splits **three** ways, and the model
pools two of them.

| group | slope | how many |
|---|--:|---|
| 1. the same candidate stands again | 0.907 | ~20% of seat-classes |
| 2. a new candidate who will poll nothing | ~0.33 | the overwhelming majority |
| 3. a new candidate who will **win** | very wrong at 0.33 | 9 of 307 in fed2022 |

Groups 2 and 3 are **indistinguishable from the corpus alone** — neither has a
prior vote in the seat. Dai Le had 0.0%. Pooling them is why arm C hurt every
emergence election it touched: fed2022 +0.143, sa2026 +0.114, fed2019 +0.094.

**So the question is narrow and answerable: within group 2+3, does salience rank
group 3 to the top?**

## What is already measured, on the election that is spent

fed2022, restricted to the 307 new candidates:

- **AUC 0.982** over 9 winners
- winners' median jump **1.61** against **0.00** for the rest
- all nine winners at the **89th–100th percentile**

fed2022 selected this framing and cannot test it.

## The test

**nsw2023 and sa2026**, neither fetched when this was written, both in the same
2021–2026 Trends window as fed2022 so no rescaling is involved.

### Primary — separation within the new-candidate population

**AUC of `jump` over new candidates, per election, must exceed 0.80.**

Sized against what it must beat: the null is 0.500 and the fitted election gave
0.982. A threshold of 0.80 sits roughly midway and is comfortably resolvable —
with 4 winners against ~290 others, the SE of an AUC near 0.8 is about 0.10, so
0.80 is three SE above chance. Unlike the calibration slope this metric has the
power to answer its own question, which is the check `CLAUDE.md` now requires.

### Secondary — the winners must be near the top, not merely above average

**Median percentile of the winning new candidates ≥ 85th**, within their own
election's new-candidate field.

### Guard — it must not simply flag everyone

**Among new candidates above the winners' minimum jump, at most 4 non-winners
per winner.** Phrased in the same units as the primary, on the same population.
This is the criterion C2 got wrong by counting across the whole field and
scoring vote-share success as failure.

## Dry-run: verdicts fixed before running

| case | expected | what it tests |
|---|---|---|
| Dai Le, Fowler 2022, prior 0.0%, won on 29.5% | ranks top decile of new candidates | the case NOTHING else can reach — group 2 and 3 are identical in the corpus here |
| a Greens candidate polling 2% with no search presence | bottom half, and NOT counted a false positive | C2's exact error |
| Alex Greenwich, sitting, prior 41.4% | **excluded — not a new candidate** | the population must be group 2+3 only; including group 1 would flatter it |
| sa2026's four One Nation winners | reported **separately** | a personal-name signal detecting a PARTY surge is likelier leakage than skill |

If the scoring code disagrees with any row, the code is wrong.

## Refusal

- **If it works on nsw2023 but not sa2026, or the reverse.** Two elections; one
  carrying the result is indistinguishable from chance.
- **If the One Nation seats drive sa2026.** They are a party emergence, not a
  personal one. Reported separately, and if removing them collapses the result,
  say so.
- **If the guard fails.** A signal that flags a fifth of the field has not
  separated anything, whatever its AUC.
- **If it needs a threshold tuned after seeing the result.** The primary is an
  AUC precisely so no threshold is required.

## What this cannot see

- **Two test elections**, both state, against a signal fitted on federal.
- **nsw2023 has ONE genuine new-candidate winner** (Regan in Wakehurst) once
  returning candidates are removed — the four Shooters-to-independent seats are
  group 1, not group 3. So sa2026 carries most of the weight, and its four are
  correlated.
- **A rank test says nothing about magnitude.** Ranking group 3 to the top does
  not tell the model what vote to give them; that is a separate question and is
  not tested here.
- Single Trends pull per candidate; no replicates.
