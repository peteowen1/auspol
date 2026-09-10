# Pre-registration: xgb-predicted surge parameters

**Written and committed 2026-09-11, BEFORE building or running anything.**

## The change

Replace the salience-derived emergence parameters with xgboost predictions:

| simulator parameter | today | proposed |
|---|---|---|
| `surge_h` | per-seat hazard from the salience corpus | xgb P(this class emerges here) |
| `surge_party` | the class the hazard was fitted for | the class xgb gives the highest P to |
| `surge_mu` | global constant 15.6 | xgb E[gain \| emergence] for that seat/class |
| `surge_sd` | global constant 6.1 | xgb sd of that gain |

**No simulator change is required.** All four are already per-seat vectors
(`R/seat_sim.R:282, 350`), and the mixture is already implemented in the
compiled core (`src/seat_sim_core.cpp:102`: with probability `surge_h[i]`, add
`N(surge_mu, surge_sd)` to the chosen candidate).

## Why, in one line

The xgb primary's **point estimate is already right**: conditional on what it
predicts, bias is ~0 at every level (−0.09 at a 20–35% prediction, n=129). What
is wrong is the **spread**. For IND predicted at 10–15%: mean actual 11.9
against 12.1 predicted, but p10 = 2.0, p90 = 26.3, and 12.1% poll above 25%,
while the simulator gives that candidate sd 3.70 — so a 30% outcome sits 5.4
standard deviations away and happens one time in eight.

The mixture shape is right; the parameters are wrong. `surge_h ≤ 0.05` for
**184 of 201** historical emergences, and `surge_mu = 15.6` against a mean
actual jump of **22.6** for emerging independents.

## Sizing, computed before choosing the criterion

Two candidate criteria were **rejected on power**, per CLAUDE.md's rule that a
primary whose MDE exceeds any plausible effect can only ever refuse:

- **Pooled seat log loss.** The 26 emergence-won seats are 1.3% of rows but
  14% of total loss. Calling *every one of them perfectly* gains at most
  **0.0399**. MDE clustered on 22 pairs is **0.0810** — twice the maximum
  conceivable effect. Cannot be the primary.
- **Mean log loss on those 26 seats.** Mean 3.241, but MDE clustered on their
  10 pairs is **3.349**, because floor seats dominate the variance
  (Kalgoorlie contributes 13.82 alone). Also cannot be the primary.

## PRIMARY criterion

**`rms_z` on the 201 emergence rows**, where
`z = (actual_share − xgb_pred) / level_sd(xgb_pred)` is how many standard
deviations the truth sat from the centre under the spread the simulator
actually used.

| | baseline | target |
|---|---|---|
| rms_z, 201 emergence rows | **3.93** | 1.00 |
| % above z = 2 | **56.2%** | 2.3% |
| % above z = 4 | 29.9% | 0.006% |

**Pass bar: rms_z ≤ 2.50.** That is a move of 1.43 against an MDE of **0.93**
(per-pair rms_z sd 1.56 over 22 pairs), so the criterion has the power to
accept as well as refuse — which is the property both rejected criteria lacked.

Clustering is on **pairs**, not rows.

## GUARDS (do-no-harm), all must hold

1. **Non-emergent minor rows must not become over-dispersed.** n = 7,056,
   currently rms_z **0.80** and 1.5% above z = 2. Guard: rms_z must stay within
   **[0.65, 1.25]** and % above z = 2 must not exceed **5%**.
   *Two-sided on purpose* — see the dry-run below.
2. **Election-wide pooled seat log loss** must not worsen by more than
   **0.010**. That is the budget from the false-positive surface: 2,024
   seat-elections won by a major with no emergence, at 0.01 each.
3. **The gain must not come from one pair.** rms_z must improve in at least
   **6 of the 10** pairs that contain an emergence-won seat.

## REFUSAL conditions — what would disqualify an apparent WIN

Named in advance, because a criterion that only says how to pass has failed
twice in this repo.

1. **A broad directional lift.** If IND or ONP win probability rises in a
   majority of seats where no non-major polls above 10%, refuse — that is the
   2026-08-19 One Nation failure (probability rose in 71 of 87 seats and fell
   in 1, which no criterion covered).
2. **Buying the tail with the body.** If the primary passes while the
   non-emergent guard lands below 0.65, the model has simply widened everything
   and the criterion was measuring inflation, not discrimination.
3. **Accuracy paid for calibration.** If pooled seat accuracy across 22 pairs
   falls by more than 0.5 points, refuse regardless of log loss.
4. **A vic2026 result the evidence cannot support.** The live forecast
   currently gives IND a median of 0 seats (90%: 0–1). If the change puts the
   IND median above the largest number of independents ever elected to the
   Victorian Legislative Assembly at one election, refuse and re-examine —
   that number is to be looked up from the VEC record **before** scoring, not
   chosen after seeing the output.

## What the criterion CANNOT see

- It scores each candidate's **marginal** distribution, not the correlation
  between candidates within a seat. A model could get every marginal right and
  still mis-call seats by making all minors surge together, or by taking the
  surge from the wrong opponent. Guard 1 and refusal 1 partly cover this;
  nothing here covers it fully.
- It says nothing about **which** opponent loses the vote. Goldstein's teal
  took it from ALP (28.3 → 11.0) and Curtin's from LNP. Both are scored the
  same here.
- Emergence is defined by a **threshold** (non-major, was <10% here last time,
  polled ≥15%). Cases just under it are counted in the guard population, so a
  change that helps only 14.9% candidates would look like harm.

## Dry-run of the criterion, on cases whose answer is already known

Per CLAUDE.md, the criterion is a measuring instrument and gets tested like one
**before** this file is committed.

| case | what the criterion should say | what it does say |
|---|---|---|
| fed2022 Curtin IND, pred 9.2, actual 29.5 | a clear failure today | z = 5.6 — flagged |
| fed2022 Goldstein IND, pred 11.8, actual 34.5 | a clear failure today | z = 6.0 — flagged |
| Non-emergent IND rows (n = 1,959) | already fine, must not move | rms_z 0.95 — inside the guard |
| GRN in safe Green seats | already fine | rms_z 0.66 non-emergent — fine |

**The dry-run found a real hole and the guard was changed because of it.** A
one-sided guard ("non-emergent rms_z must not exceed 1.25") would be passed by
the laziest possible fix: inflate every minor candidate's sd until the
emergence rows stop being outliers. That drives non-emergent rms_z *down*
toward 0.4 and the primary would improve for entirely the wrong reason. Hence
the **lower** bound of 0.65, added here rather than after seeing results.

## Decision rule

Ship if the primary passes **and** all three guards hold **and** no refusal
condition fires. Report all of them either way, including the ones that fail.
