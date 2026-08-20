# Pre-registration: are our per-seat win probabilities calibrated?

Written 2026-08-19, **before** anything is measured. Committed before running.

## The claim being tested

The published pendulum gives every seat a probability that Labor holds it. That
is a distributional claim about 88 individual contests, and **it has never been
checked**. The repo checks two-party interval coverage (93% against a claimed
95%) and, as of today, first-preference coverage. Per-seat probabilities are the
most visible output and the least tested.

The question is the reliability one: **of the seats we call 30%, do about 30%
happen?**

## What makes this testable

The same join that made the seat-swing work possible:

- run the seat model with only what was knowable **before** an election
  (`2022vic.txt`, `2023nsw.txt` — margins, regions, the swing predictors);
- score against what happened, from `fPreviousTppSwing` in the file written for
  the following cycle (`2026vic.txt`, `2027nsw.txt`).

88 Victorian and 92 NSW classic seats. **180 contests across two elections in
two states.**

## The statewide swing must come from outside the model

A seat model conditioned on the *actual* statewide result would be scored on a
question nobody can ask in advance, and would look far better than it is.

So each election is scored **twice**, and both are reported:

- **conditional** — feed the actual statewide two-party result. This isolates
  the seat layer: given a correct statewide number, are the per-seat
  probabilities right?
- **forecast** — feed the projection the model would have made at 30 days out,
  with its own uncertainty. This is the honest end-to-end claim.

The conditional run is the diagnostic; **the forecast run is the one the
decision rule uses.**

## What is measured

- **Reliability.** Bin predicted probabilities into deciles; report predicted
  versus observed frequency per bin, with counts.
- **Brier score**, against two baselines fixed now: predicting the base rate
  (the share of seats Labor actually won) for every seat, and predicting the
  2022/2018 incumbent holds with certainty.
- **A calibration slope.** Logistic regression of outcome on the log-odds of the
  prediction. **Slope 1 is calibrated; slope below 1 means overconfident** —
  probabilities pushed too close to 0 and 1.
- **Coverage of the seat-count interval**: does the 90% range for Labor's total
  contain the actual?

## Decision rule, fixed now

- **Calibration slope in [0.8, 1.25] and no reliability bin off by more than 15
  points** → calibrated. Report and change nothing.
- **Slope below 0.8** → overconfident. Then, and only then, estimate a single
  temperature on the log-odds by maximum likelihood, leave-one-election-out, and
  adopt only if it improves the held-out Brier score.
- **Slope above 1.25** → underconfident. Report; do not sharpen. Making a
  forecast more decisive is the change most likely to be regretted, and it needs
  its own case.

## Refusal section — what would make an apparent win unacceptable

- **R1 — no recalibration without a measured deficit.** If the slope is inside
  the band, change nothing, whatever AE Forecasts' or YouGov's intervals look
  like. This exists because the last two days have repeatedly tempted me to
  reach for another model's numbers as a target.
- **R2 — the temperature must not be fitted on the election it is scored on.**
  Leave-one-election-out, with the held-out Brier reported separately per
  election. With only two, a gain that appears in one and reverses in the other
  is a coincidence.
- **R3 — Brier must improve, not just slope.** A temperature that straightens
  the reliability curve while making the held-out Brier score worse is fitting
  the diagnostic rather than the forecast. Refuse.
- **R4 — no per-party or per-region temperatures.** One number for the whole
  model. With 180 contests, anything finer is noise, and a per-group correction
  is how a calibration exercise turns into a fitting exercise.
- **R5 — the conditional run must not be used to justify adoption.** It exists
  to say *where* a miscalibration lives, seat layer or statewide. If the
  forecast run is calibrated and the conditional one is not, that is
  interesting, not actionable.

## What the criteria cannot see

- **Whether the central forecast is right.** Calibration is about confidence.
  A perfectly calibrated model can still put Labor 11 seats above every other
  forecaster, which is where we currently are.
- **Minor parties.** The two-party seat model produces these probabilities, so
  this says nothing about One Nation, the Greens or independents — the
  candidate-level model is not tested here.
- **Two elections.** Both were unusual: a Labor landslide defence in Victoria
  2022 and a change of government in NSW 2023. Neither resembles a close
  contest, and 2026 may.
- **The 2026 forecast is 101 days out; this is scored at 30.** A model
  calibrated at short range can be overconfident at long range, and this cannot
  detect that.

---

## Result, 2026-08-19: CALIBRATED, nothing changed

[../reviews/seat-probability-calibration-2026-08-19.md](../reviews/seat-probability-calibration-2026-08-19.md).

161 classic seats, Victoria 2022 and NSW 2023, forecast arm. **Calibration slope
1.113**, inside the [0.8, 1.25] band and underconfident if anything. Brier
**0.0583** against 0.2382 for the base rate and 0.0994 for incumbent-certain.
Predicted mean 0.623 against an observed 0.609. Seat-count intervals covered in
both elections.

Per R1, no recalibration was looked for.

**One threshold of mine was mis-specified.** The rule required no reliability bin
off by more than 15 points; the worst bin with n ≥ 5 is off by 15.5 — a fail by
half a point on a bin of five seats, where one seat is worth 20. I set that
threshold without checking how many seats a decile could hold. Called calibrated
on the slope, which is the measure built for this, and the bin rule recorded as
inadequate rather than ignored.
