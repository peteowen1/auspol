# Is the seat model's over-confidence fixable, and does a model change beat a knob?
#
# Against docs/plans/prereg-calibration.md, committed before anything was
# fitted. The four arms, the decision rule and refusals K1-K6 are there and are
# NOT restated.
#
# The one thing that shapes the code: arm C is the NULL, not a candidate.
# CLAUDE.md records that any noise added to an over-confident model improves
# calibration, so arm B improving the slope proves nothing unless it also beats
# a one-parameter rescale that adds no knowledge whatsoever.
#
# Criterion is leave-one-election-out LOG SCORE clustered on the election. Not
# the slope: the slope can be driven to 1 by discarding information, and K6
# exists because adopting on it is the mistake arm C is there to expose.
#
# Emits CL* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

EPS <- 1e-6
MULTS <- c(1.0, 1.5, 2.5, 4.0)

# The NSW harness names its probability column `p`; the others use `prob`.
read_bt <- function(path, pair = NULL) {
  if (!file.exists(path)) return(NULL)
  d <- fread(path, showProgress = FALSE)
  pk <- if ("prob" %in% names(d)) "prob" else "p"
  out <- d[, .(pair = if (!is.null(pair)) pair else get("pair"),
               prob = get(pk), pred_p, correct = as.integer(pred == actual))]
  out[]
}

# Arm A is read from the EXPLICIT m1.0 files, not the plain backtest-*.csv
# names. Those plain names were overwritten by experimental arms earlier today,
# which produced a comparison of one arm against itself reading exactly +0.0000
# on six elections. Every arm now has its own file, including the baseline.
#
# The federal arms all run at 5,000 simulations and the state arms at 20,000.
# That is fine and deliberate: the comparison is between arms WITHIN an
# election, never across elections, and each election's arms share a setting.
arm_a <- rbindlist(list(
  read_bt("output/cal-fed-m1.0.csv"),
  read_bt("output/cal-vic-m1.0.csv"),
  read_bt("output/cal-nsw-m1.0.csv", "nsw2023"),
  read_bt("output/cal-sa-m1.0.csv", "sa2026")))
els <- sort(unique(arm_a$pair))
cat(sprintf("\nCL1  arm A: %d seats across %d elections\n", nrow(arm_a), length(els)))

lg <- function(p) -mean(log(pmax(p, EPS)))
temper <- function(p, T) stats::plogis(T * stats::qlogis(pmin(pmax(p, EPS), 1 - EPS)))

# ---- arm C: one temperature, fitted leave-one-election-out -----------------
grid_T <- seq(0.05, 1.5, by = 0.05)
fitT <- function(d) grid_T[which.min(vapply(grid_T, function(t) lg(temper(d$prob, t)),
                                            numeric(1)))]
C <- rbindlist(lapply(els, function(e) {
  T <- fitT(arm_a[pair != e])
  te <- arm_a[pair == e]
  data.table(pair = e, n = nrow(te), T = T,
             logA = lg(te$prob), logC = lg(temper(te$prob, T)))
}))
C[, gain := logA - logC]
cat("\nCL2  arm C -- temperature, the null\n")
print(C[, .(pair, n, T, logA = round(logA, 4), logC = round(logC, 4),
            gain = round(gain, 4))])

# ---- arm B: wider seat spread, multiplier fitted leave-one-election-out -----
b_files <- CJ(m = MULTS, h = c("fed", "vic", "nsw", "sa"))
# format(nsmall = 1) because R renders 4.0 as "4" while the shell that wrote
# these files rendered it "4.0" -- a mismatch that would present as a missing
# run rather than a naming bug.
b_files[, path := sprintf("output/cal-%s-m%s.csv", h, format(m, nsmall = 1))]
have <- b_files[file.exists(path)]

