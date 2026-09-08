# Pre-registration: split the non-major vote into DEFENDED and VACANT

Written and committed **before** the arm was run, 2026-09-08. Successor to
`prereg-reentry-prior-2026-09-07.md`, whose measured result is recorded in
`docs/reviews/` and whose refusal is not reopened here.

## The defect, in two seats

`seat_lean()` computes `nonmajor_prev`, the previous election's vote for every
class except Labor and the Liberals, and `reentry_fit()` uses it as a covariate:
a seat with a large non-major vote is one where a re-entering minor party is
expected to do well.

That reasoning holds only if the non-major vote is **available**. Measured on
the corpus, leave-one-election-out:

| pair | seat | party | predicted | actual |
|---|---|---|--:|--:|
| qld2024 | Traeger | ONP | **74.3** | 6.8 |
| qld2024 | Hill | ONP | **57.5** | 6.9 |
| qld2024 | Callide | ONP | 44.6 | 15.8 |

Traeger's `nonmajor_prev` is 63.3, the maximum in the entire One Nation
training set. All of it is Katter's Australian Party, and **KAP stood again in
2024 and took 49.3%**. The vote the model reads as room for One Nation was
never vacant; it was occupied by an incumbent who held it.

A predicted 74.3% first preference for a party that polled 6.8% is not a
calibration problem. It is a forecast that could not happen, which this repo
treats as broken rather than conservative.

## The change

Replace the single `nonmajor_prev` with two covariates, both computed from the
prior election's result and the target election's **nomination list**:

- `nonmajor_defended` — prior non-major vote held by classes that ARE standing
  again in this seat at the target election.
- `nonmajor_vacant` — prior non-major vote held by classes that are NOT.

Their sum is exactly the old covariate, so this is a decomposition, not an
addition of information. Leakage-free on the same grounds as the prior itself:
who is standing comes from nominations, which close before polling day, and
both `apply_reentry_prior()` and the harnesses already read that list.

Expected signs: `nonmajor_vacant` positive (room a newcomer can take),
`nonmajor_defended` near zero or negative. **If `nonmajor_defended` comes back
strongly positive, the mechanism proposed here is wrong and the arm is refused
regardless of what the pooled metric does.**

## The criterion

**Primary: PB3f, pooled seat log loss excluding floor seats.** Baseline
**0.3149** over 2,046 of 2,050 seat-elections, measured 2026-09-08 on the
shipped configuration with `AUSPOL_REENTRY=0`. Floor count 4, in fed2013,
nsw2019, wa2001 and wa2008.

**Co-primary, and this one is specific to the defect:** the count of re-entry
cells predicted above 40%. Currently **5** across 1,416 cells, and the largest
prediction, currently 74.3.

**Guards:** pooled seat-share RMSE; per-jurisdiction log loss for all six.

**Decision rule.** Adopt if the largest prediction falls below 40 AND PB3f does
not worsen by more than 0.002 AND no jurisdiction's log loss worsens by more
than **two standard errors of that jurisdiction's own paired difference**.

The last clause is written in standard errors deliberately. The predecessor
plan used a flat 0.01 and refused on South Australia, whose +0.0162 is 0.63 SE
on 47 seats — a threshold that jurisdiction cannot resolve. Sizing it here in
advance rather than arguing about it afterwards.

### Dry-run of the criterion on cases whose answer is already known

1. **Traeger qld2024.** KAP holds 63.3 of 63.3 non-major and re-stands, so
   `nonmajor_vacant` is approximately 0. The prediction must fall a long way
   from 74.3. If it does not, the covariate is not reaching the model and that
   is a bug to find before reading any pooled number.
2. **Kimberley wa2001.** Predicted 37.2, actual 42.2 — the case the whole
   prior exists for, and it is a Labor re-entry driven by the statewide offset
   and lean, not by `nonmajor_prev`. It must **not** fall materially. Kimberley
   1996 was two independents on 63%, so if the split is wired wrongly this is
   exactly the seat it will damage. A drop below 30 is a refusal.
3. **A seat with no non-major vote at all.** Both new covariates are 0 and the
   old one was 0. The prediction must be unchanged to within rounding. If it
   moves, the refit has changed something other than what this plan proposes.

## Refusal section — what disqualifies an apparent win

1. **`nonmajor_defended` positive and significant.** Stated above. The plan
   claims occupied vote is not available; a positive coefficient says the data
   disagrees, and no improvement in PB3f rescues a mechanism the fit rejects.
