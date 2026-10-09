# The biggest misses of the PUBLISHED path, by metric, from the newest scored run.
#
#   Rscript scripts/biggest_misses.R                      # primary, tcp, logloss; top 15 each
#   Rscript scripts/biggest_misses.R --metric=primary --n=30
#   Rscript scripts/biggest_misses.R --metric=logloss --pairs=vic2022,fed2022
#   Rscript scripts/biggest_misses.R --aef7               # the seven AE Forecasts pairs only
#
# WHY THIS EXISTS (2026-10-09). Asked for the biggest primary misses, I ranked
# them from output/forecasts.csv. That file is the xgb layer's share BEFORE
# the seat-poll blend, the surge and the simulation, so Goldstein 2022 read
# 4.4 (gap +30) when the published path said 27.1 (gap +7.4, and a 0.52
# favourite who won). Every number here comes from the harness run
# pool_backtests.R scored for each pair, through scripts/ledger_inputs.R: the
# same one-run-per-pair rule the AEF-7 ledger uses.
#
# Metrics, all on the final published-path output:
#   primary  sharedetail pred_share vs actual_share, per candidate class,
#            percentage points; gap = actual - ours (positive = we under-called)
#   tcp      our two-candidate-preferred % for the final two that ACTUALLY
#            happened (ourtcp scenarios) vs the official figure; AEF-7 pairs
#            only, because output/aef7-tcp-actual.csv is the only resolved
#            official final-two table. A seat whose real final two never
#            appeared in our scenarios is listed separately, not scored.
#   logloss  -log(our probability of the actual winner), floored at 1e-6 like
#            every log loss in this repo; lower is better
#
# Every run prints, before any table: the run file per pair, its git hash and
# age, whether model code changed since that hash, and whether any backtest
# file is newer than the pool (meaning pool_backtests.R needs rerunning).
# Each top seat is joined to its docs/SEAT-REGISTRY.md verdict, and seats
# missing from the registry are named so they can be added.
#
# Writes output/biggest-misses.csv (every scored row, all metrics). Emits MX* codes.

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
OUT <- "output"
EPS <- 1e-6

a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) {
  hit <- grep(paste0("^--", name, "="), a, value = TRUE)
  if (length(hit)) sub("^[^=]*=", "", hit[1]) else default
}
metric_arg <- flag("metric", "all")
top_n <- as.integer(flag("n", "15"))
pairs_arg <- flag("pairs", "")
aef7_only <- "--aef7" %in% a
metrics <- if (metric_arg == "all") c("primary", "tcp", "logloss") else strsplit(metric_arg, ",")[[1]]
bad <- setdiff(metrics, c("primary", "tcp", "logloss"))
if (length(bad)) stop("--metric must be primary, tcp, logloss or all, not: ", paste(bad, collapse = ", "))
AEF7 <- c("fed2022", "fed2025", "nsw2023", "qld2024", "sa2026", "vic2022", "wa2025")

# ---- freshness, before anything is read -------------------------------------
pb_f <- file.path(OUT, "pooled-backtest.csv")
if (!file.exists(pb_f)) stop("no output/pooled-backtest.csv -- run scripts/pool_backtests.R first")
pb_mtime <- file.mtime(pb_f)
# A scored-shape backtest file newer than the pool means the pool has not seen
# the latest run. Stage-1 (-n2000-) and hand-rerun (-p2022-) files are named
# separately so they are visible, not silently counted as fresh results.
bt <- list.files(OUT, pattern = "^backtest-.*[.]csv$", full.names = TRUE)
newer <- bt[file.mtime(bt) > pb_mtime]
if (length(newer)) {
  cat(sprintf("MX0! %d backtest file(s) are NEWER than pooled-backtest.csv (%s). Rerun scripts/pool_backtests.R before trusting this ranking:\n     %s\n",
              length(newer), format(pb_mtime, "%Y-%m-%d %H:%M"), paste(head(basename(newer), 8), collapse = "\n     ")))
} else {
  cat(sprintf("MX0  pooled-backtest.csv (%s) is newer than every backtest file in output/.\n", format(pb_mtime, "%Y-%m-%d %H:%M")))
}

