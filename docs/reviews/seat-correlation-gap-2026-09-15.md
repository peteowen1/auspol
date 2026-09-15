# The simulation draws every seat independently, and the data says it should not

2026-09-15. Pete's observation, in his words: *"if two regions with very similar
demographics - if one of them swings to ONP then the other one is way more
likely too as well - we need the sim to account for this and all the other
within seat correlations."*

He is right, it is measurable, and it is a gap in the published forecast.

## What the simulation does today

`src/seat_sim_core.cpp`, the per-draw core of `simulate_seat_contests()`:

```cpp
shift[k] = y[k] * sd_vec[k];        // statewide, SHARED by every seat
...
const double e = R::rnorm(0.0, sdc[k]);   // per seat, INDEPENDENT
v[k] = base[k] + shift[k] + e;
```

So there are exactly two levels:

| level | correlated? |
|---|---|
| statewide shift, party x party | YES -- `chol_t`, `AUSPOL_PARTY_COR="shrunk"` |
| per-seat deviation, seat x seat | **NO -- i.i.d. across seats** |

Every seat moves together through `shift[k]`, and beyond that each seat is an
independent coin. Two demographically identical seats are as unrelated as a
Melbourne inner-city seat and a Mallee farming seat.

## The measurement

Out-of-fold residuals (`actual_share - xgb_pred`), standardised WITHIN each
(election, class) so elections of different volatility contribute on the same
scale. For every pair of seats in the same election, the product of their
standardised residuals IS their correlation contribution. Binned by Euclidean
distance in the seven z-scored census columns, ~107,000 seat-pairs per bin:

| similarity bin | mean demographic distance | correlation |
|---|--:|--:|
| 1 (most similar) | 1.30 | **+0.0603** |
| 2 | 2.18 | +0.0134 |
| 3 | 2.97 | -0.0171 |
| 4 | 3.96 | -0.0377 |
| 5 (least similar) | 6.06 | **-0.0623** |

Monotone in five of five bins. Similar-minus-dissimilar gap, by class:

| class | similar | dissimilar | gap |
|---|--:|--:|--:|
| ONP | +0.0651 | -0.0902 | **+0.1553** |
| GRN | +0.0693 | -0.0839 | +0.1532 |
| ALP | +0.0808 | -0.0687 | +0.1494 |
| OTH_RIGHT | +0.0603 | -0.0531 | +0.1134 |
| LNP | +0.0266 | -0.0201 | +0.0467 |

The standardisation pins the average across ALL pairs near zero by
construction, so the level of any single bin is not the quantity of interest --
the GRADIENT is, and it is unambiguous.

## What it costs

For a party whose competitive seats are demographically alike -- which is
exactly One Nation's situation, and the Greens' -- the seats it can win sit in
bin 1 with each other. Treating `n` such seats as independent understates the
spread of the seat COUNT by about

```
sqrt(1 + (n - 1) * rho)   =   sqrt(1 + 19 * 0.06)   ~   1.5x   at n = 20
```

Each seat's own marginal probability can be perfectly calibrated while the
distribution of the TOTAL is roughly a third too narrow. "One Nation wins zero
seats" and "One Nation wins twelve" are both under-weighted, and those are the
outcomes a forecast exists to price.

This is consistent with a known symptom: the calibration slope runs well above
1 in several pairs (vic2018 2.61, vic2014 1.70, fed2022 1.57), which is what
over-confidence looks like.

## Two failed measurements, recorded so they are not repeated

Both were attempts to quantify the cost directly on each party's own top 20
seats, and both were broken in ways the output made obvious:

1. **Standardising within the 20-seat subset** forces `sum(rz) = 0` and
   therefore a mean pairwise product of exactly `-1/(n-1)`. Every row of the
   table printed `-0.0500`. The statistic could only ever return one number.
2. **Standardising on the whole election but not re-centring** made the
   statistic `mean(rz)^2 + covariance`, dominated by the subset's shared BIAS.
   It returned "correlations" of 2.43 and 1.40, which are impossible.

The bin analysis above is unaffected -- it standardises within (election,
class) and uses all pairs, so no subset mean is being smuggled in.

## What this does NOT establish

- **Proximity and historical swing correlation are untested.** Pete named all
  three inputs; only demographics has been measured. Two seats can be
  demographically alike and hundreds of kilometres apart.
- **Whether a factor model recovers it.** A measured correlation gradient is
  not a fitted covariance, and the fit has to be leakage-free and stable.
- **The effect on seat log loss.** Correlation mostly moves the seat-COUNT
  distribution; per-seat marginal probabilities move much less, so the repo's
  primary metric may barely see this. That is a criterion-design problem to
  solve BEFORE a pre-registration, not after -- `CLAUDE.md` records two arms
  refused by metrics that could not see them.

## The second thing Pete said, which reframes an earlier finding

*"demographics voting a certain way will change over time - we need to try and
track that - using polling and using elections."*

Earlier the same day I measured that roughly 85-90% of the within-election
demographic relationship does not transfer between elections (in-sample R2
0.437 on sa2026 One Nation against +1.84% pooled out-of-fold error reduction),
and I described it as untransferable. **An election-specific coefficient is a
time-varying coefficient.** Treating the drift as noise is a modelling choice I
made without noticing I had made it, and it is probably wrong: a coefficient
that moves smoothly is trackable, and polls carry information about where it
has moved to.

Both of these are in `docs/PETE-ASKED-FOR.md` as NOT DONE.
