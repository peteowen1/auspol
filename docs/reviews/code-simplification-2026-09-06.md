> **Status, 2026-09-07.** Acted on from this report: the SA (and inherited
> QLD) independent-zeroing threshold `> 0.5` aligned to the other harnesses'
> `> 0` (reporting only -- every seat was zeroed either way, so the harness
> was under-reporting its own work); the dead `avail` assignment in
> `R/flow_matrix.R` removed; `seat_shrink_vector()` documented as having no
> caller rather than left looking load-bearing; and the `.own_x` closure
> replaced by `remove_transferred_votes()` / `blend_salience_shares()` in the
> package, which removes two of the seven duplicated blocks. The remaining
> five (the level-sd/multiplier header, the MP-slope reader, the arm
> fingerprint, the permit closure, the scoring block) are NOT done and are
> the standing item.

# auspol simplification review — R/*.R, fit_seats_full.R, five backtest harnesses

Scope: R/*.R, scripts/fit_seats_full.R, scripts/backtest_candidate_{fed,vic,nsw,sa,wa}.R,
scripts/published_flags.R, scripts/harness_defaults.R. Read-only; nothing under
C:\dev\auspol was modified. All line numbers verified against the files on disk at
the time of review (dev branch, HEAD ba9979f, 2026-09-06).

---

## 1. Blocks duplicated across the five harnesses (and fit_seats_full.R)

Ranked by lines-saved × copies. All seven blocks below were verified to exist at
the cited lines by direct read, not by grep alone.

### 1a. MP-slope-tier reader — 19 lines × 5 harnesses = ~95 lines, near-verbatim

`fed.R:733-751`, `nsw.R:359-377`, `sa.R:327-345`, `vic.R:322-340`, `wa.R:199-217`.
All five read `output/mp-slope-by-target.csv`, filter to the target election with
the same "copy to a differently-named local to dodge data.table NSE" idiom, exclude
GRN by default, and build `.MP_SLOPE`. **No logic drift** — nsw/sa/vic/wa are
byte-identical apart from the one line that sets `.tgt` (a literal string, `.eb`,
or `el_to` depending on the harness's own variable name) and minor comment wording.
fed's copy differs cosmetically (comment moved elsewhere in the file) but is
functionally identical. Example (nsw.R:359-377):

```r
if (identical(Sys.getenv("AUSPOL_MP_SLOPE", "0"), "1")) {
  ...
  .mpf <- "output/mp-slope-by-target.csv"
  if (!file.exists(.mpf))
    stop("AUSPOL_MP_SLOPE=1 needs ", .mpf, " -- run scripts/fit_mp_slope.R")
  .mpt <- data.table::fread(.mpf, showProgress = FALSE)
  .tgt <- "nsw2023"
  .row <- .mpt[.mpt$target == .tgt & is.finite(.mpt$member), ]
  if (!nrow(.row))
    stop("no leave-one-out MP slopes for ", .tgt, " in ", .mpf)
  if (!identical(Sys.getenv("AUSPOL_MP_SLOPE_GRN", "0"), "1"))
    .row <- .row[.row$party != "GRN", ]
  .MP_SLOPE <- stats::setNames(as.numeric(.row$member), .row$party)
}
```

**Proposal**: `mp_slope_for(target_election, grn = FALSE)` in `R/hyperpars.R` (or a
new `R/mp_slope.R`), taking the target election label as its one varying input and
returning `.MP_SLOPE` (or `NULL`). Harness plumbing — but it's pure model-input
derivation with zero harness-specific state, so it belongs in R/, not
`scripts/harness_common.R`.

### 1b. `.own_x` closure — 8 lines × 5 (fed, nsw, sa, vic, fit_seats_full.R) = ~40 lines, byte-identical

`fed.R:695-703`, `nsw.R:399-407`, `sa.R:355-363`, `vic.R:350-358` (indented, same
body), `fit_seats_full.R:607-615`. **WA has no copy** — its header comment says so
explicitly ("this harness makes no `personal_prior_vote()` call"), which is a
correct, deliberate omission, not drift.

```r
.own_x <- function(p, seats, x) {
  if (is.null(.own_prev)) return(x)
  ov <- .own_prev[.own_prev$party == p, ]
  v <- stats::setNames(ov$own_prev_pcv, ov$seat)[seats]
  out <- x
  hit <- !is.na(v)
  out[hit] <- unname(v[hit])
  out
}
```

**Proposal**: `apply_own_prior_vote(own_prev, party, seats, x)` in
`R/candidate_returns.R`, next to `personal_prior_vote()` / `remove_transferred_votes()`
which it's the natural third half of. It closes over `.own_prev` only for brevity in
each harness; making it take `own_prev` as an explicit argument removes the closure
and the duplication in one move.

### 1c. IND-zeroing block — ~10-15 lines × 5, ONE REAL LOGIC DRIFT

`fed.R:1156-1177`, `nsw.R:462-490`, `sa.R:475-499`, `vic.R:426-441`, `wa.R:271-286`.
Shape: find seats with no IND nomination at the target election, zero the IND
column there, renormalise, log what was zeroed.

**Drift, and it is real, not just cosmetic**: SA's threshold is `> 0.5`
(`sa.R:494`: `zeroed <- no_ind[shares[no_ind, "IND"] > 0.5]`) where fed/nsw/vic/wa
all use `> 0` (e.g. `nsw.R:483`: `zeroed <- no_ind[shares[no_ind, "IND"] > 0]`).
This only affects which seats get LOGGED as "zeroed" (the zeroing itself,
`shares[no_ind, "IND"] <- 0`, applies uniformly regardless of the print threshold),
so it is not a correctness bug — but it means SA's printed zeroed-seat count is not
comparable to the other four harnesses' counts on the same definition, and nothing
in the code or its comment explains why 0.5 rather than 0 was chosen (the SA
comment at `sa.R:485-490` justifies using the target-election oracle as the
nomination proxy, but not the specific `0.5` cutoff).

**Proposal**: `zero_unnominated_class(shares, class, target_fp, code_prefix)` in
`R/seats.R` or a new `R/nomination_screen.R`, taking the print-threshold as a named
argument defaulting to `0` so SA either states its reason for `0.5` or is brought
into line.

### 1d. Salience-permit slope closure — 6-8 lines × 4 (fed, sa, vic, fit_seats_full.R)

`fed.R:759-770` (as `.fed_slope`), `sa.R:365-374` (`.sa_slope`), `vic.R:661-670`
(`.vic_slope`), `fit_seats_full.R:661-670` (`.vic_slope`, same name and body as the
Victoria harness — fit_seats_full.R is literally the live-forecast twin of
`backtest_candidate_vic.R`). **NSW inlines the equivalent logic directly inside its
per-party `for` loop** (`nsw.R:426-431`) rather than factoring it into a named
closure — same `pm[is.na(pm)] <- TRUE` idiom, different shape, so NSW is a fifth
occurrence of the *logic* but not a sixth occurrence of the *closure pattern*.
WA has no salience screen at all (no `.screened` branch).

```r
.sa_slope <- function(p, seats) {
  if (.screened && !is.null(.permit)) {
    pv <- .permit[.permit$party == p, ]
    lut <- stats::setNames(as.logical(pv$permit), pv$seat)
    pm <- unname(lut[seats]); pm[is.na(pm)] <- TRUE
    return(screened_slopes(p, seats, .returns, pm, same_mp = .MP_SLOPE))
  }
  if (.cond && !is.null(.returns)) return(conditional_slopes(p, seats, .returns, same_mp = .MP_SLOPE))
  DEV_SLOPE[[p]]
}
```

**Proposal**: `slope_for_party(p, seats, permit_tbl, returns, dev_slope_default, screened, cond, same_mp)`
in `R/salience_screen.R` next to `screened_slopes()`/`conditional_slopes()`, which
both fed/sa/vic/fit_seats_full.R call directly and NSW could call too instead of
inlining the `pm[is.na(pm)] <- TRUE` fix-up separately.

### 1e. `level_sd` parser + `SEAT_SD_MULT` header block — ~100 lines × 5, now in sync

`fed.R:65-167`, `nsw.R:28-121`, `sa.R:63-151`, `vic.R:19-104`, `wa.R:33-108`.
Parses `AUSPOL_LEVEL_SD`, builds `.level_mult`/`.lm()`, parses `AUSPOL_SEAT_SD_MULT`.
**This is the block whose bug CLAUDE.md's own history should have caught sooner**:
until today's fix (git log: "Shrink to 0.01, wire the model work into the published
forecast, unblock per-seat shrink") `SEAT_SD_MULT` silently did nothing whenever
`level_sd` was active (on by default since 2026-08-27), because
`simulate_seat_contests()` computes `sd_cell` from `level_sd` and ignores `seat_sd`
entirely when `level_sd` is given. fed's copy was fixed first and carries the long
"a LIE until 2026-09-06" post-mortem comment (`fed.R:142-153`); the other four carry
a short "PORTED FROM THE FEDERAL HARNESS 2026-09-06" comment instead
(`nsw.R:106-110`, `sa.R:136-140`, `vic.R:89-93`, `wa.R:93-97`) — **verified all five
now apply the identical fixed logic**, so there is no live drift today, but this is
exactly the shape of bug (fix lands in one harness, ported to the rest only after
someone notices) that CLAUDE.md's "a fix to one harness is a fix to ALL of them"
rule exists to prevent, and it happened again on the same parameter that already
caused the 2026-08-21 SA incident recorded in that rule.

**Proposal**: `resolve_level_sd(level_sd, seat_sd_mult)` returning the
already-multiplied `level_sd` (or a flag to multiply `seat_sd` instead), in
`R/seat_shrink.R` or `R/hyperpars.R`, called once per harness instead of the current
copy-pasted `if (is.null(.level_sd)) {...} else {...}` branch. This is the single
highest-value target: it is model logic (belongs in R/), it is exactly the class of
bug that has bitten twice, and centralising it means the next `AUSPOL_LEVEL_*`
addition can't silently fail to reach four of five harnesses again.

### 1f. Arm fingerprint / `CAL_TAG` builder — 10-40 lines × 5, structurally identical, contents necessarily differ

`fed.R:308-365`, `nsw.R:173-220`, `sa.R:187-241`, `vic.R:148-200`, `wa.R:135-153`.
The `.arm_fingerprint` local (hashes every set `AUSPOL_*` env var) is byte-identical
across all five:

```r
.arm_fingerprint <- local({
  e <- Sys.getenv()
  e <- e[grepl("^AUSPOL_", names(e)) & nzchar(e)]
  e <- e[!names(e) %in% c("AUSPOL_OUT_SUFFIX")]
  if (!length(e)) "" else {
    s <- paste(sort(paste0(names(e), "=", e)), collapse = ";")
    sprintf("-a%s", substr(tolower(paste0(as.hexmode(
      sum(utils::head(utf8ToInt(s), 4000) * seq_along(utils::head(utf8ToInt(s), 4000)))
    ))), 1, 6))
  }
})
```

This 11-line piece (identical in all five) is worth extracting on its own:
`arm_fingerprint(exclude = "AUSPOL_OUT_SUFFIX")` in a new `scripts/harness_common.R`.
The `CAL_TAG <- paste0(...)` list that follows it is genuinely harness-specific
(each harness tags a different subset of switches relevant to what it sweeps) and
should **not** be forced into one function — that would just move the
harness-specific knowledge into an if/else ladder instead of removing it. Only the
fingerprint sub-piece is real duplication; the rest of CAL_TAG is legitimate
per-harness plumbing.

### 1g. Results/scoring block — ~15 lines × 4 (fed, sa, vic, wa), NSW structurally different but shares the tail

`fed.R:1403-1424`, `sa.R:667-681`, `vic.R:605-620`, `wa.R:325-341`: build `pa`
(actual-party probability per seat), `pr` (argmax prediction), merge into `res`,
compute the calibration-slope `glm(y ~ lo, family = binomial())` on the argmax
call, `cat()` a `BX2`/`BX3`-style accuracy/Brier/log/slope line. Byte-similar
across all four modulo the pair label and one extra `seat_sd` field WA prints:

```r
z <- data.frame(y = as.integer(res$pred == res$actual),
                lo = stats::qlogis(pmin(pmax(res$pred_p, eps), 1 - eps)))
sl <- if (length(unique(z$y)) > 1)
  stats::coef(stats::glm(y ~ lo, data = z, family = stats::binomial()))[["lo"]] else NA_real_
```

NSW (`nsw.R:605-630`) builds `res` upstream in a different shape (it merges
`missing_seats` handling in first, uses `res$p` rather than `res$prob`) and splits
the accuracy/Brier/log-score prints across three separate `cat()` calls (`BT4`,
`BT5`, `BT5`, `BT6`) instead of one `BX2` line — but ends with the **same**
`z`/`sl` calibration-slope computation, character-for-character.

**Proposal**: `score_seat_calls(pred_p, pred_party, actual_party, eps = 1e-6)`
returning `list(accuracy, brier, log_loss, calibration_slope)` in a new
`R/scorecard.R`-adjacent function (R/scorecard.R already exists at 228 lines for
the poll-side scorecard; a `seat_scorecard()` sibling is the natural home) or
`scripts/harness_common.R` if it's considered harness-only plumbing — it is used
only by backtest harnesses, never by `fit_seats_full.R` (which has no "truth" to
score against), so `scripts/harness_common.R` is the better home despite computing
a statistic, because nothing outside a backtest ever needs it.

### Not worth centralising: flow-matrix build calls

`build_flow_matrix(tx, min_n = 3L)` appears 5 times across the harnesses plus once
in `fit_seats_full.R` (`fed.R:451`, `nsw.R:272`, `sa.R:275`, `vic.R:224`,
`wa.R:230`, `fit_seats_full.R:252`). This is already a thin one-line call to a
well-factored R/ function — see §2 below for the finding that `min_n = 3L` is
passed explicitly and redundantly (it's already the default), which is worth fixing
as a search-and-delete, not worth building a wrapper for.

---

## 2. Within R/

### Overlapping functions in R/candidate_returns.R (477 lines) — three functions, ~20-24 lines of identical setup each

`candidate_returns()` (35-179), `leading_candidate_returns()` (205-254),
`personal_prior_vote()` (299-441) all open with the **same** load-corpus /
validate-columns / build-match-key block:

```r
C <- corpus
if (is.null(C)) {
  f <- file.path("output", "candidacies.csv")
  if (!file.exists(f)) stop("<fn>() needs output/candidacies.csv; run scripts/build_candidacies.R", call. = FALSE)
  C <- data.table::fread(f, showProgress = FALSE)
}
C <- data.table::as.data.table(C)
need <- c("election", "seat", "party" [, "pcv"])
miss <- setdiff(need, names(C))
if (length(miss)) stop("corpus lacks: ", paste(miss, collapse = ", "), call. = FALSE)

NOWT  <- C[C$election == election_to]
PREVT <- C[C$election == election_from]
if (!nrow(NOWT))  stop("no rows for election ", election_to, call. = FALSE)
if (!nrow(PREVT)) stop("no rows for election ", election_from, call. = FALSE)

kf <- function(d) {
  sur <- surname_of(...); giv <- given_of(...); match_key(sur, giv, "initial")
}
NOWT  <- data.table::copy(NOWT)[,  .k := kf(.SD), .SDcols = names(NOWT)]
PREVT <- data.table::copy(PREVT)[, .k := kf(.SD), .SDcols = names(PREVT)]
NOWT[,  .s := normalise_seat(seat)]
PREVT[, .s := normalise_seat(seat)]
```

That's ~20 lines × 3 ≈ 60 lines of exact duplication (candidate_returns.R:36-65,
206-235, 301-330). On top of it, the "keep both spellings of a renamed seat"
idiom appears a further three times, each ~6 lines:
`candidate_returns.R:104-109` (`prev_keys`), `247-249` (same, in
`leading_candidate_returns()`), and `379-383` (`personal_prior_vote()`'s `PTx`,
structurally the same rename-and-rbind but folded into the major-party exclusion
logic so slightly harder to lift verbatim).

**Proposal**: `load_candidacy_pair(election_from, election_to, corpus = NULL, need = c("election","seat","party"))`
returning `list(now = NOWT, prev = PREVT)` with `.k`/`.s` already attached, and
`renamed_seat_keys(prev_dt, key_col = ".k")` for the both-spellings idiom. This
would cut ~60-80 lines from the file without touching any of the three functions'
actual (and non-duplicated) matching logic.

### Dead code

- **`R/flow_matrix.R:122-123`** — `avail` is assigned (`avail <- d[, list(votes =
  sum(get("votes")), denom = sum(get("votes"))), by = c("from", "to")]`) and never
  read again in the file (confirmed: the only other two hits of `avail` in the file
  are inside comments at lines 112 and 153). CLAUDE.md already records this one as
  known dead; confirmed still present and still unread.
- **`R/seat_shrink.R:26-51`, `seat_shrink_vector()`** — exported, documented (a full
  roxygen block explaining the per-seat shrink mechanism it implements), but **has
  zero callers anywhere in R/, scripts/, or tests/** (verified by grepping all three
  trees for `seat_shrink_vector(` outside its own definition — nothing found; no
  `tests/testthat/test-*shrink*` file exists either). Given the most recent commit
  ("Shrink to 0.01, wire the model work into the published forecast, unblock
  per-seat shrink") and `published_flags.R`'s own comment — `AUSPOL_INSURGENCY_SHRINK
  = "0"  # per-seat shrink -- measured and refused 2026-09-06` — this function is the
  refused per-seat mechanism, built and left in the tree unwired and untested. It
  should either be deleted (the decision was "refused," per the flag's own comment)
  or, if it's being kept for a future re-attempt, given a test file and a one-line
  note in CONSTANTS.md saying it's intentionally unwired — right now nothing
  distinguishes it from an ordinary orphaned function.

### Exported functions with no caller

Checked all 95 `@export`-tagged functions in R/ (roxygen-adjacent `<- function`
extraction, cross-checked against `grep -rn "\bfn(" R/ scripts/ tests/` excluding
each function's own definition line). Only one true positive:
**`seat_shrink_vector`** (above). No other exported function in R/ is uncalled —
everything else has at least one caller in R/, scripts/, or tests/.

### Parameters always passed the same value

**`build_flow_matrix(transfers, min_n = 3L, ...)`** — the function's own default
(`R/flow_matrix.R:42`) is `min_n = 3L`. Every production call site passes
`min_n = 3L` explicitly and redundantly: `fed.R:451,552`, `nsw.R:272`, `sa.R:275`,
`vic.R:224,581`, `wa.R:230`, `fit_seats_full.R:252`, plus 7 more one-off scripts
(`audit_flow_accuracy.R`, `diagnose_flow_cells.R`, `fetch_transfers_nsw.R`,
`parse_transfers_fed.R`, `onp_tcp_vs_yougov.R`, `score_independent_emergence.R`,
`score_independent_two_mechanism.R`, `trace_ngadjuri_count.R`,
`score_independent_federal.R`, `trace_ngadjuri_count.R`) — 16 explicit
`min_n = 3L` call sites, none of which ever varies it. Only `tests/testthat/
test-flow-matrix.R` and two other test files vary `min_n` (1L/2L) to exercise the
threshold logic itself. This is pure noise: deleting `min_n = 3L` from all 16
production call sites changes nothing (the default already is 3L) and removes one
thing a reader has to notice is not actually being overridden anywhere.

---

## 3. Bloat

### Files over ~300 lines (R/)

| File | Lines | Comment lines | Code lines | Comment:code |
|---|---|---|---|---|
| `R/seat_sim.R` | 847 | 442 | 391 | 1.13 |
| `R/trend.R` | 553 | 268 | 251 | 1.07 |
| `R/projection.R` | 504 | 243 | 242 | 1.00 |
| `R/candidate_returns.R` | 477 | 265 | 198 | 1.34 |
| `R/fundamentals.R` | 339 | — | — | — |
| `scripts/fit_seats_full.R` | 989 | 503 | 458 | 1.10 |
| `scripts/backtest_candidate_fed.R` | 1450 | — | — | — |

All five carry the repo's documented long-explanatory-comment style near 1:1 with
code — this is intentional per CLAUDE.md ("this repo's style is long explanatory
comments — do not propose deleting history") and is **not** itself a finding.
`R/seat_sim.R` and `scripts/fit_seats_full.R` are large enough (847 / 989 lines)
that a future split by concern (e.g. `seat_sim.R`'s per-cell sd computation vs. the
Monte Carlo count loop; `fit_seats_full.R`'s data-load stage vs. its model-apply
stage vs. its write-and-check stage) would help navigation, but that's a structural
suggestion, not a duplication finding, and is not sized here.

### History told twice: code comment vs. docs/CONSTANTS.md or ARCHITECTURE.md

- **The "level_sd... 99%+ and LOST fall from 23 to 12... across 886 seat-elections"
  finding** is written out in full, nearly word-for-word, in **six** places: once in
  `docs/CONSTANTS.md:386` and once in each of the five harnesses' `.level_sd`
  comment blocks (`fed.R:70-74`, `nsw.R:33-37`, `sa.R:68-72`, `vic.R:24-28`,
  `wa.R:38-42`). This is the single most-repeated piece of narrative in the
  reviewed files. Since `docs/CONSTANTS.md` is the designated place for "every
  hard-coded number... with whether it can come from data" (per CLAUDE.md), the
  five harness copies could each shrink to a one-line pointer ("see
  docs/CONSTANTS.md's `level_sd` entry") without losing the history — CONSTANTS.md
  already carries the fuller, canonical version at line 386.
- **The Philip Donato / Orange (49.1% Shooter 2019 → 53.1% IND 2023) and Nick
  McBride / MacKillop (62.3% LNP → 14.8% IND) story** is told in full **three**
  times: `ARCHITECTURE.md:78-89`, and twice inside `R/candidate_returns.R` itself —
  once in `personal_prior_vote()`'s roxygen block (256-297) and again inline at the
  `MAJ` exclusion comment (337-348). The two in-file copies are the more
  actionable duplication (same file, ~80 lines apart) — the roxygen block already
  says everything the inline comment repeats; the inline comment could be cut to
  "see the MAJ exclusion rationale above" with no loss.

`scripts/published_flags.R` (63 lines) and `scripts/harness_defaults.R` (38 lines)
are worth calling out as a **positive** counter-example: they are exactly the kind
of single-source-of-truth extraction the rest of this review recommends elsewhere
(PUBLISHED_FLAGS lives in one file, applied by both `fit_seats_full.R` and the five
harnesses), added in the same 2026-09-06 session that fixed the SEAT_SD_MULT bug.
`R/harness_common.R`-style extractions proposed in §1 would follow the same shape.

---

## 4. Ranked shortlist of refactors (max 8)

For each: what, files, estimated lines removed, risk, and which of the three
CLAUDE.md-recorded cross-harness misses (i) SA missing `shrink` for four days
[2026-08-21], (ii) flow/IND/elasticity fixes landing in SA first and missing
Victoria/NSW [2026-08-25], (iii) `SEAT_SD_MULT` inert in four of five harnesses
behind `level_sd` [live until today, 2026-09-06] — it would have prevented.

1. **Centralise `level_sd` + `SEAT_SD_MULT` resolution** (§1e). Files: all five
   harnesses' header blocks (~100 lines each) → one function in `R/hyperpars.R` or
   `R/seat_shrink.R` (~25 lines) + 5 call sites (~10 lines each). **Est. lines
   removed: ~400.** Risk: **behaviour-changing if done carelessly** — this is the
   exact code that was silently broken until today, so the refactor must reproduce
   today's fixed logic exactly. Proof: run `backtest_candidate_wa.R` (smallest,
   fastest of the five) before and after with `AUSPOL_SEAT_SD_MULT=1.15
   AUSPOL_LEVEL_SD=1.10,8.67`, diff `output/backtest-wa*.csv` byte-for-byte. Would
   have prevented **miss (iii)** outright — a single function can't be "ported to
   four of five harnesses," it's either called or it isn't.

2. **Extract the MP-slope-tier reader** (§1a). Files: 5 harnesses (~95 lines) → one
   function (~20 lines) + 5 one-line call sites. **Est. lines removed: ~75.** Risk:
   low — the block is already byte-identical across harnesses, so extraction is
   mechanical. Proof: run `backtest_candidate_nsw.R` with `AUSPOL_MP_SLOPE=1` before
   and after, diff output. Would have prevented a **future instance of miss (ii)** —
   this exact "ported to some harnesses, not others" pattern is what MP_SLOPE
   narrowly avoided (it shipped to all five already) but the next slope-tier
   addition would not, absent a single function to add it to.

3. **Extract `.own_x` into `R/candidate_returns.R`** (§1b). Files: fed/nsw/sa/vic +
   fit_seats_full.R (~40 lines) → one exported function (~10 lines) + 5 one-line
   call sites. **Est. lines removed: ~30.** Risk: low — closure becomes an explicit
   argument, mechanical. Proof: same byte-diff method on `backtest_candidate_sa.R`
   with `AUSPOL_DEV_SLOPE_MODE=conditional`. Prevents a **future instance of miss
   (ii)**: WA's harness comment already documents *why* it has no `.own_x` call —
   if `.own_x` becomes a real R/ function, the next person adding personal-prior-vote
   support to WA has one obvious place to call, not five bespoke closures to copy
   from.

4. **Fix the `min_n = 3L` noise and the shared candidacy-loading setup in
   `R/candidate_returns.R`** (§2). Files: `R/candidate_returns.R` (~60-80 lines) +
   16 call sites across scripts/ (delete `min_n = 3L`, ~16 one-word edits). **Est.
   lines removed: ~70-90.** Risk: very low, pure deletion/factoring with no
   behaviour change (the setup block is copy-paste identical, the default value is
   unchanged). Proof: `devtools::test()` (the corpus-loading paths are covered by
   `tests/testthat/test-flow-matrix.R` and candidate-returns tests) plus one
   harness byte-diff. Doesn't map to a recorded miss directly, but removes ~140
   combined lines for near-zero risk — the highest lines-saved-per-risk-unit item
   on this list.

5. **Extract the results/scoring block** (§1g). Files: fed/sa/vic/wa (~60 lines) →
   one function (~15 lines) + 4 call sites, NSW left as-is or migrated separately
   since its structure differs more. **Est. lines removed: ~45.** Risk: low-medium
   — the four copies are functionally identical today, but scoring code is exactly
   where a silent one-harness fix (better eps handling, a Brier weighting change)
   would recreate **miss (i)/(ii)**'s pattern. Proof: byte-diff `output/backtest-fed*
   -totals.csv` before/after. Would prevent a **future instance of any of the three
   misses**, since scoring is the code most likely to be tweaked in exactly the
   piecemeal way that produced them.

6. **Extract `arm_fingerprint()`** (§1f). Files: 5 harnesses (~55 lines total) →
   one function in a new `scripts/harness_common.R` (~11 lines) + 5 one-line calls.
   **Est. lines removed: ~45.** Risk: none — byte-identical already, pure lift.
   Proof: CAL_TAG string equality before/after for one arm per harness. Doesn't map
   to a recorded miss (the fingerprint itself has never drifted) but is the
   lowest-risk item on the list and a natural first commit to establish
   `harness_common.R` before the riskier items (1, 5) build on it.

7. **Delete or wire up `seat_shrink_vector()`** (§2). Files: `R/seat_shrink.R`
   (51 lines) — either delete it (0 lines removed elsewhere, -51 net) or add a test
   file and a CONSTANTS.md note. **Est. lines removed: 51 (if deleted) / 0 (if
   kept+documented).** Risk: **zero either way** — nothing calls it, so deletion
   cannot change any behaviour; not deleting it costs nothing but continued
   confusion. Proof: `grep -rn "seat_shrink_vector" R/ scripts/ tests/` returns only
   its own definition, both before and after. Doesn't map to a recorded miss, but
   is exactly the kind of "looks like a finding, gets investigated" bait CLAUDE.md
   already warns about for stale data — an unwired, tested-nowhere function
   documented as if load-bearing is the code equivalent.

8. **Point the five `.level_sd` comment blocks at `docs/CONSTANTS.md` instead of
   restating it** (§3). Files: 5 harnesses' comment blocks (~5 lines saved × 5).
   **Est. lines removed: ~20** (comment-only, not counted against the code
   line-count reductions above). Risk: none — comment-only change. Proof: N/A
   (no executable change; verify by reading CONSTANTS.md:374-419 still contains the
   full explanation post-edit). Doesn't map to a recorded miss; included because
   it's the cheapest, safest item and directly answers the "same history told
   twice" instruction in the task.

**What refactor #1 must NOT do**: silently change which of `level_sd`/`seat_sd` is
in force for the *default* (unmultiplied) case — the byte-diff proof above only
covers the multiplier being non-1; a second byte-diff at `AUSPOL_SEAT_SD_MULT=1`
(the default, where the new function should be a no-op) is equally necessary and is
the more likely place for a refactor to introduce a regression, since that's the
path with the least visible symptom if broken (nothing prints, nothing errors, it
just silently stops matching the published behaviour — exactly today's original bug
shape, inverted).

---

## Scripts/ referenced nowhere (list only, per task scope — not judged)

Checked all 151 files in `scripts/*.R` for their own filename appearing anywhere
else in `scripts/`, `docs/`, `R/`, `tests/`, or any top-level `*.md` (excluding the
file's own header). 45 came back with zero references:

```
build_candidate_ids.R          decompose_ind_vote.R           refit_fed_swing_coef.R
build_emergence_test.R         diagnose_flow_cells.R          scope_census_feasibility.R
build_salience_corpus.R        diagnose_mackillop_renorm.R    scope_onp_concentration.R
build_scrutineer_page.R        diagnose_sa_four_seats.R       scope_swing_by_base.R
case_study_party_switchers.R   diagnose_third_place.R         score_emergence.R
compare_fed2025_biggest_misses.R diagnose_vic_attribution.R   score_sa2026.R
compare_firm_weights.R         estimate_candidate_variance.R  score_seat_swing_port_round2.R
compare_salience_anchors.R     estimate_dev_slopes.R          score_statewide_cov.R
decompose_fed_swing_gain.R     estimate_onp_concentration.R   size_salience_share_boost.R
fetch_salience.R               fetch_salience_v5.R            test_anchor_k.R
fetch_seat_salience_v3.R       fit_independent_federal.R      test_cross_party_swing.R
fit_independent_two_mechanism.R fit_salience_hazard_v4.R      test_elasticity_pooled.R
gate_trends_state_vs_national.R parse_transfers_fed.R         test_gap_decay.R
probe_window_chain.R                                          test_onp_ordering_sa.R
                                                                test_salience_new_candidates.R
                                                                test_stronghold_reversion.R
                                                                test_swing_shape.R
                                                                trace_ngadjuri_count.R
```

Method: `grep -rl "<filename>"` across the five trees, excluding a match inside the
file itself. This is a mention-search, not a call-graph — a script referenced only
by an informal name in prose (not its exact filename) would be missed by this
method and so undercounted here, not overcounted. Candidates for `docs/backlog` or
deletion, per the task's instruction to list only.
