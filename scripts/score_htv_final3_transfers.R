# PRIMARY SCORE for AUSPOL_HTV_FINAL3 (docs/plans/prereg-htv-final3-2026-11-27.md): log loss of the ACTUAL Liberal
# transfers in final-three exclusions (Liberal votes went to Labor and the Greens only), two-way ALP v GRN.
# For each election with a card row, the share the model writes into LNP|ALP+GRN is fitted from EARLIER elections only
# (fit_htv_flow_rows(), elections_before()) with the switch 0 and 1, then smoothed as the simulation does:
# p_eff = (1 - s) p + s / 2. Lower is better. Paired arm - base, SE clustered on election.
#
# Usage (from the worktree, cwd = a root holding external/): Rscript <worktree>/scripts/score_htv_final3_transfers.R <worktree> [out.csv]
args <- commandArgs(TRUE)
wt <- if (length(args)) args[1] else "."
out_csv <- if (length(args) >= 2) args[2] else NA_character_
suppressMessages(devtools::load_all(wt, quiet = TRUE)); suppressMessages(library(data.table))
S <- as.numeric(Sys.getenv("AUSPOL_SMOOTH", "0.15"))
cat(sprintf("HF0 cwd %s | smoothing %.2f\n", getwd(), S))
tab <- htv_order_table()
fs <- list.files(file.path("external", "elections"), pattern = "-transfers[.]csv$", full.names = TRUE)
tx <- rbindlist(lapply(fs, function(f) fread(f, showProgress = FALSE)[from == "LNP" & votes > 0, .(election, seat, round, to, votes)]), fill = TRUE)
rs <- tx[, .(rset = paste(sort(unique(to)), collapse = "+"), alp = sum(votes[to == "ALP"]), grn = sum(votes[to == "GRN"])), by = .(election, seat, round)]
ev <- rs[rset == "ALP+GRN"]
cat(sprintf("HF1 final-three Liberal exclusions on disk: %d events, %d votes, %d elections\n", nrow(ev), sum(ev$alp + ev$grn), uniqueN(ev$election)))
els <- sort(intersect(unique(ev$election), unique(tab$election)))
skipped <- setdiff(unique(ev$election), els)
cat("HF2 elections with no card row (override never applies, untouched by the switch):", paste(sort(skipped), collapse = " "), "\n")
res <- list()
for (e in els) {
  Sys.setenv(AUSPOL_HTV_FINAL3 = "1")
  lg <- utils::capture.output(fr <- fit_htv_flow_rows(e))
  Sys.setenv(AUSPOL_HTV_FINAL3 = "0")
  if (is.null(fr)) { cat("HF3!", e, "no shares fitted\n"); next }
  te <- tab[tab$election == e]
  for (i in which(ev$election == e)) {
    s <- ev$seat[i]
    above <- if (s %in% te$seat) te[te$seat == s]$greens_above_labor[1] else if (any(te$seat == "ALL")) te[te$seat == "ALL"]$greens_above_labor[1] else NULL
    if (is.null(above)) { cat("HF4", e, s, "no card for this seat: untouched\n"); next }
    lab <- if (is.na(above)) "open" else if (above) "greens_above" else "labor_above"
    p0 <- fr[[lab]]; p1 <- if (is.null(fr$final3)) NA_real_ else fr$final3[[lab]]
    if (is.null(p0) || !is.finite(p0)) { cat("HF4", e, s, lab, "no share: untouched\n"); next }
    if (is.null(p1) || !is.finite(p1)) p1 <- p0
    a <- ev$alp[i]; g <- ev$grn[i]
    ll <- function(p, sm) { q <- (1 - sm) * p / 100 + sm / 2; -(a * log(q) + g * log(1 - q)) / (a + g) }
    res[[length(res) + 1L]] <- data.table(election = e, seat = s, card = lab, votes = a + g, actual = 100 * a / (a + g),
                                         p0 = p0, p1 = p1, ll0 = ll(p0, S), ll1 = ll(p1, S), ll0_raw = ll(p0, 0), ll1_raw = ll(p1, 0))
  }
}
R <- rbindlist(res)
R[, d := ll1 - ll0]
cl_se <- function(dd, g) { m <- dd[, .(s = sum(d), n = .N), by = g]; G <- nrow(m); N <- sum(m$n); mu <- sum(m$s) / N
  sqrt(G / (G - 1) * sum((m$s - m$n * mu)^2)) / N }
per <- R[, .(events = .N, votes = sum(votes), card = paste(unique(card), collapse = "/"), actual_vw = round(100 * sum(votes * actual / 100) / sum(votes), 1),
             used_off = round(mean(p0), 1), used_on = round(mean(p1), 1), ll_off = round(mean(ll0), 4), ll_on = round(mean(ll1), 4),
             change = round(mean(d), 4)), by = election]
print(per, nrow = 100)
pooled <- function(x, lab) {
  se <- cl_se(x[, .(election, d)], "election")
  vw <- x[, sum(votes * d) / sum(votes)]
  raw <- x[, mean(ll1_raw - ll0_raw)]
  cat(sprintf("HF5 %-26s %3d events %2d elections | log loss off %.4f on %.4f change %+.4f (SE %.4f, clustered on election) | vote-weighted change %+.4f | unsmoothed change %+.4f\n",
              lab, nrow(x), uniqueN(x$election), mean(x$ll0), mean(x$ll1), mean(x$d), se, vw, raw))
}
pooled(R, "all scored")
pooled(R[grepl("^vic", election)], "Victoria")
pooled(R[grepl("^fed", election)], "federal")
pooled(R[card == "labor_above"], "Labor-above card events")
# leave-one-election-out
lo <- sapply(unique(R$election), function(e) R[election != e, mean(d)])
cat(sprintf("HF6 leave-one-election-out mean change: min %+.4f max %+.4f (worst drop: %s)\n", min(lo), max(lo), names(lo)[which.max(lo)]))
if (!is.na(out_csv)) fwrite(R, out_csv)
