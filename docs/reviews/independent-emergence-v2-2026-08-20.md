# v2: the collinearity was real, fixing it changed nothing, and the model still cannot hold an incumbent independent

Run 2026-08-20 against
[../plans/prereg-independent-emergence-v2.md](../plans/prereg-independent-emergence-v2.md),
committed before anything was refitted.

**Verdict: KEEP ARM A again. Nothing changed in the published model.**

## The fix worked as a fix and did nothing as an improvement

The two features are now disjoint — `other_nonmajor_prev` is OTH + OTH_RIGHT
only — and they are genuinely uncorrelated: **−0.064**, against v1 where one
contained the other.

`ind_prev` went from being discarded to carrying real weight:

| term | v1 location | **v2 location** |
|---|---:|---:|
| other non-major vote | +0.0686 | +0.0687 |
| **independent vote last time** | **−0.0007** | **+0.0680** |
| margin | +0.0114 | +0.0113 |
| Coalition-held | +0.5391 | +0.5387 |

And the aggregate result did not move at all:

| | v1 | **v2** | arm A |
|---|---:|---:|---:|
| accuracy | 74/88 | 74/88 | 71/88 |
| Brier | 0.1280 | 0.1282 | 0.1471 |
| log score | 0.407 | 0.408 | 0.856 |
| **B vs A** | 1.03 SE | **1.01 SE** | — |
| **B vs S (E1)** | 0.66 SE | **0.65 SE** | — |

The plan pre-committed the reading of exactly this outcome, and it applies:
**v1's aggregate result was already the truth, and v2 has won nothing.** The
collinearity was real and worth removing, but it was not what stood between this
model and adoption.

Arm B fails the main criterion at **1.01 SE** against a 2 SE bar and fails E1 at
**0.65 SE** against the dumb-temperature control. The control remains unadoptable
in its own right at slope 1.441.

## G1 fails, and the diagnosis I gave before the scores was only half right

**Arm B is below the 0.80 bar in 5 of the 6 seats an independent held and won.**

| seat | A | **B** | S |
|---|---:|---:|---:|
| Sydney | 0.999 | **0.410** | 0.877 |
| Wagga Wagga | 1.000 | **0.524** | 1.000 |
| Lake Macquarie | 1.000 | **0.597** | 0.939 |
| Orange | 0.000 | 0.983 | 0.018 |
| Murray | 0.000 | 0.573 | 0.011 |
| Barwon | 0.003 | 0.421 | 0.055 |

Two things need separating here.

**Orange, Murray and Barwon are not really independent-held.** They were won by
the Shooters, Fishers and Farmers in 2019. The anchor's seat file records the
incumbent as `IND`; our `classify_party()` maps SFF to `OTH_RIGHT`. So arm A
giving them ~0.000 is a **classification mismatch between the seat file and the
first-preference data**, not the emergence defect — and arm B improving them to
0.42–0.98 is partly luck. That mismatch is worth its own look and is recorded
here rather than folded into this result.

The genuine incumbent independents are **Sydney, Wagga Wagga and Lake
Macquarie**, and B fails all three.

**But not for the reason I predicted.** Before the scores I said a linear
`ind_prev` term on a `log1p` outcome would systematically under-predict
incumbents. Checking the medians directly:

| seat | IND 2019 | model median | actual 2023 |
|---|---:|---:|---:|
| Lake Macquarie | 53.5 | 52.2 | 57.5 |
| Wagga Wagga | 46.1 | 47.6 | 44.2 |
| **Sydney** | **41.4** | **20.0** | **41.1** |
| Cabramatta | 30.3 | 8.3 | 16.6 |
| **Dubbo** | **28.4** | **39.7** | **0.0** |

The central predictions for Lake Macquarie and Wagga Wagga are close to right.
The functional form is not uniformly wrong — it is **exponential in the original
units**, so it happens to cross the identity line near 50% and misses badly
below it. Sydney at 41% is predicted at 20%.

So a `log1p(ind_prev)` feature is still the right repair, but the reason is that
the relationship should be **roughly identity** — next ≈ previous — and a linear
term on a log scale can only match that at one or two points.

**And Dubbo shows a second problem the plan never contemplated.** A 28.4%
independent in 2019, predicted at 39.7%, actual **0.0** — the independent simply
did not stand again. No feature in this model can know that. The model this repo
is anchored on handles it with an explicit recontest rate plus a manual
"incumbent recontest confirmed" flag, which is exogenous information of exactly
the kind refusal E4 keeps out of this work.

## What I am not doing

Not switching to `log1p(ind_prev)` here. E3 forbids changing the structure after
seeing the scores, and this is the second time the obvious repair has been
visible at exactly the moment it would be least trustworthy to make.

## What the two rounds have established

- **Emergence works on the case it was built for.** Three of the five
  catastrophic misses go from near-zero to 0.42–0.98, and the log score halves.
  That is not in doubt across either round.
- **It cannot be adopted on this evidence.** It does not clear a dumb temperature
  by a meaningful margin, which means most of the aggregate gain is just an
  overconfident model being made less confident.
- **Incumbent independents and emergent ones are different problems.** One
  round of features cannot serve both: the same term that lets a seat with no
  independent produce one also drags a sitting independent down toward the
  seat's aggregate.
- **Recontest is a third problem**, and unlike the other two it is not solvable
  from historical vote at all.

The honest next step is not a v3 of the same model. It is to treat
"an independent already holds this seat" and "an independent might emerge here"
as **two separate mechanisms with separate parameters**, which is what the
anchor does and what these two rounds have now independently argued for.
