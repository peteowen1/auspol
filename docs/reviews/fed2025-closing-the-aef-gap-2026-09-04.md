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

## Addendum: the IND national level, and an oracle bound that settles it

The largest single lever found. In forecast mode `IND` has no national poll
series, so it is folded into `OTH` and its level is derived from the PRIOR
election's ratio within that bucket — structurally pinned, unable to grow.

Independents nationally: 2.22, 2.52, 1.40, 4.66, 3.70, 5.54, **7.52** (2007
to 2025). They rose 36% in 2025. We forecast **5.23** — 2.3 points, 30% low,
applied to every independent in every seat, including every teal seat in the
loss table above.

Substituting different IND national levels (local sim, same config):

| IND level | log loss | accuracy |
|---|--:|--:|
| 5.23 — ours | 0.3587 | 83.9% |
| 5.68 — linear trend on pre-2025 elections only | **0.3473** | 83.9% |
| 6.50 | 0.3327 | 85.9% |
| 7.52 — the actual result (ORACLE) | **0.3225** | 85.9% |
| *AE Forecasts* | *0.3025* | *86.0%* |

Two things follow, and together they close the question.

**A real, legitimate gain of about 0.011 is available** by replacing the
prior-election pinning with a trend extrapolation that uses only information
available before the election. Worth doing on its own merits.

**And the goal is unreachable.** Even handed the TRUE national independent
vote — an oracle no forecaster has — this model scores 0.3225 against AEF's
0.3025. The remaining deficit is not the IND level, not the flow matrix, not
seat_sd, not elasticity, and not the slope tiers. It is seat-level
information this model does not carry.

That is the answer to "optimise until seat log loss beats AEF for fed2025":
it cannot be done by optimising, and the bound above is how we know rather
than assume.

## Final tally (2026-09-05)

Best honest configuration: **0.3588** on 150 seats, against **AEF 0.3025**.
Not beaten. Everything tried, in order:

| # | idea | result |
|---|---|---|
| 1 | **Sitting-member slope tier** | **SHIPPED.** 0.3663 → 0.3597 |
| 2 | **Notional baselines for new seats** | **SHIPPED.** 149 → 150 seats scored, 0.3597 → 0.3588 |
| 3 | Missing teal flow cells | dead — cells exist and are correct |
| 4 | Compositional per-seat noise | dead — provably a no-op |
| 5 | `seat_sd` narrowing | dead — monotonically worse (0.3607 → 0.3817) |
| 6 | Displaced-major bias | dead — t = 1.20 |
| 7 | Per-seat elasticity | dead — persistence r = −0.068 |
| 8 | IND trend level (generic) | dead — 0.3627, hurts OTH_RIGHT which is not trending |
| 9 | `shrink` retune under screened slopes | no gain — 0.10 already near-optimal |
| 10 | surge-v2 stacked on 1+2 | accuracy 84.7% but log loss 0.3630 — not adopted |

**The bound that closes it.** Handed the TRUE national independent vote —
an oracle no forecaster has — this model scores ~0.322. Still worse than
AEF's 0.3025. The deficit is not any parameter in this model.

**What the two shipped fixes are actually worth**, beyond the 0.0075 of log
loss: new seats are no longer silently dropped from the forecast, and
entrenched independents are no longer shrunk toward a 5% statewide average
every cycle. Both bite directly on Victoria 2026, which redistributes and
which has sitting independents.

**The goal as stated is not reachable by optimisation.** Closing the last
0.056 needs seat-level information this model does not carry — AEF has seat
polling and a ten-component swing decomposition. That is a data-acquisition
question, not a modelling one, and it should be decided as such rather than
approximated by tuning on a single 149-seat election.

## Session 2 (2026-09-05): 0.3663 -> 0.3294

Pete's redirect — *"a floor and shrink sound like rubbish hacks when we can
just model it better"*, and later *"I just want consistency and mapping and
traceable logic"* — was correct, and produced every gain below. The hacks
(uniform floor, shrink retune) all failed; the modelling and consistency work
all paid.

| change | log loss |
|---|--:|
| starting point | 0.3663 |
| sitting-member slope tier | 0.3597 |
| notional baselines for new seats (150 seats scored, not 149) | 0.3588 |
| salience-predicted national IND level | 0.3567 |
| **fix: level rescale did not survive `.own_x()`** | **0.3371** |
| draws scaled with the level (consistency; score-neutral) | 0.3370 |
| **fix: regenerate the stale `aec-fed-firstprefs.csv`** | **0.3294** |
| major-party defector floor | 0.3294 (no-op here) |

Accuracy 83.2% -> **86.0%**, level with AE Forecasts. Brier 0.1000 against
their 0.0996. AEF log loss 0.3025.

**The two biggest gains were both bugs, not models.** A re-forecast national
level was silently discarded in exactly the seats it existed to help, and the
seat model was reading a party classification the rest of the repo had
abandoned. Neither was visible in an aggregate metric; both were obvious once
the transformation chain was written out in order
(`party-level-pipeline-map-2026-09-05.md`).

