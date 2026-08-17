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

## Round 2: the link function was the problem, and fixing it works

Run against [../plans/prereg-onp-allocation-round2.md](../plans/prereg-onp-allocation-round2.md),
committed as `34e0f38` before the run. Criterion: leave-one-seat-out CV MAE,
46 districts, statewide total known.

| Candidate | LOO MAE | LOO RMSE | corr |
|---|---:|---:|---:|
| **A. linear on 2022 minor-right** | **4.171** | 5.235 | 0.712 |
| B. linear on 2022 LNP share | 6.329 | 7.736 | −0.006 |
| C. linear on both | 4.344 | 5.362 | 0.696 |
| D. uniform | 6.306 | 7.452 | — |

**A wins by 2.135 MAE points over uniform — clears the 1.0 bar.** A and C fall
within 0.5 of each other, so decision rule 3 (fewer predictors) selects **A**.

A useful consistency check: round 1 predicted MAE ≈ 4.1 for a linear form from
the correlation alone, before any model was fitted. The realised 4.171 matches.

Full-sample form: `ONP_seat = 14.71 + 1.21 × minor_right_2022`, adjusted
R² 0.529. The large intercept says most of the ONP vote is a flat statewide
base, which is why uniform was a respectable baseline at all; the slope adds
the geography.

**B is a clean negative result and worth keeping.** "The One Nation surge came
out of the Liberal vote" is true statewide — LNP fell 36.15 → 19.05 while ONP
rose 2.63 → 22.88 — and carries **no seat-level information whatever**:
LOO correlation −0.006, adjusted R² 0.036, coefficient p = 0.11. A mechanism
that is real in aggregate can be worth exactly zero per unit.

Worst residuals under A: Narungga −12.4, Bragg +11.8, Heysen +9.7,
Flinders −8.9, Dunstan +8.6.

## Transfer to Victoria: better than SA, not worse

Round 1 recorded a worry that Victoria's near-zero 2022 One Nation vote would
leave the predictor with nothing to work with. **Measured, that worry was
wrong** — because the predictor is the whole minor-right bloc, not One Nation
alone.

Anchor check on the Victorian parse first: ALP 36.66, GRN 11.50, ONP 0.28 all
reproduce Wikipedia's published totals exactly; LNP 34.48 against 34.49 for
Liberal plus Nationals. **Passes.**

| | Victoria 2022 | SA 2022 |
|---|---:|---:|
| statewide minor-right | 5.79% | 6.64% |
| per-seat mean | 5.84 | 6.71 |
| per-seat sd | 3.54 | 4.57 |
| seats with no minor-right candidate | **0 of 88** | 9 of 47 |

Victoria has slightly less spread but **no structural zeros at all**, which was
the single largest source of error in round 1. And the geography is the
expected one: highest are Narracan 18.58, Ovens Valley 15.67, Morwell 14.66,
Narre Warren South 13.63, Dandenong 13.06 — regional and outer-southeastern.
Lowest are Richmond 1.15, Brunswick 1.22, Brighton 1.35, Malvern 1.53,
Prahran 1.60 — inner Melbourne.

## A flaw in the round-2 pre-registration, stated rather than patched

Decision rule 4 said the winning form would be "re-estimated on Victorian
data". **That is not executable** — Victoria 2026 has no outcome, which is the
entire reason SA was used. The rule as written cannot be followed.

The workable substitute is to transfer the *shape* and fix the *level* from our
own forecast: predict each Victorian seat from its 2022 minor-right share using
SA's slope, then rescale so the vote-weighted statewide prediction equals the
Victorian ONP figure the trend model already produces (20.9%). That borrows one
number — the slope — from a different state's party system.

That is a real assumption and it should be an explicit decision, not something
absorbed silently while implementing. Flagged for Pete.

## Sizing: the allocation is the small half. The structure is the big half.

The improvement above is on ONP first preference per seat; the published output
is the ALP seat count. Sizing that, first-pass and deterministic — 2022
Victorian seat primaries, uniform statewide swings to the current forecast
(ALP 25.4, LNP 28.6, ONP 20.9, GRN 12.9, OTH 10.5), ONP set two ways, no
simulation noise and no preferences distributed.

**A free result found while doing it: Victoria did not redistribute.** All 88
district names in `2026vic.txt` match the 2022 results exactly — no seat added,
renamed or dropped. So 2022 seat primaries apply directly, with none of the
notional-boundary reconstruction that cost SA a district and added error to
every estimate there. This is the single biggest practical difference between
the Victorian job and the SA one.

