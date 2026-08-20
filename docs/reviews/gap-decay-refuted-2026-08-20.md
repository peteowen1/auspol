# The gap hypothesis is refuted, one turn after I raised it

Run 2026-08-20 against
[../plans/prereg-gap-decay.md](../plans/prereg-gap-decay.md), committed before
South Australia was scored.

**Verdict: REFUTED.** Both out-of-sample elections went the wrong way.

## The prediction and the result

The plan predicted, in writing and before scoring: *both sa2018 and sa2022 will
have a gain at or below zero.*

| election | gap | dispersion | gain | prediction |
|---|---:|---:|---:|---|
| sa2018 | 20 months | 2.753 | **+0.201** | ≤ 0 — **failed** |
| sa2022 | 34 months | 3.143 | **+0.097** | ≤ 0 — **failed** |

Both positive. The formal refusal clause fires on sa2018 exceeding +0.20, which
it does by **0.0007** — but the refutation does not rest on that hair. **The
primary prediction was that both would be at or below zero, and both were
above.**

## What the seven elections actually show

| election | federal | gap | dispersion | gain |
|---|---|---:|---:|---:|
| vic2022 | 2022 | 6 | 3.351 | +0.337 |
| nsw2023 | 2022 | 10 | 4.508 | +0.391 |
| qld2020 | 2019 | 17 | 1.676 | −0.270 *(excluded, G4)* |
| **sa2018** | 2016 | 20 | 2.753 | **+0.201** |
| vic2018 | 2016 | 24 | 3.153 | −0.185 |
| nsw2019 | 2016 | 34 | 3.399 | −0.049 |
| **sa2022** | 2019 | 34 | 3.143 | **+0.097** |

Grouped by **federal election** instead of by gap:

| federal | state elections | gaps | mean gain |
|---|---|---|---:|
| 2016 | sa2018, vic2018, nsw2019 | 20, 24, 34 | −0.011 |
| 2019 | sa2022 | 34 | +0.097 |
| **2022** | vic2022, nsw2023 | 6, 10 | **+0.364** |

**sa2018 at 20 months gained +0.20 while vic2018 at 24 months lost −0.18** —
same federal election, adjacent gaps, opposite signs. Gap does not separate
them. Refusal **G1** named this confound in advance and it is now the leading
explanation rather than the alternative.

The group difference survives at **+1.80 SE** against a 2 SE bar, and the rank
correlation actually strengthens to **−0.75**. Neither rescues the hypothesis:
the two elections that were supposed to test it both contradicted it, and the
surviving group difference is carried entirely by the two federal-2022 cycles
that generated the idea.

## What this does to the flag I raised

[fed-swing-gain-decomposition-2026-08-20.md](fed-swing-gain-decomposition-2026-08-20.md)
warned that `SEAT_SWING_COEF = 0.7452` was fitted on the two shortest-gap
elections while Victoria 2026 sits at 18 months, "in the group where the
adjustment did not help".

**That framing is wrong and is withdrawn.** Long-gap elections are not
systematically bad: SA gained at both 20 and 34 months.

A narrower concern survives, and it is worth keeping: **the coefficient was
fitted on the only two elections with a published `fed_swing`, and both follow
federal 2022, which is the most informative federal election in the set by a
wide margin.** Whether that is federal 2022 being unusual or the short gap being
real, two elections cannot say — and they are the same two elections either way.

So the risk is real but its *shape* changed: it is a sample-idiosyncrasy risk,
not a time-decay risk. Nothing here justifies touching the constant, as
pre-registered.

## G4 fired, as designed

qld2020 was **excluded** for dispersion 1.676, below the pre-registered 2.0
floor. Without that exclusion the long-gap mean would have been lower and the
result would have looked friendlier to the hypothesis. **The rule that cost the
hypothesis its best number was committed before the data was seen**, which is
the entire reason it is worth anything.

## G5 needed a clarification, recorded not hidden

G5 said the original five gains must be unchanged or the run is invalid. But
those gains come from leave-one-election-out, so adding SA to the training folds
changes them legitimately — the clause as written fires on correct behaviour.

Implemented as its intent: the five-election configuration was re-run exactly as
published and reproduces to within **0.0001** on every election. Both sets are
reported. The clarification does not favour either outcome.

## The thing worth remembering

Yesterday's version of this mistake would have been to publish the gap pattern
as a finding. It had everything a finding usually has — a clean 2-versus-3
split, a plausible mechanism, a worrying implication for the live forecast, and
a number attached.

It took **two elections and about twenty minutes** to kill, and the only reason
the test meant anything is that the prediction was written down first. The
decomposition that produced the hypothesis was good work; the hypothesis was
wrong. Those are not in tension.