source("scripts/ledger_inputs.R")   # .PB, run_table(): one harness run per pair
PB <- copy(.PB)
want_pairs <- PB$pair
if (nzchar(pairs_arg)) want_pairs <- intersect(want_pairs, strsplit(pairs_arg, ",")[[1]])
if (aef7_only) want_pairs <- intersect(want_pairs, AEF7)
if (!length(want_pairs)) stop("no pairs left after --pairs/--aef7")

# Which code produced these numbers, and has the model moved since?
PB[, git := sub("^.*-g([0-9a-f]+)[x?]?[.]csv$", "\\1", file)]
# A harness tags its files -g<sha>x when R/ or scripts/ were dirty at run time
# ("?" when git status failed): those runs include edits no commit holds, so a
# clean commit count since <sha> proves nothing about them.
PB[, dirty_run := grepl("-g[0-9a-f]+[x?][.]csv$", file)]
PB[, hand_rerun := grepl("-p[0-9]{4}-", file)]
cat(sprintf("MX1  %d pair(s) from %d run(s); run git hash(es): %s\n", length(want_pairs),
            uniqueN(PB[pair %in% want_pairs]$file), paste(unique(PB[pair %in% want_pairs]$git), collapse = ", ")))
if (any(PB[pair %in% want_pairs]$hand_rerun))
  cat(sprintf("MX1! hand-rerun file(s) were scored for: %s -- check they describe the shipped model\n",
              paste(PB[pair %in% want_pairs & hand_rerun == TRUE]$pair, collapse = ", ")))
model_paths <- c("R", "src", "scripts/published_flags.R", "scripts/harness_defaults.R",
                 "scripts/fit_seats_full.R", Sys.glob("scripts/backtest_candidate_*.R"))
if (any(PB[pair %in% want_pairs]$dirty_run))
  cat(sprintf("MX2! run(s) made from uncommitted code (file tag x or ?): %s -- the commit count below cannot vouch for them\n",
              paste(PB[pair %in% want_pairs & dirty_run == TRUE]$pair, collapse = ", ")))
wt_dirty <- suppressWarnings(system2("git", c("status", "--porcelain", "--", model_paths), stdout = TRUE, stderr = FALSE))
if (length(wt_dirty))
  cat(sprintf("MX2! %d uncommitted model-code change(s) in this checkout; the numbers below predate them:\n%s\n",
              length(wt_dirty), paste0("     ", head(wt_dirty, 10), collapse = "\n")))
for (g in unique(PB[pair %in% want_pairs]$git)) {
  n_since <- suppressWarnings(system2("git", c("rev-list", "--count", paste0(g, "..HEAD"), "--", model_paths),
                                      stdout = TRUE, stderr = FALSE))
  if (!length(n_since) || !nzchar(n_since[1])) {
    cat(sprintf("MX2! run hash %s is not in this checkout's history -- cannot tell whether model code changed since\n", g))
  } else if (as.integer(n_since[1]) > 0) {
    cat(sprintf("MX2! %s commit(s) touched model code (R/, src/, harnesses, published flags) since run %s; numbers may not describe HEAD. Judge from the subjects whether any moves a backtest number:\n", n_since[1], g))
    subj <- suppressWarnings(system2("git", c("log", "--format=     %h %s", paste0(g, "..HEAD"), "--", model_paths),
                                     stdout = TRUE, stderr = FALSE))
    cat(paste(head(subj, 10), collapse = "\n"), if (length(subj) > 10) sprintf("\n     ... and %d more", length(subj) - 10), "\n", sep = "")
  } else {
    cat(sprintf("MX2  no model-code commit since run %s.\n", g))
  }
}

# ---- candidate names: leading candidate of each class ------------------------
cands <- fread(file.path(OUT, "candidacies.csv"), select = c("election", "seat", "name", "party", "pcv"),
               showProgress = FALSE, encoding = "UTF-8")
cands <- cands[order(-pcv)][, .SD[1L], by = .(election, seat, party)][, .(pair = election, seat, party, candidate = name)]

