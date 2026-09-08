# Pre-registration: unify the six candidate-seat backtest harnesses

Written 2026-09-08, before any code is moved. This is a **refactor** plan, so the
criterion runs in reverse from every other plan in this directory: instead of
proving a change improves the model, it proves the change does **nothing at all**
to it. Anything that moves a number is, by definition, not part of this work.

Six scripts, 5,632 lines: `backtest_candidate_{fed,vic,nsw,sa,wa,qld}.R` at
1,549 / 770 / 830 / 857 / 517 / 851. The statistical core they call
(`R/reentry_prior.R`, `R/seat_sim.R`, `R/salience_surge.R`, `R/statewide_cor.R`,
`R/parties.R`, `scripts/harness_defaults.R`, `scripts/published_flags.R`) is
already shared and is **out of scope**. The duplication is entirely in the
orchestration layer.

---

## Part 1 — The audit

Produced by reading the six side by side and hashing their blocks. This section
is independently useful and is reported whether or not the refactor proceeds.

### 1.1 Two live bugs in the federal harness, both in arm H

The federal harness is the only one with **two loops** — a projection loop
(`for (K in PAIRS)`, line 428) and a simulation loop (`for (X in out_all)`, line
1291). Two objects that the other five scope correctly are scoped to the wrong
loop here.

**FED-1. `SD_OVR` is never reset inside the simulation loop.** `SD_OVR <- NULL`
sits at line 430, in the *projection* loop. `sd_override` is consumed at line
1484, in the *simulation* loop, which never clears it. With
`AUSPOL_REENTRY_SD_K > 0` and `AUSPOL_SALIENCE_EXP_SD=0` — the arm currently
under decision — pair 1's combined matrix survives into pair 2, where
`combine_sd_override()` hits its own `stop()` on a dimension mismatch
(`R/reentry_prior.R:611`) because federal pairs differ in seat count and party
columns. Where the dimensions happen to agree, it does not stop; it silently
combines the wrong pair's widening. The comment at line 429 reads "NULL per
pair, so it cannot leak from one pair to the next", which is true of the loop it
is in and false of the loop that matters.

**FED-2. `REENTRY_CELLS` is the *last* pair's cells for every pair.**
`REENTRY_CELLS` is assigned at line 644 (projection loop) and is not carried in
the `out_all` payload at line 1264. Line 1478 then calls
`reentry_sd_matrix(X$shares, REENTRY_CELLS, ...)` inside the simulation loop, so
every federal pair except the last widens cells named by fed2025's re-entry
list. `reentry_sd_matrix()` matches by name and silently drops non-matches
(`R/reentry_prior.R:569-574`), and `n_set` is computed *after* that filter — so
the log prints a plausible non-zero count for cells belonging to a different
election. This is precisely the "an arm that looks like it ran and did not"
failure the `RH1` line was added to prevent.

Both are present in the working tree as of commit `56aa2b9` plus uncommitted
changes. Neither affects any published number (`AUSPOL_REENTRY_SD_K` defaults to
0) but both affect the arm being decided. **The point-estimate re-entry fill
itself is NOT affected** — that value is computed and applied to `shares`
within the same projection-loop iteration, before the loop moves to the next
pair. Only arm H's sd-widening reads `REENTRY_CELLS` a second time, later, from
the simulation loop, after the projection loop has finished and overwritten it.

Both are present in the working tree as of commit `56aa2b9` plus uncommitted
changes. Neither affects any published number (`AUSPOL_REENTRY_SD_K` defaults to
0) but both affect the arm being decided.

### 1.2 `AUSPOL_SEED` is still inert in Western Australia

`scripts/backtest_candidate_wa.R:138` reads `SEED <- 20260825L`. It is a
literal. The other five read `Sys.getenv("AUSPOL_SEED", "42")`, and
`published_flags.R` sets `AUSPOL_SEED = "42"`.

