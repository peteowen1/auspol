# Path A, scoped: we have neither booth results nor Census — but there is a much shorter route

Written 2026-08-25, starting Path A from
[plan-mrp-scoping.md](plan-mrp-scoping.md). **Scoped before planning, and the
scoping changed the plan.**

## What we actually hold, checked rather than assumed

The MRP scoping said "booth-level results: **present**, in the anchor's
archive". **That was wrong and is corrected here.**

`external/aus-polling-analyser/analysis/Federal-State/booths-*.txt` are
**name correspondences**, not results:

```
#Adelaide
Adelaide,Prospect
Adelaide,Prospect West
```

Seat name, then booth names. No votes. They exist to transpose federal results
onto state districts, which is what `federal-transposed-to-state.csv` is built
from.

And `analysis/Archived/elections/results_*.csv` are **seat-level**:

```
Seat,Albany
fp
Rebecca Stephens,Labor,11804,50.8,6.2
```

Candidate, party, votes, percentage, swing — per **seat**, not per booth.

**So Path A as described needs BOTH of its inputs acquired from scratch:**

| input | status |
|---|---|
| booth-level results | **absent** (correspondences only) |
| Census at booth/SA1 | **absent** |
| booth → SA1 geospatial correspondence | **absent**, and the hardest piece |

That is an acquisition project plus a geospatial project plus a modelling
project. It is the largest thing this repo has ever attempted.

## The shorter route, which gets most of the value

`docs/ANCHOR-MODEL.md:110-113` records the fact that changes this:

> **ABS publishes Census data on CED/SED geographies** (Commonwealth/State
> Electoral Divisions), plus SA1→CED correspondence files for custom
> aggregation after redistributions.

**The ABS already aggregates Census data to electoral divisions.** So a
**seat-level demographic model** needs:

- Census at CED/SED — **one download, no geospatial work**
- seat-level results — **already in the repo**, 1,187 seat-elections across ten
  elections plus the state corpora

No booths. No SA1 correspondence. No ecological-fallacy problem beyond what any
seat-level model already has.

### What it buys against the problem that started this

MacKillop's Coalition fell 67.0 → 26.9 and no swing rule reaches it. A
seat-level demographic model does not ask "what did MacKillop do last time" —
it asks "how are rural, older, lower-income electorates voting now", and
MacKillop inherits that. **That is the same mechanism as MRP**, at coarser
resolution, using data the ABS publishes ready-made.

### What it does not buy

Sub-seat structure. Booth-level regression can see that a seat's swing
concentrated in its mortgage-belt booths; this cannot. **That is the real cost
of the shortcut and it should be stated whenever this is described**, rather
than letting "demographic model" imply theswingison's resolution.

## Path B (AES), and the leakage rule Pete set

The Australian Election Study is post-election. Pete's constraint, adopted:

> **only use it to help with forward-looking** — never to inform a forecast of
> the election it surveyed.

Concretely: AES from election **N** may inform a forecast of election **N+1**
and later, never of **N** itself. That is the same date-gating rule
`pool_configured_flows()` already enforces for preference matrices, and it
should reuse that pattern rather than invent a second one.

Its realistic role is **calibrating demographic vote propensities** — a prior
on how, say, education or age relates to One Nation support — not supplying
live signal. Roughly 2,000 respondents nationally is far too thin for
seat-level inference on its own.

## Build order

1. **Acquire ABS Census at SED for Victoria** (and CED federally). One
   download; confirm the geography vintage matches the current boundaries,
   since redistributions move seats between Censuses.
2. **Join to the existing seat corpus** — 1,187 federal seat-elections plus the
   state data already fetched.
3. **Pre-register before fitting anything.** The criterion must be out-of-sample
   seat-level accuracy against the **uniform swing model**, which has survived
   six alternatives this session. A demographic model is not exempt from that
   bar because it is more sophisticated.
4. **AES second**, date-gated, and only as a prior on demographic propensities.

## Honest timeline

**Not before 28 November 2026.** Step 1 is days; steps 2–3 are weeks and need
their own pre-registration and out-of-sample validation. Victoria ships on the
current model.

The value is for the cycles after Victoria — and the corpus to validate it
already exists, which is why this is worth starting properly rather than
rushing a version that cannot be checked.
