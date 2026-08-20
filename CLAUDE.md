# auspol — working notes

A forecast of Australian elections. Live target: Victoria, 28 November 2026.
Architecture in `ARCHITECTURE.md`, work queue in `docs/NEXT-STEPS.md`, and
every hard-coded number in `docs/CONSTANTS.md`.

## Before opening a PR, run this

```
powershell.exe -Command 'Rscript "scripts/check_like_ci.R"'
```

**Not optional, and not the test suite.** CI runs two things: the tests with
**no anchor data**, and `R CMD check --as-cran` with **warnings as errors**.
Every developer machine has a populated `external/aus-polling-analyser/`
clone, so `devtools::test()` passing locally proves neither.

Two PRs have already opened red for want of this: once because a change gave
`flows_for()` a hidden dependency on the anchor clone, and once because an
`.Rd` still documented a default the code had moved to a constant. The second
time the script existed and was skipped.

`--tests-only` skips the slow half while iterating. **Never before any push
to a branch that has an open PR** — not just before opening one. Three CI
failures so far were `.Rd` files stale against a changed signature, and the
third came from using `--tests-only` on a commit that went straight onto a
branch with PR #5 already open. "Before opening a PR" felt satisfied because
the PR was opened hours earlier; the rule has to be about the push.

## Changing an exported function's signature

Run `devtools::document()` **in the same commit**. A changed default with a
stale `.Rd` is a `WARNING`, and CI treats warnings as errors.

## The rule this codebase keeps relearning

**Prove a check fails on a deliberately broken input before trusting it to
pass.** Not one of the real bugs here announced itself; every one produced
plausible output while something quietly did not run, did not match, or did
not apply. Recorded with worked examples under "Recurring hazards" in
`ARCHITECTURE.md`.

Specific traps, all of which have bitten:

- **data.table NSE**: a function argument or local variable sharing a name with
  a column, used bare inside `dt[...]`, binds to the column. **Five times.**
  Compute masks outside the brackets and name the variable differently. The
  fourth was `party[party$seat == seat, ]` where `party` was both the table and
  a column — `$` then fails on an atomic vector. Related: a column named `key`
  collides with `data.table()`'s own `key=` argument and errors naming your
  data.
- **Absence of evidence read as certainty**: a lookup row carries `0%` for a
  destination that never co-occurred, and renormalising that row over whoever
  is left assigns them the *entire* transfer. One Nation won Richmond that way.
  Smooth toward uniform; a zero from a sparse table is not a measurement.
- **A size floor is not a completeness check**: a truncated download of exactly
  65536 bytes sailed past a `> 2000` guard, parsed to zero rows and dropped a
  seat from the dataset silently. Check for the closing tag, not the length.
- **`[[` on a missing name in an atomic vector THROWS**, so an `is.null()`
  guard beside it is dead code that can never fire. Use single-bracket
  indexing and test for `NA`.
- **Removing by name removes every duplicate**: `v[setdiff(names(v), x)]` drops
  all entries called `x` while only one was accounted for. 15 of 100 votes
  vanished with nothing reported. Validate names are unique at the boundary.
- **Leakage**: anything in the backtest must use only what was knowable before
  the election being predicted — flows, hyperparameters, `as_of` dates. Three
  instances, one introduced while fixing another.
- **Guards that cannot fail**: `all()` over an empty set is `TRUE`, `which()`
  drops `NA`, `NA <= 0` is `NA`, and `data.table` silently drops a column
  assigned `NULL`. A check with an `| is.na(x)` escape hatch passes on exactly
  the input it exists to catch.
- **`load_seats(Y)$incumbent` is who holds the seat NOW, not who won election
  Y-1, and its party labels are not ours.** Two distinct traps, found together
  on 2026-08-20 while scoring the NSW backtest:
  - **By-elections contaminate it.** Bega, Kiama and Pittwater all record a
    later winner than the election that produced them. Anything asking "who won
    last time" must use declared results, not this field.
  - **The anchor's party classes differ from `classify_party()`.** It files the
    Shooters, Fishers and Farmers as `IND`; we map them to `OTH_RIGHT`. So
    Barwon, Murray and Orange read as independent-held from the seat file and as
    minor-right from the first preferences. That inconsistency silently
    corrupted a check on "seats an independent held and won".
  **One source of truth per question**: party classification comes from our own
  `classify_party()` over primary vote data, never from a field someone else
  classified. Victoria is unaffected — it has zero independent-held seats — but
  the trap is in the shape of the data, not in NSW.
- **An experiment that never ran looks exactly like an experiment with no
  effect.** A file edit and the runs that depend on it must not share one
  backgrounded command: on 2026-08-19 the edit died on an `AssertionError` and
  the two runs launched behind it used the unmodified script, returning
  byte-identical output that read as "this input does not matter". Nothing in
  the output could have revealed it. **Every diagnostic must print what it
  applied**, and the value printed must be read before the result is.
