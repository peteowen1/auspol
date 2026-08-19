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

## Two model paths — know which one you are looking at

`trend_as_at()` fits with default volatility and equal pollster weights, and
**this is what gets published**. `fit_vic.R` fits with per-cycle volatility and
per-pollster noise factors, and its output is required-but-not-read.

The fuller model was measured and is **not** better: 0.2% held-out gain for 33×
the runtime. Two reviewers with full repo access have reached opposite
conclusions about which one publishes, so state it explicitly when touching
either.
