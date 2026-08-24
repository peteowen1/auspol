# Pre-registration: the per-cycle volatility gate, and NSW 2027's One Nation

Written 2026-08-25, **before** any arm is fitted or scored. Committed before
running.

## The standing symptom

`fit_nsw.R` halts. `NL3` breaches: One Nation's fitted endpoint for the NSW
2027 cycle is **19.52 against 24.67** from its last 90 days of polling, a
5.15-point deviation against a `POLL_TRACKING_BOUND` of 2.5. This has kept
the scheduled job red and is recorded in `docs/NEXT-STEPS.md` as "NSW 2027
keeps CI red".

`docs/NEXT-STEPS.md` diagnoses it as: *"the per-cycle-volatility floor (15+
polls) excludes ONP's 8-poll series, forcing the generic slow random walk
onto the one party moving fastest."*

## Diagnosis first, and it corrects that description in two ways

Run before writing this plan, because acting on the recorded description
would have produced a false negative. Nothing below is a result; it is what
the code does, established by reading and running it.

### 1. There are TWO gates, not one, and BOTH exclude One Nation

`fit_nsw.R:132` is `ps <- intersect(names(cnt)[cnt >= 15], est_parties)`.

| gate | rule | ONP in NSW | verdict |
|---|---|---:|---|
| per-cycle count | `cnt >= 15` in **this** cycle | 8 polls (2027) | **FAIL** |
| `est_parties` | `counts >= 20` across **both** cycles | 7 + 8 = 15 | **FAIL** |

An `intersect()` needs both. **Lowering only the 15 would change nothing**,
and a byte-identical output would read as "this input does not matter" —
precisely the hazard `CLAUDE.md` records for an experiment that never ran.
The recorded diagnosis names only the first gate.

### 2. Victoria already solved this and NSW never got the fix

`fit_vic.R:157` is `ps <- names(cnt)[cnt >= 15]` — **no intersect** — and
`fit_vic.R:161-162` falls back to `default_sigmas()` when a party has no
pooled estimate. Its own comment (`fit_vic.R:148-152`) says this is
deliberate and names One Nation as the reason. `fit_nsw.R` keeps the
intersect and has no fallback, so it would error on a party absent from
`est_parties` rather than default.

That is a sister-script divergence of the kind `CLAUDE.md` records
repeatedly. **It is a correctness fix in its own right and it is NOT this
experiment**, because it does not fix the breach: ONP's 8 polls fail
`cnt >= 15` in both scripts. It is listed here so the two are not confused,
and so porting it is not later mistaken for having tested the threshold.

### 3. What One Nation actually did in the NSW 2027 cycle

| date | ONP |
|---|---:|
| 2025-12-01 | 4 |
| 2025-12-14 | 16 |
| 2026-02-18 | 30 |
| 2026-02-28 | 21 |
| 2026-03-12 | 23 |
| 2026-05-01 | 22 |
| 2026-06-17 | 27 |
| 2026-07-01 | 25 |

Eight polls, 4 → 25 in seven months, and only **3 of them inside the 90-day
window `NL3` scores against**.

## The question

Does letting a thinly-polled, fast-moving party estimate its own per-cycle
volatility improve the forecast — or does the floor exist for a good reason
and the breach is the check pointing at thin data rather than at a defect?

**Both are live, and the second is not a rationalisation.** `CLAUDE.md` and
`docs/reviews/poll-lag-2026-08-19.md` already record that following the polls
more closely would have been *worse* across the whole record (MAE 1.755
against 1.862), and that the one historical case shaped like this —
**WA 2017 One Nation, polls 10.3, fitted 7.8, actual 4.9** — had the trend lag
the polls by 2.5 points and still finish 2.9 too high. Across all three
completed One Nation cycles the repo **over**-states the party by +1.42.

So the null here has real support, and an arm that tracks the polls more
closely is not automatically better.

## The criterion, fixed now

**Held-out first-preference MAE against the eventual result**, over every
completed cycle with complete actuals — the same 33-cycle / 125-comparable-row
set `scripts/test_inclusion_floor.R` scores on, and scored **only on the rows
every arm fits**, so no arm can win by declining to predict. This is the same
criterion the inclusion-floor experiment used and it is chosen for that
continuity, not selected here.

Standard error **clustered on the cycle**, not on the party-cycle: first
preferences sum to 100 within a cycle, so parties inside one are not
independent observations. `CLAUDE.md` records this exact mistake (139
party-cycles that were really 33 independent ones).

