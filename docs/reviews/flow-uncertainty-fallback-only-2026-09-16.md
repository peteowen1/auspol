# Flow-rate uncertainty: three levers tried, one real result kept

2026-09-16, following the Mirani/South Brisbane diagnosis (`docs/reviews/
base-pred-blind-to-tonights-fixes-2026-09-16.md` covers the base_pred side;
this covers the flow side). Both seats: our predicted primary matches AEF's
almost exactly, but our win probability for the actual winner is far below
AEF's, because the deciding preference flow comes from a cell with 0-1 real
observations in the qld2020 corpus and falls back to a broad "pairwise" rate.

## Lever 1: `fallback_smooth` (already built, off by default)

Extra blend toward uniform, applied only to fallback-tier transfers. Swept
0 -> 0.6 on Mirani: essentially no effect (win probability 89.7% -> 89.5%).
Not the mechanism.

## Lever 2: `flow_sd` (already built, off by default) -- blanket noise

Per-draw Gaussian noise on every transfer's rate, not just the point
estimate. This one works on the target: `flow_sd=20` moves Mirani's LNP win
probability 8.8% -> 31% (toward AEF's 41.6%) and qld2024's own pooled log
loss improves (0.3089 -> 0.2995).

**But it is not general-safe.** qld2020 (the sibling pair) gets WORSE as
`flow_sd` rises, so Queensland combined is close to a wash. Federal --
1,051 seat-elections, by far the largest, most powerful sample -- gets
clearly worse: log loss 0.2543 -> 0.2607 at `flow_sd=15`. **Not shipped as a
blanket default.**

## Lever 3: `fallback_flow_sd`, built tonight -- the surgical version, and it doesn't work

Hypothesis: confine the noise to ONLY the sparse/fallback-tier transfers
(same condition `fallback_smooth` already uses), sparing well-measured exact
cells, to get lever 2's targeted gain without its corpus-wide cost.

Built into `src/seat_sim_core.cpp` and the R reference engine
(`R/seat_sim.R`), both kept byte-identical to the pre-existing behaviour at
`fallback_flow_sd = 0` -- full `test-seat-sim.R` suite (91 assertions)
passes unchanged.

**Tested and it fails on BOTH counts.** Swept 0 -> 80 on qld2024: Mirani's
win probability barely moves (0.0956 -> 0.089, essentially flat) and South
Brisbane barely moves either (0.030 -> 0.027) -- while pooled qld2024 log
loss still gets worse (0.3089 -> 0.3110), for no compensating gain.

**Why**: the uncertainty that helped Mirani under blanket `flow_sd` evidently
lives in the EARLIER exclusion rounds too, not just the final sparse one.
Mirani's count excludes several minor candidates before reaching the
ALP-vs-{LNP,OTH_RIGHT} split; those earlier rounds have real conditional
cells (`got_cell = TRUE`) and so get none of `fallback_flow_sd`'s noise --
but a measured cell still drifts between elections (the existing `flow_sd`
docstring's own example: One Nation's rate to the Coalition measured at
47.4/60.4/47.6/61.6 across four real elections). **"Fallback vs measured" is
not the axis separating reliable transfers from unreliable ones** -- a
well-measured historical rate can still be a poor predictor of the next
election's rate, and this parameter cannot see that.

**Kept as tested, working, documented, default-off infrastructure** --
`fallback_flow_sd = 0` changes nothing, so there's no cost to leaving it in
the tree -- but it is not the fix for Mirani or South Brisbane.

## What IS real and shippable: our own final-two scenario tracking

`simulate_seat_contests()` already computes, per draw, which two parties a
seat's count comes down to (`tcp_winner`/`tcp_runnerup`) -- every harness
discarded this after computing the single headline scenario. `tcp_scenarios()`
(new, `R/tcp_scenarios.R`) aggregates it into a per-seat table of every
pairing that occurred and how often, directly comparable to AEF's own
`seatTcpScenarios` (`scripts/build_aef_tcp.R`).

Wired into `backtest_candidate_qld.R` as a proof of concept (writes
`output/backtest-<pair>-ourtcp<tag>.csv`). Immediately confirms the
diagnosis from a new angle:

| seat | our scenario split |
|---|---|
| Mirani | OTH_RIGHT-v-LNP 84.1% · OTH_RIGHT-v-ALP 10.6% · LNP-v-ALP 5.4% |
| South Brisbane | GRN-v-LNP 67.4% · GRN-v-ALP 31.9% · ALP-v-LNP 0.7% |

**Both are genuinely three-way by our own simulation's reckoning, not the
clean two-horse races a single win-probability number implies.** South
Brisbane in particular: our own draws already put real weight (32%) on the
GRN-vs-ALP shape that's closer to what actually happened, but that gets
compressed away by the time it reaches a single scenario's headline number.

**Not yet done, and this is the natural next step**: port to the other five
harnesses, wire into the AEF-7 artifact as an "our final two" column beside
AEF's, and — the more consequential use — the scenario spread itself
(`1 - max(freq)`, or an entropy measure over the scenario table) is exactly
the "is this a potential three-way seat" flag that doesn't currently exist
anywhere in the model. That flag is the natural candidate for BOTH (a) a new
feature in the primary xgb model (Pete's question: does one party's
uncertainty flow into another's prediction? -- currently no party's
prediction sees any other party's features at all, a separate real gap) and
(b) the right axis to scale flow uncertainty by per-seat, which is what
lever 3 was reaching for and missed.
