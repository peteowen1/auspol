# Fifth and last: the baseline was wrong, correcting it helped, and it still fails

Against `docs/plans/prereg-independent-remeasure.md`, committed before the run.
**Refused. The decision rule says the line closes for good, and it does.**

## The result

886 federal division-pairs, six elections, every parameter fitted
leave-one-election-out, all three arms in the **published configuration**
(`shrink = 0.10`, shrunk party correlation).

| arm | log | Brier | accuracy | slope |
|---|---:|---:|---:|---:|
| A — as published | 0.4374 | **0.0930** | 87.5% | **1.189** |
| B — three mechanisms | **0.3902** | 0.0989 | 86.5% | 1.345 |
| S — temperature control | 0.4282 | 0.0980 | 87.5% | 1.550 |

Against the pre-registered rule:

- **Primary, log score: B beats A by +1.49 SE.** Bar was 2 SE. **Fails.**
- **Brier non-inferiority: B is 1.96 SE worse.** Limit was 1 SE. **Fails.**
- **G2 control: B beats S on log by 2.23 SE.** Passes — the gain is not just
  recalibration.
- **G3: arm A's slope is 1.189**, not the 0.260 the four historical rounds
  scored against. The premise of the re-measurement is confirmed.

## What the correction was worth

The re-read was right about the defect. All four earlier rounds compared the
independent model against an arm A carrying no `shrink`, no `statewide_draws`
and no `party_cor`, at a calibration slope of 0.260 against the published 0.980.

Correcting it moved arm B from **2.52 SE worse on Brier** (v4's refusal) to
**1.49 SE better on log score**. That is a large, real change in the evidence,
and it still does not clear the bar.

**Two of the earlier reasoning threads are now settled rather than suspected:**

- **The temperature control was measuring the broken baseline.** Historically S
  nearly matched arm B, which is what sank v1–v3. Against a calibrated baseline
  B beats S by 2.23 SE, so **the gain is genuinely the independent model and not
  recalibration in disguise.** The old objection is dead — and the model still
  fails on its own merits, which is a cleaner refusal than the four before it.
- **Brier really was the wrong criterion**, and saying so did not save the
  model. B is better on log (+1.49 SE) and worse on Brier (−1.96 SE), exactly
  the split the plan anticipated. Requiring both, rather than switching to the
  favourable one, is what makes this refusal trustworthy.

## Why it still fails

Arm B buys independent seats and pays for them elsewhere: accuracy drops 87.5%
to 86.5%, Brier worsens, and the slope overshoots from 1.189 to 1.345. The
mechanism is the one v1 and v2 identified and never fixed — the model **replaces**
each seat's independent share with a draw, so it finds new independents by
degrading seats that were already right.

Nothing in this run addresses that. G6 forbade repairing it mid-experiment, and
the repair v2 identified — the relationship between an independent's previous
and next vote is roughly *identity*, which a linear term on a `log1p` outcome
cannot track — was never built.

## Closing it

The rule was written in advance: *"If B does not beat A on log by 2 SE, the line
is closed for good. Five attempts against a corrected baseline is enough, and a
sixth would be searching for a configuration that flatters it."*

**Five attempts. Closed.** What survives is the diagnosis, which is worth more
than the model was:

- **97% of our gap to AE Forecasts is twenty independent-won seats**, and within
  those we hold incumbents fine and score 0.000 on first-time winners;
- the cause is structural — a seat's baseline is the previous election's first
  preferences **by class**, so a seat where no independent stood has no `IND`
  vote to swing;
- **the fix is not a better emergence model on top of that baseline.** Five
  attempts say so. It would need the baseline itself to represent a candidate
  who did not exist last time, which is a different design, not a further
  feature.

And the standing caveat: **Victoria 2026 has zero independent-held seats.** None
of this changes the forecast currently being published.

## One mistake worth recording

This run **overwrote `output/independent-federal-scores.csv`**, the historical
v4 scores, because the edit adding a configuration tag to the filename failed
silently — the check that would have shown the traceback was piped through
`tail -1`. The file is regenerable by re-running with the historical defaults
and the fix is in place, but the baseline-clobbering hazard `CLAUDE.md` records
was live for one run, and the cause was hiding an error rather than reading it.