This matters more than a cosmetic difference. `docs/NEXT-STEPS.md` item 5 states
"`AUSPOL_SEED` now works in every harness; it was inert in four of six until
2026-09-07" and item 2 refuses the re-entry prior specifically because it needs
seed-averaging. **WA is 361 of 2,050 seat-elections and cannot be seed-averaged
at all.** Any three-seed mean quoted over the pooled corpus is a three-seed mean
over 1,689 seats and a one-seed value over 361, and the WA column of every such
table has been identical by construction rather than by agreement.

WA is also the only harness with **no `set.seed()` call** (the others call it
immediately before simulating). Today nothing between load and simulate consumes
RNG, so this is latent rather than active — but it means WA's reproducibility
rests on `simulate_seat_contests(seed=)` alone, where the other five have two
independent guarantees.

### 1.3 Switches the published configuration sets that a harness cannot honour

`published_flags.R` is applied to every unset switch by `harness_defaults.R`, so
a bare run is meant to measure what ships. Three published switches do not reach
Western Australia:

| switch | published | WA behaviour |
|---|---|---|
| `AUSPOL_PARTY_COR` | `shrunk` | **silently ignored** — WA never calls `statewide_cor()` and never passes `party_cor` |
| `AUSPOL_DEV_SLOPE_MODE` | `screened` | **silently substituted** — WA's `.cond` accepts `"screened"` but WA never calls `salience_permit_for()` or `screened_slopes()`, so it runs *conditional* slopes under the screened flag |
| `AUSPOL_SEED` | `42` | **silently ignored** (1.2 above) |

The `screened` case is worse than the surge-v2 gap the WA header does disclose
(lines 93-100), because a skip is visible as an absence while a substitution
produces a full set of numbers from a different mechanism. `docs/NEXT-STEPS.md`
records "WA harness lacks the screened slope mode" under *Deferred, not fixed* —
but that entry predates the 2026-09-07 change that made `.cond` accept
`"screened"`, and the entry now understates it.

Queensland is the only harness that **stops** rather than silently ignoring a
switch it cannot honour (`.inert`, lines 315-330). That pattern is the fix for
all of the above and exists in exactly one of six files.

### 1.4 `AUSPOL_SMOOTH` reaches two harnesses of six

`fed:288` and `wa:133` read `Sys.getenv("AUSPOL_SMOOTH", "0.15")`. `vic:214`,
`nsw:259`, `sa:274` and `qld:226` hardcode `SMOOTH <- 0.15`. A sweep of the flow
smoothing parameter would move federal and WA and return byte-identical output
for the other four — the exact "this input does not matter" signature CLAUDE.md
records for `AUSPOL_N_SIMS` in NSW (2026-08-25) and `AUSPOL_SEED` in four
harnesses (2026-09-07). It is not in `published_flags.R`, so it is also not
caught by the registry.

### 1.5 `AUSPOL_DEFECT_DISCOUNT` is one switch naming two different mechanisms

Federal (lines 692-723) **fits** the discount: a leave-one-election-out median
of major-party-member-to-non-major vote ratios from `output/candidacies.csv`,
with the target election explicitly excluded, printed as `BF0d`.

Victoria, NSW, SA, Queensland and WA all hardcode `0.282` — the federally-fitted
constant, frozen. So `AUSPOL_DEFECT_DISCOUNT=1`, which is the **published**
value, means "estimate it, holding out the target" federally and "use a federal
number" everywhere else. A cross-harness comparison of this switch is not
comparing one thing.

### 1.6 Western Australia builds a different party universe from the other five

`wa:256` — `parties <- union(colnames(A), names(sb))`, then `mat` is padded with
zero columns for classes present only at the *target* election.

The other five take `parties <- colnames(mat)` from the prior election alone. A
class that contests the target and did not contest the prior has **no column at
all** and cannot win any seat in the simulation, regardless of its statewide
share. SA (`absent22`, line 465) and Queensland (`absent_prev`, line 497) both
*detect* and *print* this population and then do nothing about it.

