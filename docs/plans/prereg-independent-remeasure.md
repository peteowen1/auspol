# Pre-registration: re-measure v3 against the model we actually publish

Written 2026-08-23, **before anything is run**. Committed before running.

**This is a re-measurement, not a fifth model.** The v3 three-mechanism
independent model is used exactly as it was fitted on 2026-08-20. Nothing about
it is repaired, re-tuned or extended. If it needs changing to win, that is a
different experiment and needs a different plan.

## Why re-measure something already refused four times

`reviews/independent-refusals-reread-2026-08-23.md`: all four rounds scored the
independent model against an arm A that is **not the published model**.
`score_independent_federal.R:62` passes no `shrink`, no `statewide_draws` and no
`party_cor`; `fit_seats_full.R` passes all three. Arm A's calibration slope
across the rounds was 0.586, 0.586, 0.586 and **0.260**. The published model,
measured on 2026-08-22 in its shipping configuration, is **0.980**.

And `reviews/discrimination-gap-2026-08-22.md` priced the defect: excluding
seats an independent won we are level with AE Forecasts (log 0.255 against
0.247), and **97% of the entire gap is twenty independent-won seats**.

## The change of criterion, and why it is suspect

**v4 refused on Brier. This plan uses log score. That change favours adoption,
and by this repo's own rule that makes it a rationalisation rather than an
amendment unless it is handled carefully.**

It is handled by **requiring both**, which is stricter than either alone:

- **Primary: per-seat log score**, clustered on the election. The defect is
  confidently-zero probabilities on seats that then flip; log score is unbounded
  below and sees them, Brier is bounded and quadratic and cannot. A seat moved
  from 0.000 to 0.30 that then wins gains at most 0.09 on Brier and 1.2 on log.
- **Non-inferiority on Brier: arm B may not be worse than arm A by more than
  1 SE.** v4's refusal was a 2.52 SE Brier reversal, and this plan does not get
  to ignore that by changing the yardstick. If B improves log while damaging
  Brier by more than 1 SE, the verdict is a **split result, reported and not
  adopted.**

Both conditions are fixed now. Neither may be dropped after seeing the numbers.

## Arms

| arm | what it is |
|---|---|
| **A** | the **published configuration** — `shrink = 0.10`, `statewide_draws`, `party_cor` as `fit_seats_full.R` passes them |
| **B** | A, plus the v3 three-mechanism independent model exactly as fitted |
| **S** | A, plus a temperature control — a one-parameter rescale of A's probabilities |

**S is retained deliberately.** It was the control that sank v1–v3, and its force
came from arm A being over-confident. Against a baseline already at slope 0.980
it should now have little to offer — and **if it still explains arm B's gain,
that settles the question for good.** Keeping it is the strongest available test
of whether the re-read was right.

## Corpus

The **886 federal division-pairs** across six elections that produced the v4
reversal, with every parameter fitted **leave-one-election-out**. Same data,
same fit, corrected baseline. NSW 2023 is reported alongside for continuity with
v1–v3 but is not the decision set — 88 seats decided nothing four times.

## Decision rule, fixed now

Six elections, so five degrees of freedom on the clustered difference.

- **Adopt if arm B beats arm A on log score by more than 2 SE AND is not worse
  than A on Brier by more than 1 SE AND passes G1 below.**
- **2 SE, not 1**, because this is the **fifth look** at the same question. The
  earlier grid experiment lowered its bar to 1 SE on an explicit
  power argument; that argument does not apply here — 886 seats across six
  elections is not a thin test — so multiplicity governs instead and the bar
  rises.
- **If B beats A on log by more than 2 SE but fails Brier or G1**, report the
  split and do not adopt.
- **If B does not beat A on log by 2 SE, the line is closed for good.** Five
  attempts against a corrected baseline is enough, and a sixth would be
  searching for a configuration that flatters it.

## Refusals

- **G1 — incumbent independents.** In every seat an independent held and won,
  arm B must give the independent at least **0.80**. This is v1's bar and arm B
  failed it twice (Sydney 0.999→0.410, Wagga 1.000→0.524). A model that finds
  new independents by forgetting existing ones is not an improvement.
- **G2 — the control.** If arm S matches or beats arm B on log score, refuse.
  The gain would again be recalibration wearing a model's clothes.
- **G3 — arm A must be verified as the published configuration** before any
  comparison, by checking the call passes all three arguments and that A's
  calibration slope lands near 0.98 rather than near 0.26. **This is the whole
  premise of the re-measurement and it gets asserted, not assumed.**
- **G4 — the classification mismatch stays out.** Orange, Murray and Barwon are
  Shooters seats the anchor's file records as `IND`. They must be excluded from
  G1 and flagged in any per-seat table; v2 found arm B "improving" them partly
  by luck.
- **G5 — the live forecast does not change as part of this run.** Adoption is a
  separate, deliberate act afterwards.
- **G6 — no repair mid-experiment.** v2 identified the right fix (the
  relationship is roughly identity, so `ind_prev` wants a form that can track
  it) and deliberately did not make it. That restraint holds here: this plan
  measures v3 as it stands.

## What this cannot see

- **Whether the recontest problem is fatal.** Dubbo: a 28.4% independent
  predicted at 39.7%, actual 0.0, because they did not stand again. No feature
  in v3 knows that, and it is not addressed here.
- **Whether any of it matters for Victoria 2026**, which has **zero
  independent-held seats**. A win here improves the model against a federal
  benchmark and may change the published Victorian forecast not at all. That is
  not an argument against doing it, but it is an argument against overselling
  the result.
- **Whether v3 is the right model.** It is the one that exists. A refusal here
  is evidence the approach is wrong, not proof.
