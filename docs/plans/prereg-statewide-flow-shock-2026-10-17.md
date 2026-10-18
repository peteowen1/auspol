# Pre-registration (DRAFT, gated): one statewide preference shock per simulation (2026-10-17)

Status: DRAFT. Committed before anything is built; step 0 below must run and pass before the arm is built.
Pete, 17 Oct: fix root causes for everything. Queue item "statewide flow shocks" (NEXT-STEPS).

## The finding

The count draws each flow's noise per seat (`flow_sd`, `R/seat_sim.R`; `fsd` in `src/seat_sim_core.cpp`), so
across 88 seats it averages out and the model treats a statewide preference swing as impossible. Measured on
the 13 transfers files (32 elections, scratchpad `flowvar.R`), on a logit scale:

| flow (vs the other major) | elections | share of variation that is between elections | after a naive time-forward predictor |
|---|---|---|---|
| LNP -> ONP | 6 | 0.59 | 0.60 (3 scored) |
| ONP -> LNP | 18 | 0.42 | 0.38, ~6.9 points |
| GRN -> ALP | 32 | 0.39 | 0.35, ~5.1 points |
| OTH_RIGHT -> LNP | 28 | 0.32 | 0.33, ~9.0 points |
| IND -> LNP | 32 | 0.12 | 0.13 |
| OTH -> ALP | 27 | 0.07 | 0.09 |

## Step 0 (gate, decided now): measure it against the SHIPPED flows

`AUSPOL_FLOW_ORACLE_CONFIGS=tf2 Rscript scripts/score_flows_oracle.R all` writes every real exclusion's
predicted (shipped tf2 flows, actual primaries) and actual split to `output/flow-event-residuals.csv`. Per
excluded class, the Labor-vs-Coalition logit residual per event, then its between-election variance with the
sampling part removed (as in `flowvar.R`). **The arm is built only if, for at least one of GRN, ONP,
OTH_RIGHT, the between-election residual sd is at least 0.15 on the logit scale (about 3.5 points at a 70/30
flow) on 10 or more elections.** If not, the shipped flow model already tracks the statewide swing: closed,
and that result is reported.

## Arm (if step 0 passes)

| Arm | Switch | Rule |
|---|---|---|
| A (shipped) | `AUSPOL_FLOW_SHOCK=0` | per-seat flow noise only. |
| F | `AUSPOL_FLOW_SHOCK=1` | plus one shared shock per simulation per excluded class. |

**F.** In each simulation, for each excluded class c, draw `delta_c ~ N(0, tau_c)` once and apply it to every
seat: the flow row is tilted on the log-odds of Coalition-side (LNP, ONP, OTH_RIGHT) versus Labor-side (ALP,
GRN) recipients, `p_k proportional to p_k exp(delta_c s_k)`, `s_k = +1/2` Coalition side, `-1/2` Labor side,
0 otherwise. `tau_c` is the step-0 between-election residual sd, fitted TIME-FORWARD per target from earlier
elections only and shrunk toward the pooled `tau` by `n / (n + 5)` (n = earlier elections with the class).
Shocks come from a separate random stream (as the Lib/Nat split's draws do), so every other draw is the
shipped one. Both engines, byte-identical (tested). Six harnesses, NT and live.

## Criterion

A shared shock barely changes any one seat's win probability; it changes how seats move TOGETHER. So:

1. **Primary: the probability given to each election's ACTUAL seat totals**, for Labor and the Coalition (log
   of the simulated frequency of the actual count, floored at 1/N), summed over the 35 elections, SE by
   election. **F ships if higher than A by more than 1 SE.** Needs the harnesses to keep each simulation's seat
   totals (a build requirement: check what the cache already holds before adding it).
2. **Guard: seat log loss, every seat**, not worse by more than 1 SE.
3. **Reported:** the width of the 80% interval on Labor's and the Coalition's seat totals, A vs F, per election
   and live vic2026; how often the actual total falls inside it (coverage).

Screen at 5,000 sims (the totals need more draws than one seat's winner), deciding run 20,000; Pete's call.

## What would make an apparent win unacceptable (decided now)

- One election supplies more than half the primary gain -> refused.
- Coverage of the 80% interval moves past 90% (over-wide) on the 35 elections -> reported to Pete before ship.
- Live: any vic2026 party's median seat total moves by more than 1 (a shock is centred, so it should not).

## What this cannot see

- Shocks shared across classes (a year when every minor's preferences lean right together); one per class.
- Flows between the minors themselves (only the Labor-vs-Coalition tilt is shocked).

## Amendment (2026-10-18, before anything is run): the standard decision rule replaces the one-election clause

Pete, 2026-10-18: refusing an arm because one election supplies most of its gain is wrong when no election is worse.
The clause "one election supplies more than half the primary gain -> refused" above is kept as text but is now REPORTED
only; it is replaced by standard rules 3 and 4 in `docs/PRE-REGISTRATION-RULES.md` (leave-one-election-out: still
better by more than 1 SE with each election dropped; no election worse by more than 2 SE of its own seats).