# TWO GRID POINTS MUST NEVER BE THE SAME FILE. Twice today a sweep produced
# byte-identical arms -- once because an experimental run overwrote the
# baseline filename, once because the filename guard changed where runs wrote
# and the copy commands still fetched the old name. Both times the comparison
# reported a difference of exactly 0.0000 and read as "this input does not
# matter", which is indistinguishable from a real null.
#
# Digests are compared rather than log scores: two arms could coincide on a
# summary statistic by chance, but not byte for byte.
if (nrow(have) > 1L) {
  have[, digest := vapply(path, function(f)
    paste(tools::md5sum(f)), character(1))]
  dup <- have[, .N, by = .(h, digest)][N > 1L]
  if (nrow(dup)) {
    print(merge(have, dup[, .(h, digest)], by = c("h", "digest"))[, .(h, m, path)])
    stop("Grid points above are BYTE-IDENTICAL, so at least one arm did not ",
         "run or was copied from the wrong file. A comparison against them ",
         "would report a null that is really a plumbing failure.")
  }
}
if (nrow(have) < nrow(b_files)) {
  cat(sprintf("\nCL3  arm B INCOMPLETE: %d of %d runs present. Missing: %s\n",
              nrow(have), nrow(b_files),
              paste(b_files[!file.exists(path), basename(path)], collapse = ", ")))
  cat("CL3  No verdict is issued on a partial grid -- a multiplier fitted on the\n")
  cat("CL3  elections that happen to have finished is fitted on a biased subset.\n")
} else {
  B_all <- rbindlist(lapply(MULTS, function(m) {
    d <- rbindlist(list(
      read_bt(sprintf("output/cal-fed-m%s.csv", format(m, nsmall = 1))),
      read_bt(sprintf("output/cal-vic-m%s.csv", format(m, nsmall = 1))),
      read_bt(sprintf("output/cal-nsw-m%s.csv", format(m, nsmall = 1)), "nsw2023"),
      read_bt(sprintf("output/cal-sa-m%s.csv", format(m, nsmall = 1)), "sa2026")))
    d[, mult := m][]
  }))
  fitM <- function(exclude) {
    s <- B_all[pair != exclude, .(l = lg(prob)), by = mult]
    s$mult[which.min(s$l)]
  }
  B <- rbindlist(lapply(els, function(e) {
    m <- fitM(e)
    te <- B_all[pair == e & mult == m]
    data.table(pair = e, n = nrow(te), mult = m, logB = lg(te$prob),
               acc = mean(te$correct))
  }))
  B <- merge(B, C[, .(pair, T, logA, logC)], by = "pair")
  B[, `:=`(B_vs_A = logA - logB, B_vs_C = logC - logB)]
  cat("\nCL4  arm B -- wider seat spread\n")
  print(B[, .(pair, n, mult, logA = round(logA, 4), logB = round(logB, 4),
              logC = round(logC, 4), B_vs_A = round(B_vs_A, 4),
              B_vs_C = round(B_vs_C, 4))])

  se_of <- function(x) stats::sd(x) / sqrt(length(x))
  for (cmp in list(list("C beats A", C$gain), list("B beats A", B$B_vs_A),
                   list("B beats C", B$B_vs_C))) {
    m <- mean(cmp[[2]]); s <- se_of(cmp[[2]])
    cat(sprintf("CL5  %-10s mean %+.4f, clustered SE %.4f -> %+.2f SE (%d df)\n",
                cmp[[1]], m, s, m / s, length(cmp[[2]]) - 1L))
  }

  # K1: accuracy must not fall by more than a point.
  acc_a <- mean(arm_a$correct); acc_b <- sum(B$acc * B$n) / sum(B$n)
  cat(sprintf("\nCL6  K1 -- accuracy A %.1f%% vs B %.1f%% (bar: within 1 point)\n",
              100 * acc_a, 100 * acc_b))
  # K2: the fitted multiplier must not vary by more than a factor of 2.
  cat(sprintf("CL6  K2 -- multiplier across folds %.1f to %.1f (bar: under 2x)\n",
              min(B$mult), max(B$mult)))
  # K4: Victoria 2018->2022 is the one under-confident election.
  cat(sprintf("CL6  K4 -- vic2022 contributes %+.4f to B-vs-C; without it %+.2f SE\n",
              B[pair == "vic2022", B_vs_C],
              mean(B[pair != "vic2022", B_vs_C]) / se_of(B[pair != "vic2022", B_vs_C])))
  fwrite(B, "output/calibration-arms.csv")
}

se_c <- stats::sd(C$gain) / sqrt(nrow(C))
cat(sprintf("\nCL7  arm C against A: %+.4f, SE %.4f -> %+.2f SE (%d df)\n",
            mean(C$gain), se_c, mean(C$gain) / se_c, nrow(C) - 1L))
cat(sprintf("CL7  temperature across folds: %.2f to %.2f\n", min(C$T), max(C$T)))
