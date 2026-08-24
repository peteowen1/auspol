# SA 2026, read properly: the Coalition paid for One Nation. In Victoria we have Labor paying.

2026-08-25. **Nothing changed.** Descriptive study of one election, prompted by
Pete asking where One Nation's South Australian gains actually came from.

This is the finding the previous three experiments were circling and missing.

## Pete's hypothesis, in levels: confirmed

Mean district-level change, SA 2022 → 2026, split by who led the seat in 2022:

| 2022 lean | seats | ONP | **LNP** | **ALP** | GRN | OTH_RIGHT |
|---|---:|---:|---:|---:|---:|---:|
| ALP-held | 25 | +21.5 | **−16.0** | −5.4 | +1.9 | −2.0 |
| **LNP-held** | 21 | **+18.7** | **−18.3** | **+0.6** | +0.4 | −1.1 |

**In Coalition-held seats it is very nearly one-for-one: One Nation up 18.7,
the Coalition down 18.3, and Labor slightly UP.** Pete's reading — that One
Nation took conservative seats off the Coalition — is exactly what the levels
show.

### And it won only there

| 2022 lean | seats | ONP 1st | ONP 2nd | ONP top-2 | mean ONP 2026 |
|---|---:|---:|---:|---:|---:|
| ALP-held | 25 | **0** | 22 | 22 | 23.8 |
| LNP-held | 21 | **3** | 8 | 11 | 21.4 |

One Nation ran second in almost every Labor seat and never won one. All its
wins came in Coalition seats — on a *lower* mean primary (21.4 against 23.8).
Being second everywhere is not the same as being competitive anywhere.

Individual collapses are severe: MacKillop 67.0 → 26.9 (**−40.2**), Black
50.1 → 10.3 (−39.7), Colton 52.3 → 24.3 (−27.9), Davenport 41.2 → 14.8 (−26.4).

## Preferences confirm the proximity, measured not assumed

From SA 2026's own transfer file, 39 One Nation exclusions across 16 seats:

| One Nation preferences went to | share |
|---|---:|
| **LNP** | **59.0%** |
| ALP | 24.6% |
| IND | 9.6% |
| GRN | 6.8% |

And in the other direction, Coalition preferences went **54.0% to One Nation**,
27.6% to Labor. **They are each other's largest destination.**

Flows are also stable rather than shifting: One Nation's flow to Labor has
drifted 45.0 (WA 2017) → ~34–36 across the last five elections, with SA 2026 at
**36.1**. Our Victorian 2026 assumption is **33.73** (mean of the last five),
which sits inside that range. **No evidence flows moved.**

## Why the earlier test found the opposite, resolved

[../plans/prereg-onp-vote-sourcing.md](../plans/prereg-onp-vote-sourcing.md)
found Labor losing *more* than proportional where One Nation gained more, and
refused Pete's hypothesis. Both results are correct and they answer different
questions. Within SA:

| | correlation with One Nation's gain |
|---|---:|
| Coalition change | **−0.171** |
| Labor change | **−0.507** |

**The Coalition fell ~17 points almost everywhere**, so it has little
cross-district variance left to correlate with. Labor's changes varied more and
tracked One Nation's district-level concentration.

So: **the levels say Coalition, the gradient says Labor, and both are true of
the same election.** A broad near-uniform Coalition collapse plus One Nation
concentrated where Labor was already weakening. The earlier test measured the
gradient by construction and could not see the levels — which is why it must
not be read as refuting Pete's point.

## The finding that matters: our Victorian projection reverses the attribution

For a nearly identical One Nation rise:

| | SA 2026 (actual) | **Victoria 2026 (our projection)** |
|---|---:|---:|
| ONP | +20 | **+20.5** (0.2 → 20.7) |
| **Coalition** | **−17** | **−5.2** (34.5 → 29.3) |
| **Labor** | **−2.5** | **−11.4** (36.7 → 25.3) |

**In South Australia the Coalition paid for One Nation. In our Victorian
forecast, Labor pays for it.** Same-sized surge, opposite source.

This is a **trend-model** output — each party is fitted independently to its own
polls — not a seat-model artefact. And it would explain the entire seat-type
asymmetry downstream: if the Coalition barely falls statewide, its strongholds
stay strong under a uniform swing, so One Nation can only win where Labor is
collapsing, which is Labor seats. That is precisely the observed pattern.

**It also unifies the three refusals.** Not the allocation (projected One Nation
primaries are identical by seat type, 20.2 vs 20.2), not the swing shape
(uniform beats proportional, MAE 3.724 vs 3.970), not district-level sourcing,
not proximity substitution. **It is the statewide level — who is projected to
pay.**

## The obvious counter-argument, which may well be right

Victoria is not South Australia. Labor has governed Victoria since 2014 and
carries the incumbency cost of a long term; SA Labor was one term in and
popular. A genuine anti-Labor swing in Victoria, independent of One Nation, is
entirely plausible and would make our projection right and this comparison
misleading.

**That is now a well-posed, cheap question**: does the Victorian polling
actually show Labor rather than the Coalition falling as One Nation rises? There
are 54 polls in the cycle and the answer does not need a new model.

## Recommended next step

Check the Victorian trend's attribution against its own polls — specifically
whether the Coalition's projected −5.2 is what the polls support while One
Nation goes to ~20. **Do not touch the seat model until that is answered**: if
the statewide attribution is wrong, every seat-level fix would be compensating
for it in the wrong place.

## Caveats

- **One election.** SA 2026 is n=1 and has no Nationals, so it cannot show
  three-cornered contests.
- **The `held22` split uses 2022 first preferences**, which predate One Nation
  existing at scale.
- A statewide aggregation in the first draft of this analysis returned zeros
  from a data.table NSE collision (`p` matched a percentage column) — the trap
  `CLAUDE.md` records five times. The per-district figures above are unaffected
  and the broken table was discarded, not reported.