2. **Kimberley damaged.** The predecessor's entire measured gain was wa2001,
   and almost all of that was one seat. A change that trims the tail by
   flattening the case the prior was built for has removed the benefit and kept
   the cost. Report Kimberley's predicted value in every run.
3. **A gain confined to Queensland.** The two worst predictions are both
   Queensland KAP seats. Queensland is 186 of 2,050 seat-elections; if PB3f
   improves there and nowhere else, this is a two-seat patch wearing a general
   change's clothes, and it should be argued as such rather than adopted as a
   model improvement.
4. **The largest prediction falling below 40 only because every prediction
   shrank.** Report the mean and median predicted value alongside the maximum.
   A model that has simply become timid will pass the co-primary while getting
   worse at the job.

## What the criterion cannot see

- Whether a class standing again is the right notion of "defended". A party
  whose sitting member has retired is standing but not defending, and this
  pools the two. `personal_prior_vote()` knows about defections and is not
  consulted here.
- Class granularity. KAP, the Shooters and assorted right-wing minors all map
  to `OTH_RIGHT`, so "the same class is standing again" can be two different
  parties. That is a `classify_party()` question, not one this plan settles.
- Anything about seats where the re-entering party's problem is the OTHER
  half of the model — the statewide offset, the breadth term, or the flow lean.

---

## Dry-run outcome, 2026-09-08 — THE ARM IS NOT RUN

Added after the dry-run and before any pooled number was computed. Everything
above is left exactly as committed.

The three cases were checked as required and the arm **fails case 1**:

| pair | seat | party | whole | split | actual |
|---|---|---|--:|--:|--:|
| qld2024 | Traeger | ONP | 74.3 | **79.2** | 6.8 |
| qld2024 | Hill | ONP | 57.5 | **63.3** | 6.9 |
| wa2001 | Kimberley | ALP | 37.2 | 37.2 | 42.2 |
| wa2005 | Alfred Cove | ALP | 41.9 | 41.9 | 22.8 |

Cases 2 and 3 pass — Kimberley is untouched, and the 14 cells with no
non-major vote at all move by at most 0.098. Case 1 goes the wrong way.

### Why, and why the premise of this plan was wrong

The coefficients came back with exactly the signs this plan predicted. On the
leave-one-out fit for qld2024, One Nation gets `nonmajor_defended` **−0.0326**
(p = 0.0001) and `nonmajor_vacant` **+0.0321** (p = 0.010). Occupied non-major
vote does suppress a newcomer and vacant non-major vote does invite one.

But the term it replaced was **already negative**: `nonmajor_prev` had
coefficient −0.0245 (p = 0.001). The model was never reading Traeger's KAP vote
as room for One Nation. The premise stated at the top of this plan — "the
model reads that as non-major vote is available" — is false, and it should have
been checked against the fitted coefficient before the plan was written.

Traeger's 74.3 comes from somewhere else entirely. Decomposing its linear
predictor: `lean` −0.116 × 23.2 = −2.69 and `flow_lean` +0.115 × 44.5 = +5.13.
Those two coefficients are **near-equal and opposite**, so the model is
effectively using the *disagreement* between the two lean measures, at about
+0.115 per point of gap. Traeger's gap is 44.5 − 23.2 = 21.3 points, worth
**+2.45 in log space, a factor of 11.6**, and that is the whole of the
blow-up. Splitting the non-major term freed `lean` to grow from −0.0988 to
−0.1161, which widened the gap term and made Traeger worse.

The gap is itself a real signal about KAP: the bloc measure files KAP's 49% as
fully right-wing, while the flow positions place it nearer the centre, and the
model has learned that seats with a large centrist-flowing right-wing bloc are
good for One Nation. In Queensland those seats are precisely the ones KAP
already holds.

### What this actually diagnoses

The fault is not a covariate. It is that a quasipoisson log link with an
offset is **unbounded**, applied to a response that is a share of 100. With
`lean` spanning 19 to 100 at roughly −0.10 per point, the fitted ratio can
range over a factor of about 3,300. Nothing in the specification prevents a
prediction above 100, and five predictions already exceed 40.

Successor arm, to be pre-registered separately: fit the re-entry share on a
**bounded link** so an impossible forecast cannot be produced by construction.
That is a different change from the one committed here, and it gets its own
plan, criterion and dry-run rather than being folded into this one.

`AUSPOL_REENTRY_SPLIT` is implemented and defaults to 1, but with
`AUSPOL_REENTRY` at 0 it reaches nothing that is published.
