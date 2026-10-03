# PARTY_COR loop-leak review, 2026-10-03

Read-only review (no R run, nothing in `scripts/` or `R/` edited). Question: does the
per-pair statewide party-correlation matrix reach the simulation of the SAME pair in each
backtest harness?

**Verdict.** The suspicion is correct for ONE harness only: `backtest_candidate_fed.R`.
There the projection and the simulation are two separate loops, so six of seven federal
pairs are simulated with fed2025's matrix. vic, nsw, qld, sa and wa do not have the bug
(vic is one loop; nsw/qld/sa run one pair per launch; wa passes no matrix at all).
At published defaults the federal bug is also **dormant**, because with
`AUSPOL_FORECAST_MODE=1` the simulator ignores `party_cor` (section 4). It is live the
moment a federal run is made with `AUSPOL_FORECAST_MODE=0`, and it is a trap for any
future change that routes `party_cor` into the federal draws.

## 1. Loop structure and the matrix each pair receives

What the table shows: for each harness, whether the matrix is built in the same loop that
simulates, which pair's matrix each simulated pair actually receives, and which pairs are
wrong. "Wrong" means the matrix was fitted for a different target than the pair simulated.

| Harness | Matrix assigned | Simulation call | Loops | Matrix each pair gets | Pairs affected |
|---|---|---|---|---|---|
| fed | `:489`, inside `for (K in PAIRS) {` `:482` (closes `:1571`) | `:1834` (`party_cor = PARTY_COR` at `:1839`), inside `for (X in out_all) {` `:1594` | TWO. Projection loop, then a separate simulation loop. `out_all` payload (`:1556-1570`) does not carry the matrix | the LAST pair in `PAIRS` for every pair. Full run: `statewide_cor("fed2025")` for fed2007, 2010, 2013, 2016, 2019, 2022 and 2025 | 6 of 7 (fed2007-fed2022). fed2025 is correct. A restricted run (`AUSPOL_FED_PAIRS=2022`) is correct, since one pair is both first and last |
| vic | `:303`, inside `for (K in PAIRS) {` `:295` (closes `:1069`) | `:986` (`party_cor` at `:988`), same loop | ONE | its own: `statewide_cor("vic<K$to>")` | none |
| nsw | `:343`, top level, once | `:1073` (`party_cor` at `:1074`), top level | none (no pair loop). One pair per run, `AUSPOL_NSW_PAIR` (`:325`), `TGT` from `TO` (`:333`) | the single target's | none |
| qld | `:314`, top level, once | `:1041` (`party_cor` at `:1043`) | none. One pair per run, `AUSPOL_QLD_PAIR` (`:296`), `TGT` `:303` | the single target's | none |
| sa | `:239`, top level, once | `:1197` (`party_cor` at `:1199`) | none. One pair per run, `AUSPOL_SA_PAIR` (`:108`), `TGT` `:115` | the single target's | none |
| wa | none | `:764`, no `party_cor` argument | ONE (`for (K in PAIRS)` `:272`, closes `:854`) | no matrix; independent draws | not applicable. Deliberate, `build_model_registry.R:359` |

Re-assignment check (comments excluded, `<<-` and `assign(` searched in all six files):
there is **no** `<<-` and no `assign(` anywhere in the six harnesses. In fed the only
assignments to `PARTY_COR` are `:233` (`NULL`, once, before the loop) and `:489` (per
pair, projection loop). Nothing in the simulation loop (`:1594-1908`) assigns it, so the
simulation loop reads whatever the projection loop left in the global on its final
iteration. Is `party_cor` passed anywhere else? In the harnesses no: there is no
`X$party_cor` or per-pair object holding it. In `R/`, `statewide_draws_as_at()` has a
`party_cor` parameter (`R/forecast_mode.R:73`), but its only harness caller
(`backtest_candidate_fed.R:997-999`) and `R/forecast_statewide.R:81` do not pass it.
`vic:939` (a flow-sweep diagnostic `s1 <- simulate_seat_contests(...)`) also passes no
`party_cor`; that is a separate, gated variant and was not studied further.

## 2. What `statewide_cor(target, mode = "shrunk")` excludes

Read from `R/statewide_cor.R:36-90` and `scripts/estimate_statewide_cov.R:319-326`.

