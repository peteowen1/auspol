# Independents cannot win a seat, and the reason is that they are scaled like a statewide bucket

Measured 2026-08-19. **Nothing changed** — this is a finding and a proposed
direction, not a fix.

## What the model says

Across 20,000 draws of the candidate-level Victorian simulation, independents
win **0 seats**, 90% interval **0–0**. They carry a win probability above zero
in **3 of 88 seats**, the largest being Hawthorn at **2e-04**.

The seats where that is hardest to believe:

| seat | IND first prefs 2022 | model's win probabilities 2026 |
|---|---:|---|
| **Mildura** | **41.2%** | LNP 0.991, ONP 0.009 — **IND absent** |
| **Shepparton** | **29.4%** | LNP 1.000 — **IND absent** |
| Benambra | 31.7% | LNP 0.998, ONP 0.002 |
| South-West Coast | 25.9% | LNP 0.996, ONP 0.004 |

An independent who took 41.2% of first preferences in Mildura three years ago
has, in this model, no path to the seat at all.

## It is not a data gap

The 2022 first preferences are loaded correctly. Independents appear in **69 of
87 seats**, nine of them at 15% or more, and they out-polled One Nation in **68
of 87**. The candidates are there; the model discards them downstream.

## The mechanism

`fit_seats_full.R` divides the seven seat-level classes into the five the trend
models (ALP, LNP, GRN, ONP, OTH) and two it does not (**IND**, OTH_RIGHT). The
unmodelled two are scaled to the forecast `OTH` total:

```
minor field scaled x0.65: IND+OTH_RIGHT+OTH at 2022 16.9% -> forecast 10.9%
```

Meanwhile One Nation is projected separately from **0.22%** statewide in 2022 to
roughly **20%** now, and allocated across seats by Greens share.

Put together, in Mildura:

| | 2022 | projected 2026 |
|---|---:|---:|
| IND | 41.2 | **25.2** |
| ONP | ~0 | **31.1** |
| LNP | — | 37.1 |
| ALP | — | 0.0 |

The independent falls to **third**, is excluded during the count, and their
preferences are distributed to somebody else. That is why the win probability is
not merely small but absent.

**A strong local independent is not a statewide minor-party bucket.** Their vote
is personal and seat-specific — that is what makes them independent — and
scaling it by the ratio of two statewide aggregates is a category error. The
`OTH` forecast falling from 16.9 to 10.9 says nothing about whether Mildura's
member is still popular in Mildura.

## What makes it worse

The number doing the displacing is the one the model is least sure of.
`fit_seats_full.R`'s own comment says of the One Nation seat allocation:

> Its allocation is the weakest part of this model and is documented and checked
> separately … trust the ONP TOTAL, not any one seat.

Yet that per-seat allocation is what pushes independents out of the final two in
exactly the regional seats where they are strongest. A quantity the code
explicitly says not to trust seat-by-seat is deciding seat-by-seat outcomes.

## A second, smaller thing found on the way

Primaries are projected by a uniform ADDITIVE swing with `pmax(0, ...)`. Labor's
statewide primary falls about 12 points, so any seat where Labor polled under
12% in 2022 is projected to **exactly zero**. That is Mildura (0.0) and
Shepparton (0.0), and Benambra is 1.0.

Only two seats, so the effect on the forecast is small — but a projected primary
of exactly 0.0% for a major party is not a plausible quantity, and `pmax()`
silently absorbing it means nothing reports that it happened.

## Not fixed here, and what a fix would need

This needs a pre-registration before anything is built, and the obvious repair
is not obviously right:

- **Do not scale a seat's independent vote by the statewide `OTH` ratio.** A
  candidate-specific vote should be projected on its own terms — most simply, by
  carrying the 2022 seat share forward unscaled, or with a decay estimated from
  how independent votes have actually persisted between elections.
- **The competing claim to test against it:** a personal vote often collapses
  when the sitting independent retires, so carrying it forward unchanged would
  over-call the seats where they have gone. That is a real effect and the fix
  must not assume it away.
- **The criterion cannot be statewide first-preference MAE**, which is what the
  last two experiments used. Independents are 5.5% of the statewide vote and the
  question is entirely about *which seats they win*. Scoring this on a statewide
  aggregate would repeat the mistake the inclusion-floor experiment made, where
  the criterion could not see the thing that decided the answer.

Whether Victoria elects any independents in 2026 is genuinely uncertain — the
two who held Mildura and Shepparton both lost in 2022. **Zero is a defensible
forecast. Zero by construction is not**, and that is what this is.
