# Pre-registration: a class's statewide vote kept in the seats it contests, 2026-10-19

Committed BEFORE either arm is built or run. Pete: "go" (19 Oct, after the trace). Decision rule: the standard rule at
the top of `PRE-REGISTRATION-RULES.md`, no departures. Evidence: `reviews/miss-diagnosis-aef7-2026-10-19.md`.

## The defect: two mechanisms

1. **Zeroing drains the class (CONFIRMED in code).** `zero_unnominated()` (`R/nomination_zero.R:41-90`) zeroes a class
   in every seat where it has no candidate and gives the freed share to that seat's other classes. The class's
   statewide total falls by the share of seats it skipped, and nothing returns it to the seats it contests.
   nsw2023: One Nation stood in 17 of 93 seats; level 1.84 (actual 1.80, right); contested seats given about 2 to 5,
   actual 5 to 15 (1.84 x 93/17 = 10.1 expected per contested seat). Live: inert until nominations (9 Nov), then
   acts on every class that skips seats.
2. **A class absent last time is not modelled (CONFIRMED in the SA harness; others to check while building).** The
   harness's classes come from the previous election's matrix (`scripts/backtest_candidate_sa.R:766-778`), so a party
   that returns after an absence has no column and is forecast at exactly 0 wherever it stands. sa2022 (19 seats,
   actual 3 to 11), nsw2019 (12 seats). wa2001 is a likely third (One Nation mean error +6.04 over all seats).

## The arms (both default "0", measured separately, then together)

- **A, `AUSPOL_CLASS_CONSERVE=1`**: inside `zero_unnominated()` (so every harness and `zero_unnominated_live()` reach
  it through one function), after zeroing: for each class that lost share, scale its remaining (contested) cells so
  the class's seat-mean total equals its pre-zeroing seat-mean total, then renormalise each row by taking the
  added share proportionally from that row's other classes. Iterate the scale-and-renormalise to a 0.01-point
  tolerance (renormalising shrinks the scaled cells a little each time). Equal seat weights, as the seat-mean
  checks above use. No cap. Prints the class, seats contested, total before and after.
- **B, `AUSPOL_CLASS_ENTRY=1`**: in every harness that builds its classes from the previous election, a class with
  candidates in the target election and a statewide level from the level model but no column gets one, at its
  statewide level in every seat where it stands (then arm A's conservation applies to it). Prints each class added.
  Built in every harness with that structure; a harness where it cannot apply says why in the commit.
- Not changed: the level model, the trees, the concentration profile across contested seats (arm A keeps each
  seat's relative standing; where a profile exists it is untouched).

## Measurement

1. Screen each arm with `quick_arm.R --pairs=all --slots=1` (memory is tight; never alongside a deciding run), then
   A+B together.
2. Deciding run (20k) for the best arm or combination that is not WORSE.
3. Score with `scripts/score_quick_targets.R` (targets: seats with a cell moved by more than 0.05 points).

## Decision (standard rule)

Primary: target-seat log loss better by more than 1 SE (clustered on election). Guard: all seats not worse by more
than 1 SE. Leave-one-election-out holds. No election worse by more than 2 SE of its own seats. Without the two
largest-gain seats the gain keeps its sign. Reported, not voted: squared share error on the moved cells (expected to
fall clearly; the class's own cells should move toward actual in most elections), direction (contested cells up),
the 1e-4 floor, each election's share of the gain, AEF-7.

## Named in advance: what would make a win unacceptable

(a) The gain lives only at the floor. (b) The moved cells' share error RISES while seat log loss falls: a win from
the wrong numbers. (c) Live: before shipping, a vic2026 walk with a simulated nomination list (One Nation skipping
the 20 seats where it polled least in 2022) shown to Pete, since the live effect only appears after 9 Nov.
Known blind spot: arm A conserves the PREDICTED level; if the level itself is wrong (sa2026 20.4 vs 23.0, wa2025
1.94 vs 4.03) it conserves the wrong total. That is a level question, separate from this.
