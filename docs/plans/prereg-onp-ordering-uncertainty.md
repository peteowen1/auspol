# Pre-registration: put One Nation's uncertainty in the ORDERING, not the level

Written 2026-08-19, **before** anything is built. Committed before running.

## Why the previous attempt failed, and what that implies

[onp-seat-uncertainty-2026-08-19.md](../reviews/onp-seat-uncertainty-2026-08-19.md)
gave One Nation a larger per-seat sd on its *share*. It was refused: the party's
win probability **rose in 71 of 87 seats and fell in 1**. Adding symmetric noise
to a party that is behind almost everywhere is a one-way ratchet — upside noise
crosses the winning threshold, downside noise costs nothing in a seat already
lost.

The deeper problem is that the noise was the wrong *shape*. What the calibration
actually measured was **ordering error**: quantile mapping forces the predicted
distribution of shares across seats to equal the observed one exactly, so the
magnitudes cannot be wrong and only the assignment of shares to seats can be.
The RMSE of 5.045 is entirely mis-ranking. Modelling it as independent additive
noise on each share was therefore unfaithful to the thing measured, and the
ratchet is the consequence.

## What is proposed

Perturb the **ordering index**, not the share. Each draw:

1. Add noise to `idx = ONP_B1 * GRN_share`, the quantity seats are ranked on.
2. Re-run the existing quantile mapping on the perturbed ranking.

The multiset of One Nation shares across seats is **identical in every draw** —
only which seat receives which share varies. So the statewide total is preserved
exactly, and so is the number of seats at any given share level. What is
uncertain is the assignment, which is exactly what was measured.

This is also structurally two-sided in a way additive noise is not: a seat that
currently gets a high share can receive a low one, and vice versa.

## How the noise scale is chosen — the rule, fixed now

**Set the perturbation so that the Spearman rank correlation between the
perturbed ordering and the central ordering equals 0.779** — the correlation
between predicted and actual One Nation shares measured on South Australia 2026
by `scripts/calibrate_onp_seat_sd.R`.

Found by bisection on the noise sd, to within 0.005 of the target, with the
resulting sd written to `docs/CONSTANTS.md`. No grid and no tuning: the target
is a measured quantity and the sd is whatever reproduces it.

**Refusal condition on the constant:** if the required noise sd is so large that
the perturbed ordering is effectively random (rank correlation with the central
ordering below 0.3 at the chosen sd, i.e. the bisection fails to converge on
0.779 from below), do not adopt — that would mean the ordering carries no usable
signal and the honest representation is a uniform allocation, which is a
different change.

## Acceptance criteria, fixed now

- **C1** — One Nation's **median seat count moves by at most 1**, and its **mean
  by at most 0.5**. Stricter than last time's ±2, deliberately: this design
  claims to preserve the expected count, so it should.
- **C2** — ALP and LNP medians move by at most 2 each.
- **C3** — One Nation's 90% seat interval must **widen or stay equal**. It may
  not narrow.
- **C4** — primaries sum to 100 per seat; nothing negative.

## Refusal section — what would make an apparent win unacceptable

Required by `CLAUDE.md` after two experiments where the real decision came from
something found afterwards. Each of these is a **refusal**, fixed now, not a
consideration to weigh later.

- **R1 — one-sidedness.** Count the seats where One Nation's win probability
  rises and where it falls. If **rises exceed falls by more than 3×**, refuse.
  Last time it was 71 against 1. A change that claims to be neutral
  re-assignment must move probability in both directions.
- **R2 — the motivating case must not be the only thing that moves.** If the
  independent in South-West Coast gains probability while the total variation
  across all other seats is negligible (fewer than 10 seats changing by more
  than 0.01), refuse. That would mean the change is reaching one seat, which is
  fitting to the case that prompted it.
- **R3 — no free seats.** If One Nation's mean seat count rises at all while its
  statewide vote share is unchanged, that is the ratchet returning in another
  form. C1 bounds it at 0.5; a rise of any size should be reported prominently
  even when it passes.
- **R4 — the majors must not pay for it.** If ALP's and LNP's *combined* mean
  seat count falls by more than 1 while One Nation's rises, the change is
  transferring seats rather than expressing uncertainty.

## What the criteria cannot see

Stated in advance, since the last two plans were caught out here.

- **Whether the ordering is right at all.** Everything here is calibrated to
  reproduce a correlation of 0.779 measured on ONE election in ANOTHER state.
  If the Greens-share ordering is simply wrong for Victoria, this change makes
  the model honestly uncertain about a wrong ranking, which is better than
  falsely certain but is not correct.
- **Whether independents should win.** No criterion here tests that, on purpose.
  If the result is that independents still never win, this change has still done
  its job if C1–C4 and R1–R4 hold.
- **Seat-level accuracy.** There is no Victorian holdout to score against, for
  the reasons recorded in
  [prereg-independent-projection.md](prereg-independent-projection.md). Nothing
  here demonstrates the seat probabilities got better, only that they stopped
  claiming certainty the calibration says is unwarranted.

## Decision rule, fixed now

- **C1–C4 pass and no R fires** → adopt.
- **Any R fires** → refuse, and do not adjust the design to make it stop firing.
  A second attempt needs a new pre-registration.
- **C1 fails** → the design does not preserve the expected count as claimed.
  Refuse; that is the whole premise.
- **C3 fails** → the perturbation is not reaching the outcome. Check the wiring
  before judging anything else — and unlike last time, verify by inspecting
  per-seat probabilities rather than the seat-count interval, which is not
  sensitive enough to serve as a wiring check.

---

## Result, 2026-08-19: REFUSED on R1

[../reviews/onp-ordering-uncertainty-2026-08-19.md](../reviews/onp-ordering-uncertainty-2026-08-19.md).

The design worked as specified. `ONP_ORDER_SD = 0.3575` reproduces a rank
correlation of 0.781 against the 0.779 target; the multiset of shares is
identical in 200 of 200 draws and the statewide mean ratio is preserved to six
decimals. **C1, C2, C3 and C4 all passed** — including C3, which the previous
attempt failed.

**R1 refuses it.** One Nation's win probability rose in **57** seats and fell in
**13** — a ratio of 4.4×, against a bar of 3×. The improvement over the previous
attempt is large (71:1 → 57:13), so the diagnosis was right; it is still not
two-sided enough.

R3 fired as its report-prominently condition: the mean seat count rose by
**+0.108** on an exactly preserved statewide vote.

**Why preserving the total is not enough.** A seat outcome is a threshold event
and the map from share to win probability is convex over the relevant range, so
moving a high share INTO a seat where One Nation is competitive gains more than
moving it OUT of a safe one loses. The lean survives any reassignment that does
not correct for that curvature.

Refused rather than tuned, per this plan's own rule. R1's 3× is a number I
chose and 4.4× is close to it — which is exactly the reasoning the refusal
section exists to stop.

Kept: `party_draws` in `simulate_seat_contests()` (inert unless passed) and
`scripts/calibrate_onp_ordering.R`.
