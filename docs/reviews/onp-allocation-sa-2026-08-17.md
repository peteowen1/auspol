# Allocating a One Nation surge across seats: round 1, on SA 2026

Run 2026-08-17 against the criterion fixed in
[../plans/prereg-seat-primaries.md](../plans/prereg-seat-primaries.md),
committed as `50ae372` before any data was fetched.

## Why South Australia

Victoria 2026 cannot test this — no outcome yet. South Australia ran the same
experiment on 21 March 2026 and it is a close analogue:

| | SA 2026 actual | Vic 2026 forecast |
|---|---:|---:|
| ONP first preference | 22.9% | 20.9% |
| ONP swing | +20.3 | from 0.28% |

One Nation won 4 SA seats from nothing, while the Liberal vote collapsed from
36.15% to 19.05%.

## Data

Per-district first preferences for all 47 SA House of Assembly seats, both
2022 and 2026, parsed from Wikipedia's wikitext exports (which compile ECSA
returns). ECSA's own results site is a JavaScript application and serves no
static per-district data; there is no bulk CSV.

**Anchor check, run before looking at any result** — parsed statewide shares
against Wikipedia's published summary table:

| Party | Parsed | Published |
|---|---:|---:|
| ALP | 37.49 | 37.5 |
| ONP | 22.88 | 22.9 |
| GRN | 10.36 | 10.4 |
| LNP | 19.05 | 18.9 (Liberal only) |

LNP differs because we fold The Nationals into LNP as the model does; the rest
match to rounding. **Passes.**

Second anchor, on the geography rather than the totals: ONP's strongest seats
are Narungga 37.5, MacKillop 35.3, Light 34.5, Elizabeth 33.3 — regional and
outer-northern. Its weakest are Bragg 9.1, Unley 9.4, Adelaide 11.6 — wealthy
inner Adelaide. That is the expected One Nation geography. **Passes.**

Coverage: One Nation contested **all 47** seats in 2026, so there is no
non-contest complication. Per-seat ONP ranged **9.1 to 37.5, sd 7.53**.

46 of 47 districts match across the two elections; Ngadjuri (2026) has no 2022
counterpart and is excluded. Note that SA redistributes after every election,
so the 2022 figures are on **pre-redistribution boundaries** — a real source of
mismatch that is not corrected here.

## Result

Criterion: MAE of predicted per-seat ONP first preference, statewide total
taken as known. Bar: beat uniform allocation by ≥1.0 point.

| Baseline | MAE | RMSE | corr with truth |
|---|---:|---:|---:|
| 1. uniform (22.61 everywhere) | **6.306** | 7.452 | — |
| 2. 2022 minor-right proxy, rescaled | 9.298 | 11.253 | 0.735 |
| 3. transposed federal ONP | not run | | |

**Baseline 2 fails, by 2.99 MAE points in the wrong direction.** Per the
decision rule fixed in advance: **adopt uniform allocation.**

Baseline 3 was not run — it needs a 2025 federal division to SA district
correspondence, which was not built. Recorded as not-run rather than dropped.

## Why it failed, which is the useful part

**The predictor has real signal; the functional form destroyed it.**
Correlation with the truth is **0.735** (Spearman 0.727) — the 2022 minor-right
vote ranks seats well. Proportional rescaling is what broke:

| District | 2022 minor-right | predicted | actual | error |
|---|---:|---:|---:|---:|
| Elizabeth | 18.1 | 62.1 | 33.3 | +28.8 |
| Taylor | 16.5 | 56.6 | 34.3 | +22.3 |
| Davenport | 0.0 | 0.0 | 20.2 | −20.2 |
| Black | 0.0 | 0.0 | 18.7 | −18.7 |
| West Torrens | 0.0 | 0.0 | 18.0 | −18.0 |

Two failure modes, both structural:

1. **Structural zeros are read as certainty.** Black, Colton, Davenport,
   Hartley and West Torrens had no minor-right candidate on the 2022 ballot —
   verified against the source, not a parsing artefact. Proportional allocation
   turns "nobody stood" into "predicted 0% ONP". They delivered 16–20%.
2. **Multiplying a small base explodes.** Statewide minor-right was 6.6% in
   2022 against ONP's 22.6% in 2026, so the rescaling factor is about 3.4. A
   seat on 18.1% is projected to 62.1%, which is not a possible vote share for
   a new entrant.

Sizing what a better link function is worth, from the correlation rather than
by fitting: r = 0.735 implies R² = 0.54, so residual sd would be
7.53 × √0.46 = 5.11 and MAE about **4.1** — roughly 2.2 points better than
uniform, comfortably clear of the 1.0 bar. That is an implication of the
reported correlation, **not a fitted result**, and it is why round 2 is worth
running rather than abandoning the predictor.

## What this does not license

Fitting a linear form now and reporting it as though it had been pre-registered.
The functional form is exactly the kind of choice that, made after seeing the
answer, guarantees the answer. Round 2 is pre-registered separately in
[../plans/prereg-onp-allocation-round2.md](../plans/prereg-onp-allocation-round2.md)
and committed before it runs.

## Transfer risk to Victoria, which is worse than SA's

SA had something to work with: minor-right parties polled 6.6% statewide in
2022 and One Nation itself contested 19 of 47 seats. **Victoria 2022 gave One
Nation 0.28% statewide — 10,323 votes.** Whatever predictor survives round 2
will have a thinner base in Victoria than it had here, so the SA result is an
upper bound on how well this can be expected to work.
