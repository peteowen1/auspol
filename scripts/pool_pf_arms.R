# The 2x2: XGBoost PRIMARIES x XGBoost FLOWS, pooled over all 22 pairs.
#
# Answers the question Pete asked on 2026-09-11 -- "compare xgb primary table
# flows to xgb primary xgb flows" -- and its follow-on, whether the two
# challengers ADD, OVERLAP or INTERFERE.
#
#   p0f0  shipped primaries, table flows   (the published baseline)
#   p0f1  shipped primaries, xgb flows
#   p1f0  xgb primaries,     table flows
#   p1f1  xgb primaries,     xgb flows
#
# WHY THIS AND NOT pool_backtests.R. That script takes the NEWEST file per
# pair, which is exactly right for "what does the model score today" and
# exactly wrong here: four arms of the same pair exist at once and it would
# silently keep one. This one reads each arm's own harness logs, which name
# the file each run wrote (`BS5 wrote output/backtest-...csv`), so an arm is
# pooled from its OWN files by construction rather than by a glob that could
# match a neighbour's.
#
# Emits PF* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

EPS <- 1e-6                       # the harnesses' own floor; see pool_backtests.R
RUNDIR <- "output/_pfrun"
ARMS <- c("p0f0", "p0f1", "p1f0", "p1f1")
ARM_LABEL <- c(p0f0 = "shipped primaries + table flows",
               p0f1 = "shipped primaries + xgb flows",
               p1f0 = "xgb primaries + table flows",
               p1f1 = "xgb primaries + xgb flows")

# ---- 1. which files belong to which (arm, seed), from the logs themselves ---
read_arm_seed <- function(arm, seed) {
  d <- file.path(RUNDIR, sprintf("%s_s%d", arm, seed))
  if (!dir.exists(d)) return(NULL)
  logs <- list.files(d, pattern = "[.]log$", full.names = TRUE)
  if (!length(logs)) return(NULL)

  # DID THE ARM ACTUALLY APPLY? Found by the review gate, 2026-09-11, and it is
  # this repo's own named hazard reproduced in the script built to prevent it:
  # "an experiment that never ran looks exactly like an experiment with no
  # effect."
  #
  # xgb_primary_override() and xgb_flow_conditional_override_for() FAIL OPEN --
  # a missing model or oof file prints `XG1!`/`XF9!` and returns the input
  # unchanged, and the harness then runs to completion and writes an output
  # file identical in shape to a real one. These logs are already being read to
  # find that filename; nothing was reading them for the marker. A p1f0 arm
  # whose oof file went missing would have pooled as "the xgb primary is worth
  # nothing", which is a conclusion about a file, not a model.
  ignored <- unlist(lapply(logs, function(lg) {
    ln <- readLines(lg, warn = FALSE)
    grep("^(XG1!|XF9!|XS9!).*(ignored|unchanged|FAILED|missing)", ln, value = TRUE)
  }))
  if (length(ignored)) {
    cat(sprintf("PF0!! %s: %d override(s) DID NOT APPLY -- this arm is not what its name says:\n",
                basename(d), length(ignored)))
    for (m in unique(ignored)) cat(sprintf("PF0!!   %s\n", substr(m, 1, 150)))
    if (!identical(Sys.getenv("AUSPOL_ALLOW_INERT_ARM", "0"), "1"))
      stop("refusing to pool ", basename(d), ": an override this arm is named for did not run. ",
           "Fix the missing input, or set AUSPOL_ALLOW_INERT_ARM=1 if you know why it is inert.")
  }
  fs <- unlist(lapply(logs, function(lg) {
    ln <- readLines(lg, warn = FALSE)
    m <- regmatches(ln, regexpr("output/backtest-[^ ]+[.]csv", ln))
    unique(m)
  }))
  fs <- unique(grep("-totals|allprobs|-seatsd|-diag|-sharedetail", fs, value = TRUE, invert = TRUE))

  # FALLBACK FOR A HARNESS THAT DOES NOT LOG WHAT IT WROTE. Every harness
  # prints "wrote output/backtest-...csv" except backtest_candidate_vic.R,
  # which just fwrite()s and says nothing -- so Victoria, the LIVE TARGET,
  # silently dropped out of this comparison entirely and the pooled number
  # read as 19 pairs instead of 22 with no complaint.
  #
  # The vic harness's output file and its log finish in the same second, so
  # matching on mtime is exact here rather than approximate. It is still a
  # heuristic, so it NAMES the file it attributed instead of doing it quietly,
  # and refuses rather than guesses when the match is not unique.
  for (lg in logs) {
    reg <- sub("[0-9]*[.]log$", "", basename(lg))
    # Single-pair harnesses embed the year (backtest-nsw2023-...), multi-pair
    # ones do not (backtest-vic-...), so match the bare region prefix -- an
    # anchored "region then punctuation" pattern misses the former and raises a
    # false "dropped" alarm on a file that is already in hand.
    if (any(grepl(sprintf("^backtest-%s", reg), basename(fs)))) next
    cand <- list.files("output", pattern = sprintf("^backtest-%s.*[.]csv$", reg), full.names = TRUE)
    cand <- grep("-totals|allprobs|-seatsd|-diag|-sharedetail", cand, value = TRUE, invert = TRUE)
    if (!length(cand)) next
    hit <- cand[abs(as.numeric(difftime(file.mtime(cand), file.mtime(lg), units = "secs"))) <= 2]
    if (length(hit) == 1L) {
      cat(sprintf("PF0m %s/%s: log names no output file; matched %s by mtime (%s)\n",
                  basename(d), basename(lg), basename(hit), format(file.mtime(hit), "%H:%M:%S")))
      fs <- c(fs, hit)
    } else if (length(hit) > 1L) {
      cat(sprintf("PF0! %s/%s: log names no output file and %d files share its mtime -- NOT guessing; %s is dropped\n",
                  basename(d), basename(lg), length(hit), reg))
    } else {
      cat(sprintf("PF0! %s/%s: log names no output file and none matches its mtime -- %s is dropped\n",
                  basename(d), basename(lg), reg))
    }
  }
  if (!length(fs)) return(NULL)
  rbindlist(lapply(fs, function(f) {
    if (!file.exists(f)) { cat(sprintf("PF0! %s/%s: named in a log but not on disk -- dropped\n", arm, basename(f))); return(NULL) }
    x <- tryCatch(fread(f, showProgress = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x)) { cat(sprintf("PF0! %s/%s: unreadable or empty -- dropped\n", arm, basename(f))); return(NULL) }
    pcol <- if ("prob" %in% names(x)) "prob" else if ("p" %in% names(x)) "p" else NA_character_
    if (is.na(pcol) || !all(c("pred","actual") %in% names(x))) {
      cat(sprintf("PF0! %s/%s: missing prob/p/pred/actual -- dropped\n", arm, basename(f))); return(NULL)
    }
    if (!"pair" %in% names(x)) {
      mm <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
      if (!length(mm)) { cat(sprintf("PF0! %s/%s: no pair column and none in the name -- dropped\n", arm, basename(f))); return(NULL) }
      x[, pair := mm]
    }
    x[, .(arm = arm, seed = seed, pair = as.character(pair),
          p = pmin(pmax(get(pcol), EPS), 1), hit = as.integer(pred == actual))]
  }))
}

