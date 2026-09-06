# Which salience statistic actually separates an emergence from a token
# candidacy? Measured on the UNBIASED emergence sample, not on hand-picked hard
# cases.
#
# WHY THIS SCRIPT EXISTS. Four statistics have been proposed today and three
# were judged on samples that could not settle anything:
#
#   level          the campaign mean          -- puts Cameron Smith (a
#                                                footballer, 3.8% of the vote)
#                                                above every teal
#   rise ratio     campaign / baseline        -- puts James Laurie (4.3%) top,
#                                                because his baseline is 0 and
#                                                the ratio divides by a floor
#   jump           campaign - baseline        -- Pete's, and the best of the
#                                                three: it cancels a namesake's
#                                                persistent volume without a
#                                                near-zero denominator
#   seat ratio     candidate / incumbent      -- cannot tell a loud challenger
#                                                from an obscure incumbent:
#                                                Bohm 5.64 (lost) and Chaney
#                                                5.38 (won) both come from
#                                                incumbents polling ~5 volume
#
# The comparisons so far used 7 to 11 cases in which the losers were CHOSEN
# because they were the known failures. That is an adversarial sample and its
# AUCs (0.250, 0.571, 0.667) measure nothing.
#
# This runs every statistic over output/emergence-trends.csv: 15 winners and 28
# losers selected on polling >= 5%, WITHOUT reference to their salience. That is
# the only sample here that can rank the statistics honestly.
#
# Emits CA* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

R <- fread("output/emergence-trends.csv", showProgress = FALSE)
cat(sprintf("CA1  %d rows | %d won | columns: %s\n", nrow(R), sum(R$won),
            paste(names(R), collapse = ", ")))

# The paired fetcher now stores baselines; older cache entries do not. Report
# coverage rather than silently scoring whatever happens to be present.
has_base <- all(c("cand_base", "anchor_base") %in% names(R))
if (!has_base) {
  cat("CA!  cand_base/anchor_base absent -- this cache predates the\n")
  cat("CA!  keep-the-series fix, so only `level` and `ratio` are scoreable.\n")
  cat("CA!  Refetch with scripts/fetch_emergence_trends.R to compare jump.\n")
}

# `stats` holds quoted expressions evaluated against R, our own data.table,
# purely so each statistic can be named once and reused in both the pooled and
# incumbent-only loops. No external or user input reaches eval() -- every
# expression is a literal written above.
stats <- list(
  level = quote(cand_hits),
  ratio = quote(ratio)
)
if (has_base) {
  stats$jump  <- quote(cand_hits - cand_base)
  stats$rise  <- quote(cand_hits / pmax(cand_base, 0.5))
  # Two anchors: loud for this seat AND loud in absolute terms. Multiplying is
  # the cheapest version of "both must hold".
  stats$both  <- quote(ratio * (cand_hits - cand_base))
}

auc_of <- function(v, won) {
  ok <- is.finite(v)
  v <- v[ok]; won <- won[ok]
  n1 <- sum(won); n0 <- length(won) - n1
  if (n1 < 3 || n0 < 3) return(c(NA, n1, n0))
  rk <- rank(v)
  c((sum(rk[won]) - n1 * (n1 + 1) / 2) / (n1 * n0), n1, n0)
}

cat("\nCA2  AUC by statistic, on the UNBIASED sample\n")
res <- list()
for (nm in names(stats)) {
  v <- eval(stats[[nm]], R)
  a <- auc_of(v, R$won == TRUE)
  res[[nm]] <- data.table(stat = nm, auc = a[1], won = a[2], lost = a[3])
  if (is.na(a[1])) cat(sprintf("  %-6s too few usable rows\n", nm))
  else cat(sprintf("  %-6s AUC %.3f   (%d won vs %d lost)\n", nm, a[1], a[2], a[3]))
}

# Incumbent-anchored only: a PM-fallback ratio is a different measurement and
# pooling the two was flagged from the start.
if ("anchor_type" %in% names(R)) {
  cat("\nCA3  incumbent-anchored rows only\n")
  I <- R[anchor_type == "incumbent"]
  for (nm in names(stats)) {
    v <- eval(stats[[nm]], I)
    a <- auc_of(v, I$won == TRUE)
    if (is.na(a[1])) cat(sprintf("  %-6s too few usable rows\n", nm))
    else cat(sprintf("  %-6s AUC %.3f   (%d won vs %d lost)\n", nm, a[1], a[2], a[3]))
  }
}
cat("\nCA9  the winner here is the statistic that ships; the hand-picked\n")
cat("CA9  comparisons earlier today do not override this one.\n")