- **It excludes ONLY the target pair itself (leave-one-out).** `by_target` is built as
  `D[rownames(D) != t, ]`: every other pair stays in, **including elections AFTER the
  target**. It is not time-forward. By `CLAUDE.md` ("Leave-one-out is NOT time-forward")
  that is a leak of later elections into an earlier target. This is true even when the
  right matrix is used, so it is a separate, pre-existing finding from the loop bug.
- The fit has 15 pairs (`estimate_statewide_cov.R:118-130`: fed 7, vic 3, nsw 2, sa 1,
  qld 2; WA excluded on purpose). Each per-target matrix uses 14.
- A target not in the fit (all WA, and any pair the spec lacks) gets the all-pairs matrix.
  `AUSPOL_COV_LOO=0` forces the all-pairs matrix for every target. `target = NULL` also
  gives the all-pairs matrix (live forecast).

What the mismatch means for each federal pair in a full run (every one of them is handed
`statewide_cor("fed2025")`, which is the matrix fitted on all 15 pairs EXCEPT fed2025):

| Pair simulated | Matrix it should get | Matrix it gets | Consequence |
|---|---|---|---|
| fed2007, 2010, 2013, 2016, 2019, 2022 | fitted without its own pair | fitted without fed2025, so it CONTAINS the pair being scored | the in-sample leak the leave-one-out change (2026-09-07) was built to close is reinstated for each of the six; the log line still prints "leave-one-out, 14 pairs (fed2025 held out)", which reads as fine if the reader does not compare it to the pair |
| fed2025 | fitted without fed2025 | same | correct |

Note the printed `COV fedYYYY party correlation ...` line at `:492` is emitted in the
projection loop with the correct per-pair value, so the log reads right while the
simulation uses a different matrix. That is the "plausible output, quietly not applied"
shape the repo keeps relearning.

Unaffected: the last federal pair, any restricted federal run (one pair), vic (one loop),
nsw/qld/sa (one pair per run), wa (no matrix).

## 3. The published path

`scripts/fit_seats_full.R` does not have the pattern. It reads `AUSPOL_PARTY_COR`
(default `"shrunk"`, `:223`, `:1243`) and calls `statewide_cor(NULL, ...)` exactly once
(`:1251`) for the one live target (Victoria 2026), so nothing is per-pair and there is
nothing to leave out. It builds correlated `sw_draws` itself (`:1283-1290`,
`Z %*% chol(sw_cor)`) and hands them to the simulator as `statewide_draws = sw_draws`
(`:1467`). There is no `party_cor =` argument in the published call (`grep` finds none)
and no loop around it. Confirmed.

Adjacent parity gap, found while checking (not part of the loop bug): the published
forecast makes its statewide draws CORRELATED, but in fed forecast mode the harness
draws come from `statewide_draws_as_at()` called without `party_cor`
(`backtest_candidate_fed.R:997-999`), so they are INDEPENDENT. See section 4.

## 4. Is the bug live at published defaults?

- `scripts/published_flags.R:80`: `AUSPOL_PARTY_COR = "shrunk"`. `:28`: `AUSPOL_COV_LOO =
  "1"`. `:343`: `AUSPOL_FORECAST_MODE = "1"`. `harness_defaults.R` has no
  `AUSPOL_PARTY_COR` line of its own; it applies `apply_published_flags()` to every unset
  switch (`:21-34`), so a bare harness run gets all three above.
- `COR_MODE` in fed is therefore `"shrunk"` at defaults (`:234`), so the wrong-matrix
  assignment does run on every full federal run.
- **But the effect is nil at defaults.** In `R/seat_sim.R`, `shift_mode` is
  `if (!is.null(statewide_draws)) 0L else if (is.null(chol_t)) 1L else 2L` (`:1071`; the
  R fallback at `:1191` has the same priority). Fed passes `statewide_draws = X$sw_draws`
  (`:1839`), and under `FORECAST_MODE=1` `sw_draws` is `FC$draws` (`:1023`), never NULL.
  So `party_cor` is built into `chol_t` but never used: **the federal harness at
  published defaults is insensitive to `PARTY_COR`, right or wrong.** The
  `-cor` filename tag and the `COV` log line say a correlation was applied when none was.
  (It still gets validated in `seat_sim.R:719-741`, so an invalid matrix would still stop
  the run.)
- The bug IS live for a federal run with `AUSPOL_FORECAST_MODE=0` set explicitly and
  `AUSPOL_PARTY_COR` on, because then `sw_draws` is NULL and `chol_t` drives the shifts.
  For vic, nsw, qld, sa the matrix is live at defaults and correct. WA is unaffected.
