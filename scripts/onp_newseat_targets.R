# Target seats for docs/plans/prereg-onp-newseat-rule-2026-10-25.md, fixed BY RULE before any run:
# a seat where One Nation stood at the target election (output/candidacies.csv, pcv > 0) and had NO
# candidate at the previous election of the same jurisdiction (matched on the normalised seat name).
# Also prints, per election, whether the House and Senate ordering keys and the time-forward spread
# exist for those seats (R/onp_newseat.R), i.e. where each arm can apply at all.
#
# name_at_prev = FALSE flags a seat whose name did not exist at the previous election (a
# redistribution). The harness's own "no history" flag is One Nation's share in its previous-election
# matrix, which for a renamed seat is the notional result, so a FALSE row can differ between the two.
#
# Run: powershell.exe -Command 'Rscript scripts/onp_newseat_targets.R [data_root] [house_csv] [out_dir]'
#   data_root: a checkout with output/ and external/ (default "."); house_csv: the table
#   scripts/build_onp_house.R writes (default <data_root>/output/house-onp-by-district.csv);
#   out_dir: where onp-newseat-targets.csv and onp-newseat-target-seats.csv go (default docs/plans).
args <- commandArgs(trailingOnly = TRUE)
ROOT <- if (length(args) >= 1) args[1] else "."
HOUSE <- if (length(args) >= 2) args[2] else file.path(ROOT, "output", "house-onp-by-district.csv")
OUTD <- if (length(args) >= 3) args[3] else file.path("docs", "plans")
suppressMessages(devtools::load_all(quiet = TRUE))
options(auspol.root = normalizePath(ROOT))
suppressMessages(library(data.table))
house <- if (file.exists(HOUSE)) fread(HOUSE) else NULL
if (is.null(house)) cat("CT0! no House table -- House coverage reported as missing\n")
cand <- fread(out_path("candidacies.csv"), showProgress = FALSE)
cat(sprintf("CT0 candidacies: %d rows, %d elections\n", nrow(cand), uniqueN(cand$election)))
prs <- all_election_pairs()
prs <- c(prs, list(list(election = "wa2001", prev = "wa1996"), list(election = "qld2017", prev = "qld2015")))
prs <- prs[!duplicated(vapply(prs, `[[`, "", "election"))]
rows <- list(); seat_rows <- list()
for (pr in prs) {
  el <- pr$election; pv <- pr$prev
  ke <- cand$election == el & cand$party == "ONP" & cand$pcv > 0
  if (!any(ke)) next
  now <- unique(cand$seat[ke])
  kp <- cand$election == pv
  prev_seats <- unique(cand$seat[kp])
  kpo <- kp & cand$party == "ONP" & cand$pcv > 0
  prev_onp <- normalise_seat(unique(cand$seat[kpo]))
  nk <- normalise_seat(now)
  tgt <- now[!nk %in% prev_onp]
  new_name <- sum(!normalise_seat(tgt) %in% normalise_seat(prev_seats))
  act <- cand[ke, .(actual = sum(pcv)), by = .(seat)]
  hs <- function(order) {
    if (order == "federal" && is.null(house) && !identical(sub("[0-9]{4}$", "", el), "fed"))
      return(list(cov = NA_real_, src = "none: no House table given"))
    k <- tryCatch(onp_federal_key(tgt, el, order = order, house = if (order == "federal") house else NULL),
                  error = function(e) structure(list(), why = conditionMessage(e)))
    if (is.list(k)) return(list(cov = NA_real_, src = paste0("none: ", attr(k, "why"))))
    list(cov = mean(!is.na(k)), src = attr(k, "source"))
  }
  H <- hs("federal"); S <- hs("senate_rank")
  lvl <- mean(act$actual[match(tgt, act$seat)])
  cv <- onp_newseat_cv(el, lvl)
  rows[[length(rows) + 1]] <- data.table(election = el, prev = pv, onp_seats = length(now), prev_onp_seats = length(prev_onp),
    target_seats = length(tgt), target_new_name = new_name, target_mean_actual = round(lvl, 2),
    house_cov = round(H$cov, 2), house_src = H$src, senate_cov = round(S$cov, 2), senate_src = S$src,
    cv = if (is.null(cv)) NA_real_ else round(cv$cv, 3), cv_n = if (is.null(cv)) 0L else cv$n,
    cv_k = if (is.null(cv)) NA_real_ else round(cv$k, 3))
  tt <- sort(tgt)
  seat_rows[[el]] <- data.table(election = el, prev = pv, seat = tt,
                                onp_actual = round(act$actual[match(tt, act$seat)], 4),
                                name_at_prev = normalise_seat(tt) %in% normalise_seat(prev_seats))
}
R <- rbindlist(rows)
stopifnot(nrow(R) > 0, all(R$target_seats >= 0))
print(R[, .(election, prev, onp_seats, prev_onp_seats, target_seats, target_new_name, target_mean_actual, house_cov, senate_cov, cv, cv_n, cv_k)])
fwrite(R, file.path(OUTD, "onp-newseat-targets-2026-10-25.csv"))
fwrite(rbindlist(seat_rows), file.path(OUTD, "onp-newseat-target-seats-2026-10-25.csv"))
cat(sprintf("CT1 total target seats %d over %d elections\n", sum(R$target_seats), sum(R$target_seats > 0)))