- **Grepping for check codes**: patterns anchored on an adjacent quote miss
  `cat(sprintf("\nG3 ...`. Three incomplete greps, one of which let `B1` mean
  two different things. The registry is a table in `ARCHITECTURE.md`.

## Constants

Every one is inventoried in `docs/CONSTANTS.md` with whether it can come from
data. **A constant missing from that file is a bug in that file.** Priors that
can be estimated are chosen by held-out error over a pre-registered grid —
write the grid, criterion and decision rule to `docs/plans/` and **commit it
before running**, so the criterion cannot be chosen to fit the answer.

**A decision rule must also say what would make an apparent WIN unacceptable.**
Committing the criterion first is not enough on its own, and this has now gone
wrong twice in three experiments:

- the inclusion floor (2026-08-19): floor 15 cleared the pre-registered bar
  three times over and was refused on an anchor written after the result.
- One Nation seat uncertainty (2026-08-19): every relevant criterion passed or
  was mis-specified, and the change was refused on a directional side effect —
  the party's win probability rose in 71 of 87 seats and fell in 1 — that no
  criterion covered.

Both refusals look right on the merits and both were reported honestly. That is
not the point: in each case the real decision came from something invented after
seeing the results, which is what pre-registration exists to prevent. The lesson
was written down after the first and **not applied to the second**, so it is
here rather than in a plan file.

So every plan needs a refusal section naming, in advance: the directional side
effects that would disqualify a winner, and what the criterion cannot see. If
that section is hard to write, the criterion is probably measuring the wrong
thing — which was true both times.

**And write every tolerance in standard errors, or compute its size in standard
errors when you write it.** Two criteria have now failed the same way, four days
apart, and both failures were computable from `n` before the experiment ran:

- the reliability-bin rule (2026-08-19): "no bin off by more than 15 points",
  set without checking that a decile could hold five seats, where one seat moves
  the bin by 20.
- the first-preference widening rule (2026-08-19): "within 5 points of nominal"
  at the 50%, 80% and 95% levels. Copied from a 95% rule where 5 points is 2.6
  SE; at the 50% level the same 5 points is **1.16 SE**, so it rejected a
  perfectly calibrated interval about a quarter of the time. Both candidates
  were refused by a test with no power to accept either.

**Cluster the standard error on the right unit.** In that case the 139
party-cycles were 33 independent cycles, because first preferences sum to 100
within a cycle — treating them as 139 understates the SE. Ask what the
independent observation actually is before dividing by `sqrt(n)`.

A criterion changed after seeing results is worth almost nothing, so the only
defence is to get the size right in advance. Where an amendment is unavoidable,
make it a **visible addition with the original clause left unedited**, and check
whether it favours the answer found later — if it does, it is not an amendment,
it is a rationalisation. The one amendment made so far picked the value
pre-registered *first*, which is the only reason it was allowed to stand.

## The seat model is the candidate model. There is no second seat model.

**`fit_seats_full.R` / `simulate_seat_contests()` is the forecast.** The
two-party path — `simulate_seats()` in `R/seats.R`, `fit_seats.R`,
`test_seat_probability_calibration.R` — is **retired**. It cannot elect a minor
party, and South Australia elected four One Nation members in March 2026.

So:

- **Never improve, tune, measure or reason about the two-party seat model.** A
  finding that only moves it is not a finding.
- **Anything it can still do that the candidate model cannot gets PORTED, then
  the two-party version is deleted.** Not kept as a cross-check.
- **Check which model a constant reaches before working on it.** `fed_swing`
  and `SEAT_SWING_COEF` live in `simulate_seats()` and `fit_seats_full.R` never
  reads them; `AUSPOL_FLOW_SHIFT` moves `fl$flow_alp`, which only reaches the
  statewide two-party anchoring and leaves the published seat output
  byte-identical.

This rule was given three times in conversation and drifted from three times on
2026-08-20 — a coefficient refit, a seat-type test and an exposure analysis were
all built on the retired path before anyone noticed. It is written here because
`CLAUDE.md` reloads every turn and a conversation does not.

## Two trend-model paths — know which one you are looking at

`trend_as_at()` fits with default volatility and equal pollster weights, and
**this is what gets published**. `fit_vic.R` fits with per-cycle volatility and
per-pollster noise factors, and its output is required-but-not-read.

The fuller model was measured and is **not** better: 0.2% held-out gain for 33×
the runtime. Two reviewers with full repo access have reached opposite
conclusions about which one publishes, so state it explicitly when touching
either.
