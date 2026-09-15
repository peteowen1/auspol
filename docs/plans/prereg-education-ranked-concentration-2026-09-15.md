# Pre-registration: allocate a minor party's seat-level spread by education, not by tree

Written 2026-09-15, BEFORE running anything. Pete's hypothesis, arrived at by
asking why sa2026's One Nation seats were missed.

## The claim

We predict a minor party's STATEWIDE primary well and cannot say WHICH SEATS it
does best in. Two pieces already exist that together answer that, and they are
not currently combined:

- **How much** spread: the fitted concentration curve, `SD = a * statewide^k`,
  estimated leave-one-out across 16 elections (`output/onp-concentration-curve.csv`,
  R2 0.52). For sa2026 it called SD 9.18 against an actual 7.67.
- **Which seats**: Year 12 completion. Its correlation with the vote of a
  right-minor party is negative in **every** election in the corpus.

Currently the XGBoost override decides which seats, and it is measurably bad at
it: sa2026 One Nation predicted 17.9 in Narungga (actual 37.5) and 19.3 in
Bragg (actual 9.1) -- two seats 28 points apart predicted 1.4 points apart.

## What is already settled and is NOT re-tested here

- Census features as ordinary model inputs: **built, measured, refused**
  (`reviews/xgb-primary-sd-and-census-2026-09-12.md`). Raw made sa2026 ONP RMSE
  8.658 -> 9.544 and destroyed the ranking, +0.362 -> +0.057. This plan does
  NOT re-propose that. The feature is used as a RANKING inside an existing
  structural mechanism, not as a 41st column for a tree to weigh.
- The concentration curve itself: shipped, `AUSPOL_ONP_CONC_SD="auto"`.
- That the override shrinks a good input: measured, base_pred beats xgb_pred on
  sa2026 ONP by 2.65 to 3.79 MAE.

## Why a tree cannot use this and a structural rule can

The correlation is present in all 43 party-elections measured, and its
MAGNITUDE scales with the party's own level:

| ONP pair | mean vote | r with Year 12 |
|---|---|---|
| fed2019 | 3.2 | -0.365 |
| wa2025 | 3.8 | -0.506 |
| qld2020 | 7.2 | -0.594 |
| qld2024 | 8.0 | -0.657 |
| fed2022 | 4.9 | -0.669 |
| fed2025 | 6.4 | -0.757 |
| sa2026 | 23.0 | **-0.922** |

Averaged over a corpus where the party usually polls 3-8%, a tree learns a
muted version and applies it uniformly. It has no way to know the relationship
should be worth three times as much at 23%. That is an INTERACTION with the
party's own statewide level, and the corpus contains one example of that level
-- so it must be imposed, not learned.

## The estimand

For a party class and election, given the statewide level `L` and the fitted
concentration `SD(L)`: assign each seat a predicted share by ranking seats on
`yr12_pct` (within the election, so the corpus-wide drift from 51.4 to 60.8
mean Year 12 cannot leak across pairs) and spreading the predictions along that
ranking to hit `SD(L)`, centred on `L`.

Applies to classes whose education correlation is established in sign:
`ONP`, `OTH_RIGHT` (negative), `GRN` (positive). NOT `IND` -- its sign is
inconsistent across elections (-0.357 to +0.240) and it is excluded here rather
than fitted afterwards.

## Criterion, fixed now

**Primary, and named before running: qld2020 and fed2013 OTH_RIGHT.** These are
right-minor parties above the corpus norm (qld2020 ONP 7.2% with r -0.594;
fed2013 OTH_RIGHT 9.9% with r -0.490) and NEITHER is the case that motivated
this. Metric: per-seat primary RMSE for that class, against the shipped arm.

**Adopt if** both improve, and the pooled primary RMSE across all 23 pairs does
not worsen by more than 0.02.

**sa2026 is scored LAST and is confirmation, not evidence.** Every observation
motivating this plan came from it. If sa2026 improves and the two primary
targets do not, the answer is NO.

