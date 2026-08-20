# Pre-registration: re-test the seat-swing port on three elections, with a rule for the middle

Written 2026-08-20, **before the re-test runs**. Committed before running.

An **addition** to
[prereg-seat-swing-port-to-candidate.md](prereg-seat-swing-port-to-candidate.md).
That plan is **left unedited**; its rule stands as written for the run it
governed.

## Why re-testing is legitimate rather than a second bite

[../reviews/seat-swing-port-2026-08-20.md](../reviews/seat-swing-port-2026-08-20.md)
refused the port at **−0.04 SE** and named the reason in its own text: *"the
evidence is 88 seats, one election — precisely the sample size that today said
the independent model improved by 1.46 SE when six elections said it did not."*

Since then the corpus grew: Queensland correspondences were built, the seat
sample went from 180 to 548, and the scorable elections from two to seven. The
candidate backtests now cover **three** elections (Victoria 2018, Victoria 2022,
NSW 2023) where the port was tested on one.

**Same feature, same criterion, same code, more data.** Nothing about the port
has been changed to make it look better.

## The honest check on this amendment

`CLAUDE.md` requires asking whether an amendment favours the answer already
seen. **It does not.** The previous result was −0.04 SE — zero to three decimal
places — which lands in zone 2 below and would be **deleted**, not rescued. A
rule written to rescue that result would have to reach below zero, and this one
does not.

## THE POWER CALCULATION, DONE FIRST

The independent observation is the **election**, not the seat: seats within a
cycle share a flow matrix and the statewide draws, so they are not independent.
Three elections means a clustered standard error on **2 degrees of freedom**.

**This test is very unlikely to clear 2 SE, and that is stated before it runs.**
The per-seat SE on one election was 0.0099; three elections clustered will not
shrink that to where a real-but-small effect becomes visible. **Zone 3 below is
therefore the expected landing place, not an escape hatch reached for
afterwards.**

Both are reported: the per-seat SE (comparable with the original run) and the
election-clustered SE (the honest one).

## Three zones, fixed now

**Zone 1 — clears 2 SE on the clustered difference.** Adopt. Turn
`AUSPOL_SEAT_SWING_PORT` on by default and delete `simulate_seats()`.

**Zone 2 — the difference is zero or negative.** Delete the port and
`simulate_seats()` with it. A feature that does not help after three elections
is not waiting for a fourth.

**Zone 3 — positive but short of 2 SE.** Decided on these four, named now:

1. **Prior plausibility.** `fed_swing` is independently validated: on two state
   elections it cuts held-out seat-swing MAE from **3.9476 to 3.3655**. This is
   a known-real signal being asked whether it survives into a noisier target,
   not a speculative feature fishing for significance. **Counts in favour.**
2. **Direction consistency.** The improvement must be positive in **at least 2
   of 3** elections. One election carrying it counts against, whatever the
   pooled number.
3. **Detectability.** If the power calculation says an effect of the observed
   size was never detectable at this sample, "did not clear the bar" carries no
   information and is not read as evidence against.
4. **Mechanism check.** The port must move the primaries it claims to
   (`seat_swing_adjustment()` applied one-for-one) and must not move the
   statewide totals — it sums to zero by construction, so a non-zero statewide
   shift means it is doing something other than advertised. **A failure here
   overrides everything above.**

**Adopt in zone 3 only if 1, 2 and 4 all hold.** Two of three is not enough.

## Refusals — what disqualifies an apparent win

- **P1 — a win resting on one election is refused**, per zone 3 rule 2.
- **P2 — calibration must not degrade.** If the port improves the Brier score
  while moving the calibration slope away from 1, it is trading honesty for
  score and is refused. Carried over from the original plan.
- **P3 — no re-reading NSW 2023 alone.** Its −0.04 SE is published. If this run
  changes that number, something upstream moved and the run is invalid until
  explained.
- **P4 — the Victorian harness must be ported without other changes.** The port
  block moves from `backtest_candidate_nsw.R` to `backtest_candidate_vic.R`
  unchanged. Any edit to it is a different experiment.
- **P5 — zone 3 must not become the default answer.** If the result lands in
  zone 3 and rules 1, 2 or 4 fail, the outcome is **zone 2**: delete. Zone 3 is
  a way to accept a small real effect, not a way to avoid deciding.

## What this cannot see

- **Whether it helps Victoria 2026 specifically.** All three test elections are
  two-major contests. The election being forecast has One Nation near 21%, and
  `seat_swing_adjustment()` moves votes between ALP and LNP only — so it is
  silent about exactly the seats most in doubt.
- **Anything below the detection floor**, which the power calculation says is
  most of the plausible range.