SEEDS <- 1:3
ALL <- rbindlist(lapply(ARMS, function(a) rbindlist(lapply(SEEDS, function(s) read_arm_seed(a, s)))))
if (!nrow(ALL)) stop("no arm output found under ", RUNDIR)

# ---- 2. COVERAGE, asserted, not assumed ------------------------------------
# A missing pair does not error -- it shrinks n and quietly changes the pooled
# number, which is the whole failure mode this repo keeps hitting. So print the
# grid and refuse to draw a comparison across arms that saw different pairs.
known <- vapply(all_election_pairs(), `[[`, character(1), "election")
cov <- ALL[, .(pairs = uniqueN(pair), seats = .N), by = .(arm, seed)]
setorder(cov, arm, seed)
cat("\nPF1  coverage -- pairs and seat-elections per (arm, seed); every cell should read the same\n")
print(cov)
for (a in unique(ALL$arm)) for (s in unique(ALL[arm == a]$seed)) {
  miss <- setdiff(known, unique(ALL[arm == a & seed == s]$pair))
  if (length(miss)) cat(sprintf("PF1! %s seed %d is MISSING %d pair(s): %s\n", a, s, length(miss), paste(miss, collapse = ", ")))
}
# DROP INCOMPLETE (arm, seed) CELLS BEFORE AVERAGING. A seed still running has
# a subset of pairs, and averaging it with a finished seed produces a number
# that is neither -- weighted toward whichever pairs happened to finish first,
# and moving every time you re-run the pooler. Averaging a partial seed is how
# a "result" changes under you without the model changing at all.
full_n <- max(cov$pairs)
part <- cov[pairs < full_n]
if (nrow(part)) {
  cat(sprintf("PF1i %d (arm, seed) cell(s) are INCOMPLETE and excluded from the averages: %s\n",
              nrow(part), paste(sprintf("%s s%d (%d/%d pairs)", part$arm, part$seed, part$pairs, full_n), collapse = ", ")))
  ALL <- ALL[!paste(arm, seed) %in% paste(part$arm, part$seed)]
}
common <- Reduce(intersect, lapply(split(ALL, ALL$arm), function(d) unique(d$pair)))
if (length(common) < uniqueN(ALL$pair)) {
  cat(sprintf("PF1! arms do not share all pairs; comparing on the %d pair(s) common to all: dropped %s\n",
              length(common), paste(setdiff(unique(ALL$pair), common), collapse = ", ")))
  ALL <- ALL[pair %in% common]
}