## Refusal: what would make an apparent win unacceptable

- **If it works only where the party is large.** Check qld2020 (7.2%) and
  wa2025 (3.8%) separately. A rule that helps surges and hurts ordinary
  elections is a surge detector wearing a general rule's clothes, and the
  corpus has one surge.
- **If GRN moves the wrong way.** The sign is positive for Greens in 23 of 23.
  If imposing the ranking helps ONP and hurts GRN, the mechanism is not
  "education predicts minor-party geography" but something fitted to the right.
- **If it beats the shipped arm only because the shipped arm is the OVERRIDE.**
  Measure against `base_pred` too. base_pred already carries the concentration
  curve, so if education-ranking does not beat base_pred it adds nothing and
  the real finding is the one already recorded: turn the override off for
  surging minors.
- **Any improvement that vanishes when seats are ranked by a DIFFERENT
  plausible feature** (born_aus_pct, r +0.581 on sa2026) is not evidence for
  education specifically, only for "rank by something correlated". Run that as
  a placebo.

## What this cannot see

- Whether education is causal or a proxy for something else (income, industry,
  urbanity). Irrelevant to forecasting accuracy, relevant to how far it can be
  trusted in a new jurisdiction.
- Victoria 2026 directly. No Victorian election in the corpus has a right-minor
  party above 6.5%, so the target case remains an extrapolation whatever this
  returns.
- Whether the concentration curve's `SD(L)` is right at Victorian levels. It
  called sa2026 at 9.18 against 7.67 actual -- 20% too wide -- and vic2026 is a
  further extrapolation.

## Scoping, measured BEFORE the criterion and recorded whatever it says

Three facts found while reading the mechanism, all before anything was scored.
Recorded here because the second and third weaken the plan, and a fact that
becomes inconvenient later is exactly the one that gets omitted.

**1. The mechanism already exists and this is a one-vector change.** Both the
harness (`backtest_candidate_sa.R:715`) and the live path
(`fit_seats_full.R:585`) rank seats and map a concentration shape onto that
ranking. `AUSPOL_ONP_ORDER` already takes `federal` or `greens`. This adds a
third option; it does not add a mechanism.

**2. The federal ordering signal exists for ONE pair.** Spearman of each signal
against the ACTUAL vote:

| pair | class | Year 12 | federal |
|---|---|---|---|
| qld2020 | ONP | 0.665 | n/a |
| fed2013 | OTH_RIGHT | 0.591 | n/a |
| qld2024 | ONP | 0.747 | n/a |
| fed2022 | ONP | 0.739 | n/a |
| fed2025 | ONP | 0.800 | n/a |
| sa2026 | ONP | 0.922 | **0.939** |
| sa2026 | OTH_RIGHT | 0.144 | **0.538** |

So on the only pair where both exist, **federal is better** -- and everywhere
else there is no federal signal at all. The plan is therefore NOT "replace
federal with education". It is "extend a mechanism that runs on one pair to the
other 22", and the named targets qld2020 and fed2013 currently have NO
concentration applied, which makes the test cleaner than originally written:
mechanism off versus mechanism on, ordered by education.

**3. For VICTORIA specifically this will probably change little.** The two
orderings agree at Spearman **+0.764** over the 78 seats carrying both, and all
eight of federal's top-ranked Victorian seats fall in education's top 12 of 78.
Murray Plains is federal 4th / education 1st; Gippsland East 3rd / 2nd. If the
Victorian forecast moves a lot on this change, that is a reason to distrust the
implementation, not to celebrate.

Education's advantage in Victoria is coverage: 78 of 88 seats have a federal
signal, census has all 88.

## Prediction, written before running

qld2020 and fed2013 OTH_RIGHT improve modestly (RMSE down 0.1-0.3 points),
sa2026 ONP improves substantially (8.658 -> under 7), pooled is roughly
neutral. If sa2026 moves and the two targets do not, this plan fails its own
primary criterion and is refused regardless of how good the sa2026 number looks.
