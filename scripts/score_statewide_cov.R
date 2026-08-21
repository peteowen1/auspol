# Does correlating the parties' statewide votes predict seat TOTALS better?
#
# Against docs/plans/prereg-statewide-covariance.md. The arms, the decision rule
# and refusals V1-V5 are there and are NOT restated.
#
# THE CRITERION IS THE TOTAL, NOT THE SEAT, and that is the whole design. A
# covariance between parties' statewide votes barely moves any single seat's
# marginal probability while moving the joint distribution a great deal, so
# scoring it the way every previous test here scored things would mostly miss
# it. Each election contributes one ACTUAL total per party, scored under that
# arm's predicted distribution of totals.
#
# The actual totals are counted from the per-seat backtest output rather than
# from the commissions' files, because a harness scores only the seats it could
# match -- the predicted distribution is over that seat set, so the actual must
# be too.
#
# Emits SC* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

# (per-seat file, totals file, pair label if the file carries no pair column)
SRC <- list(
  list(seat = "backtest-fed%s-n5000.csv",  tot = "backtest-fed-totals%s-n5000.csv",  pair = NULL),
  list(seat = "backtest-vic%s.csv",        tot = "backtest-vic-totals%s.csv",        pair = NULL),
  list(seat = "backtest-nsw2023%s.csv",    tot = "backtest-nsw2023-totals%s.csv",    pair = "nsw2023"),
  list(seat = "backtest-sa%s.csv",         tot = "backtest-sa-totals%s.csv",         pair = "sa2026"))

# fed's tag puts -n before -cor, so the arm suffix is not simply appended.
path_for <- function(tmpl, arm) {
  f <- file.path("output", sprintf(tmpl, ""))
  if (arm == "") return(f)
  g <- file.path("output", sprintf(tmpl, ""))
  sub("[.]csv$", paste0(arm, ".csv"), g)
}

load_arm <- function(arm) {
  act <- list(); pred <- list()
  for (S in SRC) {
    fs <- file.path("output", sub("%s", "", S$seat, fixed = TRUE))
    ft <- path_for(S$tot, arm)
    if (!file.exists(fs) || !file.exists(ft)) {
      stop("Missing ", if (!file.exists(fs)) fs else ft,
           ". Run the backtest harnesses in both arms first.")
    }
    d <- fread(fs, showProgress = FALSE)
    if (!"pair" %in% names(d)) d[, pair := S$pair]
    act[[length(act) + 1L]] <- d[, .N, by = .(pair, party = actual)]
    t <- fread(ft, showProgress = FALSE)
    if (!"pair" %in% names(t)) t[, pair := S$pair]
    pred[[length(pred) + 1L]] <- t
  }
  list(actual = rbindlist(act), pred = rbindlist(pred, fill = TRUE))
}

A <- load_arm("")
B <- load_arm("-cor")
# THREE TIMES this session a run has written into another arm's filename and
# produced a comparison of one arm against itself. Digests, not summary
# statistics: two arms can coincide on a log score by chance, never byte for
# byte across 20,000 simulations.
for (S in SRC) {
  fa <- path_for(S$tot, ""); fb <- path_for(S$tot, "-cor")
  if (identical(unname(tools::md5sum(fa)), unname(tools::md5sum(fb)))) {
    stop(basename(fa), " and ", basename(fb), " are BYTE-IDENTICAL, so one arm ",
         "wrote into the other's filename and this would compare an arm with ",
         "itself. That has happened three times today; regenerate the baseline.")
  }
}
els <- sort(unique(A$actual$pair))
cat(sprintf("\nSC1  %d elections, arms A (independent) and B (correlated)\n", length(els)))
if (!setequal(els, unique(B$actual$pair))) stop("The arms cover different elections.")

