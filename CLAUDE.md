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

## EVERY REQUEST FROM PETE GOES IN `docs/PETE-ASKED-FOR.md`

**Read that file at the start of any session.** It is the register of what he
asked for and whether it is actually in the model.

A request leaves the register when it SHIPS, or when he has been told in a
message — not a commit, not a plan file — that it is not happening and why.

**"In a plan" is not "shipped". "Built but flagged off" is not "shipped".**

Written 2026-09-11, when Pete asked what he had requested that was never
delivered, and the answer was three things. One of them was demographics as
model features, which he had asked for in the same breath as *"if you leave
any vars out let me know dont just silently do it"*. It was left out silently.

The failure is never a refusal. It is judging something unready, folding that
judgement into a plan, and never saying plainly **"I am not doing what you
asked, and here is why."** From the outside that is indistinguishable from
having done it — which is why he ends up assuming a feature is in the model
when it is not.

## A NEGATIVE RESULT IS ONLY REPORTABLE FROM THE STRONGEST VERSION YOU CAN BUILD

**Before saying a model, feature or design "doesn't work", state what you gave
it against what was available. If the answer is "a subset", that is not a
result — it is a to-do.** Four times on 2026-09-11 alone a negative was reported
from the cheapest version to hand. The worst, "we cannot predict who surges",
used 7 of the 25 features the primary model already had; with all of them AUC
went 0.751 → 0.936. Pete had to ask four separate times. Full table: `docs/reference/claude-md-incident-detail.md`.

**The asymmetry is the whole argument.** Building the full version costs
minutes. A wrong negative gets written into a plan, reasoned from, and closes a
line of work.

So, concretely:

1. **When Pete says "fit an xgboost on it", fit it.** Do not argue from `n`.
   Fit it with `xgb.cv` and early stopping, report it beside the alternative,
   and let the measurement decide. An objection that a two-minute run would
   settle is not an objection, it is a delay.
2. **Name the feature count in the result.** "AUC 0.75 using 7 of the 25
   features available" is a reportable sentence. "AUC 0.75" is not.
3. **If the convenient input is a summary file, go back to the source.** The
   emergence model used an eleven-column output file because it was there.
   `output/xgb-primary-v6-features.csv` now exists precisely so that excuse is
   gone — and `fit_xgb_flows_v1.R` already wrote its own.
4. **A refusal needs the same evidence bar as a ship.** Both close a question.

### The same root, one level up: ASK WHAT THE SYSTEM ALREADY HAS

Same day: `scripts/fit_xgb_primary_v6.R` was found feeding the party's ACTUAL
statewide share at the election being predicted, and reading that one file the
conclusion was "this is the harness's design, deliberate". **The pipeline
already predicts exactly that quantity** — `state_mean` in `fit_seats_full.R`,
stage one of the model, written into `ARCHITECTURE.md` that morning. Pete had to
point it out. (`AUSPOL_LEVEL_MODE`, default `"pred"`, now controls it.)

So, before accepting a limitation or designing around it:

- **Ask what already computes this quantity.** Grep for it across `R/` and
  `scripts/`, not just in the file that surfaced the problem.
- **Re-read the architecture doc you wrote.** If the answer is in it, the
  failure is not knowledge, it is not looking.
- **"Deliberate design" is a claim that needs a source.** A code comment saying
  a thing is the design is evidence that someone coded it that way, not that it
  was chosen — and never that Pete chose it. Say which of the three it is.

## The rule this codebase keeps relearning

**Prove a check fails on a deliberately broken input before trusting it to
pass.** Not one of the real bugs here announced itself; every one produced
plausible output while something quietly did not run, did not match, or did
not apply. Recorded with worked examples under "Recurring hazards" in
`ARCHITECTURE.md`.

Specific traps, all of which have bitten:

