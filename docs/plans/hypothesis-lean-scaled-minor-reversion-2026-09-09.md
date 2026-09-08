# Hypothesis: minor-to-central-party reversion scaled by seat lean

Not pre-registered, not designed, **not to be implemented** until a design
session with Pete works through real example seats per `CLAUDE.md`'s own
rule ("BUILDING a model... design it WITH Pete, on real examples from the
data, before writing the rule"). This file exists so the idea survives
between sessions, nothing more.

## The idea, in Pete's words (2026-09-09)

Melbourne (fed2025) is Labor winning back a large share from the Greens —
row 3 of the worst-seats-vs-AEF table
(`docs/reviews/` — see the session's AEF-comparison table, not yet a
standalone review doc). Current guess: **how much a minor party's vote
reverts to its "more central" counterpart should scale with the seat's
underlying lean**, not be a flat statewide reversion rate. Candidate
instances of the same shape:

- **GRN → ALP**, in a seat/election where Labor is polling well nationally
  (Melbourne fed2025).
- **ONP → LNP**, in a seat/election where One Nation's vote is soft and
  the seat leans conservative underneath.
- **LNP → teal**, in an election where LNP is polling weak nationally —
  Pete's own note that this might be the *same mechanism* as the teal
  emergence problem, just viewed from the other side (the swing away from
  LNP, not just the emergence of the IND/teal candidate).

## What exists today (checked 2026-09-09, before any design session)

- No seat-lean-scaled flow mechanism exists anywhere in the live candidate
  path. `R/flow_trend.R`'s `margin` is a **preference-flow** total (votes
  moving from party A to B across a whole election), not an electoral
  **lean/TPP-margin** concept — different thing, same word.
- The teal-side fix already shipped (arm C, salience-expected/exp-sd,
  `docs/plans/prereg-salience-expected-and-variance-2026-09-07.md`) has no
  seat-lean term either — it works entirely through the Google Trends
  salience screen, uniformly across governed candidates.

## Before this can be pre-registered

1. Pull 5-10 real seat examples covering all three legs (GRN→ALP,
   ONP→LNP, LNP→teal), each showing: the seat's prior TPP/lean, the
   minor party's incumbent-election share, the swing back to the central
   party, and whether lean predicts the SIZE of that swing. Only Melbourne
   is identified so far — the ONP→LNP and LNP→teal examples still need
   pulling from data before this is discussable, not assumed.
2. Decide what "seat lean" means operationally here — TPP margin at t-1?
   A smoothed multi-election average? This repo has no existing column for
   it in the candidate path, so it would be new plumbing, not a wire-up.
3. Name the refusal conditions up front, per `CLAUDE.md`'s pre-registration
   rule — in particular: does this double-count with the salience screen
   (which already treats emergent/governed candidates asymmetrically), and
   does scaling by lean risk pushing SA/VIC/WA the wrong way the way arm C
   did on the teal side.
