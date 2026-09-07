# The salience corpus was missing the candidates it exists to find — and Trends cannot see them anyway

2026-09-07. Two findings, one fixed and one that is a limit of the data source.

## Finding 1, fixed: minor-right candidates were cut before being queried

`scripts/fetch_salience_v6.R` selects who to query as "the top two non-majors
per seat by the PARTY's prior vote in that seat, plus every independent". The
comment beside that rule already states the problem it was written for:

> An emergent candidate is by definition the one with no prior vote, so any rule
> ranking on prior vote excludes them.

Independents were exempted from the cut for exactly that reason. `OTH_RIGHT`
was not — and `OTH_RIGHT` is the class that won Barwon, Murray and Orange in
2019, Mirani in 2020 and four South Australian seats in 2026.

Roy Butler is the case. The Shooters polled **2.50%** in Barwon in 2015, below
the independents' 16.9% and the Greens' 6.2%. He ranked third, was never
queried, and then won the seat with 33.0%. The corpus held Barwon's two
independents and two majors and not the winner.

The scale of it, measured across the 22 corpus elections:

| | in corpus | missing |
|---|--:|--:|
| non-major candidates | 4,192 | 5,675 |
| **`OTH_RIGHT`** | **842** | **2,024 (71%)** |
| non-major WINNERS | 99 | **16** |

Seven of the eleven largest missing winners are `OTH_RIGHT`, including Robbie
Katter (Traeger, 58.9%), Shane Knuth (Hill, 52.6%), Philip Donato (Orange,
49.1%), Nick Dametto (Hinchinbrook, 42.5%) and Helen Dalton (Murray, 38.8%).

**The class the model keeps losing to was the least-covered class in the signal
built to catch it.** Fixed: `OTH_RIGHT` is now exempt from the prior-vote cut,
on the same reasoning already written down for independents.

## Finding 2, not fixable here: Google Trends cannot see rural candidates

nsw2019 was refetched first, and all three Shooters winners are now in the
corpus. It does not help:

| candidate | seat | vote | jump |
|---|---|--:|--:|
| Philip Donato | Orange | 49.1% | **0.0000** |
| Helen Dalton | Murray | 38.8% | 0.0129 |
| Roy Butler | Barwon | 33.0% | **0.0000** |

Two of the three register **zero** measurable search interest in the
pre-election window, having won their seats. 88% of that election's candidates
are at zero and the maximum jump in the whole election is 0.04.

Now look at who does register in nsw2019:

| candidate | seat | jump |
|---|---|--:|
| Alex Greenwich | Sydney | 0.0441 |
| Jenny Leong | Newtown | 0.0214 |
| Jamie Parker | Balmain | 0.0194 |
| Dai Le | Cabramatta | 0.0179 |
| Greg Piper | Lake Macquarie | 0.0169 |

Every one metropolitan or peri-urban. **The seats this model loses are rural** —
Barwon, Murray, Orange, Shepparton, Mirani, Kalgoorlie — and Google Trends
floors low-volume search terms at zero, so a candidate in a small country
electorate is indistinguishable from a candidate nobody has heard of.

This is a property of the source, not of our wiring, and it bounds what any
salience arm can achieve. Suzanna Sheed is the exception that fits the rule:
Shepparton is a regional city of about 50,000, big enough to generate volume,
and her jump is 0.164 — the highest in her seat by a distance.

**So the emergence problem splits in two.** Where there is search volume,
salience sees it and the expected-primary and expected-variance arms are the
right response. Where there is not — most of rural Australia — a different
signal is needed, and search interest will never be it.

## What follows

- The coverage fix stands on its own: the corpus is now honest about who it
  contains, and a zero is now a measured zero rather than a candidate nobody
  asked about.
- A full refetch across all 22 elections is queued. It will add real signal in
  urban seats and confirm zeros in rural ones.
- Barwon and Orange are NOT fixable by salience. They need a mechanism that
  does not depend on national search volume — the candidate-count and
  nomination data already flagged for after Victorian nominations close, or the
  minor-party-momentum idea, are the candidates.
