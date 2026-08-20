# Round 2: the port is better in both elections, and refusal P2 fires anyway

Run 2026-08-20 against
[../plans/prereg-seat-swing-port-round2.md](../plans/prereg-seat-swing-port-round2.md),
committed before this ran.

**Verdict: do NOT adopt. Refused on P2.** The port improves the score in both
elections and degrades calibration in one, which is a conflict rather than a
power problem — and the difference between those two things is the whole point
of this write-up.

## Deviation from the plan, recorded not absorbed

The plan says three elections. **There are two.** `seat_swing_adjustment()`
needs the seat file for the election being predicted, and `2018vic.txt` does not
exist, so Victoria 2014→2018 cannot be ported. It runs identically in both arms
— confirmed, largest probability difference **0.000000** — which makes it a
clean control rather than a loss.

Testable: **Victoria 2018→2022 (78 seats)** and **NSW 2023 (88 seats)**.

## The result

| | Brier off | Brier on | gain |
|---|---:|---:|---:|
| vic2022 | 0.09415 | 0.09024 | **+0.00391** |
| nsw2023 | 0.14680 | 0.14640 | **+0.00043** |

| | difference | SE | |
|---|---:|---:|---:|
| per-seat, 166 seats | −0.00206 | 0.00849 | **−0.24 SE** |
| **election-clustered, 1 df** | −0.00217 | 0.00174 | **−1.25 SE** |

Round 1's NSW figure reproduces exactly at −0.04 SE, so **refusal P3 passes** and
nothing upstream moved.

## Zone 3's criteria, all three of which hold

The plan predicted this would land in zone 3 and fixed four tests in advance.

1. **Prior plausibility — holds.** `fed_swing` independently cuts held-out
   seat-swing MAE from 3.9476 to 3.3655. A known-real signal, not a fishing
   expedition.
2. **Direction consistency — holds.** Positive in **2 of 2** elections.
3. **Detectability — holds.** 2 SE needs 0.00348; observed 0.00217, which is 62%
   of the bar. Not undetectable, just short.
4. **Mechanism — holds.** 59 of 78 Victorian and 56 of 88 NSW seat probabilities
   moved; mean signed change +0.0008, near zero as a redistribution requires.

**By zone 3 alone this adopts.** It does not adopt, because the refusals sit
above the zones.

## P2, which fires

> "If the port improves the Brier score while moving the calibration slope away
> from 1, it is trading honesty for score and is refused."

| calibration slope | off | on | distance from 1 |
|---|---:|---:|---|
| vic2022 | 2.515 | 0.679 | 1.515 → **0.321**, toward |
| nsw2023 | 0.541 | **0.338** | 0.459 → **0.662**, away |

NSW's Brier improves while its slope moves away from 1. **That is the P2
condition, met exactly.**

The mechanism is coherent and worth stating, because it is not noise. The port
adds signal, which makes predictions **sharper**. Victoria was badly
under-confident at 2.515 and sharpening fixed it. NSW was already over-confident
at 0.541 and sharpening made it worse. **The same change helps a model that is
too timid and hurts one that is already too sure**, and both are true at once.

Victoria's log score also worsened, 0.2582 → 0.2829, while its Brier improved —
the same signature. Not a pre-registered criterion, so it decides nothing, but
it points the same way.

## A defect in my own plan, stated rather than exploited

**P2 does not say whether it applies per election or pooled.** Pooled, mean
distance from 1 goes 0.987 → 0.492 and calibration clearly *improves*; per
election, it fires on NSW.

I wrote that clause today, so I cannot claim it as someone else's ambiguity. The
reading is resolved against the change, for two reasons: the clause is written
without qualification, and `CLAUDE.md` records that the status quo wins ties
precisely so an ambiguity found after the results cannot be settled by whichever
reading gives the preferred answer.

## Why this is a refusal and not an underpowered null

The instruction behind zone 3 was to stop treating 2 SE as a mechanical cutoff
when the data is too thin to show a real effect. That reasoning applies to a
result that is **positive on every measure but small**. It does not apply here.

**This result has two metrics pointing in opposite directions on the same
election.** More data would resolve that, but it is a substantive conflict, not
an absence of evidence — and adopting through it would be exactly the
after-the-fact reasoning the zones exist to prevent.

## What would settle it

A third portable election, which needs a seat file for the predicted year. The
binding constraint is `2018vic.txt`, whose absence is what cut this test from
three elections to two. **South Australia 2026 is the strongest candidate**:
`2026sa.txt` carries `fed_swing` for all 47 seats, the transfers and first
preferences are already fetched, and it is the only completed election where One
Nation contested at the level Victoria is forecasting.

The port stays behind `AUSPOL_SEAT_SWING_PORT`, default off. **It is not
deleted**, because zone 2 is for a feature that does not help, and this one does
— on both elections, on the metric the plan named first.
