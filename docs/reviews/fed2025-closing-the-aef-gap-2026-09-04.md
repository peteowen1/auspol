# Trying to beat AE Forecasts on fed2025: one win, five dead ends, and why the rest needs data

2026-09-04. Goal set by Pete: *optimise until seat log loss is better than AEF
for fed2025 — optimise parameters and implement any untested ideas.*

**Not achieved. 0.3597 against AEF's 0.3025**, from a starting 0.3663. The gap
narrowed by about 10%. This records what was tried, because four of the six
things tested are now measured dead ends and should not be re-run.

All numbers: fed2025, forecast mode, published config
(`AUSPOL_SHRINK=0.10 AUSPOL_DEV_SLOPE_MODE=screened`).

## Where the loss is

Concentrated, not diffuse. Mean log-loss gap by our predicted party: ALP 0.058,
LNP 0.059, GRN 0.106, IND 0.241. The individual misses are almost all seats a
sitting independent held and retained:

| seat | actual | ours | AEF |
|---|---|--:|--:|
| Mackellar | IND | 0.40 | 0.75 |
| Wentworth | IND | 0.46 | 0.83 |
| Kooyong | IND | 0.37 | 0.60 |
| Curtin | IND | 0.36 | 0.63 |
| Mayo | IND | 0.13 | 0.84 |

Against an empirical base rate: a non-major MP who personally re-contests
**holds 82.7% of the time** (43 of 52, across 10 election pairs), and their vote
barely moves (mean change −0.13 points). When the person does NOT re-contest:
33.3% hold, vote falls 27.8 points.

## What worked

**A sitting-member slope tier.** `conditional_slopes()` pooled a returning
MEMBER with a returning also-ran. Measured separately over 531 returning
non-major candidacies across 10 election pairs:

| group | n | slope | se |
|---|--:|--:|--:|
| returning, WAS the sitting MP | 52 | **0.954** | 0.026 |
| returning, was NOT the MP | 479 | **0.800** | 0.046 |
| pooled (what shipped) | 531 | 0.924 | 0.021 |

2.9 SE apart. Pooling shrinks an entrenched independent toward a ~5% statewide
IND average every cycle — a teal on 36% projects to 33.1 when the measured
expectation is flat. Shipped behind `AUSPOL_MP_SLOPE=1`, off by default.

All four metrics improve: log loss 0.3663 → **0.3597**, Brier 0.1128 →
**0.1104**, accuracy 82.6% → **83.2%**, calibration slope 1.476 → **1.397**.

## What did not — five measured dead ends

**1. Missing flow cells for teal contests.** Hypothesised that `GRN|IND+LNP`
was absent and fell back to a pooled row that sends only 22% to the
independent. **Wrong**: zero rounds in the real data have GRN excluded with
only IND+LNP surviving — in a teal seat the Greens go out while Labor is still
standing, which uses `GRN|ALP+IND+LNP` (IND 51.4%, ALP 39.4%, LNP 9.2%), then
`ALP|IND+LNP` (IND 76.3%). Both cells exist and are right.

**2. Compositional per-seat noise.** The per-seat shock is K independent draws
never renormalised, so a seat's shares stop summing to 100. Renormalising is
**provably a no-op**: scaling every party by one constant cannot change a
preferential count. Implemented, measured identical to 3 decimal places,
reverted. (A sum-to-zero constraint is also useless here — it leaves the
pairwise margin variance at exactly 2σ², unchanged.)

**3. `seat_sd` too wide.** `prereg-seat-calibration.md` only ever swept
seat_sd UPWARD (1.0–2.0×). Swept it DOWN for the first time: log loss gets
monotonically **worse** — 0.3607 at 3.27, 0.3675 at 1.5, 0.3817 at 0.5.
Accuracy rises as it narrows (83.9 → 85.9) while log loss falls apart, i.e.
narrowing buys right answers at the cost of catastrophic confident misses.
The shipped value is already optimal in both directions.

**4. The displaced major is over-projected.** In seats a returning non-major MP
defends, does the major runner-up beat uniform swing? Mean excess **+1.04
points, t = 1.20** over 122 rows; for the runner-up specifically −0.53,
t = −0.85. Not significant. The 3–5 point over-projection visible in three teal
seats is noise.

**5. Per-seat elasticity** — the component named in
`aef-primaries-and-elasticity-2026-08-25.md` as the concept AEF has and we lack.
Estimated each seat's amplification of the statewide swing over six federal
pairs (886 seat-pair estimates, mean 0.99, sd 1.72), then tested whether it
**persists**: does a seat's elasticity in earlier pairs predict the next?

**Correlation −0.068. R² 0.005. Slope −0.152 (t = −1.84).**

It does not persist — if anything it mean-reverts. Per-seat elasticity as
estimable from this corpus is noise, and adding it would add variance with no
signal. Consistent with AEF's own SA output, where the elasticity term was
0.000 in all four seats examined.

## Why the rest of the gap is not a parameter problem

The decisive measurement. Our projection's realised residual sd on fed2025,
against the sd the model assumes (`level_sd = 1.10 + 8.67·√(p(1−p))`):

| group | n | realised resid sd | assumed sd |
|---|--:|--:|--:|
| sitting MPs, share > 20% | 126 | 4.52 | 5.35 |
| non-sitting, share > 20% | 168 | 5.56 | 5.00 |
| **non-major sitting MPs** | 17 | **7.75** | 5.06 |

For the exact seats where we lose to AEF, our projections are **worse than the
model assumes**, not better. The ~40% we give a teal is therefore roughly
honest given our own projection quality. Narrowing their uncertainty to buy
log loss would make the model confidently wrong; that is the failure mode
`shrink` exists to prevent, not to create.

So the remaining 0.057 is **discrimination**, exactly as
`seat-calibration-2026-08-22.md` concluded — and closing it requires better
seat-level information, not better-tuned parameters. AEF has seat polling and a
ten-component swing decomposition; we have a statewide trend and seat history.

**What was deliberately not done**: tuning knobs on a single 149-seat election
until the number crossed 0.3025. Every lever above was checked against multiple
elections or a persistence test first, and the one that shipped is justified on
531 observations across 10 election pairs rather than on fed2025. A win
manufactured on one election is the failure this repo's pre-registration
culture exists to prevent, and it would not survive contact with Victoria 2026.

## What would actually be next

Not another parameter. Candidate-level information the model does not yet
carry: sophomore surge, retirement effects, and the incumbent's own margin
history — the components AEF names that are NOT elasticity, since elasticity is
now measured as non-persistent here. Each needs its own pre-registration and
its own held-out test.
