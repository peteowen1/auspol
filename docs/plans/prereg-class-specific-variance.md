# Pre-registration: variance that scales with the level, per PARTY CLASS

2026-09-03, written before any harness has been run with it. Ticket A1 shipped a
single level-dependent curve for every party; this asks whether that curve
should differ by class. Follows on from
`docs/reviews/level-variance-2026-08-27.md`, which named this as the better-aimed
change and did not build it.

## The problem, in the shipped model's own numbers

`AUSPOL_LEVEL_SD` defaults to `1.10,8.67`, so every party in every seat draws

```
sd(share) = 1.10 + 8.67 * sqrt(p(1-p))
```

The review that adopted it also measured, on NSW, that the seats it was fixing
were not the seats it was widening:

| NSW calibration slope | base | with level_sd |
|---|--:|--:|
| all seats | 0.565 | 0.720 |
| **excluding IND wins** | **0.959** | **1.272** |

Excluding independents the model was **already almost perfectly calibrated**, and
a global widening pushed it from 0.959 to 1.272 — past 1 and out the other side.
The miscalibration lives in the non-major seats; the fix was applied everywhere.

## The change

Two new parameters, multipliers on the slope `b`, splitting non-majors from each
other rather than only from the majors:

```
majors (ALP/LNP/NAT):  sd = 1.10 + 8.67 * sqrt(p(1-p))              unchanged
independents (IND):    sd = 1.10 + 8.67 * m_IND * sqrt(p(1-p))
other non-majors:      sd = 1.10 + 8.67 * m_OTH * sqrt(p(1-p))
```

`m_IND = m_OTH = 1` recovers the published model exactly, which is how the no-op
is proven. Class comes from `classify_party()` and nothing else — per the
one-source-of-truth rule in `CLAUDE.md`, never from a field someone else
classified.

**Splitting IND from the other non-majors is the point, not an elaboration.**
The review's finding was specifically about independents. A pooled non-major
class would answer a different and easier question, and a win on it would not
license the claim that independents need more variance.

## The grid, fixed before anything runs

Staged, because a full 5x5 grid is 25 arms across five harnesses and the
background-task cap makes that unaffordable.

```
Stage 1:  m_OTH = 1.00 fixed;  m_IND in {1.00, 1.25, 1.50, 1.75, 2.00}
Stage 2:  m_IND at the stage-1 winner;  m_OTH in {1.25, 1.50}
```

Seven arms. `m_IND = m_OTH = 1.00` is the control and must reproduce the
published output. **Stage 2 runs only if stage 1 passes its criterion**, on the
same terms A2 imposed on A3.

**The grid is multipliers, not a fitted curve, deliberately.** Fitting a
per-class curve first and then registering a test of the fitted value invites the
question of whether the grid was drawn around the answer. The fitted per-class
curves will be computed and **reported** alongside, but the decision runs on the
grid.

## Primary criterion

**Mean paired change in log loss on seat-elections a NON-MAJOR won, clustered on
the seat, pooled across all five harnesses. Must improve by at least 1.171.**

Log loss first is the standing metric order in `CLAUDE.md`. The subset is named
in advance because this is a targeted change, so per the targeted-fix rule the
election-wide number is the guard, not the criterion.

### Where 1.171 comes from

Sized on the matched federal pair already on disk — `backtest-fed-n3000.csv`
against `backtest-fed-lv110_867-n3000.csv`, 886 seat-elections, the same seats
under both arms — so the standard error is of the **paired difference**, not of
the level. That federal sd is then applied to the pooled win counts:

| subset | pooled n | fed paired sd | SE | **MDE (2.80 SE)** |
|---|--:|--:|--:|--:|
| **any non-major won** | **87** | 3.901 | 0.418 | **1.171** |
| IND won | 55 | 4.368 | 0.589 | 1.649 |
| other non-major won | 32 | 3.090 | 0.546 | 1.530 |
| a major won | 1,461 | 0.960 | 0.025 | 0.070 |
| all seats | 1,548 | 1.355 | 0.034 | 0.096 |

For scale: level_sd delivered **−1.705** on federal non-major wins (p = 0.004)
and **−1.968** on federal IND wins (p = 0.020).

**Setting the bar from the pooled n is not choosing a tolerance after seeing the
result.** How many seat-elections a non-major won is a property of who won
elections that are already over. It is computable, and was computed, without
running a single arm. What must not be chosen after the fact is the tolerance
given the *answer*, and nothing here depends on that.

**The one-way ratchet.** The sd above is federal, applied to a pooled sample on
the assumption it transfers. If the observed pooled paired-difference sd comes in
**above** 3.901, the bar is recomputed **upward** at scoring time and the change
must clear the higher bar. If it comes in below, **the bar stays at 1.171**. The
asymmetry is the whole safeguard: a surprise that makes the test easier is not
allowed to.

### The IND subset is a co-primary, and it now has the power

**IND-won seats must also improve by at least 1.649.** Both must hold.

This was nearly excluded. Sized on federal alone (n = 30) the IND MDE is 2.233,
larger than the 1.968 that level_sd delivered there — a criterion that would
refuse a change the size of the last one that worked. Pooled across five
harnesses n reaches 55 and the MDE falls to 1.649, under the plausible effect. So
the co-primary is admissible only because it is pooled, and this document would
have been wrong to scope it to federal.