**Seats where each party reaches the final two** (of 88; `OTH` excluded from
the contender set because it is a bucket of many separate candidates, not one
contender):

| Party | ONP uniform | ONP allocated |
|---|---:|---:|
| ALP | 64 | 65 |
| LNP | 66 | 59 |
| **ONP** | **39** | **44** |
| GRN | 7 | 8 |

Three things follow, and the order matters.

1. **The current model's central assumption fails in about a quarter of the
   chamber.** The TPP seat model assumes Labor is in the final two everywhere.
   Here it is not, in **23–24 of 88 seats**.
2. **One Nation is a final-two contender in roughly half the chamber** — 39 to
   44 seats — a contest the model cannot currently represent anywhere.
3. **Allocation is the second-order part.** The final-two pair differs between
   the uniform and allocated scenarios in **15 of 88** seats. Real, but the
   structural change — simulating primaries at all — is two and a half times
   larger. Round 2's 2.1-point MAE gain buys those 15 seats; it does not buy
   the other ~40.

So the answer to "is this correctness work or accuracy work" is: **the
structure is accuracy work, and larger than expected.** The allocation refines
it.

**One Nation leads on primaries in zero seats under either scenario.** Every
potential ONP seat win therefore depends entirely on preferences, which makes
the preference stage — not the allocation — the thing that decides whether
they win 0 seats or 15.

## Caveats on the sizing, none of which are small

- **Deterministic.** No simulation noise and no preferences distributed. This
  counts who is in the final two, not who wins. It cannot be read as a seat
  count.
- **Uniform swing on 2022 seat primaries.** Real per-seat swings vary, and
  that variation is the part already measured as unforecastable.
- **The SA slope is transferred**, per the flaw noted above.
- **Narracan's 2022 election failed** — the National candidate died and a
  supplementary election was held on 28 January 2023, which Labor did not
  contest. Its row therefore shows ALP 0.0 and an unusual minor field, and it
  sits at the top of the Victorian minor-right list at 18.58. Excluding it
  moves the per-seat minor-right sd from 3.54 to 3.29 and the max to 15.67
  (Ovens Valley). Immaterial to the conclusion, but the seat needs handling.

## The preference stage cannot be built from the data in this repo

`preference-estimates.csv` records **one number per party per election: the
share flowing to ALP** (`R/load_polls.R:119-134`). `derive_tpp()`
(`R/tpp.R:23-71`) uses it in a single step, which is all a two-party model
needs.

A sequential elimination needs more than that. When a minor-right party is
excluded in a seat where **both LNP and ONP are still standing**, the file is
silent on how its preferences split between them — and that is precisely the
quantity that decides whether One Nation converts final-two placings into
seats. The data we hold cannot answer the question the seat model exists to
ask.

**Available sources, both partial:**

- Wikipedia carries full round-by-round distribution tables for **17 of 47**
  SA 2026 districts and **0 of 88** Victorian 2022 ones. The 17 are likely the
  close and interesting seats, so estimating a flow matrix from them would be
  selection-biased in exactly the seats where preference behaviour is least
  typical.
- ECSA and the VEC both publish complete distributions per seat — the VEC's
  district pages carry a "Distributions" link. That is the real source, and a
  separate scrape from the first-preference one.

## Sizing whether the matrix matters, before recommending that acquisition

Parameterise the unknown as **theta**: the share of an excluded party's
non-Labor preferences going to ONP when ONP survives, with the remainder split
among other survivors in proportion to their tallies. Sweep it, using the
Victorian flows the model already estimates (GRN 83.5, ONP 33.7, OTH 48.9).

| theta | ALP | LNP | GRN | ONP |
|---:|---:|---:|---:|---:|
| 0.0 | 47 | 34 | 5 | **0** |
| 0.3 | 49 | 32 | 5 | **0** |
| 0.5 | 49 | 32 | 5 | **0** |
| 0.6 | 51 | 29 | 5 | **2** |
| 0.7 | 52 | 25 | 5 | **5** |
| 1.0 | 52 | 22 | 4 | **9** |

**One Nation wins nothing until minor-right preferences favour it over the
Liberals by better than about 55/45, then rises to 9 seats at the extreme.**
That is a genuinely useful bound: the matrix matters, but over a narrower range
than "ONP contends in 44 seats" suggested.