- **data.table NSE**: a function argument or local variable sharing a name with
  a column, used bare inside `dt[...]`, binds to the column. **Eight times.**
  data.table scopes the table's columns into the WHOLE `i` expression, so
  `raw[raw$election == election]` became `raw$election == raw$election`, always
  TRUE, and was caught only by a test querying a label that cannot exist. Fix:
  never a bare column-name symbol inside `[`, even qualified with `$` on one
  side only -- copy the argument to a differently-named local first, and
  compute masks outside the brackets. Related: `party[party$seat == seat, ]`
  fails when `party` is both the table and a column, and a column named `key`
  collides with `data.table()`'s own `key=` argument. All eight cases: `docs/reference/claude-md-incident-detail.md`.
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
- **A COLUMN THAT IS CONSTANT WITHIN A SUBGROUP IS A LABEL FOR THAT SUBGROUP,
  and a tree will use it as one.** Filler values on rows where a feature does
  not apply (`state_elec_gap = 999` on every non-federal row, 2026-09-12) let
  xgboost split on jurisdiction: 96% of non-federal predictions moved, by up
  to 5.87 points. If a feature only exists for part of the corpus, either fit
  that part separately or do not add it -- a filler value is not neutral.
- **A PERCENTILE of a mostly-tied variable reports "is this the mode?", not
  "how big is this?"** `jump` is 51-81% exactly zero, so any non-zero value
  ranked above the 81st percentile and pure noise scored 0.98 (2026-09-12,
  `docs/reviews/salience-percentile-fix-2026-09-12.md`). **Before
  percentile-ranking anything, print three numbers: percent exactly zero, count
  of distinct values, and the size of the largest tied block.** Now ranked
  among non-zero values only (`R/salience_surge.R:92`,
  `AUSPOL_SALIENCE_PCTILE_NZ`).

## Before saying we don't have data, READ `docs/DATA-REGISTRY.md` and `docs/DATA-DICTIONARY.md`

Both are **generated from disk** — `scripts/build_data_registry.R` and
`scripts/build_data_dictionary.R`. Never hand-edit either; rerun the script.

- **Registry** answers *do we have this file*.
- **Dictionary** answers *do we have this field*, and carries a
  "Columns we download and DROP" section that diffs each raw source against the
  processed extract.

**The second question is the one that keeps going wrong**, because the file is
in the registry, so the registry says yes, and the field is gone anyway. Two of
the four failures below were exactly that. **Never aggregate a source down to
the columns you happen to need** — write every column through and select later.

### The same rule applies to anything SCRAPED, and it is more expensive there

**Store the raw response, never the summary you happen to want today.** A
re-fetch is rate-limited and may simply be unavailable; a disk write is free.

Cost of learning this on 2026-08-26: `fetch_seat_salience.R` cached an 8-week
mean of each Google Trends series and discarded the weekly points. When the
**campaign rise** turned out to be the statistic that separates a real
emergence from a namesake — Cameron Smith the rugby league captain outscored
Bill Shorten in Maribyrnong on 3.8% of the vote — all **259 cached batches**
needed refetching, and by then Google had throttled us out entirely. The
information had been on disk and was thrown away.

So: cache the series, derive the statistic. Level, rise, peak, slope,
volatility and time-to-peak all come free from a stored series and all cost a
fresh scrape from a stored mean.

### What the registry lists

It lists every election, every raw commission download, the candidate-level
corpus, and the known gaps, with file sizes so a zero-byte file cannot pass as
a working one.

This exists because the same data has been declared missing **three separate
times on 2026-08-25 alone**, each time while sitting on disk:

- **booth results and electoral boundaries** — both in `external/reference/`;
  only the anchor archive had been searched.
- **candidate-level federal first preferences for all seven elections** — in
  `external/reference/aec/` since August. `fetch_preferences_fed.R` has been
  downloading the AEC's `HouseFirstPrefsByCandidateByVoteType` files all along
  and aggregating the names away. A whole plan was written around acquiring
  data that was already there.
- **seat-level swing** — the AEC ships a `Swing` column in that *same file*,
  for every candidate in every division across all seven elections.
  `backtest_candidate_fed.R` still records that it "cannot test" the seat-swing
  port for want of a swing predictor. Same file, same fetcher, same loss.

