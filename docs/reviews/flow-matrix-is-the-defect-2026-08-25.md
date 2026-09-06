# The flow matrix has no cell for a One Nation contest, and the fallback is catastrophically wrong

2026-08-25. Found by asking Pete's question: our primaries in Hammond and
Ngadjuri are excellent and our probabilities are hopeless — is it the flows?

**Yes. And it is not a subtle miscalibration; the numbers are wrong by factors
of eight and twelve.**

## The decisive cells do not exist

`simulate_seat_contests()` looks up a conditional rate keyed on who was
excluded and who survives. For the contests that decide these seats:

| cell needed | present? |
|---|---|
| `ALP \| LNP+ONP` | **NO — falls back to pooled** |
| `ALP \| GRN+LNP+ONP` | **NO — falls back to pooled** |
| `GRN \| LNP+ONP` | **NO — falls back to pooled** |
| `LNP \| ALP+ONP` | **NO — falls back to pooled** |

The matrix is built from **federal 2025**, where One Nation almost never
reaches the final two. So the very contests Victoria 2026 is forecasting have
no conditional cell at all.

## The pooled fallback, against what actually happened

| excluded | our pooled rate to ONP | **SA 2026 actual** | error |
|---|---:|---:|---:|
| **ALP** | **2.9%** | **22.1%** | **7.6× too low** |
| **LNP** | **4.5%** | **54.0%** | **12× too low** |
| GRN | 2.4% | 10.2% | 4.3× too low |

**When the Coalition is excluded, our model sends One Nation 4.5% of its
preferences. Reality sent 54.0%.**

That single number decides Hammond and Ngadjuri. In both, the actual count had
the Coalition finishing third and its preferences electing One Nation. Our
matrix cannot represent that at all.

## The pooled rate is contaminated in a second way

```
pooled ALP:  IND 59.9%  LNP 25.9%  GRN 6.8%  OTH_RIGHT 4.4%  ONP 2.9%
```

**Sixty per cent of Labor's pooled preferences go to independents** — because
the pool averages over every federal contest, and independents were the common
survivor. In a seat with no independent standing, that 59.9% is renormalised
across whoever remains, redistributing a mass that describes a completely
different contest.

That is the failure `CLAUDE.md` records as *"absence of evidence read as
certainty"* and the renormalisation trap that once handed One Nation Richmond —
arriving here from the opposite direction.

## And the flows carry no uncertainty whatsoever

```
simulate_seat_contests() args:
  shares, matrix, party_sd, seat_sd, n_sims, smooth,
  seed, statewide_draws, party_draws, shrink, party_cor
```

**No flow-uncertainty argument exists.** The matrix is one fixed object applied
identically in all 20,000 draws. `CLAUDE.md` already records this — *"flows
enter the seat simulation as constants, so a forecast quantity is treated as
known"* — and the one-step-ahead error of a flow rate was measured at **sd 3.65
points**.

## Why this explains everything Pete asked about

**Why are the probabilities so wrong when the primaries are right?**
In Hammond we project One Nation 27.1 against the Coalition's 26.6 — a lead.
It then loses in essentially every draw because it receives 2.9% of Labor
preferences instead of 22.1%, and 4.5% of Coalition preferences instead of
54.0%. The primaries are fine; the count throws the seat away.

**Why does AEF do better on worse primaries?**
Their One Nation primary in Hammond is 18.8 against our 27.1 — considerably
worse — and they still reach 0.128 where we reach 0.025. A model with correct
preferences and a poor primary beats one with an excellent primary and
preferences that are wrong by an order of magnitude.

**Is this why the calibration slope is bad?**
**Yes, and it is the cleanest explanation available.** A wrong flow rate held
constant across every draw produces the same wrong answer 20,000 times. The
simulation has no mechanism to be uncertain about it, so it is not merely
wrong — it is *confidently* wrong, which is exactly what a slope of 0.299
measures.

## What follows

Three separable pieces of work, in order of value:

1. **Get ONP-versus-major flows from an election that has them.** SA 2026's own
   transfer file is already in the repo, and for a **Victoria 2026** forecast it
   is legitimate — it predates the election. It must not be used to predict SA
   2026 itself.
2. **Fix the pooled fallback.** A pooled rate whose largest destination is a
   party not standing in the seat should not be renormalised onto the
   survivors as though it were informative.
3. **Give flows per-draw uncertainty.** `AUSPOL_FLOW_UNC` was built and never
   adopted; `docs/plans/prereg-flow-uncertainty.md` pre-committed adoption as
   BLOCKED for want of a backtest. **That backtest now exists** — SA 2026 is
   precisely the out-of-sample test that plan said was missing.

**None of these needs demographics, booth data, MRP or betting odds.** This is
where the day's effort should have gone, and the primaries table is what made
it visible.
