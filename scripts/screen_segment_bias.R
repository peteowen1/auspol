# Share-level screen: would a TIME-FORWARD segment bias correction help? Seconds to run.
#
# For each target election T and each segment (party x status x juris, as in
# scripts/audit_share_bias.R), estimate the mean signed error using ONLY elections
# whose polling day is strictly before T's, shrink it toward 0 by its precision
# (w = tau^2 / (tau^2 + se^2), tau^2 the between-segment variance of the earlier
# biases), and subtract it from T's predictions. Compare squared error before and
# after, per segment and pooled, SE clustered on election. No row of T informs its
# own correction. Share level only: no renormalisation, no seat probabilities. A
# PASS here earns a harness arm (scripts/quick_arm.R); it ships nothing.

suppressPackageStartupMessages({library(data.table); devtools::load_all(quiet = TRUE)})
source_lines <- readLines("scripts/audit_share_bias.R")
# Reuse the audit's construction of F (signed error + status) without its printing.
stop_at <- grep("^clus <- function", source_lines)
eval(parse(text = source_lines[seq_len(stop_at - 1)]))   # trusted repo script, same file this one documents

F[, edate := as.Date(unname(election_dates(election)))]
F[, seg := paste(party, status, juris, sep = "|")]
targets <- sort(unique(F$election))

corr <- rbindlist(lapply(targets, function(T) {
  tday <- unique(F$edate[F$election == T])
  H <- F[F$edate < tday]
  if (!nrow(H)) return(data.table(election = T, seg = character(0), adj = numeric(0)))
  S <- H[, {m <- mean(err); E <- tapply(err - m, election, sum); k <- length(E)
            list(bias = m, se = if (k > 1) sqrt(k / (k - 1) * sum(E^2)) / .N else NA_real_, n = .N)}, by = seg]
  S <- S[!is.na(S$se)]
  if (!nrow(S)) return(data.table(election = T, seg = character(0), adj = numeric(0)))
  tau2 <- max(0, stats::var(S$bias) - mean(S$se^2))
  S[, w := tau2 / (tau2 + se^2)]
  data.table(election = T, seg = S$seg, adj = S$w * S$bias)
}))
G <- corr[F, on = .(election, seg)]
G[is.na(adj), adj := 0]
G[, err_new := err - adj]
cat(sprintf("cells %d; with a non-zero time-forward correction %d (the rest had no earlier data for their segment)\n",
            nrow(G), sum(G$adj != 0)))

delta <- function(d) {
  dd <- d$err_new^2 - d$err^2; m <- sum(dd)
  E <- tapply(dd, d$election, sum); k <- length(E)
  se <- if (k > 1) sqrt(k / (k - 1) * sum((E - m / k)^2)) else NA_real_
  list(n = nrow(d), sq_err_before = sum(d$err^2), change = m, se = se,
       pct = 100 * m / sum(d$err^2), rmse_before = sqrt(mean(d$err^2)), rmse_after = sqrt(mean(d$err_new^2)))
}
cat("\nPooled, every cell (squared error in points^2; negative change = better; SE clustered on election):\n")
print(as.data.table(delta(G))[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])
cat("\nBy segment, n >= 50, ranked by change:\n")
B <- G[, delta(.SD), by = seg][n >= 50][order(change)]
print(B[, .(seg, n, change = round(change, 1), se = round(se, 1), pct = round(pct, 1),
            rmse_before = round(rmse_before, 2), rmse_after = round(rmse_after, 2))], nrows = 40)
cat("\nBy election (does it help late elections, i.e. the ones with most history?):\n")
print(G[, delta(.SD), by = election][order(election), .(election, n, change = round(change, 1), pct = round(pct, 1))])
