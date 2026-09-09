# Compare our shipped model against AE Forecasts, per-election and worst
# seats. Reads only pooled outputs and the newest backtest file per pair --
# no fresh sim. Emits AEF* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "output"
eps <- 1e-6

sd_all <- fread(file.path(OUT, "pooled-sharedetail.csv"), showProgress = FALSE)
bt_all <- fread(file.path(OUT, "pooled-backtest.csv"), showProgress = FALSE)
aef_primary <- fread(file.path(OUT, "aef-primary-all.csv"), showProgress = FALSE)
aef_scores  <- fread(file.path(OUT, "aef-seat-scores.csv"), showProgress = FALSE)

MAP <- data.table(
  pair = c("fed2022","nsw2023","vic2022","qld2024","fed2025","wa2025","sa2026"),
  aef_code = c("2022fed","2023nsw","2022vic","2024qld","2025fed","2025wa","2026sa")
)

# newest non-sharedetail, non-allprobs, non-totals win-probability file for a
# pair. Federal/NSW/QLD name files by PAIR (backtest-fed-p2025-...,
# backtest-nsw2023-...); SA and WA name files by JURISDICTION regardless of
# pair (backtest-sa-..., backtest-wa-...) and rely on an internal `pair`
# column instead -- caught by a real "no win file" miss for sa2026 rather
# than assumed.
JURIS_PREFIX <- c(sa2026 = "sa", wa2025 = "wa", vic2022 = "vic")
newest_win_file <- function(pr) {
  pat <- if (pr %in% names(JURIS_PREFIX)) sprintf("^backtest-%s-", JURIS_PREFIX[[pr]])
         else if (grepl("^fed", pr)) sprintf("^backtest-fed-p%s-", sub("fed","",pr))
         else sprintf("^backtest-%s-", pr)
  f <- list.files(OUT, pattern = pat, full.names = TRUE)
  f <- f[!grepl("sharedetail|allprobs|totals", f)]
  if (!length(f)) return(NULL)
  f[which.max(file.mtime(f))]
}

read_win <- function(pr) {
  f <- newest_win_file(pr)
  if (is.null(f)) return(NULL)
  d <- fread(f, showProgress = FALSE)
  if ("pair" %in% names(d)) d <- d[d$pair == pr]
  if ("p" %in% names(d)) setnames(d, "p", "our_p")
  if ("prob" %in% names(d)) setnames(d, "prob", "our_p")
  d[, .(seat, actual, our_pred = pred, our_p = pmin(pmax(our_p, eps), 1))]
}

all_rows <- list()
for (i in seq_len(nrow(MAP))) {
  pr <- MAP$pair[i]; ac <- MAP$aef_code[i]
  win <- read_win(pr)
  if (is.null(win)) { cat(sprintf("AEF0! no win file for %s\n", pr)); next }
  a <- aef_scores[election == ac]
  a[, aef_p := pmin(pmax(prob, eps), 1)]
  setnames(a, "pred", "aef_pred")
  m <- merge(win, a[, .(seat, aef_pred, aef_p)], by = "seat")
  m[, delta := (-log(our_p)) - (-log(aef_p))]
  sd_p <- sd_all[pair == pr]
  ap_p <- aef_primary[election == ac]
  m <- merge(m, sd_p[, .(seat, party, our_primary = pred_share, actual_primary = actual_share)],
             by.x = c("seat","actual"), by.y = c("seat","party"), all.x = TRUE)
  m <- merge(m, ap_p[, .(seat, party, aef_primary = aef_pcv)],
             by.x = c("seat","actual"), by.y = c("seat","party"), all.x = TRUE)
  m[, pair := pr]
  all_rows[[pr]] <- m
}
ALL <- rbindlist(all_rows, fill = TRUE)

cat("\n=== PER-ELECTION: our seat log loss vs AEF's (lower is better) ===\n")
per <- ALL[, .(n = .N,
               our_ll = mean(-log(our_p)),
               aef_ll = mean(-log(aef_p)),
               our_acc = mean(our_pred == actual),
               delta  = mean(-log(our_p)) - mean(-log(aef_p))),
           by = pair]
setorder(per, pair)
print(per[, .(pair, n, our_acc = round(our_acc,3), our_ll = round(our_ll,4),
              aef_ll = round(aef_ll,4), delta = round(delta,4))])
cat(sprintf("\nPooled seat log loss, ALL 22 elections (our full backtest, not just AEF-comparable): %.4f\n",
            sum(bt_all$logloss * bt_all$n) / sum(bt_all$n)))
cat(sprintf("Pooled seat log loss on the %d AEF-comparable elections: ours %.4f vs AEF %.4f (delta %+.4f)\n",
            nrow(per), mean(-log(ALL$our_p)), mean(-log(ALL$aef_p)),
            mean(-log(ALL$our_p)) - mean(-log(ALL$aef_p))))

cat("\n=== WORST 10 SEATS (our log loss minus AEF's, worst first) ===\n")
setorder(ALL, -delta)
worst <- ALL[1:10, .(pair, seat, actual, our_pred, our_p = round(our_p,3),
                      aef_pred, aef_p = round(aef_p,3),
                      our_primary = round(our_primary,1),
                      actual_primary = round(actual_primary,1),
                      aef_primary = round(aef_primary,1),
                      delta = round(delta,2))]
print(worst)
fwrite(ALL, file.path(OUT, "aef-comparison-full.csv"))
cat(sprintf("\nwrote %s\n", file.path(OUT, "aef-comparison-full.csv")))
