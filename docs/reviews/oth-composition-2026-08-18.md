# The OTH bucket varies enormously between seats — and it does not matter yet

Measured 2026-08-18 from the Victorian 2022 candidate-level data
([vic-preference-flows-2026-08-18.md](vic-preference-flows-2026-08-18.md)).

## What the model does

`derive_tpp()` gives everything outside ALP/LNP/GRN/ONP a single preference
flow. For Victoria 2026 that is **48.872**, one number for the whole bucket.

## What the components actually do

Measured in the two-party configuration (excluded with Labor and the Coalition
remaining):

| component | to ALP | n | ballots |
|---|---:|---:|---:|
| independents | **61.1** | 5 | 47,949 |
| minor-right (Family First, Freedom, Lib Dems, DLP …) | **35.4** | 2 | 9,169 |
| left-leaning minors (Cannabis, Animal Justice, Socialists …) | **unmeasurable** | — | — |

The left bloc has **no** two-party cell: those candidates are never the last
excluded in a Labor-versus-Coalition contest, so their ballots always merge
into another pile before the final count. Aggregate distribution tables carry
no vote provenance, which is the same limit that killed the SA attempt.

`n = 2` on minor-right is thin; the direction is far better established than
the magnitude.

## Composition varies hugely between seats

Across 87 districts, within the bucket:

| | mean | sd | range |
|---|---:|---:|---:|
| bucket as share of the seat's vote | 17.1% | 7.6 | 5.6 – 46.2 |
| independents' share **of the bucket** | 26.3% | **25.3** | 0 – 89.2 |
| minor-right share of the bucket | 42.8% | 21.9 | 6.7 – 87.0 |

Applying the measured component flows (and the model's own 48.9 for the
unmeasured left bloc), the bucket's implied two-party flow per seat:

**mean 46.3, sd 5.6, range 37.1 – 58.7.** The model uses 48.872 everywhere.

| lowest implied flow | | highest implied flow | |
|---|---:|---|---:|
| Gippsland East | 37.1 | Kew | 58.7 |
| Ovens Valley | 37.3 | Mildura | 58.6 |
| Dandenong | 37.6 | South-West Coast | 58.4 |

Mildura is the extreme case: an OTH bucket worth **46.2%** of the seat's vote,
implied flow 58.6 against an assumed 48.9 — a 9.7-point flow error on nearly
half the seat's ballots.

## Why this does not currently affect anything published

**It does not touch the seat model.** `simulate_seats()` works from
`fTppMargin` (`R/seats.R:51`), the notional two-party margin the anchor takes
from the actual count. Per-seat preference behaviour is already baked into
those margins by the people who counted the votes. Our flow estimate is never
applied per seat.

**Statewide, the effect is probably small and is not knowable yet.** The one
place the OTH flow is used is `derive_tpp()`, converting statewide first
preferences to a statewide two-party figure. Only the statewide-weighted
composition matters there, and 48.872 is a historical blend of exactly that.
It would be wrong only if 2026's composition differs materially from the
average of the elections it was estimated from — and Victorian nominations are
not in (`2026vic.txt` has no `sRunningParties`), so the 2026 composition is
unknown.

**No sizing is offered.** Three sizings tonight were computed before the
mechanism was understood and two of them were wrong. The composition-weighted
statewide effect cannot be computed without the 2026 field, and inventing a
figure for it would repeat the error.

## Where it will bite

The primary-vote seat rebuild. That computes each seat's two-party figure
**from primaries and flows** rather than reading a notional margin from the
anchor, which is precisely the calculation the per-seat spread above breaks.
A rebuild applying 48.872 to Mildura would be wrong by around 4.5 points of
seat two-party vote.

So this is a **prerequisite for the rebuild, not a defect in the current
model** — and the rebuild needs an independent class, which the model does not
have. The 2026 seat file already lists an independent as the expected
challenger in South-West Coast, one of the three most independent-leaning seats
in the state.