This is a substantive modelling divergence sitting inside a "duplication"
problem, and it overlaps the re-entry prior's own subject matter. It must be
decided by evidence, not inherited by whichever file a reader opens.

### 1.7 The check-code registry has broken, in three separate ways

ARCHITECTURE.md's registry does not cover the `B*` harness codes at all. Within
the six files:

- **`BS1p` is emitted by four harnesses** (fed:1303, vic:585, nsw:640, sa:650),
  and `BS1f` by the same four, and `BS0s` by three. The `BS` prefix is South
  Australia's. A grep for `BS1p` across the six logs returns four jurisdictions.
- **`BS1c` means three different things inside `backtest_candidate_sa.R`**: the
  conditional-slopes failure (`BS1c!`, line 343), the One Nation concentration
  arm (line 513), and the seat-swing port (line 632). Queensland inherited the
  fault: `BQ1c` is both conditional slopes and the seat-swing port, and `BQ1s`
  is both the seat-file fallback and `shrink`.
- **Federal reuses two codes for two meanings each**: `BF0v` is both the
  surge-v2 hazard line (1417) and the point-estimate blend line (1444); `BF0s`
  is both the flat surge hazard (286) and the salience level lines (989, 1016).
- **NSW emits four prefixes from one file**: `BT*`, `BN*` (`BN0v`, `BN1c`,
  `BN1d`), `NB*` (`NB0`, `NB1e`) and `BS*`.

This is the same failure as the `B1` collision ARCHITECTURE.md records, at
larger scale, and it is the direct cause of the near-miss recorded in this
session's brief (coding the NSW summary line as `BT2` when `BT2` already labelled
by-election truth notes).

### 1.8 Blocks that are byte-identical, and blocks that have drifted

Hashed across all six:

| block | verdict |
|---|---|
| `.level_sd` + `.level_mult` + `.lm` (~55 lines) | **byte-identical in all six** |
| `.arm_fingerprint` (~12 lines) | **byte-identical in all six** |
| `.own_x()` | identical in five; WA adds an early `if (!nrow(ov)) return(x)` that is provably equivalent (`setNames(numeric(0), character(0))[seats]` is all-`NA`, so `hit` is all-`FALSE`) |
| MP-slope block (~22 lines) | **five distinct hashes**; NSW and QLD agree. The only substantive difference is the target expression (`eb` / `.eb` / `TGT` / `"sa2026"` / `el_to`) |
| surge-v2 `v2_pairs` (~10 lines × 5) | now agrees with `scripts/fit_salience_surge_v2.R` in all five, after the Queensland `sa2026`→`qld2024` fix. NSW substitutes `list(election = TGT, prev = PRV, region = "nsw")` for the fixed `nsw2023` row — harmless today (both NSW pairs end up training on the same eight) but undocumented |
| `CAL_TAG` | six different clause lists, genuinely so |

`all_election_pairs()` (`R/reentry_prior.R:682`) exists *specifically* to end
per-harness pair lists — its own docstring cites the Queensland `sa2026` drift
as the reason. **The surge-v2 list was never migrated to it.** The same
duplication the package function was written to kill is still live in five files,
in a second list.

### 1.9 Structural divergences that are not jurisdiction-specific data handling

| behaviour | fed | vic | nsw | sa | wa | qld |
|---|---|---|---|---|---|---|
| `stopifnot(is.finite(SHRINK), SHRINK >= 0, SHRINK < 1)` | yes | **no** | **no** | yes | yes | yes |
| prints published shrink beside actual (`BS1s`/`BQ1s`) | no | no | no | yes | no | yes |
| writes `-totals` file | yes | yes | yes | yes | **no** | yes |
| writes `-allprobs` file | yes | **no** | **no** | yes | **no** | yes |
| checks per-seat probabilities sum to 1 | no | no | no | yes | no | yes |
| uses `reentry_apply_harness()` | yes | yes | yes | yes | **no — hand-rolled** | yes |
| stops on a switch it cannot honour | no | no | no | no | no | **yes** |
| reliability bins printed | no | no | **yes** | no | no | no |
| misses table printed | **no** | yes | yes | yes | no | yes |