The third one produced a wrong recommendation, not just wasted time. **The cost
is not the lookup — it is that "we don't have X" gets written into a plan and
then reasoned from.**

Two habits follow:

1. **Check the registry first**, then the filesystem, then conclude. `ls` on one
   directory is not a search.
2. **Regenerate the registry whenever you fetch or build data**, in the same
   commit. A stale registry is worse than none, which is the same rule
   `~/.claude/CLAUDE.md` applies to hand-maintained reference data.

Candidate NAMES live only in `output/candidacies.csv`
(`scripts/build_candidacies.R`). Every per-seat results file carries
`seat, party, votes` and nothing else, so any candidate-level question starts
from the corpus, not from the election files.

## Fit constants with SHRINKAGE, never a hard `min_n` cliff

Pete's rule, 2026-09-09: *"Can't we always just build shrinkage into our
regressions so we never overfit? I'd rather have someone there if there's some
signal than have just one flat figure."*

A threshold that discards an estimate below `min_n` and trusts it completely
above is indefensible — a cell at n=41 is believed outright and one at n=39 is
ignored outright. Three fitting functions written in a single session had
cliffs at 5, 40 and 200. **Partial-pool instead**: shrink each cell toward the
pooled mean by how precisely it is measured,

```
w      = tau^2 / (tau^2 + se_i^2)      # tau^2 = between-cell variance
shrunk = mu + w * (est_i - mu)
```

so a thin cell degrades gracefully toward the prior rather than falling off a
cliff. `AUSPOL_PARTY_COR="shrunk"` already does this for the statewide
correlation; the fitted constants should too.

**The reason this matters most is not tidiness — it is that shrinkage makes a
weak signal safe to INCLUDE rather than refuse.** A term with three clusters
shrinks almost entirely back to the prior, so adding it costs nearly nothing
and picks up signal if the signal is real. That is the answer to "there might
be something there but we cannot power a test for it", which had just caused a
surge-conditioned slope to be abandoned on 3 events.

It also stops a false binary between a well-measured single observation and a
noisy pooled fit — worked example in
[reviews/onp-concentration-validated-2026-09-09.md](docs/reviews/onp-concentration-validated-2026-09-09.md).

**Limits, because "never overfit" overstates it**: shrinkage trades variance
for bias, assumes the cells are exchangeable draws from a common distribution,
and its weight is itself estimated — unstable with few groups. It does not
license fitting anything at any n; it makes the failure graceful.

**When the BETWEEN-group variance is itself barely estimable, shrinkage will
UNDER-separate groups that genuinely differ.** Losing defectors and sitting
members (2026-09-09) were not separable by rank test at n=12 (p = 0.408), which
is absence of evidence, not evidence of absence, and the shrinkage weight
inherited that low power. **So the corrective for a suspicious shrinkage result
is an OUTCOME check — does the shrunk value predict better on the target
cells? — not a bigger significance test.** See
`docs/plans/prereg-defector-pooling-2026-09-09.md`.

## Constants

Every one is inventoried in `docs/CONSTANTS.md` with whether it can come from
data. **A constant missing from that file is a bug in that file.**

**Full pre-registration rules, with the incidents that produced each one, moved
to [`docs/PRE-REGISTRATION-RULES.md`](docs/PRE-REGISTRATION-RULES.md)** (2026-09-17
hub-slimming pass — ~13KB a session not designing an experiment doesn't need
every turn). Headlines, read the linked file before writing a criterion:

- Commit the grid, criterion and decision rule **before running**, so it can't
  be chosen to fit the answer.
- **Name what would make an apparent win unacceptable, in advance** — a
  criterion passing on the merits is not the same as nothing being invented
  after seeing results.
- **Scope the metric to the change**: a targeted fix validates on its named
  targets, primary; election-wide is the do-no-harm guard. Reversed, a real
  fix affecting `k` of `n` seats needs `n/k` times the effect to clear an
  aggregate bar.