## The harness does not reproduce the published baseline, so trust the shape and not the level

**ALP wins 47–52 seats here against a published figure of 39.** That gap is
the anchor check failing, and it is reported rather than explained away.

(This section first said 35, taken from `NEXT-STEPS.md`, which was itself
stale — the published median is 39, with 50% 33–45, 90% 23–51 and P(majority)
26%, per `output/vic-page-data.json`. Caught in review on 2026-08-17 and
corrected in both places. Quoting a hub instead of the artefact is how a stale
number propagates.)

Measured cause, in part: the implied statewide ALP two-party from these
primaries and flows is **49.19** against the published **47.8** — the harness
runs **1.39 points hot for Labor**. On a pendulum where Victorian Labor seats
bunch between 54 and 60, a point and a half of two-party vote moves a great
many seats at once. The rest of the gap is that this sweep is deterministic
with no seat noise, no regional effects and no projection uncertainty, and
applies uniform swings to 2022 primaries rather than using the notional
margins the real model uses.

**This repo has been bitten by exactly this before** — recorded under the
2026-08-16 lessons: *"A sensitivity sweep on a simplified harness predicted the
wrong sign. It ran `fit_cycle_trends` bare while the pipeline has firm factors,
the fold correction and estimated sigmas. A stripped-down harness is not the
model."* The same caution applies here and for the same reason.

So: the **shape** — flat at zero below theta ≈ 0.5, rising after — is worth
acting on. The **counts** are not. And because the harness is hot for Labor it
is correspondingly cold for LNP and ONP, which means 0–9 is more likely a floor
than a ceiling.

## Theta measured: 0.348, which is below the threshold

**Two corrections to the plan as stated above, both of which changed the
target.**

First, Victorian distribution data cannot answer this question. **One Nation
contested 5 of 88 Victorian districts in 2022**, averaging 4.96% where it ran.
When a minor-right party was excluded in a Victorian seat, One Nation was
almost never standing to receive anything. SA 2026 is the only Australian
election with One Nation live in the count at scale.

Second, the 17 Wikipedia distribution tables are **not** a close-seats
selection as claimed above. They are **alphabetical** — Adelaide, Badcoe,
Black, Bragg, Chaffey, Cheltenham, Colton, Croydon, Davenport, Dunstan, Elder,
Elizabeth, Enfield, Finniss, Flinders, Florey — an editor working the list and
stopping at F. Alphabetical order is arbitrary with respect to politics, so the
subset is usable.

**Estimated from 27 qualifying exclusions across 16 districts** — a minor-right
party excluded with both LNP and ONP still standing:

| | value |
|---|---:|
| vote-weighted theta | **0.348** |
| unweighted mean | 0.298 |
| median | 0.286 |
| sd | 0.155 |
| range | 0.066 – 0.526 |

Anchor check on the parse: in every exclusion, Labor's transfer plus the
non-Labor transfers reconcile **exactly** to the excluded candidate's running
total (Elizabeth 281 + 880 = 1161; Croydon 488 + 612 = 1100; Florey
141 + 664 = 805). **Passes.**

**The sweep put the threshold for One Nation winning any seat at theta ≈ 0.5.
The measured value is 0.348, and the single highest observation across 27
exclusions is 0.526.** On this evidence One Nation wins **approximately zero
seats** — it reaches the final two in roughly half the chamber and then loses
those contests on preferences.

That is the answer to the question this whole line of work was asking. Building
the primary-and-preferences model changes the **contest structure** in ~44
seats and the **seat count** by close to nothing, because Liberal-leaning minor
party voters do not preference One Nation heavily enough to get it over the
line.

"Approximately" rather than "exactly": theta's sd of 0.155 puts the threshold
about one standard deviation above the mean, so individual seats can and do
exceed it. A simulation with per-seat variation would give One Nation a small
non-zero seat expectation rather than a flat zero — which is still an
improvement on a model where the number is zero by construction and carries no
uncertainty at all.

## A separate finding worth acting on regardless

**Labor's share of these minor-right transfers is 0.203.** The model gives the
whole OTH bucket a flow of **48.9%** to Labor. Minor-right voters are inside
that bucket flowing at about 20%, which means the blended figure is wrong in
both directions depending on a seat's minor composition — too low where the
minors are left-leaning, far too high where they are not.

This affects the **published two-party number today**, not just the seat model,
and it does not depend on any of the primary-simulation work landing. It should
be sized on its own.
