# Walk rows for a fitted no-re-stander retention rate (IND gap, prereg-ind-gap-restand follow-up).
# For every seat where the IND class had candidates last time and none of them stands for it again:
#   prev  = IND class share in the seat last time (sum of IND pcv)
#   lp/ln = statewide (or national) IND level at the previous / current election, from formal votes
#   now   = IND class share in the seat now (every IND now is a newcomer here)
#   rate  = (now - ln) / (prev - lp): the slope on the old gap that would have hit the result exactly
devtools::load_all(".", quiet = TRUE)
library(data.table)
C <- fread("output/candidacies.csv", showProgress = FALSE)
C[, votes := as.numeric(votes)]; C[, pcv := as.numeric(pcv)]
el <- unique(C[, .(election, region, year)])[order(region, year)]
el <- el[!grepl("byel|^tas|^act", election)]
pairs <- el[, .(from = head(election, -1), to = tail(election, -1)), by = region]
lvl <- C[, .(lvl = 100 * sum(votes[party == "IND"], na.rm = TRUE) / sum(votes, na.rm = TRUE)), by = election]
rows <- rbindlist(lapply(seq_len(nrow(pairs)), function(i) {
  f <- pairs$from[i]; t <- pairs$to[i]
  x <- tryCatch({ invisible(capture.output(xx <- candidate_returns(f, t), file = nullfile())); xx }, error = function(e) NULL)
  if (is.null(x)) return(NULL)
  a <- x[party == "IND" & class_gap_restand %in% FALSE, .(seat)]
  if (!nrow(a)) return(NULL)
  pv <- C[election == f & party == "IND", .(prev = sum(pcv, na.rm = TRUE), prev_names = paste(sprintf("%s %.1f", surname, pcv)[order(-pcv)], collapse = ", ")), by = seat]
  nw <- C[election == t & party == "IND", .(now = sum(pcv, na.rm = TRUE), now_names = paste(sprintf("%s %.1f", surname, pcv)[order(-pcv)], collapse = ", ")), by = seat]
  a <- merge(a, pv, by = "seat", all.x = TRUE); a <- merge(a, nw, by = "seat", all.x = TRUE)
  a[, `:=`(pair = t, lp = lvl$lvl[lvl$election == f], ln = lvl$lvl[lvl$election == t])]
  a
}), fill = TRUE)
rows <- rows[is.finite(prev) & is.finite(now)]
rows[, gap := prev - lp]; rows[, gap_now := now - ln]; rows[, rate := gap_now / gap]
cat("rows with no statewide level (dropped):", rows[!is.finite(gap) | !is.finite(gap_now), .N], "in", paste(unique(rows[!is.finite(gap) | !is.finite(gap_now)]$pair), collapse = ", "), "
")
rows <- rows[is.finite(gap) & is.finite(gap_now)]
cat("seat-elections where nobody re-stands, with an IND standing now:", nrow(rows), "in", uniqueN(rows$pair), "pairs\n")
cat("(seats with no IND now are left out: the class has no cell to forecast)\n\n")
# pooled no-intercept slope, and by size of the old gap
fit <- function(d) if (nrow(d) >= 2) sum(d$gap * d$gap_now) / sum(d$gap^2) else NA_real_
rows[, band := cut(gap, c(-Inf, 0, 5, 15, Inf), labels = c("gap <= 0 (seat was below level)", "0-5 pts", "5-15 pts", "> 15 pts"))]
cat("Carry rate by size of the old gap (no-intercept least squares; 0 = old gap gone, 1 = all of it carried):\n")
print(rows[, .(n = .N, carry_rate = round(fit(.SD), 3), median_rate = round(median(rate[abs(gap) > 1]), 3)), by = band][order(band)])
cat(sprintf("\nAll: carry rate %.3f over %d seat-elections (shipped slope on these seats is the IND new-candidate slope, ~0.3-0.4)\n",
            fit(rows), nrow(rows)))
cat("\nBy jurisdiction:\n")
rows[, jur := sub("[0-9]+$", "", pair)]
print(rows[, .(n = .N, carry_rate = round(fit(.SD), 3)), by = jur][order(-n)])
show <- function(d) print(d[, .(pair, seat, last_time = prev_names, now = now_names, prev = round(prev, 1), lvl_prev = round(lp, 1),
                               lvl_now = round(ln, 1), got = round(now, 1), rate = round(rate, 2))], nrow = 50)
cat("\nNAMED EXAMPLES:\n")
show(rows[(pair == "vic2022" & seat %in% c("Pascoe Vale", "Monbulk", "Ripon")) | (pair == "fed2022" & seat %in% c("Kooyong", "Mallee", "Chisholm")) |
          (pair == "fed2025" & seat %in% c("Grey", "Riverina", "Fairfax"))])
cat("\nBIGGEST OLD GAPS (> 15 pts):\n"); show(rows[gap > 15][order(-gap)][1:min(.N, 15)])
fwrite(rows, "docs/reviews/ind-gap-carry-rows-2026-10-30.csv")