Notes on three of these:

- **WA hand-rolls the re-entry prior** (lines 314-343) rather than calling the
  shared `reentry_apply_harness()`. The hand-roll is a near-copy and its only
  behavioural difference is that it has no `tryCatch` around
  `apply_reentry_prior()` — so WA aborts where the other five report `RE1!` and
  continue. That duplication was created *today*, in the session that also fixed
  WA's missing `positions` argument.
- **WA writes no totals**, so the statewide-covariance criterion in
  `prereg-statewide-covariance.md` — whose primary quantity is the seat-count
  distribution — structurally cannot be evaluated on WA's 361 seat-elections.
- **NSW never subsets `shares` to `keep`.** It simulates every seat with a prior
  baseline, including seats it does not score, and `seat_share_rmse(shares,
  fp_tgt)` at line 770 therefore covers a wider seat set than the log loss on
  the line above it. The other five subset before simulating.

### 1.10 Two latent traps worth naming before anyone edits these files

- **`keep` is used for two things in SA and Queensland.** `keep <- pinned[i, ]`
  (a logical party mask, sa:562, qld:543) and `keep <- intersect(rownames(shares),
  win$seat)` (a seat vector, sa:601, qld:567). It works only because the
  elasticity block happens to precede the seat match. Victoria and NSW renamed
  theirs to `keepc`; SA and Queensland did not.
- **Victoria prints the MP tier twice**, as `BV1n` (line 393) and `BV1m` (line
  429), with different content under two codes.

---

## Part 2 — The target shape

### 2.1 What genuinely differs between jurisdictions, and what does not

Read all six and the real differences are **data acquisition, pair enumeration,
truth provenance, and which arms are admissible**. Everything between "I have a
seat × class matrix of prior shares plus two statewide vectors" and "I have a
scored CSV" is the same computation in all six, and the audit above is what
happens when it is maintained six times.

**Stays per-jurisdiction (config data, not code):**

- pair list, and the env variable that selects among them
  (`AUSPOL_NSW_PAIR`, `AUSPOL_QLD_PAIR`, `AUSPOL_FED_PAIRS`)
- first-preference, transfer and winner file names, resolved per pair —
  Queensland's two pairs having two *different* flow sources
  (`qld2020` own distribution vs `fed2019`) is a two-field difference in a
  config row, not a code branch
- polling date per target (`FED_DATE`, `VIC_DATE`, `WA_DATE`)
- seat-spread source: seat file of the target (vic/nsw/sa), seat file with a
  later-file fallback (qld), median over all pairs (fed), **previous pair's
  realised swing spread (wa)**
- truth provenance and its known contaminations: Victoria's by-election
  exclusion list plus its first-preference-leader cross-check, NSW's
  next-seat-file disagreement count, SA's `Frome → Ngadjuri` rename, WA's
  coverage guard and 55% skip floor
- the minimum-seats sanity floor and its explanatory message
- **the arm admissibility table**, with a reason string per unavailable arm

**Becomes shared (one implementation, tested):**

- switch resolution and validation — `level_sd`, `level_mult`, `SEAT_SD_MULT`,
  `SHRINK`, `PARTY_SD`, `SMOOTH`, `SEED`, `N_SIMS` — with the `LV1`/`LV2`/`CAL`
  disclosure lines
- `CAL_TAG` construction, including the fingerprint and code tag
- the projection chain: dev slopes → MP tier → personal prior vote and vote
  transfer → salience screen → elasticity → re-entry post-swing write →
  zero-IND-where-nobody-nominated → renormalise
- the salience stage: hazard fit, point-estimate blend, recipient, scale,
  sd override
- the `simulate_seat_contests()` call and its argument assembly
- scoring and output: accuracy, Brier, log loss, calibration slope, seat-share
  RMSE, the single summary line, the per-seat / allprobs / totals writes, the
  sum-to-one check

