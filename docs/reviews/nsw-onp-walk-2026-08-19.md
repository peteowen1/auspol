# NSW's One Nation lags because the party that moved most is the only one denied its own volatility

Measured 2026-08-19. **Nothing changed.** A fix needs a pre-registration.

## The symptom

`NL3` breaches and keeps the scheduled job red: NSW 2027 fits One Nation at
**19.52** against **24.67** over the last 90 days of polling, a gap of 5.15
against a bound of 2.5.

## The series

Every NSW poll naming One Nation this cycle:

| date | firm | ONP |
|---|---|---:|
| 2025-12-01 | Redbridge | 4 |
| 2025-12-14 | Spectre | 16 |
| 2026-02-18 | SMS Morgan | 30 |
| 2026-02-28 | DemosAU | 21 |
| 2026-03-12 | ResolvePM | 23 |
| 2026-05-01 | ResolvePM | 22 |
| 2026-06-17 | DemosAU | 27 |
| 2026-07-01 | ResolvePM | 25 |

Four to thirty in eleven weeks, then flat in the low-to-mid twenties for five
months. **The fitted endpoint of 19.52 is below every poll taken since
February.** That is a lag, not a judgement about where the party will land.

## The cause

`fit_nsw.R:132` decides which parties get their own per-cycle volatility:

```r
ps <- intersect(names(cnt)[cnt >= 15], est_parties)
```

One Nation has **8** polls in the cycle, so it fails the 15-poll floor — and
`est_parties` needs 20 pooled across completed cycles, which it also fails. It
is therefore the one party in the cycle fitted with the **generic default random
walk**, and that default is calibrated on parties that do not move twenty points
in three months.

The per-cycle sigma table confirms it. ALP, GRN, LNP and OTH each get their own
`rw_cycle`; One Nation has no row at all:

| year | party | n | rw_pooled | rw_cycle |
|---|---|---:|---:|---:|
| 2027 | ALP | 28 | 0.2749 | 0.2873 |
| 2027 | GRN | 28 | 0.0377 | 0.0480 |
| 2027 | LNP | 28 | 0.2423 | 0.2601 |
| 2027 | OTH | 28 | 0.2935 | 0.3217 |
| 2027 | **ONP** | **8** | — | **absent** |

**The party whose trend most needs a fast walk is denied one**, because the test
for "can we estimate this" is poll count, and a new party is by definition
thinly polled.

To be exact: SFF and DEM also lack a per-cycle walk in this cycle. One Nation is
not uniquely denied — it is the only party denied one that is large enough and
volatile enough for it to matter, and the only one that is both asserted on and
breaching.

## Why Victoria's equivalent gap closed and this one did not

`fit_vic.R` carries a comment describing exactly this case:

> A party with enough polls in THIS cycle gets its own sigmas even if the
> completed cycles had too few to pool from — which is exactly One Nation's
> situation in Victoria (9 polls across 2018+2022, 18 in 2026).

(That comment says 18; a poll has arrived since it was written and the count is
now 19. Quoted as-is, with the drift noted, rather than silently corrected.)

Victoria's One Nation has **19** polls, clears the 15 floor, and gets a
per-cycle walk fitted to its own movement. Its gap fell from 2.78 to **2.39** as
polls accumulated and it no longer breaches. NSW's has **8**, gets the default,
and sits 5.15 out.

Same party, same surge, opposite outcomes — decided by whether the cycle
happened to cross a poll-count threshold.

## This is the T3 mechanism, and it was already open

The Others work pre-registered three causes and T3 was "the walk is too slow".
It did not fire for Others (p=0.14, sign right) and
[others-bias-2026-08-18.md](others-bias-2026-08-18.md) recorded it as open,
noting it "has never been tested on a party moving this far". This is that test
case, arriving on its own.

## Not fixed, and what a fix has to be careful about

Two directions, neither safe to bolt on:

1. **Lower the 15-poll floor for per-cycle volatility.** Direct, and estimating
   a variance from 8 points is exactly how the federal ONP hyperparameters hit
   both optimiser bounds — which `fit_nsw.R`'s own header records as the reason
   the floor exists. Lowering it re-opens that.
2. **Widen the default walk for a party far from its prior.** Keys on the right
   thing (movement, not sample size), but "far from its prior" needs a
   threshold, and choosing one after seeing that NSW breaches at 5.15 is fitting
   to the case in front of me.

Either needs its own pre-registration with a criterion that is not statewide
first-preference MAE — the same trap the last three experiments had to route
around.

**Do not relax `NL3` to clear the build.** The check is right: the fit does not
track the polls, and the reason is now known.