# ---- seat registry verdicts --------------------------------------------------
# One verdict per (section pair, seat) from docs/SEAT-REGISTRY.md: the first of
# NOTHING TO FIX / OPEN / PARKED / DATA in the bullet that names the seat.
reg_lines <- readLines("docs/SEAT-REGISTRY.md", encoding = "UTF-8", warn = FALSE)
reg <- list(); cur <- NA_character_; buf <- NULL
flush_buf <- function() {
  if (is.null(buf) || is.na(cur)) return(invisible())
  txt <- paste(buf, collapse = " ")
  names_part <- regmatches(txt, regexpr("^- \\*\\*[^*]+\\*\\*", txt))
  if (!length(names_part)) return(invisible())
  nm <- gsub("^- \\*\\*|\\*\\*$", "", names_part)
  nm <- gsub("\\([^)]*\\)", "", nm)
  seats_here <- trimws(unlist(strsplit(nm, ",| and ")))
  seats_here <- seats_here[nzchar(seats_here)]
  v <- regmatches(txt, regexpr("NOTHING TO FIX|OPEN|PARKED|DATA", txt))
  reg[[length(reg) + 1L]] <<- data.table(pair = cur, seat = seats_here, registry = if (length(v)) v else "noted")
}
for (ln in reg_lines) {
  if (grepl("^## ", ln)) {
    flush_buf(); buf <- NULL
    m <- regmatches(ln, regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", ln))
    cur <- if (length(m)) m else NA_character_
  } else if (grepl("^- ", ln)) {
    flush_buf(); buf <- ln
  } else if (!is.null(buf)) {
    buf <- c(buf, trimws(ln))
  }
}
flush_buf()
REG <- unique(rbindlist(reg), by = c("pair", "seat"))

# ---- read each pair's run once ----------------------------------------------
sd_all <- rbindlist(lapply(want_pairs, function(pr) {
  x <- run_table(pr, "sharedetail")
  if (is.null(x)) return(NULL)
  if ("xgb_primary_on" %in% names(x) && any(x$xgb_primary_on != 1))
    stop(pr, ": sharedetail has xgb_primary_on != 1 -- a base_pred-only stage-1 run, not the published model")
  x[, .(pair = pr, seat, party, ours = pred_share, actual = actual_share)]
}), fill = TRUE)
ap_all <- rbindlist(lapply(want_pairs, function(pr) {
  x <- run_table(pr, "allprobs")
  if (is.null(x)) return(NULL)
  x[, .(pair = pr, seat, party, prob, actual_winner = actual, is_actual)]
}), fill = TRUE)

lab <- function(d) {
  d <- merge(d, REG, by = c("pair", "seat"), all.x = TRUE)
  d[is.na(registry), registry := "-"]
  d
}
show <- function(d, cols, title, note) {
  cat(sprintf("\n%s\n%s\n", title, note))
  print(d[, ..cols], row.names = FALSE)
  miss <- d[registry == "-", unique(paste(pair, seat))]
  if (length(miss)) cat(sprintf("MX9  not in docs/SEAT-REGISTRY.md (add an entry once a seat is dug into): %s\n",
                                paste(miss, collapse = ", ")))
}
long <- list()

# ---- primary ----------------------------------------------------------------
if ("primary" %in% metrics && nrow(sd_all)) {
  P <- sd_all[is.finite(ours) & is.finite(actual)]
  P[, gap := actual - ours]
  P <- merge(P, cands, by = c("pair", "seat", "party"), all.x = TRUE)
  cat(sprintf("\nBMP  primary: %d candidate-class rows, %d seats, %d pairs; RMSE %.3f points\n",
              nrow(P), uniqueN(P[, .(pair, seat)]), uniqueN(P$pair), sqrt(mean(P$gap^2))))
  top <- lab(P[order(-abs(gap))][seq_len(min(top_n, .N))])[order(-abs(gap))]
  top[, `:=`(ours = round(ours, 1), actual = round(actual, 1), gap = round(gap, 1))]
  show(top, c("pair", "seat", "party", "candidate", "ours", "actual", "gap", "registry"),
       sprintf("Biggest PRIMARY misses (top %d)", nrow(top)),
       "Primary vote share, percentage points, final published path. gap = actual - ours: positive = we under-called. Closer to 0 is better.")
  long$primary <- P[, .(metric = "primary", pair, seat, party, candidate, ours, actual, err = gap)]
}

# ---- log loss ---------------------------------------------------------------
if ("logloss" %in% metrics && nrow(ap_all)) {
  W <- ap_all[, .(actual_winner = actual_winner[1L],
                  p_actual = if (any(is_actual %in% TRUE)) sum(prob[is_actual %in% TRUE]) else 0,
                  fav = party[which.max(prob)], p_fav = max(prob)), by = .(pair, seat)]
  W[, ll := -log(pmax(p_actual, EPS))]
  cat(sprintf("\nBML  log loss: %d seats, %d pairs; mean %.4f (lower is better); %d seat(s) gave the winner probability 0 (scored at the 1e-6 floor)\n",
              nrow(W), uniqueN(W$pair), mean(W$ll), sum(W$p_actual <= 0)))
  top <- lab(W[order(-ll)][seq_len(min(top_n, .N))])[order(-ll)]
  top[, `:=`(p_actual = round(p_actual, 3), p_fav = round(p_fav, 3), ll = round(ll, 2))]
  show(top, c("pair", "seat", "actual_winner", "p_actual", "fav", "p_fav", "ll", "registry"),
       sprintf("Biggest LOG-LOSS misses (top %d)", nrow(top)),
       "ll = -log(our probability of the actual winner), floored at 1e-6; lower is better. p_actual = what we gave the winner; fav/p_fav = our favourite.")
  long$logloss <- W[, .(metric = "logloss", pair, seat, party = actual_winner, candidate = NA_character_,
                       ours = p_actual, actual = 1, err = ll)]
}

# ---- two-candidate preferred ------------------------------------------------
if ("tcp" %in% metrics) {
  tp <- intersect(want_pairs, AEF7)
  ta_f <- file.path(OUT, "aef7-tcp-actual.csv")
  if (!length(tp)) {
    cat("\nBMT  tcp: none of the selected pairs has a resolved official final two (AEF-7 only); skipped\n")
  } else if (!file.exists(ta_f)) {
    cat("\nBMT! tcp: output/aef7-tcp-actual.csv missing -- run scripts/build_aef7_tcp_actual.R\n")
  } else {
    act <- fread(ta_f, select = c("pair", "seat", "f1", "f2", "f2cp"), showProgress = FALSE)[pair %in% tp & is.finite(f2cp)]
    sc <- rbindlist(lapply(tp, function(pr) {
      x <- run_table(pr, "ourtcp"); if (is.null(x)) return(NULL)
      x[, pair := pr][]
    }), fill = TRUE)
    # our scenario for the ACTUAL final two, in either order; f1_tcp_pct is f1's share
    m1 <- merge(act, sc[, .(pair, seat, f1, f2, freq, pct = f1_tcp_pct)], by = c("pair", "seat", "f1", "f2"))
    m2 <- merge(act, sc[, .(pair, seat, f1 = f2, f2 = f1, freq, pct = 100 - f1_tcp_pct)], by = c("pair", "seat", "f1", "f2"))
    TC <- rbind(m1, m2)[, .SD[which.max(freq)], by = .(pair, seat)]
    TC[, gap := f2cp - pct]
    unpaired <- act[!TC, on = .(pair, seat)]
    cat(sprintf("\nBMT  tcp: %d of %d seats with an official final two scored (%d pairs); MAE %.2f points; %d seat(s) whose real final two never appeared in our scenarios: %s\n",
                nrow(TC), nrow(act), uniqueN(TC$pair), mean(abs(TC$gap)), nrow(unpaired),
                if (nrow(unpaired)) paste(head(paste(unpaired$pair, unpaired$seat), 12), collapse = ", ") else "none"))
    top <- lab(TC[order(-abs(gap))][seq_len(min(top_n, .N))])[order(-abs(gap))]
    top[, `:=`(ours = round(pct, 1), actual = round(f2cp, 1), gap = round(gap, 1), scen_freq = round(freq, 3))]
    show(top, c("pair", "seat", "f1", "f2", "ours", "actual", "gap", "scen_freq", "registry"),
         sprintf("Biggest TCP misses (top %d, AEF-7 pairs)", nrow(top)),
         "f1's two-candidate-preferred %, real final two only. gap = actual - ours: positive = we under-called f1. scen_freq = how often our sims produced that final two (0-1).")
    long$tcp <- TC[, .(metric = "tcp", pair, seat, party = paste(f1, f2, sep = "v"), candidate = NA_character_,
                     ours = pct, actual = f2cp, err = gap)]
  }
}

if (length(long)) {
  L <- rbindlist(long, fill = TRUE)
  fwrite(L, file.path(OUT, "biggest-misses.csv"))
  cat(sprintf("\nBMW  wrote output/biggest-misses.csv (%d rows: %s)\n", nrow(L),
              paste(sprintf("%s %d", names(long), vapply(long, nrow, 1L)), collapse = ", ")))
}