**Deliberately NOT forced uniform:**

- Federal `FORECAST_MODE`. It is a genuinely different statewide input, not a
  variant of the oracle path, and it drags `statewide_draws_as_at()`,
  `fit_fundamentals()`, the folded-class rescale and four experimental arms
  behind it. It becomes a named stage implementation
  (`statewide_input = "oracle" | "forecast"`) that any jurisdiction *could* take
  and only federal currently does.
- Victoria's `AUSPOL_FLOW_UNC` ensemble, which replaces the simulation call
  entirely with 40 replicates.
- SA's One Nation concentration arm, which needs a per-region transposed-federal
  file that only SA has.
- Federal's notional baselines, insurgency shrink, flow trend, flow pooling,
  IND salience/trend and minor-poll adjustment.

Each of these stays a jurisdiction-scoped extension registered in that
jurisdiction's config. **The test is not "can this be shared" but "is a copy of
it in another file dangerous".** Federal's forecast mode is not dangerous
because it exists once; `BS1p` printed by four harnesses is.

### 2.2 The shape

```
R/harness_options.R    harness_options()   parse and validate every AUSPOL_*
                                           switch once; return a typed list;
                                           print LV1/LV2/CAL
R/harness_tag.R        harness_tag()       CAL_TAG from that list + config
                                           extras + fingerprint + code tag
R/harness_project.R    harness_project()   mat, fa, fb, st_a, st_b, opts, cfg
                                           -> shares (post-swing, post-renorm)
R/harness_salience.R   harness_salience()  hazard, blend, recipient, scale, sd
R/harness_simulate.R   harness_simulate()  the simulate_seat_contests() call
R/harness_score.R      harness_score()     metrics, summary line, file writes

scripts/harness/fed.R  } config lists only: loaders, pairs, dates, truth,
scripts/harness/vic.R  } spread source, arm admissibility with reasons
scripts/harness/nsw.R  }   ~120-160 lines each
scripts/harness/sa.R   }
scripts/harness/wa.R   }
scripts/harness/qld.R  }

scripts/backtest_candidate_{fed,vic,nsw,sa,wa,qld}.R
                       kept as thin drivers (~40 lines + the existing header
                       essay, which is load-bearing documentation and is NOT
                       deleted), so every run command in NEXT-STEPS, CLAUDE.md
                       and the plans still works unchanged
```

Keeping six entry points with their headers intact is deliberate. Those headers
carry the reasoning for every jurisdiction quirk — WA's leakage argument, SA's
"read this before quoting the One Nation number", Queensland's four named
differences — and a single `AUSPOL_REGION=` driver would orphan all of it.

### 2.3 The one design rule that would have prevented most of this audit

**A jurisdiction declares which arms it implements, and setting an arm it does
not implement is a `stop()`, not a shrug.** Queensland already does this. Applied
across the six, that single rule catches, in advance: WA's missing `sd_override`
plumbing, WA's missing `positions`, WA's ignored `AUSPOL_PARTY_COR`, WA's
substituted slope mode, WA's inert seed, and the four harnesses that ignore
`AUSPOL_SMOOTH`. It is worth more than the deduplication.

---

## Part 3 — The migration, which cannot silently change behaviour

### 3.1 Stage 0 — freeze the golden master, on a clean commit

Before any line moves:

1. Commit or stash the working tree. The current tree is dirty across all six
   harnesses (arm H). A golden master taken on a dirty tree is not reproducible,
   and `.code_tag` will mark it `x`.
2. Run all 22 pairs at published defaults, seed 42, `AUSPOL_N_SIMS=20000`, one
   launch per pair (the 10-minute background cap).
3. Archive every `output/backtest-*.csv`, `-totals*.csv` and `-allprobs*.csv`
   into `output/golden/<sha>/`, plus the full stdout of each run.