## Secondary, and these are guards not criteria

- **Election-wide log loss must not worsen by more than 0.096.** A change that
  buys non-major seats by wrecking the rest is refused whatever the primary says.
- **Log loss on seats a MAJOR won must not worsen by more than 0.070.** This is
  the mechanism check: the majors' curve is untouched by construction, so any
  movement beyond simulation noise means the class filter is leaking.

## Dry-run: verdicts fixed before running

| case | expected | what it tests |
|---|---|---|
| `m_IND = m_OTH = 1.00` | **byte-identical** to today's published output | the no-op. If it differs the wiring is wrong and nothing else in this document means anything |
| a seat where LNP polls 60% | **unchanged** at every setting | the class split. The majors' curve must not move — this is the whole difference from A1, and if a major's probability shifts beyond simulation noise the filter is leaking |
| Dai Le, Fowler 2022 (projected 1.8%, actual 29.5%) | log loss **improves** as `m_IND` rises | direction. A1 made her worse by narrowing the band at 1.8%; an IND-only widening must move her the other way |
| a GRN-won seat at stage 1 | **unchanged**, because `m_OTH = 1.00` there | the IND/other split itself. If Greens move while only `m_IND` varies, the two classes are not separate |

The second and fourth are the discriminating ones. A1 already widens everything;
if the majors move, or if the Greens move at stage 1, this arm is A1 again with a
bigger number.

## Refusal — what disqualifies a winner

- **If the majors' calibration slope moves by more than 0.05** in either
  direction. The premise is that they were already right; touching them refutes
  the premise, not the criterion.
- **If a flat widening captures the same gain.** A control arm raising the slope
  for EVERY class — majors included — runs alongside the winner. If it matches
  the primary within the MDE, ship nothing and record that the class split was
  not the mechanism. This is the spread-versus-slope confound that sank the
  deviation slopes; it applies unchanged.
- **If any party's Victoria 2026 median seat count moves by more than 3.** Stop
  and hand the decision to Pete. Same threshold as A1, which moved ALP by 2.
- **If the gain sits in one harness.** Report per-harness; a change positive on
  federal and negative on two others is a federal artefact.
- **If the winning `m_IND` is at the edge of the grid** (2.00). The grid was then
  drawn too narrow to contain the answer, and the result is a direction, not a
  value. Re-register a wider grid rather than shipping the edge.
- **If the co-primary passes only because the pooled subset is dominated by one
  election.** fed2022 and fed2025 carry 20 of the 55 IND wins between them.
  Report the leave-one-election-out primary; if dropping any single election
  takes it below the bar, that is a refusal.

## What the criteria cannot see

- **87 non-major wins carry the whole primary**, 55 of them independents. No
  quantity of major-party seat-elections changes that, and it is the binding
  constraint on everything here.
- **One Nation cannot be scored at all.** It won **4** seat-elections across all
  five harnesses. The SA 2026 seats called 0.000 are the failure that motivated
  the candidate model, and they sit inside `m_OTH` with GRN (18), OTH_RIGHT (6)
  and OTH (4). A stage-2 win says the *other-non-major* class needs more
  variance; it cannot say One Nation does.
- **Nothing here is candidate-level.** It is a property of the share and the
  party class, not of the person standing. Salience remains the intended fix for
  emergence and is still unshipped, so that cost is current, as it was for A1.
- **The 0-1% band still breaks the pattern** (residual sd 4.22 against a fitted
  2.7) because it contains the emergences. Widening the slope does not reach it:
  at p = 0.018, `sqrt(p(1-p))` is 0.133, so even `m_IND = 2.00` moves the sd from
  2.25 to 3.41. If the primary turns on Fowler-type seats, that is a finding
  about the intercept, not the slope, and needs its own registration.
- **The paired sd is federal and assumed to transfer.** Guarded by the one-way
  ratchet above, but a badly wrong assumption still costs a wasted run.

## Run settings, added 2026-09-03 before any arm was scored

**The grid runs at `AUSPOL_N_SIMS=5000`, not the harness default of 20000.**

A visible addition, not an edit: nothing above is changed, and no arm had been
scored when this was decided. `n_sims` is a harness setting rather than a model
parameter, and the arms on disk already run at 300, 2500, 3000 and 5000.

Measured on South Australia, same seed, same arm, 5000 against 20000:

| | |
|---|--:|
| mean change in `pred_p` | 0.00186 |
| max change in `pred_p` | 0.01415 |
| change in log loss on the non-major subset | −0.0066 (sd 0.0105) |
| worst move among the 20 seats above `pred_p` 0.999 | 0.0005 |
| **effect the primary must detect** | **1.171** |

Simulation noise is about **1/180th** of the effect, and the extreme tail — the
region log loss punishes hardest and the reason log loss is the primary at all —
barely moves. Stage 1 goes from roughly 9 hours to 2.4.

**Does this favour the answer found later?** No, and it cannot: it was fixed
before any arm was scored, it applies identically to the base and to every arm,
and the paired design uses one seed so what noise remains largely cancels.

**The winning setting is re-verified at `n_sims = 20000` before anything ships.**
The published forecast keeps 20000 regardless; this governs the backtest only.

## Amendments

None. Any change to this document must be a visible addition with the original
clause left unedited, and must state whether it favours the answer found later.
