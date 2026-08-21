# The One Nation tail shape is fine. Two actual elections say so, and YouGov is the outlier.

Run 2026-08-20. No model change. This closes the last measurable piece of the
One Nation disagreement without one.

## The question

After replacing the ordering and fixing the compression, our One Nation
allocation matches YouGov on spread (CV 0.327 against 0.332) and correlates with
it at +0.735. What remained was the extreme top: **our maximum district is 33.0%,
theirs is 44.0%.**

The open worry was that magnitudes are quantile-mapped onto **South Australia
2026's** observed spread, and that SA might be the wrong template for Victoria —
too thin a tail.

## Four distributions, expressed as ratios to their own mean

Level removed, so this is shape alone. This is exactly what the quantile map
copies.

| source | n | p50 | p75 | p90 | p95 | **max** |
|---|---:|---:|---:|---:|---:|---:|
| **SA 2026, actual result** | 47 | 0.99 | 1.21 | 1.48 | 1.51 | **1.63** |
| **NSW 2023, actual result** | 17 | 0.88 | 1.21 | 1.45 | 1.51 | **1.57** |
| YouGov Victoria 2026, modelled | 88 | 1.04 | 1.20 | 1.38 | 1.55 | **1.76** |
| ours, SA-mapped | 87 | 0.99 | 1.22 | 1.48 | 1.51 | **1.63** |

Three things follow.

**The shapes agree almost everywhere.** p75 is 1.20–1.22 in all four. p90 is
1.38–1.48, p95 is 1.51–1.55. Whatever else is in dispute, how One Nation's vote
spreads across districts is not.

**Our allocation reproduces SA exactly**, which is what it is supposed to do and
had not been checked at the quantile level before.

**The only real difference is the single top value**, and there **two actual
election results agree with each other and disagree with YouGov**: SA 1.63 and
NSW 1.57 against YouGov's modelled 1.76. Our tail is not thin — theirs is fat,
and it is the one of the four that nobody has counted votes for.

## Decomposing what is left

| | ours | YouGov | ratio |
|---|---:|---:|---:|
| statewide **level** | 20.2 | 25.0 | **1.238** |
| **tail** (max ÷ mean) | 1.63 | 1.76 | 1.077 |

`1.238 × 1.077 = 1.333`, and `33.0 × 1.333 = 44.0` — the two multiply out to
exactly the observed gap.

**74% of the remaining difference is the statewide level; 26% is tail shape.**

## What this settles and what it does not

**Settled: the tail shape needs no change.** It matches the only two actual
election results available, and changing it to match YouGov would mean adopting
a modelled tail over two counted ones — the exact move this project's discipline
refuses.

**Not settled, and now clearly the whole remaining question: is One Nation's
Victorian statewide vote 20.2 or 25.0?** That is a *polling* disagreement, not a
seat-allocation one. It cannot be resolved by anything in the seat model, and
the earlier poll-lag work already found that across three completed One Nation
cycles we **over**-state the party by +1.42 on average — which argues our 20.2
is if anything generous, not timid.

The One Nation seat gap has now been decomposed to the end:

- **not preference flows** — both models agree the party attracts them badly;
- **not the ordering** — replaced with a direct measurement, +0.814 rank
  correlation;
- **not the spread** — CV 0.327 against SA's actual 0.334;
- **not the tail** — 1.63 against two actual elections' 1.63 and 1.57;
- **the statewide level**, and nothing in this repo can adjudicate it.