4. Record `scripts/pool_backtests.R` output as the headline: 22 pairs, 2,050
   seat-elections, PB3/PB3f.

**Additionally, and this is the load-bearing piece: add a shares dump to all six
harnesses first.** Federal (`AUSPOL_DUMP_SHARES`) and WA
(`AUSPOL_WA_DUMP_SHARES`) already have one; the other four do not. The
pre-simulation `shares` matrix is a deterministic function of the projection
chain with **no Monte Carlo in it**, so a diff on it is exact, instant, and
isolates a projection bug from simulation noise. Most of this migration touches
only the projection chain, and being able to prove it in seconds per pair rather
than minutes changes the cost of the whole project.

Unifying the dump switch to one name (`AUSPOL_DUMP_SHARES`) across all six is
itself a behaviour-preserving change and is the first commit.

### 3.2 The tolerance is zero, and here is why that is achievable

**Requirement: byte-identical `shares` dumps and byte-identical per-seat
probability CSVs, for every pair, at every stage.** Not "within tolerance".

This is achievable, not aspirational:

- `simulate_seat_contests()` is deterministic given `seed`, and the C++ core is
  proven `expect_identical()` against the R engine on a full fed2022 run
  (2026-09-07).
- A pure code move changes no RNG call and no arithmetic order, so `dev_slope()`
  and the renormalisations produce the same doubles.
