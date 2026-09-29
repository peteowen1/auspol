# Pre-registration: drop `fed_aligned`, retested time-forward

Written 2026-09-29 17:40, before running. Retest of
`prereg-fundamentals-drop-fed-aligned-2026-09-20.md`, which was REFUSED on
leave-one-out fits (fundamentals MAE +0.543, SE 0.253). The retest audit
(`reviews/refused-arms-retest-audit-2026-09-29.md`, row 1) marks that verdict
as resting on a leaky baseline: a leave-one-out fit learns the federal-drag
term partly from later elections. Since v51 the statewide fundamentals and
mix are time-forward, so the question is re-asked on the same footing.

nsw2023 after v51: trend 54.17, time-forward fundamentals 46.22, projection
52.58, actual ~54.3.

## The arm

`fit_fundamentals(features = setdiff(FUNDAMENTALS_FEATURES, "fed_aligned"))`
inside the time-forward fit: each election's fundamentals from elections
before it only, each target's mix refitted on earlier elections carrying
their own time-forward fundamentals, exactly as `fundamentals_tf()` /
`projection_mix_tf()` do. Baseline = the same with `fed_aligned` kept.
Script: `scripts/retest_fed_aligned_tf.R` (statewide only; no rebuild).

## Criterion, in order

1. **Primary: time-forward projection absolute error at horizon 1**, paired
   over every target with a time-forward mix. The arm passes if the mean
   paired difference (arm - baseline) is at least one SE in its favour.
2. **Do no harm: time-forward fundamentals absolute error** over every
   election with >= 10 earlier elections does not rise by more than one SE.
3. **Unacceptable win**: the primary passing only because of nsw2023. The
   paired mean without nsw2023 must not favour the baseline.
4. Reported, not decisive: horizon 730 projection error; nsw2023's own
   numbers; the `fed_aligned` coefficient at each cutoff.

Decision: 1-3 pass -> flag `AUSPOL_FUND_FEATURES`, full rebuild S, ships if
the ledger seat log loss improves. Otherwise refused, and the nsw2023
statewide miss is recorded as the fundamentals' honest error.

## RESULT (2026-09-29 17:50): REFUSED again, now time-forward

`scripts/retest_fed_aligned_tf.R`, output `output/retest-fed-aligned-tf.csv`.
Absolute error in Labor two-party points, lower is better; diff = drop -
base, negative favours dropping the term.

| measure | n | with | without | diff | SE |
|---|--:|--:|--:|--:|--:|
| fundamentals, time-forward | 50 | 3.307 | 3.867 | +0.560 | 0.344 |
| **projection @1 day (primary)** | 28 | 1.736 | 1.697 | -0.039 | 0.080 |
| projection @1 day, without nsw2023 | 27 | 1.716 | 1.713 | -0.003 | 0.074 |
| projection @730 days | 20 | 2.823 | 3.069 | +0.246 | 0.361 |

1. Primary fails: -0.039 is half an SE, not one.
2. Do no harm is borderline (+0.56, 1.6 SE worse; the bar is 1 SE): fails.
3. The whole day-before gain is nsw2023 (error -2.27 -> -1.26); without it
   the arms tie (-0.003).

The coefficient is learned time-forward and is stable: -2.4 to -3.3 points
at every cutoff from 2001 on (nsw2023's own fit: -2.95). It is not a leak
artefact; the leave-one-out verdict of 20 Sep stands. nsw2023's statewide
miss (projection 52.58 vs ~54.3) is the fundamentals' honest error on an
election that went against a well-established pattern. Feature list
unchanged; nothing ships.
