> **Status, 2026-09-07.** Findings A and B were applied the same night as
> byte-identical hoists, and then superseded: the whole per-draw loop is now
> compiled (`src/seat_sim_core.cpp`), byte-identical to the R engine and about
> 15x faster, so a full 18-election sweep runs in minutes. Finding F
> (memoising `governed_population()` across the pair loop) is NOT done and is
> now worth proportionally more, since it is a fixed cost the compiled core
> did not touch.

# Performance review: seat simulator + federal backtest harness

Scope: `R/seat_sim.R` (`simulate_seat_contests()`), `R/flow_matrix.R`,
`R/flow_trend.R`, `R/salience_surge.R`, `R/candidate_returns.R`,
`scripts/backtest_candidate_fed.R`. Strictly read-only on the repo; all
measurements from scratch scripts against real fed2019/fed2022 data
(`external/elections/aec-fed-*.csv`, `output/candidacies.csv`).

Builds on the 2026-09-04 hot-loop fix (NEXT-STEPS), which converted the
string-keyed `exists()`/`get()` environment for the main flow-cell lookup to
a preallocated integer-indexed list, and stopped `mostattributes<-` from
firing by dropping `base_v`'s names once, early. Confirmed still in place:
`mostattributes<-` is now a rounding error in every profile below (<2%,
where it wasn't even in the top 20 in the true-default-path run).

## 1. Timer first

**Important caveat on wall-clock numbers.** This machine had a live
background backtest process (confirmed via `Get-Process`: one `Rscript.exe`
at 5.7GB RSS — the "other runs hold ~5GB" mentioned in the task) running
concurrently with every timing run here. System free memory swung from
4165MB down to 531MB (below the 800MB floor I was told not to run under) and
back up to 3GB+ over the course of this review, entirely from that other
process's activity, not mine. The first timing pass (`shrink=0.10,
flow_sd=3.65` — see below on why that's not representative) showed
**non-monotonic** wall-clock scaling (317, 184, 179 us/seat-sim at n_sims =
500, 1000, 2000) that is very likely memory-contention noise, not
algorithmic behaviour — a same-process CPU-time profile taken moments later
for the same n_sims=2000 case came in at under a third of that wall-clock
figure. **Treat every raw wall-clock number below as noisy** on this shared
machine; the `Rprof` self-time breakdowns (which undercount time the process
was blocked/swapped, not scheduled) are the more trustworthy signal here.

**Input:** real fed2019 first preferences → 151-seat share matrix (7
parties: ALP, GRN, IND, LNP, ONP, OTH, OTH_RIGHT), flow matrix built from
real fed2019 transfers (2160 rows, `min_n=3`). This is what the
`fed2019→fed2022` pair of `backtest_candidate_fed.R` actually uses.

**First pass used the wrong defaults.** I initially timed with
`shrink=0.10, flow_sd=3.65` as "plausible" values. Checking the harness
(`scripts/backtest_candidate_fed.R` line ~1400) and
`scripts/published_flags.R` shows the actual call passes
`shrink = shrink_arg` (0.01 published), `flow_sd = FLOW_SD` (**0** —
`AUSPOL_FLOW_SD` published value is `"0"`), `surge_h` from surge-v2,
`party_cor = "shrunk"`, `level_sd = c(1.10, 8.67)`. **`flow_sd` is off in the
production configuration.** Re-ran with the true defaults.

### True-default-path timing (level_sd on, shrink=0, flow_sd=0, surge_h=0, party_cor=NULL, statewide_draws=NULL — matching what `simulate_seat_contests()` is actually called with when `AUSPOL_FLOW_SD`/`AUSPOL_SURGE_H` are unset)

| n_sims | elapsed | us / seat-sim |
|---|---|---|
| 500  | 5.285s  | 70.00 |
| 2000 | 18.979s | 62.84 |

Scaling 500→2000 (4x draws) took 3.6x the time — **sub-linear**, i.e. no
evidence of worse-than-linear scaling on this clean run. Solving for a fixed
per-call setup cost `F` and a linear per-seat-sim cost `c`:
`c ≈ 60.5 us/seat-sim`, `F ≈ 0.72s`. That `F` matches (see §2) the
`vapply`/`match.fun` self-time seen in every profile — a genuine fixed
per-call cost, **negligible at the production `n_sims=20000`** (0.7s out of
an extrapolated ~190s) but visible at n_sims ≤ 2000, which is why the first,
badly-parameterised pass looked like worse-than-linear scaling. **Not
proposed as a fix** — not line-attributable (see below) and irrelevant at
production scale.

Extrapolating the clean 60.5us/seat-sim rate to the real config
(n_sims=20000, 151 seats) gives **~190s (~3.2 min) for the
`simulate_seat_contests()` call itself** — well under the stated "~10-12
minutes per pair." §3 accounts for most of the rest: `surge_hazard_for()`
(on by default via `AUSPOL_SALIENCE_SURGE_V2=1`), `build_flow_matrix()`,
screened/conditional slopes, and other per-pair harness work not inside the
simulator. **This extrapolation itself is unverified** — I did not run
n_sims=20000 (against the task's memory-safety instruction), so treat "~3.2
min of the ~10-12" as an estimate, not a measurement, and flag the
possibility that GC pressure from the ~10x larger TCP matrices behaves worse
than linearly at full scale (not checked).

## 2. The hot loop, read with the timer's numbers in hand

Line-level `Rprof` (0.005s interval, `line.profiling=TRUE`, one warmup call
excluded from the profile) on the **true-default-path** config,
n_sims=2000, 151 seats, K=7 parties. Total sampled time 6.55s.

| file:line | code | self % | total % (incl. callees) |
|---|---|---|---|
| `seat_sim.R:687` | `pp <- pmin(pmax(base_v, 0), 100) / 100` (inside `sd_cell` for `level_sd`) | 3.74% | **23.36%** |
| `seat_sim.R:570` | `ck <- paste0(from_i, ".", paste(alive_i, collapse = "."))` (inside `ss_lookup`, the superset-cell cache key) | 2.90% | **15.95%** |
| `seat_sim.R:727` | `mask <- sum(bitwShiftL(1L, alive - 1L))` | 4.96% | 8.17% |
| `seat_sim.R:775` | `v[alive] <- v[alive] + pot * p` | 3.97% | 3.97% |
| `seat_sim.R:756` | `p <- if (tot <= 0) rep(u, length(alive)) else (1 - sm) * (w / tot) + sm * u` | 2.14% | 2.14% |
| `seat_sim.R:726` | `alive <- alive[alive != from]` | 2.52% | 2.52% |
| `seat_sim.R:690` | `v <- base_v + shift + stats::rnorm(K, 0, sd_cell)` | 1.91% | 4.43% |
| (function) `vapply`/`match.fun`/`FUN` | — | ~14% combined | ~15% |

**Finding A — the level_sd per-cell computation (line 687) is recomputed
n_sims times per seat when it is invariant across the whole `s` loop for
that seat.** `sd_cell` depends on `base_v`, which is `shares[i, ]` (this
seat's fixed projected shares) **unless `party_draws` overrides it**. The
federal harness never passes `party_draws` (grepped the call site — absent).
So for the entire production configuration, `base_v` and hence `sd_cell` are
**constant across all 20,000 draws for a given seat**, and the
`pmin(pmax(...))/100` → `level_sd[1] + level_sd[2]*level_mult*sqrt(pp*(1-pp))`
chain is being run 20,000x more often than necessary. This is the single
largest item found: **23.36% of sampled time** in this profile, and since
`level_sd` has been on by default since 2026-08-27 (`AUSPOL_LEVEL_SD` in
`published_flags.R`), it is on the real production path, not an
experimental arm.

*Fix*: precompute an `nseat x K` `sd_cell_by_seat` matrix once, before the
`s` loop, when `party_draws` is `NULL`; fall back to the current per-draw
computation only for seats/parties `party_draws` actually overrides (or
simply keep the current per-draw path whenever `party_draws` is non-NULL,
which is the existing, rarer case). The RNG draws (`stats::rnorm(K, 0,
sd_cell)`) consume the identical parameter values in the identical order —
this is a pure hoist, not a numeric change.

**Finding B — the superset-fallback cache key (line 570) uses a string
build (`paste0`/`paste`) where an integer key is already sitting in scope.**
`ss_lookup(from_i, alive_i)` is called from inside the elimination loop
whenever the main dense-list lookup misses (`fallback_rate` was 24% in
these runs), and its *own* cache (`ss_cache`, a `new.env()`) is keyed on a
string built fresh from `from_i` and `alive_i` on every call — including
cache **hits**. The caller already has `mask <- sum(bitwShiftL(1L, alive -
1L))` (line 727) computed at this point for the *main* dense-list lookup,
and `mask` **is** the survivor-set bitmask `alive_i` would encode — so
`ss_lookup` could take `mask` directly and use the exact same
`from * 2^K + mask` integer key the 2026-09-04 fix already uses for
`cell_list`, either as a second preallocated dense list or folded into the
same one (they're disjoint: `cell_list` only holds entries `build_flow_matrix()`
actually populated). This is the identical "string-keyed environment vs.
preallocated integer-indexed list" pattern the prior fix already applied to
the *main* lookup — it just didn't reach this sibling one. Line 570 alone
accounts for **15.95% of total time**; the `nm <- paste0(...)`
matrix-lookup-key construction a few lines below only needs to run on an
actual cache miss (matching `build_flow_matrix()`'s own character keys), so
that part is unavoidable, but the *cache key itself* is pure waste.

**Finding C — TCP retention writes (task's explicit ask): measured, not a
hot spot.** No line in the TCP-write block (`tcp_winner[s,i] <-`,
`tcp_runnerup[s,i] <-`, `tcp_share[s,i] <-`, `wins[i,w] <-`, `totals[s,w] <-`,
roughly lines 782-797) appears anywhere in the top-20 self-time lines in any
profile taken. Together they're comfortably under 5% of sampled time.
**Do not touch these** — no reachable win, and they hold the exact
byte-identical-output guarantee the 2026-09-04 fix proved.

**Finding D — repeated `which()`/matrix-name lookups: not significant.**
`alive <- which(v > 0)`, `which.min(v[alive])`, `which.max(v[alive])` operate
on length-≤7 vectors once per seat-draw or once per elimination round; none
show up materially in the profile. `parties[w]` (line 783, single positional
index into a 7-element character vector) is likewise negligible. The
2026-09-04 fix's "drop `base_v`'s names once, early" change is doing its
job — `mostattributes<-` is <2% here, down from what NEXT-STEPS records as
a real cost pre-fix.

**Finding E — the per-source `flow_sd` draw (line 771,
`p <- pmax(0, p + stats::rnorm(length(p), 0, .fsd/100))`) is NOT on the
default path** (`AUSPOL_FLOW_SD` published value is `"0"`), so it costs
nothing in the current production configuration. **When it IS enabled**
(the first, mis-parameterised timing pass used `flow_sd=3.65`), it costs
roughly a **third of total runtime** (33.21% total-time at line 771 in that
run) — the same `pmax` overhead as Finding A, plus a fresh `rnorm` and
renormalisation, on every elimination round rather than once per seat. This
isn't a bug (the branch is correctly gated `if (.fsd > 0 && length(alive) >
1L)`), but it's worth knowing: **if `AUSPOL_FLOW_SD_BY_SOURCE` is ever
promoted into `published_flags.R`, budget for it roughly doubling
per-elimination-round cost**, and the same "avoid `pmax`'s generic dispatch
on tiny vectors" fix as Finding A would apply there too.

**The `vapply`/`match.fun`/`FUN` cost (~14% combined self-time, not
line-attributable to any `seat_sim.R` line):** the only `vapply` call in the
function is the one-time `sd_vec <- vapply(parties, ...)` at line 436 (7
elements) — far too small to explain a ~0.6-0.8s cost. This matches the
fixed per-call overhead `F ≈ 0.72s` computed from the timing table above
(§1), so it's very likely R re-compiling the closures `simulate_seat_contests()`
defines internally (`put`, `ss_lookup`, `.fix_surge`) fresh on every call to
the outer function. **Not chased further** — it's a per-*call* constant
(not per-draw), so at the real n_sims=20000 it's under 0.5% of the ~190s
core simulation cost. Flagged as an open question, not a finding to act on.

## 3. Harness-level costs (measured directly, real corpus/data)

| step | measured cost | called | note |
|---|---|---|---|
| `fread` on `aec-fed-firstprefs.csv` / `-transfers.csv` / `-winners.csv` | 0.001-0.008s each | once/pair | negligible |
| `fread output/candidacies.csv` | 0.02-0.04s | **once per call site** that doesn't pass `corpus=` | small but avoidable, see below |
| `build_flow_matrix(fed2019 tx, min_n=3)` | **3.826s** | once/pair | see below |
| `candidate_returns(fed2019, fed2022)` | 0.197s | once/pair *only when* `AUSPOL_DEV_SLOPE_MODE=screened/conditional` | published default is `screened`, so this DOES run |
| `personal_prior_vote(fed2019, fed2022)` | 0.119s | once/pair, same gate | |
| `leading_candidate_returns(fed2019, fed2022)` | 0.105s | once/pair | |
| `surge_hazard_for("fed2022", ...)` | **6.244s** | once/pair, published default `AUSPOL_SALIENCE_SURGE_V2=1` | dominated by `surge_training_population()`, see below |
| `surge_training_population()` for the 8 non-target training pairs | **4.415s** of the 6.244s above | once/pair | |
| `surge_training_population()` for the 1 target pair | 0.634s | once/pair | |

**`published_flags.R` matters a lot here.** `scripts/harness_defaults.R`
applies `PUBLISHED_FLAGS` to every unset switch, so an unadorned harness run
(what actually produces the "~10-12 min/pair" figure) has
`AUSPOL_DEV_SLOPE_MODE=screened`, `AUSPOL_SALIENCE_SURGE_V2=1`,
`AUSPOL_DEFECT_DISCOUNT=1`, `AUSPOL_MP_SLOPE=1`, `AUSPOL_PARTY_COR=shrunk`,
`AUSPOL_QLD_FLOWS=1`, and `AUSPOL_FORECAST_MODE=1` (federal-specific) — **all
on**, none of them the "everything off" configuration I'd assumed on first
read of the harness's own inline `Sys.getenv(..., "0")` defaults. This
matters for anyone reasoning about the harness's cost from the file alone:
the file's own literal defaults understate what actually runs.

**Finding F — `surge_training_population()` recomputes `governed_population()`
identically across outer pairs and is a clean memoization target.**
`SURGE_V2_PAIRS` (`R/salience_surge.R`'s caller, `backtest_candidate_fed.R`)
has 9 entries: 5 federal + 4 non-federal (`vic2022`, `nsw2023`, `sa2026`,
`wa2008`). Each of the 6 outer `PAIRS` iterations in the harness calls
`surge_hazard_for()` with `train_pairs = SURGE_V2_PAIRS` minus (at most) the
current federal target — meaning the same 4 non-federal pairs, and most of
the federal ones, get their `governed_population()`/`surge_training_population()`
recomputed **from scratch on every one of the 6 outer iterations**, at
~4.4s/8-pairs ≈ 0.55s per pair-computation measured above. Memoizing by
`(election, prev, region)` across the whole harness run (a simple named-list
cache, computed once, shared across the `PAIRS` loop) would cut this to
roughly 1/6th of its current cost. **Estimated saving: ~15-25s over a 6-pair
federal run** — small against the ~60-72 minute total, but free (pure
memoization of a deterministic pure function, zero risk to output) and
belongs to `R/salience_surge.R` itself (fixable inside `surge_hazard_for()`
or `surge_training_population()`, so it benefits every harness that calls
them, not just federal).

**`build_flow_matrix()`'s 3.8s is a real but proportionate cost, not
obviously fixable.** Reading the "SUPERSET CELLS" section
(`R/flow_matrix.R` lines ~156-185): it enumerates subsets of the observed
destination classes up to size `k_max = min(K, 7)` (bounded, so up to 120
subsets for K=7, not growing with more parties past 7), and for each subset
does a `vapply` scan over every exclusion event (`d_sets`) plus a filter/
aggregate. That's **O(120 × events)** — linear in the transfer data, not
quadratic — so it scales proportionately if `AUSPOL_QLD_FLOWS`/`AUSPOL_WA_FLOWS`
add more rows (QLD is on by default, adding ~750 events per CLAUDE.md; my
3.8s measurement used only fed2019's own ~2160 rows without QLD pooling, so
the real per-pair cost is somewhat higher than measured here — not
re-measured). Called once per pair (not redundant across pairs, since each
pair uses a different prior election's transfers), so no cross-pair
memoization opportunity the way Finding F has. At ~4-8s × 6 pairs it's
roughly 1% of total run time — not a priority.

## 4. Memory

- **TCP character matrices are small, not the memory driver.**
  `object.size()` on a real n_sims=2000, 151-seat result:
  `tcp_winner`/`tcp_runnerup`/`tcp_share` are 2.3MB each (7MB total object).
  Extrapolated ×10 to the real n_sims=20000: **~73MB for one pair's TCP
  output.** Character matrices are cheap here because R interns strings —
  only 7 distinct party labels repeat across 3M+ cells. **Not a fix
  target.**
- **The observed ~5.7GB background Rscript RSS is not explained by TCP
  matrices** (73MB/pair × 6 pairs retained ≈ 440MB even in the worst case of
  holding every pair's full result simultaneously). The harness's `out_all`
  list retains `shares`, `fm`, and `sw_draws` for all 6 pairs across the
  whole run before scoring (`res_all`/`tot_all`/`all_probs` further
  accumulate per-pair outputs) — this wasn't sized directly (would require
  attaching to the live process, which I avoided since it's mid-run and I
  was told to leave it alone), so the true driver of the 5.7GB figure is
  **not identified here** and is flagged as an open question rather than a
  finding.
- No `as.data.table()`/`copy()` calls were found inside `simulate_seat_contests()`'s
  draw loop (it operates on plain matrices/vectors throughout, by design —
  see the file's own header comment on why). `build_flow_matrix()` and the
  `candidate_returns.R` functions do use `data.table::copy()`, but only once
  per call (setup), not per-row/per-draw — consistent with their measured
  sub-second, non-scaling costs above.

## 5. Ranked optimisations (≤6), by (minutes saved per six-pair federal run) / risk

All estimates below extrapolate the n_sims=2000 profile shares to
n_sims=20000 and ×6 pairs; **none of this was measured at full production
scale** (blocked by the task's memory-safety instruction), so treat the
minute figures as estimates with the same uncertainty as the "~3.2 min of
10-12" extrapolation in §1.

1. **Hoist `sd_cell` (level_sd computation) out of the `s` loop when
   `party_draws` is NULL — Finding A.** Estimated ~23% of
   `simulate_seat_contests()`'s own runtime, which is itself estimated at
   ~3.2 of the ~10-12 min/pair. **Estimated saving: ~4-5 min across a
   6-pair run.** Risk: low — pure hoist of an invariant computation, RNG
   draw values and order unchanged.
   *Proof of value-identical*: same seed, `output/backtest-fed-*-p<year>-*.csv`
   byte-identical before/after (the file already has this proof pattern from
   the 2026-09-04 fix — same standard applies).

2. **Convert `ss_cache` (superset-fallback lookup) from a string-keyed
   `environment` to an integer-indexed structure using the `mask` already
   computed at the call site — Finding B.** Estimated ~16% of
   `simulate_seat_contests()`'s runtime. **Estimated saving: ~3 min across a
   6-pair run.** Risk: low-medium — mirrors the exact pattern the
   2026-09-04 fix already validated for the main cell lookup, but touches a
   second, separate cache with its own miss-path (`matrix$superset[[nm]]`
   string lookup) that must be left alone (only the *cache key* changes, not
   the underlying data source).
   *Proof of value-identical*: same as above — `fallback_rate` and every
   simulated outcome are unaffected since this only changes how a memoized
   value is looked up, never what value is returned.

3. **Memoize `governed_population()`/`surge_training_population()` by
   `(election, prev, region)` across the harness's `PAIRS` loop — Finding
   F.** Estimated ~15-25s per 6-pair run. Risk: very low — pure function,
   deterministic, no numeric change; implement as a package-level or
   harness-local cache keyed on the three strings.
   *Proof of value-identical*: same seed, byte-identical output CSVs
   (this doesn't touch RNG-consuming code at all, since `surge_hazard_for()`'s
   own `pick_lambda()`/ridge fit is deterministic given its inputs).

4. **Do not touch TCP writes, `which()`/matrix indexing, or `mostattributes<-`**
   — measured negligible (Findings C, D). Listed here as a explicit
   *non-recommendation* so a future reviewer doesn't re-spend effort
   re-checking items this pass already cleared.

5. **If `AUSPOL_FLOW_SD_BY_SOURCE` is ever adopted into `published_flags.R`,
   apply the same `pmax`-avoidance idea as #1 to line 771 first** — Finding
   E measured it at ~33% of runtime when enabled. Not actionable now since
   it's off by default; recorded so the cost is known in advance rather than
   discovered after the arm ships (per the CLAUDE.md rule about a
   fixed-once-not-in-its-sibling pattern — this is the reverse case, a cost
   that will apply to a currently-inactive code path).

6. **Confirm the n_sims=20000 extrapolation directly, once, when memory
   allows.** Every minute-estimate above rests on a 10x linear extrapolation
   from n_sims=2000 that was *itself* only cleanly measured once (the
   "true-default-path" run in §1); the earlier badly-parameterised run
   showed non-monotonic scaling that turned out to be memory-contention
   noise from a concurrent process, not the code under test. A single clean
   n_sims=20000, one-pair run (isolated, no concurrent heavy process, `Get-Process`
   watched for peak RSS) would firm up every number in §5 before anyone
   spends implementation time on #1-#3. This is a measurement task, not a
   code change, and carries no correctness risk — just a memory/time cost
   this review's constraints didn't allow.

## What last week's fix (2026-09-04) already covered, and what it left

It closed the string-keyed-environment / `as.character()` cost on the
**main** flow-cell lookup and the `mostattributes<-` names-copying cost on
`base_v`. Both are confirmed gone here (negligible in every profile taken).
It did **not** reach: (a) the *sibling* string-keyed cache for the
superset-fallback lookup (`ss_cache`/`ss_lookup`, Finding B — same pattern,
same fix, not yet applied, exactly the kind of "fixed once, not in its
sibling" gap CLAUDE.md's recurring-hazards section warns about elsewhere in
this repo); (b) the fact that `level_sd`'s per-cell computation is
draw-invariant and belongs outside the `s` loop entirely (Finding A — not a
lookup-scheme problem, a redundant-recomputation problem, a different class
of bug from what the 2026-09-04 pass was hunting for); (c) anything at the
harness level (Finding F).

## Scripts used (scratch, not committed)

- `time_seat_sim.R` — first pass, mis-parameterised (`shrink=0.10,
  flow_sd=3.65`), useful mainly as the memory-contention cautionary tale in
  §1.
- `time_seat_sim2.R` — line-level profiling, same mis-parameterised config,
  first sighting of Findings A/B/E.
- `time_seat_sim3.R` — corrected to the true published-default config
  (`shrink=0, flow_sd=0, level_sd=c(1.10,8.67)`); the numbers quoted in §1-2
  come from this one.
- `time_harness_stages.R` — §3's `fread`/`build_flow_matrix`/`candidate_returns`/
  `personal_prior_vote`/`leading_candidate_returns` timings.
- `time_surge_v2.R` — §3's `surge_hazard_for()`/`surge_training_population()`
  timings (Finding F).
- `time_sizes.R` — §4's `object.size()` measurements.

All under
`C:\Users\peteo\AppData\Local\Temp\claude\C--dev-auspol\cc141398-163a-47bb-b977-f522480ef17c\scratchpad\`.