### THE CRITERION IS NOT "THE BREACH GOES AWAY"

Stated as its own heading because it is the way this experiment most plausibly
goes wrong. Making `NL3` green by fitting the polls more closely is optimising
for the check, and the historical record above says that is the wrong
direction. **An arm that clears `NL3` and does not improve held-out MAE is a
refusal, not a win.**

## The grid, fixed now

Applied to `fit_nsw.R`'s `walk_of()`, with the `est_parties` intersect removed
and Victoria's default fallback in place for every arm (so gate 1 cannot
silently bind and produce a null result):

- per-cycle threshold: **8, 10, 12, 15 (status quo), 20**

Victoria's own `cnt >= 15` moves in lockstep in a second run, reported
separately, because the two scripts having *different* thresholds is a new
sister-script divergence and the point of this work is to remove one, not add
one.

## The decision rule, fixed now

- **Adopt the best threshold only if it beats 15 by more than 2 clustered SE**
  on held-out FP MAE. Two SE is this repo's standard bar (the
  statewide-covariance and independent-emergence work both used it).
- **Ties inside 2 SE go to the status quo**, 15.
- **If the curve is not monotonic and the winner is an isolated spike**, do not
  adopt — with 33 clusters that is noise, and picking the argmin of a noisy
  curve fits the constant to its own test set.
- **Report the number of affected (cycle, party) rows BEFORE reading any MAE**,
  and **abort if fewer than 10**. A threshold change that moves three rows
  cannot be measured at 2 SE on this corpus, and reporting a number from it
  would be false precision. If it aborts, the honest output is "this cannot be
  decided on the available record", not a verdict.

## Refusal: what would make an apparent WIN unacceptable

Required by `CLAUDE.md` because two of this project's three experiments were
refused on grounds invented after seeing the result. Named in advance:

- **R1 — it makes One Nation worse where we can check it.** If the winning arm
  increases MAE on ONP specifically across the three completed ONP cycles
  (WA 2017, and the two others in the record), refuse regardless of the pooled
  number. The pooled criterion averages over the exact party the mechanism
  targets, and the record says this party is the one we already over-state.
- **R2 — it is a one-way ratchet on minor parties.** If the winning arm raises
  the fitted endpoint for thinly-polled parties in most cycles and lowers it in
  almost none, refuse. That is the asymmetry `docs/reviews/onp-seat-uncertainty-2026-08-19.md`
  already caught once (71 seats up, 1 down) and it indicates the change is
  adding upside rather than accuracy.
- **R3 — it only helps where the actuals cannot see it.** If the gain
  concentrates in (cycle, party) rows the eventual results do not break out
  separately, refuse: that is the inclusion-floor failure mode, where an arm
  won by matching the granularity of the historical record rather than by
  forecasting better.
- **R4 — Victoria's published forecast moves materially.** Victoria 2026 is the
  only forecast this repo publishes. Any arm that changes its ONP endpoint by
  more than 1.0 point must be reported prominently and adopted only with that
  change stated, never as an incidental side effect. (ONP has 19 polls there
  and passes `cnt >= 15` already, so the expectation is no movement at all —
  which means **any** movement is a signal something else changed.)

## What the criterion cannot see, stated in advance

- **Whether `NL3` is the right check for a 3-poll window.** The bound of 2.5 is
  the 99th percentile of |fitted − polls(90d)| over 138 historical
  party-cycles, but the breach size orders by how few polls name the party
  (Victoria 2026 ONP breached at 2.78 on 10 polls; NSW 2027 at 5.15 on 3). That
  is consistent with thin data rather than a modelling error, and **no arm of
  this experiment tests it.** If every arm is refused, that question is what
  remains, and it needs its own plan — not a quiet loosening of
  `POLL_TRACKING_BOUND`.
- **The 2027 cycle itself has no actual result** and cannot be scored. The
  criterion is entirely historical; NSW 2027 is the motivating case and is
  *not* evidence about it.
- **Nothing here tests the `est_parties` gate on its own.** It is removed in
  every arm as a precondition, so this experiment cannot say whether removing
  it was right — only what the per-cycle threshold is worth given it is gone.

## Prediction, written before running

Recorded so a result that improves a slice it cannot reach reads as a bug
rather than a bonus, per `CLAUDE.md`.

