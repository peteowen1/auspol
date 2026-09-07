# Pre-registration: widen the statewide covariance to the non-WA pairs

Written and committed **before** the arm was run, 2026-09-07. Successor to
`prereg-statewide-cov-loo-2026-09-07.md`, whose C2 was refused.

## What is proposed

`scripts/estimate_statewide_cov.R` fits the correlation of statewide
first-preference changes on **10** pairs: six federal, two Victorian, one New
South Wales, one South Australian. Five more exist whose first-preference files
are already on disk and which the harnesses already score:

- `fed2007` (fed2004 → fed2007)
- `nsw2019` (nsw2015 → nsw2019)
- `vic2014` (vic2010 → vic2014)
- `qld2020` (qld2017 → qld2020)
- `qld2024` (qld2020 → qld2024)

That is 15 pairs, not 21. **Western Australia's six are deliberately excluded**,
because the previous pre-registration's refusal 1 fired on exactly them:
`cor(ALP, IND)` is −0.16 with WA in the fit and +0.43 without it. WA's Assembly
has almost no independents and its statewide Labor swings are enormous (+12 in
2017, +18 in 2021, −18 in 2025), so a flat IND column against very large ALP
moves manufactures a correlation about nothing. Excluding them is not a
convenience; it is the finding of the previous experiment applied.

Queensland is the most valuable addition: it carries real One Nation votes
(13.73% in 2017, 7.12% in 2020), and refusal V3 of the original covariance plan
records that ONP's column rests on South Australia 2026 and little else.

## The criterion, chosen so it can see the effect

The previous criterion could not. It made pooled seat log loss primary at a
0.002 bar, and pooled log loss is dominated by seats sitting at the `1e-6`
floor: **6 of 2,050 seat-elections carry 11.2% of it**. One of them crossing the
floor moved the pooled figure by 0.0019 — the entire measured difference —
without the model changing at all.

So:

**Primary: `PB3f`, pooled seat log loss EXCLUDING seats where either arm gives
the actual winner ≤ 1e-4.** Currently 0.3076 over 2,044 seat-elections. A change
that moves this is a change to the model.

**Reported beside it, never as the decision:** pooled log loss including those
seats (`PB3`, currently 0.3452), the count of floor seats and which pairs they
sit in. If the floor count changes, say which seat and why, because that is
where the model's real failure lives and it must not be hidden by the primary
that excludes it.

**Secondary do-no-harm guards:** pooled Brier (0.0945), pooled seat-share RMSE,
and per-jurisdiction log loss for all six.

**Decision rule.** Adopt if `PB3f` does not worsen by more than 0.002 and no
jurisdiction's log loss worsens by more than 0.01. Adopt on a tie: using data we
hold is the better default when the evidence is indifferent.

### Dry-run of the criterion on cases whose answer is already known

Required by this repo's rule that a criterion is an instrument and gets tested
like one. Three cases, each with a verdict established before this plan:

1. **The leave-one-out change (C1, yesterday's arm).** Known verdict: no
   material effect — largest per-pair move 0.0004, control pair byte-identical.
   The criterion should return "adopt, indifferent". `PB3f` would move well
   under 0.002. **Correct.**
2. **Barwon crossing the floor.** Known verdict: not a model change at all; the
   seat went 0.000050 → 0.000001 because the covariance was rebuilt on corrected
   federal data. The old criterion called this 0.0019 of harm. `PB3f` excludes
   Barwon entirely and moves ~0, while the reported `PB3` still shows the move
   and the floor count still names the seat. **Correct, and this is the case the
   old criterion got wrong.**
3. **`shrink` at 0.10 versus 0.01.** Known verdict: 0.10 is materially worse —
   CLAUDE.md records ~0.006 of mean log loss, because a scalar shrink caps every
   seat. It touches all 2,050 seats, not just the floor, so `PB3f` sees it at
   roughly full size. **Correct: the criterion is not blind to real changes.**

A criterion that is right on all three is measuring the model rather than the
constant.

## Refusal section — what disqualifies a winner

1. **A sign flip on any correlation above 0.15 when Queensland is excluded.**
   The same test that refused the WA widening, applied to the jurisdiction this
   one leans on. Queensland is two of the five added pairs and carries the ONP
   signal; if it alone reverses a relationship, the matrix is describing
   Queensland.
2. **`cor(ONP, LNP)` moving by more than 0.30 raw.** It is expected to move —
   that is much of the point — but a move larger than the SA-to-no-SA swing
   (−0.83 to −0.35) would mean Queensland has replaced South Australia as the
   single source rather than joined it.
3. **An improvement that lives entirely in the five added pairs.** Those pairs
   move from the all-pairs matrix to a leave-one-out matrix as a side effect of
   joining the fit, which is a different change from the widening. If the gain
   is confined to them, it is that side effect and not the widening.

## What the criterion cannot see

- Era. All pairs are pooled regardless of date, and the party structure of 2001
  is not that of 2025.
- Whether excluding WA is right in general, as opposed to right for this matrix.
  WA seats are still SCORED; only its pairs are kept out of this one estimate.
- Whether a correlation of realised *changes* is the right object for a
  simulator that draws deviations from a projected level. Related, not identical.