# Log score of the ACTUAL total under the predicted distribution of totals.
# Floored at half a simulation, so an outcome the arm never produced costs a
# large but finite amount rather than infinity -- otherwise one impossible
# result decides the whole comparison.
score_arm <- function(X, arm_name) {
  P <- X$pred
  cols <- setdiff(names(P), "pair")
  out <- list()
  for (e in els) {
    sims <- P[pair == e]
    n <- nrow(sims)
    a <- X$actual[pair == e]
    tot <- 0; k <- 0L
    for (p in cols) {
      if (!p %in% names(sims)) next
      obs <- a[party == p, N]
      obs <- if (length(obs)) obs[1] else 0L
      col <- sims[[p]]
      # A party absent from one pair's simulation arrives as NA through
      # rbindlist(fill = TRUE); it won no seats there, so NA is 0 rather than
      # a missing score. Without this the whole election scores NA and the
      # comparison silently loses it.
      col[is.na(col)] <- 0L
      pr <- sum(col == obs) / n
      tot <- tot - log(max(pr, 0.5 / n))
      k <- k + 1L
    }
    out[[length(out) + 1L]] <- data.table(pair = e, arm = arm_name,
                                          parties = k, logscore = tot / k)
  }
  rbindlist(out)
}
sa <- score_arm(A, "A"); sb <- score_arm(B, "B")
M <- merge(sa[, .(pair, A = logscore)], sb[, .(pair, B = logscore)], by = "pair")
M[, gain := A - B]
setorder(M, -gain)
cat("\nSC2  log score of the ACTUAL seat total, per party, averaged\n")
print(M[, .(pair, A = round(A, 4), B = round(B, 4), gain = round(gain, 4))])

se <- stats::sd(M$gain) / sqrt(nrow(M))
z <- mean(M$gain) / se
cat(sprintf("\nSC3  B beats A by %+.4f, clustered SE %.4f -> %+.2f SE (%d df)\n",
            mean(M$gain), se, z, nrow(M) - 1L))
cat(sprintf("SC3  bar set in advance: +2 SE. Positive in %d of %d elections.\n",
            sum(M$gain > 0), nrow(M)))

# V4 needs the per-seat score not to degrade: a change that improves totals by
# making individual seats worse is trading the thing the pendulum is for.
cat("\nSC4  guard -- per-seat log score must not degrade by more than 1 SE\n")
ps <- function(arm) {
  r <- list()
  for (S in SRC) {
    f <- path_for(S$seat, arm)
    if (!file.exists(f)) return(NULL)
    d <- fread(f, showProgress = FALSE)
    pk <- if ("prob" %in% names(d)) "prob" else "p"
    if (!"pair" %in% names(d)) d[, pair := S$pair]
    r[[length(r) + 1L]] <- d[, .(pair, prob = get(pk))]
  }
  rbindlist(r)[, .(ls = -mean(log(pmax(prob, 1e-6)))), by = pair]
}
pa <- ps(""); pb <- ps("-cor")
if (!is.null(pa) && !is.null(pb)) {
  pm <- merge(pa, pb, by = "pair", suffixes = c("_A", "_B"))
  pm[, d := ls_A - ls_B]
  pse <- stats::sd(pm$d) / sqrt(nrow(pm))
  cat(sprintf("SC4  per-seat: %+.4f, SE %.4f -> %+.2f SE (positive = B better)\n",
              mean(pm$d), pse, mean(pm$d) / pse))
} else {
  cat("SC4  per-seat comparison unavailable: one arm did not write per-seat output.\n")
}

verdict <- if (z > 2) {
  "ADOPT B -- clears the 2 SE bar on seat totals"
} else if (z < -2) {
  "REFUSE B -- correlating the draws makes seat totals WORSE"
} else {
  sprintf("KEEP A -- B is %+.2f SE, short of the bar. The covariance is real; at this sample it does not pay for itself.", z)
}
cat(sprintf("\nSC5  verdict: %s\n", verdict))
cat("SC5  V1 and V2 apply to any reading of this: One Nation's upside rising is\n")
cat("SC5  the PREDICTED direction and is not evidence, and moving closer to\n")
cat("SC5  YouGov must play no part.\n")
fwrite(M, file.path("output", "statewide-cov-score.csv"))
