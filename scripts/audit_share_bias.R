# Where is the shipped primary-vote prediction systematically off? A seconds-fast map
# of signed error by party class x candidate status x jurisdiction, to choose which
# fixes are worth a harness run (CLAUDE.md: screen at share level first).
#
# Signed error = predicted - actual, percentage points (positive = we over-called).
# Prediction = xgb_pred_seat, the per-seat published-path prediction in
# output/forecasts.csv (err_* columns there are ABSOLUTE; recomputed signed here).
# Status, from output/candidacies.csv, keyed on the person:
#   sitting   -- this candidate won this seat at the previous election
#   returning -- stood in this seat at the previous election but did not win
#   new       -- did not stand in this seat at the previous election
# SE is clustered on election (cells in one election share its statewide error).
#
# Writes output/share-bias-audit.csv.

suppressPackageStartupMessages({library(data.table); devtools::load_all(quiet = TRUE)})

F <- fread("output/forecasts.csv")
cat(sprintf("forecasts.csv: %d rows, %d elections, built %s\n",
            nrow(F), uniqueN(F$election), paste(unique(F$built_at), collapse = ", ")))
F <- F[!is.na(F$actual_share) & !is.na(F$xgb_pred_seat) & !is.na(F$candidate)]
F[, err := xgb_pred_seat - actual_share]

person_key <- function(nm) {
  nm <- trimws(nm)
  comma <- grepl(",", nm, fixed = TRUE)
  sur <- ifelse(comma, sub(",.*$", "", nm), sub("^.*\\s", "", nm))
  giv <- ifelse(comma, trimws(sub("^[^,]*,", "", nm)),
                ifelse(grepl("\\s", nm), sub("\\s+\\S+$", "", nm), ""))
  paste0(toupper(gsub("[^A-Za-z]", "", sur)), "_", toupper(substr(giv, 1, 1)))
}
C <- fread("output/candidacies.csv", select = c("election", "region", "year", "seat", "name", "elected"))
C[, pkey := person_key(name)]
el <- unique(C[, .(election, region, year)])[order(region, year)]
el[, prev := shift(election), by = region]
prev_of <- setNames(el$prev, el$election)

F[, pkey := person_key(candidate)]
F[, prev_el := unname(prev_of[election])]
P <- C[, .(prev_el = election, seat, pkey, prev_elected = elected)]
F <- P[F, on = .(prev_el, seat, pkey), mult = "first"]
F[, status := ifelse(is.na(prev_elected), "new", ifelse(prev_elected %in% TRUE, "sitting", "returning"))]
F[, juris := ifelse(region == "fed", "fed", "state")]
cat(sprintf("cells scored: %d; status: %s\n", nrow(F),
            paste(names(table(F$status)), table(F$status), sep = " ", collapse = ", ")))

clus <- function(d) {
  # mean signed error with an election-clustered SE
  m <- mean(d$err); E <- tapply(d$err - m, d$election, sum); k <- length(E)
  se <- if (k > 1) sqrt(k / (k - 1) * sum(E^2)) / nrow(d) else NA_real_
  list(n = nrow(d), elections = k, bias = m, se = se, rmse = sqrt(mean(d$err^2)),
       sq_err_share = sum(d$err^2))
}
tot_sq <- sum(F$err^2)
A <- F[, clus(.SD), by = .(party, status, juris)]
A[, `:=`(t = bias / se, share_of_sq_err = sq_err_share / tot_sq)]
A <- A[order(-abs(t))]
fwrite(A, "output/share-bias-audit.csv")
cat("\nSigned bias by segment (points; positive = over-called), segments with n >= 20, ranked by |bias / SE|:\n")
print(A[n >= 20, .(party, status, juris, n, elections, bias = round(bias, 2), se = round(se, 2),
                   t = round(t, 1), rmse = round(rmse, 2), pct_sq_err = round(100 * share_of_sq_err, 1))], nrows = 40)
