# The full preference distributions exist after all, and they move two of the numbers

Run 2026-08-20. Data acquisition plus a correction to
[onp-allocation-sa-2026-08-17.md](onp-allocation-sa-2026-08-17.md), whose
closing section named this as the blocker on the rebuild.

## The blocker, quoted and removed

That review ends:

> "16 districts is not enough. 97 events spread across 28 distinct cells, most
> with n ≤ 2."
>
> "Settling the seat count needs full distribution-of-preferences tables across
> many elections — a materially larger acquisition than the first-preference
> data, and the real blocker on the rebuild."

It had 16 districts because Wikipedia publishes a full distribution for only
some seats. **The ECSA API carries `finalDistribution` for all 47**, with every
exclusion round, every candidate's vote change, and which candidates were still
standing.

| | review | this |
|---|---:|---:|
| districts | 16 | **47** |
| exclusion events | 97 | **294** |
| cells (model party classes) | 28 | 26 |

Same granularity, **three times the events per cell**. Ten cells now carry five
or more events; seven are singletons.

**Raw, it is worse, and that is worth knowing.** Conditioned on the literal
survivor set the 294 events land in **119** cells, 66 of them singletons —
poorer per-cell coverage than the review's 97-in-28. The gain comes entirely
from collapsing the ballot's minor parties into the model's classes with
`classify_party()`. More events did not by itself buy more power.

## Anchor check

The review reports that of Liberal preferences reaching Labor or One Nation,
**62.7%** went to One Nation. On 47 districts: **66.2%**. Consistent, and the
extraction is wired to abort if the two disagree by more than 8 points.

## Two of the review's conditional claims reverse

| cell | review (16 districts) | this (47 districts) |
|---|---:|---:|
| **ONP → ALP, survivors {ALP, LNP}** | **57.0%** (n = 2) | **31.1%** (n = 7) |
| GRN → ALP, survivors {ALP, ONP} | 81.5% | 80.4% (n = 12) |
| GRN → ALP, survivors {ALP, LNP} | 74.5% | **84.5%** (n = 6) |

The review concluded *"Greens preference Labor harder when the alternative is
One Nation than when it is the Liberals"*. On 47 districts the ordering is the
other way — 84.5% against Liberals, 80.4% against One Nation. Both samples are
small and this is not significant either way, but the claim as stated is not
supported by the fuller data.

**The One Nation cell matters more.** The review used a 19.3–57.0 range to argue
the model's single fixed **33.7%** flow-to-Labor could not express reality. On
47 districts that range collapses:

| survivors | events | ONP → ALP |
|---|---:|---:|
| {ALP, LNP} | 7 | **31.1%** |
| {ALP, GRN, LNP} | 6 | **17.7%** |

**31.1% against a model constant of 33.7% is close.** The configuration where
the constant is clearly wrong is the one with the Greens still standing, at
17.7%. That is a narrower and more actionable finding than "a scalar cannot
express any of this", and it rests on 7 and 6 events rather than 2.

## What has and has not changed

**Changed:** the acquisition the review called the real blocker is done for
South Australia, and it cost one afternoon rather than the "materially larger"
effort anticipated — because the data was behind an undocumented API rather
than genuinely unpublished.

**Not changed:** the review's second structural gap, *"one state, one
election"*. Every number here is still SA 2026. Nothing about a state where One
Nation polls 3% is measured by an election where it polled 22.9%.

**Also not changed:** its first gap, party classes rather than candidates. The
collapse to `classify_party()` classes is what made the cells usable, and it is
the same simplification the review warned about — a Victorian ballot carries
Legalise Cannabis, Animal Justice, Family First, Freedom and Victorian
Socialists as separate candidates excluded one at a time. Here they are all
`OTH`, and `OTH` is the largest source of transfers by far, at 148 of 294
events.

## What this does not license

Rerunning the Victorian seat count off this matrix. The review already tried
that off the 16-district version, got Labor 56 and One Nation 0, called it
incoherent and said not to quote it. Three times the events does not make a
single-election, single-state, class-collapsed matrix into a basis for a
published seat count, and no criterion for adopting one has been
pre-registered.

**The next honest step is another election, not another analysis of this one.**
Victoria and NSW publish distribution-of-preferences data; whether they publish
it per district in a form this reachable is unknown and is a fetch, not a
modelling question.