### Also refused, with measurements

- **Blanket upset-hedging floor**: monotonically worse (0.3516 -> 0.4085).
  AEF hedges SELECTIVELY, which needs seat-level information.
- **shrink below 0.10**: 0.02 gives 0.3573, 0.05 gives 0.3520, 0.10 gives
  0.3502. Lowering it hurts; the 2026-08-22 value stands.
- **Raw-jump magnitude hybrid** (named as unevaluated in
  `salience-c3-v3-2026-09-04.md`): refused. For predicting WHO wins, jump
  percentile has z = 4.19 and raw jump z = 0.88. Among the 18 governed
  winners raw jump explains no more than noise (t = 1.62, n = 18): Oakeshott
  won 47.1% on jump 0.014, Steggall 43.5% on 0.913, Bowler 34.0% on 0.000.
  Raw jump is not comparable across elections, exactly as the fixed-anchor
  design anticipated. The percentile choice was correct.
- **Major-party defector history**: the McBride rule's premise ("two
  examples, no basis to fit") is outdated — there are 12 sitting-member
  defectors and retention is 0.284 (sd 0.191). But implemented correctly, as
  a FLOOR rather than a replacement, it is a no-op on fed2025. Calare is not
  a missing-history problem: the seat already carries a ~20% independent base
  from Kate Hook in 2022 and still projects only 0.122.

### Where the remaining 0.027 sits

Independents, and now specifically the MAGNITUDE of a strong emergence rather
than its detection. We beat AEF on Labor seats by 3.23 and lose 4.23 on
independents. Fowler 0.154 vs 0.682, Calare 0.122 vs 0.411, Bradfield 0.234
vs 0.521, Kennedy 0.416 vs 0.922. The teals — Mayo, Wentworth, Curtin,
Kooyong — have dropped out of the loss table entirely.

The model detects these candidates (the screen fires) and still under-projects
how far they go. Salience cannot supply the magnitude, per the refusal above.
That is the open question, and it is a modelling one, not a parameter one.

## Session 3 (2026-09-05): 0.3294 -> 0.3022, and a statistical tie

| change | log loss |
|---|--:|
| carried in from session 2 | 0.3294 |
| **availability-conditioned flow fallback** | **0.3138** |
| **defector vote ADDITIVE to its new class** | **0.3036** |
| three-seed mean at that configuration | **0.3022** |
| *AE Forecasts* | *0.3025* |

Seeds 42/43/44 give 0.3036 / 0.3023 / 0.3007. Mean 0.3022 against AEF's
0.3025 — a difference of 0.0003 against a between-seed SE of about 0.0008.
**That is a statistical tie on log loss and is not reported as a win.**
Brier IS a win: 0.0892 against 0.0996, consistent across all three seeds, as
is accuracy at 86.9% against 86.0%.

The loss profile has fully inverted. Independents now score **−1.02** and
Labor **−2.67** against AEF (this model is ahead on both). The entire
residual is Coalition seats at **+4.04**.

### Refused in session 3, with measurements

- **Superset flow cells** (matched on supersets of the alive set rather than
  exact equality): recovers the true rate in isolation — LNP with {ALP, IND}
  alive reads 71.2% against a measured 69.9% — but a wash on score once
  `pairwise` is already in place. Kept; it is more correct and costs 2.7s.
- **Per-class pooling by prior-measured volatility**: 0.3045. Refused.
- **Recent state elections as a flow source** (WA March 2025, QLD October
  2024, both before fed2025): 0.3171. Refused — jurisdiction-specific
  behaviour outweighs recency.
- **Salience as a survival signal for sitting non-major MPs**: refused, and
  it runs the WRONG WAY. Incumbents who lost had HIGHER mean salience (0.931)
  than those who held (0.837); z = −1.03, p = 0.30. Bandt lost Melbourne at
  percentile 1.00, Daniel lost Goldstein at 0.97. Salience measures
  attention, and a threatened incumbent attracts more of it — it cannot
  separate "under siege" from "safe and prominent". This closes salience as a
  route to incumbent risk.
- **Re-estimating the defector coefficient under additive semantics**:
  regression through origin gives 0.295 (se 0.051, t = 5.84) against the
  0.282 already in use. No change warranted; the parameter was already right.

### What the remaining deficit actually is

One Nation preference drift, and nothing else. ONP -> LNP was 61.6% in
fed2025 against the 51.1% our fed2022-built matrix predicts, over 1.46M
votes, in EXACT conditional cells — so it is not a conditioning failure. The
rate oscillates (47.4, 60.4, 47.6, 61.6) with whether One Nation directed
preferences to the Coalition, which is a deal decision published before
polling day in how-to-vote cards that this repo does not hold.

Three separate attempts to work around it without that data — more history,
volatility-weighted history, and contemporaneous state elections — all made
the forecast worse.
