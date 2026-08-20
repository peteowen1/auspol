# Re-validated on five elections: three of the four adopted predictors are worthless, and one carries everything

Run 2026-08-20 against
[../plans/prereg-seat-swing-revalidation.md](../plans/prereg-seat-swing-revalidation.md),
committed before anything was refitted. `scripts/revalidate_seat_swing.R`.

**Verdict per the pre-registered rule: WITHDRAW** the three predictors this test
could measure. Their pooled held-out MAE is worse than doing nothing.

## Why this was re-run

`seat_swing_adjustment()` is **live in the published model** and was validated on
**two** elections. Today the independent-emergence model improved by 1.46 SE on
one election and got **2.52 SE worse** on six. Two elections establishes nothing,
and this component ships.

Three federal elections became available, taking the sample from 2 to 5
(629 seats). `fed_swing` is empty in every federal seat file — correctly, since
there is no separate federal swing at a federal election — so the five-election
test covers `retirement`, `soph_cand` and `soph_party` only.

## The five-election result

Leave-one-election-out, predicting each seat's deviation from its own election's
statewide swing:

| election | n | uniform swing | model | gain |
|---|---:|---:|---:|---:|
| vic2022 | 88 | 3.351 | 3.376 | **−0.025** |
| nsw2023 | 93 | 4.508 | 4.382 | +0.126 |
| fed2019 | 150 | 2.943 | 3.155 | **−0.212** |
| fed2022 | 148 | 3.327 | 3.230 | +0.097 |
| fed2025 | 150 | 3.002 | 2.953 | +0.049 |
| **pooled** | **629** | **3.3360** | **3.3368** | **−0.0008** |

Positive in 3 of 5, but the pooled gain is **negative**. The rule fires:
*withdraw if the pooled held-out MAE is worse than uniform swing.*

Split as K3 required — and it goes the opposite way to what K3 anticipated:

| | elections | seats | pooled gain |
|---|---:|---:|---:|
| state | 2 | 181 | **+0.0527** |
| federal | 3 | 448 | **−0.0224** |

## The finding that matters, and it is post-hoc

The five-election test could not include `fed_swing`. So the same comparison was
run on the two state elections where all four predictors exist:

| model | leave-one-election-out MAE |
|---|---:|
| **`fed_swing` alone** | **3.3655** |
| all four — **as adopted** | 3.4249 |
| uniform swing (baseline) | 3.9476 |
| the other three alone | **4.0091** |

Three things follow, and the third is the one to act on:

1. **`fed_swing` carries the entire component.** Alone it beats the baseline by
   0.58.
2. **The other three are worse than doing nothing** — 4.0091 against a 3.9476
   baseline. On their own they add noise.
3. **Adding them to `fed_swing` makes it worse**: 3.4249 against 3.3655. The
   adopted four-predictor model is **beaten by one of its own predictors**.

This was measured after seeing the five-election result, so it is **post-hoc**
and is reported as such. But it is not an isolated read: the five-election test
independently found those same three predictors worth ≤ 0, on 629 seats and a
completely different sample. Two independent lines agree.

**`fed_swing` itself remains validated on only two elections** and this exercise
could not change that. It is the strongest thing in the seat model (t = 8.46)
and the least tested.

## C6 is answered — the blocker from earlier today is gone

The port of `seat_swing_adjustment()` into the candidate model was refused this
morning because `soph_cand` moved 54% of its value when refitted without NSW.
On five elections, the largest shift of any coefficient from its pooled value,
measured in that fit's own standard error:

| term | largest shift |
|---|---:|
| `ret_i` | 0.73 SE |
| `soc_i` | **1.19 SE** |
| `sop_i` | 1.26 SE |

**All stable.** C6 is answered: the coefficients do not move meaningfully across
elections, and the 54% figure was a two-election artefact — exactly as suspected
when the criterion was flagged as mis-specified.

The irony is worth recording: **C6 blocked porting a component that this test
now says should mostly be removed.** The blocker was wrong and the caution was
right, for unrelated reasons.

## Signs held

K2 required retirement to hurt the incumbent and a sophomore to gain, on the
pooled fit. Both hold: `ret_i` −2.036 (t = −4.60), `soc_i` +0.811 (t = 1.67).
So the original directional findings were not noise — the predictors point the
right way. They simply do not pay for the variance they add.

## What has NOT been changed

Nothing. The published model still uses all four predictors.

The pre-registered rule withdraws the three, and the supplementary evidence says
`fed_swing` alone is better than all four — but that specific comparison is
post-hoc, and this project's whole lesson today is about not acting on a
favourable number found after the fact. The change is recorded as recommended,
with its own pre-registration owed before it ships.
