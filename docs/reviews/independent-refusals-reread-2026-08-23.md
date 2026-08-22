# Re-reading four refusals: they were all scored against a baseline we do not ship

Independent emergence has been built and refused four times. Today's benchmark
work priced the hole at **97% of the gap to a real forecaster**, so the four
refusals are worth re-reading before a fifth attempt. Re-reading them turns up
something none of them could have known.

## What each round actually did

| round | what changed | result | why refused |
|---|---|---|---|
| **v1** | 4 features, NSW 2019→2023 | Brier 1.03 SE better, accuracy 74/88 vs 71/88 | **broke incumbent independents**: Sydney 0.999→0.410, Wagga 1.000→0.524. `ind_prev` was collinear with `nonmajor_prev` and the fit discarded it |
| **v2** | collinearity removed | identical aggregate, 1.01 SE | **still broke them** — but for a different reason: the true relationship is roughly *identity* (next ≈ previous) and a linear term on a `log1p` outcome crosses it only once. Sydney 41% predicted at 20% |
| **v3** | three mechanisms, split by incumbency | Brier 1.46 SE better, **slope 0.974**, accuracy 74/88 | 1.46 SE against a pre-registered 2 SE bar |
| **v4** | same model, 886 federal division-pairs, LOO | **Brier 2.52 SE WORSE** | reversal on the larger corpus. The line of work stopped |

Two genuine problems were identified along the way and remain real:

- **Recontest.** Dubbo: a 28.4% independent in 2019, predicted 39.7%, actual
  **0.0** — the independent simply did not stand again. No feature in the model
  can know that.
- **A classification mismatch.** Orange, Murray and Barwon were Shooters seats
  the anchor's seat file records as `IND`. Arm A scored ~0.000 there for a
  reason unrelated to emergence, and arm B "improving" them was partly luck.

## The thing none of the four could know

**Every round scored arm B against an arm A that is not the published model.**

`scripts/score_independent_federal.R:62`:

```r
simulate_seat_contests(sh, fm, party_sd = psd, seat_sd = 3.5,
                       n_sims = n, smooth = SMOOTH, seed = seed)
```

No `shrink`. No `statewide_draws`. No `party_cor`. `fit_seats_full.R` passes all
three. The same omission appears in `score_independent_emergence.R` and
`score_independent_two_mechanism.R`.

The evidence is in the rounds' own numbers. Arm A's calibration slope:

| | v1 | v2 | v3 | v4 |
|---|---:|---:|---:|---:|
| arm A slope | 0.586 | 0.586 | 0.586 | **0.260** |

**The published model, measured today in the shipping configuration, is 0.980.**

## Why that matters more than it sounds

**The temperature control was answering a question that only exists for the
broken baseline.** Control arm S was introduced in v1 to test whether arm B's
gain was really just "an over-confident model made less confident" — and the
verdict each round was that B barely cleared it (0.65–1.06 SE). That objection
is decisive against a baseline at slope 0.26. Against a baseline **already at
0.980 there is nothing for a temperature to fix**, and the control loses its
force.

**And v4's criterion was Brier, which is the least sensitive proper score for
this defect.** Its own table shows arm B *ahead* on log score:

| arm | Brier | log score | slope |
|---|---:|---:|---:|
| A — as published (but not really) | **0.0932** | 0.5444 | 0.260 |
| B — three mechanisms | 0.0986 | **0.4782** | 0.353 |

Brier is bounded and quadratic, so a seat moved from 0.000 to 0.30 that then
wins gains at most 0.09. Log score, which is unbounded below, gains 1.2 — and
log score is both what AE Forecasts beats us on and where the entire measured
gap sits. v4 refused on the metric least able to see the thing being fixed.

## What this does and does not license

**It does not vindicate the model.** Arm B broke incumbent independents in v1
and v2, and v3's fix has never been tested against a correctly-configured
baseline. The federal reversal might survive the correction, and if it does the
line really is dead.

**It does mean all four verdicts rest on a comparison that was not what it
claimed to be** — the same defect found three times today in other harnesses,
here for a fourth. The right response is to re-run the existing v3 model against
the published configuration on the federal corpus, changing nothing else. That
is a re-measurement, not a fifth model.

## What a re-measurement must hold fixed

- **The v3 model exactly as it was fitted.** Not repaired, not re-tuned. If it
  needs changing to win, that is a fifth attempt and needs its own plan.
- **Arm A becomes the published configuration** — `shrink`, `statewide_draws`
  and `party_cor` as `fit_seats_full.R` passes them.
- **Log score becomes the criterion**, pre-registered as such *before* the run,
  with Brier and accuracy reported alongside. The justification is written down
  now rather than after: the defect is confidently-zero probabilities on seats
  that then flip, and Brier cannot see them.
- **The control arm stays**, because if it still explains the gain against a
  calibrated baseline, that settles it for good.
- **The incumbent-independent check stays.** v1's G1 bar — a seat an independent
  held and comfortably won must keep a high probability — is the right guard and
  arm B failed it twice.
