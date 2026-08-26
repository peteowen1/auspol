# Pre-registration: predict a non-major's first preferences directly

> **OUTCOME 2026-08-26: REFUSED.** Failed criteria 1 and 2 on fed2025 (winners
> RMSE 2.99 base against 8.55 with salience) and the refusal clause on declining
> incumbents fired — Bandt predicted 66.2% on an actual 39.5%. Not a scale
> artefact: refitting inside fed2025 still adds nothing. **The attribution fix
> (`prev_party` over `prev_seat`) is separable, holds on both elections, and is
> what proceeds.** Scored in `docs/reviews/salience-regression-refused-2026-08-26.md`.
> Nothing below this line was edited after seeing the result.

Written 2026-08-26, **after** the fed2022 feature search and **before** any
other election has been fetched. That ordering is stated plainly because it
matters: the model form below was *selected* on fed2022, so fed2022 cannot also
be its test. fed2019 and fed2025 are the test.

## What this supersedes, and why

`docs/plans/prereg-salience-surge-hazard.md` proposed
**hazard x fixed surge size**: a logistic P(emergence) firing a canned
`N(+15.6, 6.1)` shift. That has two arbitrary parameters where the data can set
both, and it failed its own gate — the six named seats reached a mean
probability of 0.0267 against a required 0.10, because a 35% hazard does not
produce a 35% win when `+15.6` from a 5% base does not reach 29%.

Pete's objection was the right one: **regress the vote directly and let the
count decide.** That route was refused in the earlier pre-registration on slope
0.34 / R2 0.473 — measured on the *old* per-seat salience share, before the
name, weekly, hyphen, geo and cross-seat-batching fixes. **That refusal rested
on a broken instrument** (AUC 0.841) and does not bind the current one (0.971).

## The model

```
pcv ~ prev_party + log1p(max(jump, 0)) + is_ind + is_grn + prev_ind
```

| term | meaning |
|---|---|
| `prev_party` | THIS party's first-preference share in THIS seat last election |
| `jump` | salience: campaign mean minus pre-campaign baseline, cross-seat scale |
| `is_ind`, `is_grn` | party class |
| `prev_ind` | the seat's prior INDEPENDENT vote, separate from `prev_party` |

Output is the projected first-preference share for that candidate, which
replaces the swung value in `shares`. **The count then runs unchanged** — no
override, no cap, no hazard.

## Measured on fed2022 (leave-one-out), all 151 seats

| model | all | winners (14) | <5% band (39) |
|---|---:|---:|---:|
| `prev_seat` — **what ships today** | 8.72 | **17.11** | 11.68 |
| `prev_seat` + salience | 7.48 | 9.46 | 10.42 |
| `prev_party` + salience | 4.71 | 8.28 | 5.34 |
| + party class | 4.02 | 6.12 | 4.25 |
| **+ prev_ind (proposed)** | **3.92** | **5.79** | — |

**The single largest gain is not salience.** Correcting the attribution —
`prev_party` instead of `prev_seat` — takes 7.48 to 4.71. The current model
puts *the seat's best non-major* under whichever non-major is being projected,
which is how Scott Robson inherited Adam Bandt's 23.7% in Melbourne and was
predicted at 34.2% on an actual 1.1%.

## Features tested and REFUSED, recorded so they are not re-litigated

Each added singly to the base. Only `prev_ind` improved anything:

| feature | all | winners |
|---|---:|---:|
| prev_grn | +0.08 | +0.20 |
| ncand22 | +0.03 | +0.06 |
| margin | +0.00 | −0.13 |
| inc_retiring | +0.01 | −0.01 |
| lnp_seat | +0.02 | +0.03 |
| teal_state | +0.02 | +0.02 |

Retirement, seat safety, Liberal-held, teal-state — none add anything once
salience is present. That is mild evidence salience already captures what those
structural proxies were reaching for.

Earlier, incumbency and margin added to a smaller base made it **worse** (4.02 →
4.25 → 4.27). **151 seats with 14 winners cannot support six predictors**, and
anything further would fit noise.

## Criterion

**fed2019 and fed2025, neither yet fetched.** Fitted on fed2022 and applied
out-of-sample.

1. **Beat `prev_party` alone on RMSE** over all seats in each election. Salience
   must earn its place against the corrected attribution, not against the broken
   one. Beating `prev_seat` is not the bar.
2. **Beat it on the winners** in each election.
3. **No worse in the <5% band by more than 1.0 point** in either. The current
   version over-predicts no-hopers by +8.9 on average, and a model that fixes
   winners by inflating everyone is not a fix.

## Refusal — what disqualifies it

- **If it only works in fed2022.** That is the teal wave — the most favourable
  election that exists for a candidate-salience signal. If fed2019 or fed2025
  fails criterion 1, do not ship.
- **If fed2025 fails specifically.** That election contains sitting independents
  DECLINING — Bandt and Daniel both lost. A signal that only says "loud equals
  winner" will get those wrong, and that is the failure mode most likely to
  matter live.
- **If the gain vanishes once `prev_party` is corrected in the baseline too.**
  The attribution fix and the salience signal must be credited separately; if
  the published model adopts `prev_party` alone and salience then adds nothing,
  salience is not the improvement.
- **If any feature beyond the five listed is added after seeing results.** The
  feature search happened on fed2022 and is closed.

## What the criterion cannot see

- **The party-class abstraction is the deeper problem and this does not fix it.**
  "IND" is a residual bucket, not a party: two independents in a seat are summed,
  an independent's vote belongs to a person rather than a seat, and a uniform
  statewide "IND swing" is close to meaningless. This regression is a better
  patch on that wound, not a repair of it. Candidate-level modelling of
  independents is the real fix and needs its own design.
- **Every salience figure is a single Trends pull.** The literature wants
  replicates.
- **Nothing here tests a state election**, and Victoria is the live target.
- **fed2019 has one emergence (Steggall), not six.** A signal tuned on a wave
  may not fire on a single case.