Expect the affected-row count to be **small** — parties with 8–15 polls in a
scorable cycle are uncommon in this corpus — and the abort clause to be a
real possibility rather than a formality. If it does clear 10 rows, expect the
pooled MAE difference to be **small and inside 2 SE**, because the historical
record says following minor-party polling more closely is not an improvement.

**Victoria 2026's ONP endpoint should not move at all.** It already passes
`cnt >= 15`.

---

## Result, 2026-08-25: ABORTED, and the abort gate above was mis-specified

Run by `scripts/test_walk_threshold.R`. **No arm was scored.** The prediction
above — that the abort clause was "a real possibility rather than a
formality" — was right, but for a reason the plan got wrong.

### The gate passed as written, and the gate was measuring the wrong unit

| unit | count | floor | verdict |
|---|---:|---:|---|
| scorable affected **rows** | 15 | 10 | passes |
| independent **cycles** those rows sit in | **6** | 10 | **aborts** |

This plan fixed "abort under 10 affected ROWS" in one section and "standard
error clustered on the CYCLE, because first preferences sum to 100 within a
cycle" in another. **Those two clauses are inconsistent** — a row gate cannot
protect a cycle-clustered SE. Six clusters is about five degrees of freedom,
where the plan's own 2 SE bar is not a 95% test at all (t(5) needs 2.57).

This is the failure `CLAUDE.md` records twice — a tolerance written without
computing its size in SE — committed in a plan written the same day that rule
was re-read, and by the person who had just re-read it. Recorded as an
amendment with the original clause left unedited above.

**Checked, as `CLAUDE.md` requires, whether the amendment favours the answer
found later: it does not.** Aborting leaves `fit_nsw.R` red and this problem
unsolved. The convenient outcome would have been to score the arms on 15 rows,
find something, and ship a fix. The corrected unit forbids that.

### The finding that matters more than the abort

Of the 15 scorable affected rows, only **2** are the case this experiment is
about — a thinly-polled *minor* party moving fast:

| cycle | affected parties | is this the mechanism? |
|---|---|---|
| nsw 2019 | ONP | **yes** |
| wa 2017 | ONP | **yes** |
| qld 1995 | ALP, LNP, OTH | no — whole cycle is thin |
| sa 2014 | GRN | no |
| sa 2022 | ALP, GRN, LNP, OTH | no — whole cycle is thin |
| wa 2025 | ALP, GRN, LIB, NAT, OTH | no — whole cycle is thin |

In four of the six cycles **every** party shares one poll count, so the change
is not party-specific at all — it is "this whole cycle was barely polled". Those
rows would dominate any pooled MAE while telling us nothing about the mechanism.

And one of the two real instances is **WA 2017 One Nation**, which this repo
already documents as evidence *against* the change: polls 10.3, fitted 7.8,
**actual 4.9**. The trend lagged the polls by 2.5 points and still finished 2.9
too high.

**So the historical record contains one usable observation of this mechanism,
and it points the other way.** No grid, criterion or bar can fix that. This is
not a refusal of the change — it is that the change cannot be decided on
held-out score, and any future attempt must say so up front rather than
rediscovering it.

### What this leaves, and what it does not authorise

- **`NL3` on NSW 2027 is still breaching and `fit_nsw.R` is still red.**
  Nothing here fixes that, and **`POLL_TRACKING_BOUND` must not be loosened**
  to make it green — that is the "worst possible reason to change a check" this
  plan named at the outset.
- **The open question is now the one the criterion could not see**, stated in
  advance above: whether `NL3` is the right check for a party with 3 polls in
  its 90-day window, given breach size orders by how few polls name the party
  (Victoria 2026 ONP 2.78 on 10 polls; NSW 2027 5.15 on 3). That needs its own
  plan and its own pre-registered bound, derived from the poll count rather
  than adjusted until NSW passes.
- **The sister-script port is untouched by this abort** and is a correctness
  question, not a scored one — see below.

### The port has exactly one affected row, and it is not One Nation

Established while counting: NSW's `SFF` has **15 polls in the 2023 cycle and
15 total**, so it *passes* `cnt >= 15` and *fails* `est_parties >= 20`. It is
the only NSW party the `intersect` at `fit_nsw.R:132` currently excludes that
Victoria's rule would include.

So porting `fit_vic.R:157`'s treatment to NSW moves exactly one historical
row, and it is not the row anyone was trying to fix. That makes the port a
consistency argument — two scripts should not treat one situation differently —
and **not** something to justify with a held-out number it cannot support. It
needs a decision, not an experiment.