- Consequence for past results: any federal pooled number at published defaults was not
  affected by this bug. Any past federal run with forecast mode off was affected for the
  six pairs above. Whether such runs exist in `output/` was not checked.

## 5. Minimal fix per harness, and other loop-crossing globals

Fix, federal only (the others need no change):

1. At `:1556-1570`, add `PARTY_COR = PARTY_COR` to the `out_all` list payload, beside
   `REENTRY_CELLS`. `list(...)` keeps a NULL element, so the no-correlation arm still
   round-trips.
2. At the top of the simulation loop (beside the `SD_OVR <- NULL` reset at `:1605`), add
   `PARTY_COR <- X$PARTY_COR`, with a comment naming this review. Or pass
   `party_cor = X$PARTY_COR` at `:1839` and delete the global read.
3. Add a one-line print inside the simulation loop of `attr(X$PARTY_COR, "cor_source")`
   so the matrix actually used is in the log next to the pair, and a `stopifnot` that it
   mentions `fed<K$to>`.
4. A test: with `AUSPOL_FED_PAIRS` unset and `AUSPOL_FORECAST_MODE=0`, assert the
   simulation loop's matrix for fed2022 is NOT `identical()` to the one for fed2025
   (assumed to differ, since they are fitted on different pair sets; not verified).
   Prove the test fails on the unfixed script first.
5. Separately, per `CLAUDE.md` "fix to one harness is a fix to all": nothing to port. The
   other five were checked above and do not have the two-loop shape. If fed is ever
   merged to a single loop (see `docs/plans/harness-unification-2026-09-08.md`) this
   class of bug disappears.

Other globals with the same shape in fed (assigned in the projection loop `:482-1571`,
read in the simulation loop `:1594-1908`). Method: every line-start `name <- ` in the
projection range, minus names re-assigned in the simulation range, then read in the
simulation range, with false positives (comments, strings, `$fit`) removed by hand.

| Global | Assigned (projection loop) | Read (simulation loop) | Status |
|---|---|---|---|
| `PARTY_COR` | `:489` | `:1839` | LEAKS, this review |
| `FLOW_SD` | `:607` (only when `AUSPOL_FLOW_SD_BY_SOURCE > 0`; initial `:321`) | `:1840` | LEAKS the same way: the last pair's per-source flow sd is used for every pair. The vector is named by source class, so the wrong pair's values are silently matched by name. `AUSPOL_FLOW_SD_BY_SOURCE` is off at published defaults (`published_flags.R:455` sets `AUSPOL_FLOW_SD = "0"`; the by-source switch is not in the flags file, so it defaults to 0 at `:595`), so dormant like the others |
| `REENTRY_CELLS` | `:717` | `:1796` | already fixed, carried as `X$REENTRY_CELLS` (`:1570`) |
| `SD_OVR` | `:484` | `:1758-1811` | already fixed, reset at `:1605` |
| `sd_w`, `h`, `v`, `sdt`, `dump_f` | various | various | re-assigned inside the simulation loop before use; not a leak |
| `surge_arg`, `surge_party_arg`, `surge_mu_arg`, `surge_sd_arg`, `.xgb_flow_ov`, `shrink_arg`, `psd`, `.htv_ov` | simulation loop only | simulation loop | each initialised at the top of the simulation loop (`:1696-1698`, `:1813`); not a leak |

## What I could not confirm

- **Whether `output/statewide-cov.rds` holds what the code says.** I did not run R. The
  list of 15 pairs and 14 per target is read from `estimate_statewide_cov.R`, not from
  the file (rds dated 2026-09-19).
- **How large the numerical effect is** for fed with forecast mode off. Not measured; it
  needs a run. By reading only, the effect on the six pairs is a shift in the draw
  correlation, and for six of the seven it is an in-sample matrix.
- **Whether any past `output/backtest-fed*` file was made with forecast mode off** and
  therefore carries the bug. The arm fingerprint in the filename would say; not checked.
- **That the variable scan is complete.** It catches line-start `name <- ` assignments
  only. Assignments of the form `x[[k]] <-`, `names(x) <-`, `=` and assignments inside
  `local()` or functions were not scanned. Reads of a global inside a helper function
  called from the simulation loop were not traced.
- **The 10-minute-cap practice.** Memory notes say federal is run a pair at a time via
  `AUSPOL_FED_PAIRS`; those runs are unaffected, but I did not check which runs were
  full.
