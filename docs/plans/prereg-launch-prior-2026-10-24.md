# Pre-registration: launch prior for sitting members under a new label or in a new seat (2026-10-24)

Pete, 2026-10-24: *"a founder or sitting defector carries their own personal vote into the new party."* Diagnosis and
sizing: `docs/reviews/launch-prior-investigation-2026-10-24.md`. Walked with Pete the same day (Pilbara wa2001, Dalrymple
qld2012, Hill qld2017; Hillarys wa2017 as the cost side). His choices: build it as a hold-or-fade mixture, and include
sitting members who moved seat as a separate level.

Written before any code. Nothing below has been run.

## What the arm does

A sitting member at the previous election (corpus `elected`, or a by-election winner) who now stands under a different
label (level 1), or under the same label in a different seat (level 2 adds this), gets a two-outcome vote instead of one
median carry:

- with probability `pi` they **hold**: keep `r_hi` of their previous primary vote;
- otherwise they **fade**: today's carry, unchanged.

`pi = (hi + k * pi0) / (n + k)` over earlier cases only (`fit_pairs_for()`), where a case is "hi" if it kept more than
0.6 of its previous vote, `pi0` is the pooled rate across every jurisdiction, and `k = 3`. `r_hi` is the median kept share
of earlier hi cases, shrunk by n/(n+3) toward the fade carry. No min_n cliff: an election with no earlier case uses `pi0`.

The vote a holding member takes comes out of their old party (on top of `AUSPOL_DEFECT_CONSERVE`, which already leaves the
unclaimed vote with the old party), so in fade draws the old party keeps its vote. Simulator hook: the existing per-seat
insurgent draw in `R/seat_sim.R` (`surge_h`, `surge_mu`, `surge_sd`, `surge_from_zero`). Person matching reuses
`personal_prior_vote()` (`R/candidate_returns.R:527`), `.cs_match` (`R/cross_seat_vote.R:88`) and
`.defector_cross_seat_cases` (`R/defector_state.R:60`); no third matcher.

Switches: `AUSPOL_LAUNCH_PRIOR` = `0` (shipped, off) / `1` / `2`; `AUSPOL_LAUNCH_PRIOR_K` = `3`. Both go into
`scripts/published_flags.R`, `docs/CONSTANTS.md`, `fit_seats_full.R` and all six harnesses in one commit.

## Arms

| arm | setting | differs from baseline on |
|---|---|---|
| baseline | `AUSPOL_LAUNCH_PRIOR=0` (shipped) | - |
| L1 | `AUSPOL_LAUNCH_PRIOR=1` (sitting members, new label) | that switch only |
| L2 | `AUSPOL_LAUNCH_PRIOR=2` (L1 plus sitting members, same label, new seat) | that switch only |

No grid on `k` or the 0.6 cut: one value each, fixed here.

Limiting cases, stated before running: with `pi` forced to 0 the arm must be byte-identical to baseline (a unit test).
An election with no flagged candidate must score exactly 0 in quick_arm.

## Criterion (the standard decision rule)

1. **Primary:** seat-winner log loss (minus the log of the probability given to the actual winner; lower is better) on
   the flagged seats, arm better than baseline by more than 1 SE clustered on election.
2. **Guard:** seat log loss over every seat of every scored election, not worse by more than 1 SE.
3. Leave-one-election-out: primary stays better by more than 1 SE with each election dropped.
4. No single election worse on seat log loss by more than 2 SE of its own paired seat differences.
5. Gain keeps its sign with the two largest-gain seats removed.
6. Named cost seats Ryan fed2010, Buderim qld2017 and Hillarys wa2017 each reported; together not worse by more than 1 SE.

L2 ships only if L1 passes and L2 passes against L1 on the level-2 seats.

**Noise, said before running:** about 50 level-1 seats with 14 winners. The planning effect is -0.003 pooled against
recent arm SEs of 0.0013 to 0.0056, so this test may only be able to refuse. A refusal on that power is reported as
"not shown", not "no effect".

**What would make an apparent win unacceptable:** a gain that comes from raising every defector in seats the party held,
seen as clause 6 failing while the primary passes.

## Running it

1. Named targets first: `scripts/quick_arm.R "AUSPOL_LAUNCH_PRIOR=1" --pairs=wa2001,wa2008,qld2012,qld2017,fed2013,fed2010,wa2017`.
2. Then `--pairs=all` for L1 and L2.
3. Deciding run: `scripts\deciding_run.ps1 -Arm "AUSPOL_LAUNCH_PRIOR=1" -Label launch-prior-l1` at 20,000 sims, all pairs.
   quick_arm floors winner probability at 0.5/N, so the floor seats this arm exists for are only fully visible at 20k.
