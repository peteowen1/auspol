# WHERE does the xgb flow override help, and where does it hurt?
#
# The 2x2 (docs/reviews/xgb-primary-x-flows-2x2-2026-09-11.md) left the flow
# arm at p = 0.111, and two pairs carry most of that: wa2001 (+0.048) and
# fed2016 (+0.035) against a -0.0096 mean. A pooled number cannot say whether
# that is a broad drift or three seats crossing the log-loss floor, and those
# two call for opposite responses -- so this goes to the seat.
#
# Compares p1f0 (xgb primaries + table flows) against p1f1 (xgb primaries + xgb
# flows), seat by seat, averaged over the 3 seeds. Reads each arm's own files
# through the same log-derived discovery scripts/pool_pf_arms.R uses, so the
# two scripts cannot disagree about which file belongs to which arm.
#
# Emits DG* codes.
options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))
suppressMessages(devtools::load_all(quiet = TRUE))

EPS <- 1e-6
RUNDIR <- "output/_pfrun"
SEEDS <- 1:3
FOCUS <- c("wa2001", "fed2016")

# Same file discovery as pool_pf_arms.R, kept deliberately identical.
read_arm_seed <- function(arm, seed) {
  d <- file.path(RUNDIR, sprintf("%s_s%d", arm, seed))
  if (!dir.exists(d)) return(NULL)
  logs <- list.files(d, pattern = "[.]log$", full.names = TRUE)
  fs <- unlist(lapply(logs, function(lg) {
    ln <- readLines(lg, warn = FALSE)
    unique(regmatches(ln, regexpr("output/backtest-[^ ]+[.]csv", ln)))
  }))
  fs <- unique(grep("-totals|allprobs|-seatsd|-diag|-sharedetail", fs, value = TRUE, invert = TRUE))
  for (lg in logs) {
    reg <- sub("[0-9]*[.]log$", "", basename(lg))
    if (any(grepl(sprintf("^backtest-%s", reg), basename(fs)))) next
    cand <- list.files("output", pattern = sprintf("^backtest-%s.*[.]csv$", reg), full.names = TRUE)
    cand <- grep("-totals|allprobs|-seatsd|-diag|-sharedetail", cand, value = TRUE, invert = TRUE)
    hit <- cand[abs(as.numeric(difftime(file.mtime(cand), file.mtime(lg), units = "secs"))) <= 2]
    if (length(hit) == 1L) fs <- c(fs, hit)
  }
  rbindlist(lapply(fs, function(f) {
    if (!file.exists(f)) return(NULL)
    x <- tryCatch(fread(f, showProgress = FALSE), error = function(e) NULL)
    if (is.null(x) || !nrow(x)) return(NULL)
    pcol <- if ("prob" %in% names(x)) "prob" else if ("p" %in% names(x)) "p" else NA_character_
    if (is.na(pcol) || !all(c("pred", "actual", "seat") %in% names(x))) return(NULL)
    if (!"pair" %in% names(x)) {
      mm <- regmatches(basename(f), regexpr("(fed|vic|nsw|sa|qld|wa)[0-9]{4}", basename(f)))
      if (!length(mm)) return(NULL)
      x[, pair := mm]
    }
    x[, .(arm = arm, seed = seed, pair = as.character(pair), seat = as.character(seat),
          p = pmin(pmax(get(pcol), EPS), 1), pred = as.character(pred),
          actual = as.character(actual))]
  }), fill = TRUE)
}

ALL <- rbindlist(lapply(c("p1f0", "p1f1"), function(a)
  rbindlist(lapply(SEEDS, function(s) read_arm_seed(a, s)))), fill = TRUE)
ALL <- ALL[pair %in% FOCUS]
stopifnot(nrow(ALL) > 0)

# Average the seed noise out per (arm, pair, seat) BEFORE differencing, so a
# seat is not credited with a swing that is one seed's RNG.
S <- ALL[, .(ll = mean(-log(p)), p = mean(p), seeds = .N,
             actual = actual[1], pred = paste(unique(pred), collapse = "/")),
         by = .(arm, pair, seat)]
W <- dcast(S, pair + seat + actual ~ arm, value.var = c("ll", "p", "pred"))
W[, d_ll := ll_p1f1 - ll_p1f0]
setorder(W, pair, -d_ll)

for (pr in FOCUS) {
  P <- W[pair == pr]
  tot <- sum(P$d_ll) / nrow(P)
  cat(sprintf("\nDG1  %s: %d seats, mean per-seat log-loss change %+.4f (positive = xgb flows WORSE)\n",
              pr, nrow(P), tot))
  # HOW CONCENTRATED IS IT? A handful of seats crossing the floor and a broad
  # drift are different bugs with opposite fixes, and the pooled number cannot
  # tell them apart.
  P[, share := d_ll / sum(d_ll[d_ll > 0])]
  worst <- head(P[d_ll > 0], 8)
  cat(sprintf("DG1  %d seats worse, %d better; the worst 5 carry %.0f%% of all the damage\n",
              sum(P$d_ll > 0), sum(P$d_ll < 0),
              100 * sum(head(P[d_ll > 0]$d_ll, 5)) / sum(P[d_ll > 0]$d_ll)))
  cat("DG2  worst seats (p_* is the probability given to the party that ACTUALLY won; higher is better)\n")
  print(worst[, .(seat, actual, p_table = round(p_p1f0, 4), p_xgb = round(p_p1f1, 4),
                  ll_table = round(ll_p1f0, 3), ll_xgb = round(ll_p1f1, 3),
                  d_ll = round(d_ll, 3))])
  best <- head(P[order(d_ll)], 5)
  cat("DG3  best seats\n")
  print(best[, .(seat, actual, p_table = round(p_p1f0, 4), p_xgb = round(p_p1f1, 4),
                 d_ll = round(d_ll, 3))])
  # FLOOR SEATS, reported separately. A seat at EPS contributes -log(1e-6)=13.8
  # by itself, so one seat crossing the floor moves a pair's pooled log loss by
  # more than most real model changes do.
  nf_t <- sum(P$p_p1f0 <= 1e-4); nf_x <- sum(P$p_p1f1 <= 1e-4)
  cat(sprintf("DG4  seats given <= 1e-4 for the actual winner: table flows %d, xgb flows %d\n", nf_t, nf_x))
  cat(sprintf("DG5  accuracy: table %d/%d, xgb %d/%d\n",
              sum(P$pred_p1f0 == P$actual), nrow(P), sum(P$pred_p1f1 == P$actual), nrow(P)))
}

fwrite(W, "output/diag-flow-regressions.csv")
cat("\nDG6  wrote output/diag-flow-regressions.csv\n")