- **Metric order for seat probabilities: log loss, then Brier, then
  reliability by band. Calibration slope is reported, never decisive** — it
  missed a change that cut log loss 29%.
- **Size the primary metric's own noise (its MDE) against the expected
  effect** before choosing it as primary. One with MDE larger than any
  plausible effect can only ever refuse.
- **Dry-run every criterion on two or three cases whose answer you already
  know, before committing it.** A criterion is a measuring instrument.
- **Write every tolerance in standard errors**, and cluster the SE on the
  actual independent unit, not the row count.
- An unavoidable amendment is a **visible addition with the original clause
  left unedited** — if it favours the later answer, it's a rationalisation.

## A fix to one harness is a fix to ALL of them. Apply and test everywhere.

**`docs/MODEL-REGISTRY.md`** (generated by `scripts/build_model_registry.R`,
never hand-edited — rerun it) is the check for this rule: every published
switch, whether each harness and the published forecast script actually
honours it, and why every gap exists (intentional exclusion, a dead
experiment, or genuinely open). Built 2026-09-09 after "now works in every
harness" was claimed and wrong twice — `AUSPOL_SEED` was hardcoded in WA,
and `AUSPOL_SEAT_SD_MULT` never reached `fit_seats_full.R`, the actual
published forecast, at all. Regenerate it before trusting a parity claim,
same discipline as `docs/DATA-REGISTRY.md`.

**Two reading traps.** The table's columns run `fit_seats` (published)
**first**, then `fed | nsw | qld | sa | vic | wa` — misread once as the
other order, which turned a deliberate exclusion into a reported bug. And
the generator only greps the harness files and `fit_seats_full.R`, so a
switch read inside `R/` (not the harness itself) shows "UNEXPLAINED" even
when it's correctly wired — `AUSPOL_SD_DEPARTED` is the current example.

There are **six** candidate-seat backtest harnesses — `backtest_candidate_fed.R`,
`_vic.R`, `_nsw.R`, `_sa.R`, `_wa.R`, `_qld.R` (built 2026-09-07) — and they
share a structure but not a file. **Any improvement, parameter or bug fix
applied to one MUST be applied to all six and measured on all six in the same
session.** Not "noted for later".

**A sweep is minutes now, not an hour** (`src/seat_sim_core.cpp`, 2026-09-07),
so there is no longer a compute excuse for measuring one and deferring the
rest. Exploratory arms run at `AUSPOL_N_SIMS=5000`; only the deciding run
needs 20,000.

Per-pair details (pair lists, flow sources) are in each harness's header
comment and in `docs/reference/claude-md-incident-detail.md`. The ones that change how a number reads:

- **`_fed.R` is the largest harness** (7 pairs, 1,036 seat-elections against
  WA's 361), so prefer federal first and WA second when a criterion needs to
  resolve anything.
- **"Measured on NSW" or "on QLD" means one pair.** `AUSPOL_NSW_PAIR` (2019 or
  2023, default 2023) and `AUSPOL_QLD_PAIR` (2020 or 2024, default 2024) each
  pick one, and both need running. `_vic.R` runs its three pairs in one go.

**Every log-loss number here is clamped at `eps = 1e-6` before the log.** That
constant is not cosmetic: a seat given probability exactly zero contributes
`-log(eps)` by itself, so moving the floor to 1e-9 moved vic2014 from 0.4662 to
0.5608 and wa2001 from 0.8731 to 1.1155 with no change to the model. Pooled log
loss is set as much by how many seats sit at the floor as by anything else, and
every one of those seats is an emergence the model gave nothing to.

**`scripts/pool_backtests.R` gives the pooled table across all 22 pairs and
2,050 seat-elections** — accuracy, Brier and seat log loss per pair and overall.
Run it instead of adding up six logs by hand. It takes the newest file per pair
and prints that file's timestamp and code tag, so a row describing an older
model is visible rather than silent.

**Both exceed the 10-minute background-task cap when run as two arms in one
command.** Run one arm per launch, and use `AUSPOL_FED_PAIRS` to take federal a
pair at a time; a killed run loses every arm behind it. Queensland was built
2026-09-07 and scores 0.3350 against AE Forecasts' 0.3578.

**Every harness carries its own copy of the surge training pair list**, and they
are NOT the same list. Queensland's had `sa2026` renamed to `qld2024` when it
was copied from the South Australian harness, so it trained without the four One
Nation winners until 2026-09-07. Before changing one, diff it against
`scripts/fit_salience_surge_v2.R`, which is the list with the reasoning attached
— membership is deliberate, and pairs with no governed emergence were ruled out
rather than forgotten.

**WA scores 2005→2008 on only 67% of its seats** (redistribution renames
them) and `wa2001` falls back to pooled flows. Coverage is printed per pair; a
pair scored on two thirds of its seats is not comparable with one scored on all
of them.

This has gone wrong twice on the same parameter: `shrink` missing from the SA
harness (2026-08-21, four days of SA calibration figures describing a model we
do not publish) and the flow fixes going into SA only (2026-08-25). **A harness
missing a parameter produces numbers that look like findings**, and they get
investigated, written up and reasoned from.

So, concretely, when changing a harness:

1. `grep` the other five for the thing you are adding. If it is absent there,
   it is part of this change, not a follow-up.
2. Run all six and report the metric before and after for each. A change that
   helps one election and hurts another is a finding, and you cannot see it
   from one run.
3. If a fix genuinely cannot apply somewhere, **say why in the commit** rather
   than leaving the gap silent — a silent gap is indistinguishable from an
   oversight the next time someone reads those numbers.

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

## The published configuration lives in `scripts/published_flags.R`, and nowhere else

Every `AUSPOL_*` switch and the value the published forecast runs at. Both
`fit_seats_full.R` and the six harnesses (via `scripts/harness_defaults.R`)
apply it to every switch the caller left unset, so **a harness run with no
environment measures what ships**, and a run that sets anything has to name
it (the arm fingerprint in the output filename does the rest).

**A switch missing from `CAL_TAG` is NOT a filename-collision bug.**
`.arm_fingerprint` hashes every set `AUSPOL_*` variable already, so two arms
differing only in an un-fingerprinted switch still get different output
filenames. Asserted otherwise three times in one session (2026-09-16/17,
`fe91e68`) before computing both hashes settled it in under a minute.
`CAL_TAG` is for a human reading the filename, not for preventing a
collision — check what it actually does before claiming it doesn't.

This exists because on 2026-09-06 a day of headline numbers ("fed2025 0.2886,
ahead of AE Forecasts") came from a harness "shipped config" that had
surge-v2 OFF and the v1 salience ratio ON — the opposite of the forecast on
both counts. What ships scores 0.3017, a tie. `fit_seats_full.R`'s own
RUN_FLAGS list said shrink 0.10 a day after the code moved to 0.01. Two lists
drift in both directions; there is one now.

**When you add a switch to `fit_seats_full.R`, add it to `published_flags.R`
in the same commit.** A `Sys.getenv("AUSPOL_...", default)` anywhere else is
documentation; the registry is the behaviour.

## A primary-vote fix must be tested in `base_pred` AND the xgb layer, always

`base_pred` (`dev_slope()`, `R/dev_slope.R`) is the pre-xgb swing baseline
every harness builds first, and it dominates the shipped ensemble's SHAP
decomposition -- typically +16 to +22 points of a row's prediction, against
single-digit contributions from most engineered xgb features. **An xgb
feature layered on top of an unconditioned baseline is a small correction
fighting a big one, and it can pass every test (pooled RMSE, a placebo-
controlled targeted delta, a real published p-value) while barely moving the
actual number for the seat it was built for.**

Written 2026-09-16 after shipping two real, correctly-sized, correctly-
measured xgb features in one session -- `seat_outperf` and the minor-to-
minor defector discount -- and finding neither touched `base_pred` at all.
Both had SHAP contributions near zero (`seat_outperf`: +0.4 on the seat it
was built for, against `base_pred`'s +22.2) because the discount machinery
they extend (`personal_prior_vote()`'s `major_discount`/`minor_discount`,
`screened_slopes()`'s same/new conditional-slope tables) was wired into the
harnesses' OWN xgb-feature-building calls only, never into the SAME
harnesses' `base_pred`-building calls to the identical functions. Full
trace: `docs/reviews/base-pred-blind-to-tonights-fixes-2026-09-16.md`.

**So: before calling a fix "shipped," check the specific seat(s) it targets
end to end** -- the actual predicted primary vote against actual, not just
the aggregate metric. And **when a fix is proposed, test it edited into
`base_pred` AND as an xgb feature, not one or the other** — either can look
like a real, positive, statistically clean result while leaving the
published number for the flagship case untouched.

## Two trend-model paths — know which one you are looking at

`trend_as_at()` fits with default volatility and equal pollster weights, and
**this is what gets published**. `fit_vic.R` fits with per-cycle volatility and
per-pollster noise factors, and its output is required-but-not-read.

The fuller model was measured and is **not** better: 0.2% held-out gain for 33×
the runtime. Two reviewers with full repo access have reached opposite
conclusions about which one publishes, so state it explicitly when touching
either.

## Two XGB-primary override paths — same trap, different mechanism

`R/xgb_primary_override.R` holds two functions that both "override the primary
shares with the XGB challenger" and are easy to conflate:

- **`xgb_primary_override()`** (`AUSPOL_XGB_PRIMARY`) — the **six backtest
  harnesses only**. Substitutes in a STATIC cached file
  (`output/xgb-primary-v6-oof-predictions.csv`), written once by
  `scripts/fit_xgb_primary_v6.R`. Whatever `base_pred`/`dev_slope()` values
  were baked into that pool at the time it was last built are frozen there —
  a later fix to `dev_slope()`/`screened_slopes()`/`candidate_returns()` has
  **zero effect** on a backtest run under this flag until the cache is
  regenerated (the 4-step non-circular retrain,
  `docs/reviews/xgb-primary-circularity-2026-09-13.md`).
- **`xgb_primary_predict_live()`** (`AUSPOL_XGB_PRIMARY_LIVE`) — **the
  published Victoria forecast only** (`fit_seats_full.R`). Sets `base_margin`
  from THIS RUN'S OWN freshly-computed `shares` matrix at prediction time
  (`R/xgb_primary_override.R:481-483`), so a primary-vote fix reaches the
  published number **immediately on the next run**, with no retrain needed —
  the trained tree model only ever learned a residual correction on top of
  whatever `base_margin` it's handed.

**A primary-vote fix can be live in production and simultaneously invisible
to a backtest run at `AUSPOL_XGB_PRIMARY=1`, at the same time, correctly.**
These are not the same "xgb layer" — they are two different mechanisms gated
by two different, similarly-named env vars. Found 2026-09-18: the
`AUSPOL_HONOUR_DEPARTED` fix was reported as "does not reach the published
forecast" from a backtest test alone, and that claim was wrong — Pete caught
it by asking directly whether published defaults use base_margin now. Before
claiming a fix does or doesn't reach "the published number", check **which of
these two functions the script you're actually asking about calls** — grep
`fit_seats_full.R` specifically, don't reason from `xgb_primary_override()`'s
docstring alone. `docs/MODEL-REGISTRY.md`'s per-switch table can mislead here
too: it lists `AUSPOL_XGB_PRIMARY` as reaching `fit_seats_full.R` ("yes"),
which is very likely a grep substring false-positive against
`AUSPOL_XGB_PRIMARY_LIVE`/`_OOF`/`_SD` mentions in comments, not a real call
site — `fit_seats_full.R` has no direct call to `xgb_primary_override()`.
Verify with a function-name grep, not the registry table, when this matters.