# ---- 3. pooled seat log loss, per seed then averaged ------------------------
# Seeds are simulation noise, not independent observations -- average over
# them. PAIRS are the clustering unit for any standard error.
per_seed <- ALL[, .(n = .N, accuracy = mean(hit), brier = mean((1 - p)^2),
                    logloss = -mean(log(p))), by = .(arm, seed)]
setorder(per_seed, arm, seed)
cat("\nPF2  per seed -- pooled seat log loss, LOWER IS BETTER (accuracy: higher is better)\n")
print(per_seed[, .(arm, seed, n, accuracy = round(accuracy, 4),
                   brier = round(brier, 4), logloss = round(logloss, 4))])

arm_tbl <- per_seed[, .(seeds = .N, n = mean(n),
                        accuracy = mean(accuracy), brier = mean(brier),
                        logloss = mean(logloss), logloss_sd = stats::sd(logloss)), by = arm]
arm_tbl[, label := ARM_LABEL[arm]]
setorder(arm_tbl, arm)
base_ll <- arm_tbl[arm == "p0f0"]$logloss
arm_tbl[, delta := logloss - base_ll]
cat("\nPF3  THE 2x2 -- pooled seat log loss averaged over seeds. LOWER IS BETTER.\n")
cat("     delta is versus p0f0, the published baseline; negative = better than what ships.\n")
print(arm_tbl[, .(arm, label, n = round(n), accuracy = round(accuracy, 4),
                  brier = round(brier, 4), logloss = round(logloss, 4),
                  sd_over_seeds = round(logloss_sd, 4), delta = round(delta, 4))])

# ---- 4. do they add, overlap, or interfere? --------------------------------
g <- stats::setNames(arm_tbl$logloss, arm_tbl$arm)
if (all(ARMS %in% names(g))) {
  d_prim <- g[["p1f0"]] - g[["p0f0"]]
  d_flow <- g[["p0f1"]] - g[["p0f0"]]
  d_both <- g[["p1f1"]] - g[["p0f0"]]
  cat(sprintf("\nPF4  primary alone %+.4f | flows alone %+.4f | sum if independent %+.4f | both together %+.4f\n",
              d_prim, d_flow, d_prim + d_flow, d_both))
  inter <- d_both - (d_prim + d_flow)
  cat(sprintf("PF4  interaction %+.4f -- negative means the two help each other, positive means they overlap or interfere\n", inter))
}

# ---- 5. the contrast Pete named, paired on pairs ---------------------------
# xgb primary + table flows  vs  xgb primary + xgb flows. Paired by PAIR,
# because pairs are the independent unit; seeds are averaged inside each cell
# first so simulation noise does not inflate the n.
pp <- ALL[, .(logloss = -mean(log(p)), n = .N), by = .(arm, seed, pair)]
pp <- pp[, .(logloss = mean(logloss), n = mean(n)), by = .(arm, pair)]
W <- dcast(pp, pair + n ~ arm, value.var = "logloss")
if (all(c("p1f0","p1f1") %in% names(W))) {
  W[, diff := p1f1 - p1f0]
  setorder(W, diff)
  cat("\nPF5  per pair: xgb primary + xgb flows MINUS xgb primary + table flows. Negative = xgb flows win.\n")
  print(W[, .(pair, n = round(n), p1f0 = round(p1f0, 4), p1f1 = round(p1f1, 4), diff = round(diff, 4))])
  tt <- stats::t.test(W$p1f1, W$p1f0, paired = TRUE)
  cat(sprintf("\nPF6  mean per-pair difference %+.4f over %d pairs, t = %.2f, p = %.3f (paired, clustered on pairs)\n",
              mean(W$diff), nrow(W), unname(tt$statistic), tt$p.value))
  cat(sprintf("PF6  xgb flows better in %d of %d pairs, worse in %d\n",
              sum(W$diff < 0), nrow(W), sum(W$diff > 0)))
}
if (all(c("p0f0","p1f1") %in% names(W))) {
  W[, diff_best := p1f1 - p0f0]
  tt2 <- stats::t.test(W$p1f1, W$p0f0, paired = TRUE)
  cat(sprintf("PF7  both challengers vs the published baseline: mean %+.4f, t = %.2f, p = %.3f; better in %d of %d pairs\n",
              mean(W$diff_best), unname(tt2$statistic), tt2$p.value, sum(W$diff_best < 0), nrow(W)))
}

fwrite(W, "output/pf-arms-by-pair.csv")
fwrite(arm_tbl, "output/pf-arms-pooled.csv")
cat("\nPF8  wrote output/pf-arms-pooled.csv and output/pf-arms-by-pair.csv\n")
