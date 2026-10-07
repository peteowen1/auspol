# Share-level screen, seconds: are LARGE predicted shares for independents and
# minor parties systematically too high? Signed error by predicted-share band, then
# a time-forward test of a band correction (each target uses only earlier elections,
# shrunk by precision), exactly as scripts/screen_segment_bias.R does for segments.

suppressPackageStartupMessages({library(data.table); devtools::load_all(quiet = TRUE)})
src <- readLines("scripts/audit_share_bias.R")
eval(parse(text = src[seq_len(grep("^clus <- function", src) - 1)]))   # trusted repo script: builds F

M <- F[!F$party %in% c("ALP", "LNP")]
M[, band := cut(xgb_pred_seat, c(-Inf, 5, 10, 15, 20, 30, Inf), right = FALSE,
                labels = c("<5", "5-10", "10-15", "15-20", "20-30", "30+"))]
M[, edate := as.Date(unname(election_dates(election)))]
cl <- function(e, el) { m <- mean(e); E <- tapply(e - m, el, sum); k <- length(E)
  c(bias = m, se = if (k > 1) sqrt(k / (k - 1) * sum(E^2)) / length(e) else NA_real_) }
cat("Non-major cells: signed error (predicted - actual, points; positive = over-called) by predicted-share band:\n")
print(M[, {r <- cl(err, election); .(n = .N, elections = uniqueN(election), mean_pred = round(mean(xgb_pred_seat), 1),
         mean_actual = round(mean(actual_share), 1), bias = round(r[["bias"]], 2), se = round(r[["se"]], 2))}, by = band][order(band)])

corr <- rbindlist(lapply(sort(unique(M$election)), function(T) {
  H <- M[M$edate < unique(M$edate[M$election == T])]
  if (!nrow(H)) return(NULL)
  S <- H[, {r <- cl(err, election); .(bias = r[["bias"]], se = r[["se"]])}, by = band][!is.na(se)]
  if (nrow(S) < 2) return(NULL)
  tau2 <- max(0, stats::var(S$bias) - mean(S$se^2))
  data.table(election = T, band = S$band, adj = tau2 / (tau2 + S$se^2) * S$bias)
}))
G <- corr[M, on = .(election, band)]; G[is.na(adj), adj := 0]
G[, err_new := err - adj]
d <- function(x) { dd <- x$err_new^2 - x$err^2; E <- tapply(dd, x$election, sum); k <- length(E)
  list(n = nrow(x), change = round(sum(dd), 1), se = round(sqrt(k / (k - 1) * sum((E - sum(dd) / k)^2)), 1),
    pct = round(100 * sum(dd) / sum(x$err^2), 1)) }
cat("\nTime-forward band correction, squared error change (points^2; negative = better; SE clustered on election):\n")
print(rbind(G[, c(band = "ALL", d(.SD))], G[, d(.SD), by = band][order(band)], fill = TRUE))