- The repo has already accepted byte-identity as the standard twice: the seat-sim
  hoists (2026-09-04, `seat-probs-vic-2026.csv` byte-identical) and the NSW pair
  refactor (2026-09-07, "the 2023 pair reproduces its previous output
  byte-for-byte, which is what accepted the refactor").

**A floating-point excuse is not accepted.** If a byte differs, the order of
operations changed, and the change is a model change wearing a refactor's
clothes. Find it or revert.

**The single exception, handled by sequencing rather than by tolerance:** WA
cannot be byte-identical *and* honour `AUSPOL_SEED`. So fixing WA's seed is
**not part of this migration**. It is a separate, pre-registered change made
*before* stage 0, with its own before/after measurement of all seven WA pairs, so
that the frozen golden master already contains the corrected behaviour. The same
applies to FED-1 and FED-2 (§1.1) and to every other finding in Part 1 that moves
a number.

### 3.3 Stage 1 — the provably-inert extractions

One commit each, in this order, each proven by a `shares` diff on **all 22
pairs** (seconds, not minutes):

1. `AUSPOL_DUMP_SHARES` unified across six. *(enables everything below)*
2. `.level_sd` / `.level_mult` / `.lm` → `harness_options()`. Byte-identical in
   all six, so this is mechanical. ~330 lines removed.
3. `.arm_fingerprint` → shared. Byte-identical in all six. ~70 lines removed.
4. `.own_x()` → shared, taking WA's guarded form. Requires stating the
   equivalence argument in the commit. ~55 lines removed.
5. MP-slope block → shared, taking the target as an argument. Five hashes
   collapse to one. ~130 lines removed.
6. surge-v2 `v2_pairs` → the package, beside `all_election_pairs()`, with NSW's
   `TGT`/`PRV` substitution made an explicit parameter and documented. ~50 lines
   removed, and one more hand-maintained list retired.

Expected: ~640 lines gone, **zero bytes of output changed**, no simulation run
needed beyond the shares diffs.

### 3.4 Stage 2 — `harness_tag()`, proven with no compute at all

`CAL_TAG` is a pure string function of the environment. Build `harness_tag()`,
then unit-test it against a grid of ~25 environment configurations, asserting it
reproduces each of the six existing tag expressions exactly. Where a harness has
a genuinely unique clause (`-p` and `-fc` and `-insurg` federally, `-unc` in
Victoria, `-conc` in SA, `-m` absent in WA), the config supplies it.

This costs no simulation and closes the class of bug the tag exists to prevent —
a new switch missing from one file's tag — permanently.

### 3.5 Stages 3-8 — one jurisdiction at a time

**Order, and the argument for it:**

> **Queensland → South Australia → NSW → Victoria → WA → Federal.**

Not "fewest quirks first" and not "most drift first". The criterion is **cheapest
to re-prove, with an external check available**, then increasing structural
difficulty, with the two that would *reshape the seams* last.

- **Queensland first.** 93 seats × 2 pairs = 186 seat-elections, so a full
  re-prove is cheap. It exercises the pair-selector machinery. It is the only
  harness that already has the arm-admissibility guard, so the shared version can
  be built against a working example. And it is benchmarked against AE Forecasts
  (0.3294 against 0.3578), so a regression is visible against a number outside
  this repo.
- **South Australia second.** 47 seats, single pair, and Queensland's parent — so
  the two configs should differ in exactly the four ways Queensland's header
  names. If they differ in a fifth, that is a finding.
- **NSW third.** Two pairs on the `AUSPOL_NSW_PAIR` pattern, plus the truth
  cross-check, plus the four-prefix code cleanup.
- **Victoria fourth.** Three pairs in one run, the by-election truth list with
  its own guard, and `AUSPOL_FLOW_UNC` as the first jurisdiction-scoped
  extension.
- **WA fifth.** The hardest config: no seat file, previous-pair spread, coverage
  guard and skip floor, no salience, hand-rolled re-entry, and the different
  party universe (§1.6). Deliberately late so the shared seams are not designed
  around the exception.
- **Federal last.** Largest (1,036 of 2,050 seat-elections), the two-loop
  structure, forecast mode, notional baselines, and eight arms no other harness
  has.

**The named cost of this order, stated in advance:** the shared core is unproven
on the majority of the corpus until the final stage. Mitigation — the old federal
script is untouched until stage 8, so its golden-master diff is re-run as a
regression check at the end of *every* stage; if federal ever diverges while
federal code has not been touched, something shared has leaked.

**Per stage:**

1. Write the config. Run the old script and the new driver side by side.
2. Diff the `shares` dump for every pair the jurisdiction owns. **Must be
   byte-identical.**
3. Diff the per-seat CSV, totals and allprobs against `output/golden/<sha>/`.
   **Must be byte-identical.**
4. Diff the stdout, modulo timestamps. Every disclosure line the old script
   printed must still print. A missing `RH1`, `SR1` or `TR1` is a failed stage.
5. Only then delete the old body, keeping the header essay in the driver.

### 3.6 Arms that are OFF at published defaults get their own golden runs

A default-config golden master exercises none of: elasticity, flow uncertainty,
seat-swing port, insurgency shrink, forecast mode, notional baselines, flow
trend, flow pooling, IND salience, IND trend, minor-poll adjustment, ONP
concentration, re-entry, re-entry sd, salience expected, salience exp-sd.

That is sixteen code paths the migration would move without ever running. For
each, one golden run on its cheapest jurisdiction (or its only one), taken at
stage 0 and diffed at the stage that moves it. Where an arm is genuinely too
expensive to golden — federal forecast mode over seven pairs — say so explicitly
in the commit rather than letting the silence read as coverage.

### 3.7 Sizing

| stage | scope | compute | effort |
|---|---|---|---|
| 0 — freeze | 22 pairs + 16 arm runs | ~1 session of launches | 1 session |
| 1 — inert extractions | ~640 lines | shares diffs only | 1 session |
| 2 — tag | pure string tests | none | ½ session |
| 3 — qld | 186 seat-elections | 2 pair-runs | 1 session |
| 4 — sa | 47 | 1 pair-run | ½ session |
| 5 — nsw | 181 | 2 pair-runs | 1 session |
| 6 — vic | 239 | 3 pairs, one run | 1½ sessions |
| 7 — wa | 361 | 7 pairs, one run | 2 sessions |
| 8 — fed | 1,036 | 7 pair-runs | 2-3 sessions |

**Total ~10-11 sessions.** End state: roughly 900-1,100 lines of shared,
documented, unit-tested package code plus ~150 lines of config per jurisdiction
plus the preserved headers — call it 2,000-2,200 lines against 5,632 today, with
the check-code registry repaired and the arm-admissibility guard universal.

---

## Part 4 — Refusal section: what makes this NOT worth doing

Written before starting, in the shape this repo requires.

1. **A jurisdiction that cannot be reproduced byte-for-byte after two attempts
   is abandoned, not approximated.** Its script stays standalone and the plan
   records why. A "close enough" migration converts a file that is known-correct
   into one that is unknown-correct, which is strictly worse than the
   duplication being removed.

2. **If the shared functions accumulate more than three `if (region == ...)`
   branches, the abstraction is wrong and the work stops.** Six honest copies
   beat one file with six hidden modes. The failure this project exists to fix is
   *silent divergence*; a config field nobody reads is exactly as silent as a
   missing line, and harder to grep for. Concretely: if `harness_project()` needs
   to know it is running WA, the party-universe question (§1.6) has been buried
   rather than decided.

3. **A half-migrated state is worse than either end state, so there is a hard
   date.** Victorian nominations close 12 noon 9 November 2026 and the poll is 28
   November. Three jurisdictions on the shared core and three standalone means
   "a fix to one harness is a fix to all of them" now requires understanding two
   architectures — which is precisely the cost this work claims to remove,
   doubled. **Either finished and merged, or fully reverted, by 30 September
   2026.** Not "mostly done".

4. **If the justification is "future arms will be cheaper", check it against the
   record.** The last four arms (surge recipient, salience expected, salience
   exp-sd, re-entry sd) each cost roughly 30 lines × 6 files — perhaps an hour of
   typing apiece. That is not the case for this work. **The case is the defect
   rate**: nine parity defects found in eleven days, three of which produced
   numbers that were investigated and written up before anyone noticed (the SA
   `shrink` calibration slope, the WA `flow_lean` NA, the fed2025 headline). If
   the audit above had turned up only tidiness findings, this plan should be
   refused.

5. **If stage 0 is skipped because "the pooled metrics agree to four decimals",
   refuse and go back.** Four decimals of pooled log loss is *below* the noise
   floor: NEXT-STEPS item 5 records the seed alone moving vic2014 by 0.0112 at
   5,000 sims, and PB2f records the whole 0.0019 difference between two model
   versions being one seat crossing the `1e-6` floor. Metric agreement at that
   precision is evidence of nothing.

6. **If a bug found mid-migration is fixed in the same commit as the migration,
   the stage is void.** The byte-identity test is the entire safety net, and it
   cannot survive a deliberate behaviour change riding along. Every finding in
   Part 1 is its own commit, before or after, never during.

7. **If the arm-admissibility guard (§2.3) is dropped to save time, the value
   proposition is gone.** Deduplication alone does not stop the next WA-shaped
   defect; the guard does. If the guard is cut, so is the plan.

## What the criterion cannot see

- **Byte-identity proves the refactor changed nothing. It does not prove
  anything was right.** Every defect in Part 1 that is not fixed beforehand will
  be reproduced by the golden master with perfect fidelity — WA's hardcoded seed
  most of all.
- **It cannot see a path no run exercises.** §3.6 is a partial answer, not a
  complete one; sixteen off-by-default arms cannot all be goldened economically,
  and the ones that are skipped are stated rather than covered.
- **It cannot tell a correct config from a faithful one.** If WA's config
  records `seed = 20260825` because that is what the old script did, every diff
  passes and the defect is now written down as intent.
- **It says nothing about whether the party-universe divergence (§1.6), the
  defect-discount divergence (§1.5) or the `AUSPOL_SMOOTH` gap (§1.4) should be
  resolved toward the majority or toward the minority.** Those are three
  separate model questions that this audit surfaces and this plan deliberately
  does not answer. Resolving them by picking whichever behaviour is easier to
  share would be exactly the "change smuggled inside a refactor" that clause 6
  forbids.
