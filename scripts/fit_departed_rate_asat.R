# Time-forward departed-leader retention rate (the 0.38 in screened_slopes()).
#
# The shipped `departed_rate = c(IND = 0.38)` was measured once, on every
# election in the corpus (docs/reviews/departed-leader-retention-2026-09-15.md,
# n = 305), with no committed fitting script. Every backtest that uses it
# therefore trains on elections AFTER the one it predicts. This refits the SAME
# quantity, by the SAME definition, using only elections whose polling day is
# strictly before each target's.
#
# Population (as the review): every (seat, class) where a non-major class polled
# >= 15% at the previous election of that jurisdiction AND that class's leader
# there was elected (a sitting member) AND did not stand in the seat again
# (keyed on the person, any label). Retention = sum(class % now) / sum(class %
# before), the ratio of means. "now" is 0 if the class has no candidate.
#
# Anchor check, printed first: over ALL cells this must reproduce the review's
# 0.38 on n ~ 305, or the population is not the one the constant came from.
#
# Writes output/departed-rate-by-target.csv: target, n_hist, k_hist (elections),
# rate, se (clustered on election), fallback.

suppressPackageStartupMessages({library(data.table); devtools::load_all(quiet = TRUE)})

MIN_PRIOR <- 15
MAJORS <- c("ALP", "LNP")
FALLBACK <- 0.38   # the shipped value; used only where a target has no earlier cell

cand <- fread("output/candidacies.csv",
              select = c("election", "region", "year", "seat", "name", "party", "pcv", "elected"))
cat(sprintf("candidacies: %d rows, %d elections, years %d-%d\n",
            nrow(cand), uniqueN(cand$election), min(cand$year), max(cand$year)))

person_key <- function(nm) {
  nm <- trimws(nm)
  comma <- grepl(",", nm, fixed = TRUE)
  sur <- ifelse(comma, sub(",.*$", "", nm), sub("^.*\\s", "", nm))
  giv <- ifelse(comma, trimws(sub("^[^,]*,", "", nm)),
                ifelse(grepl("\\s", nm), sub("\\s+\\S+$", "", nm), ""))
  paste0(toupper(gsub("[^A-Za-z]", "", sur)), "_", toupper(substr(giv, 1, 1)))
}
cand[, pkey := person_key(name)]
cand <- cand[!is.na(cand$pcv)]   # the live election has no votes

el <- unique(cand[, .(election, region, year)])[order(region, year)]
el[, prev_election := shift(election), by = region]
el <- el[!is.na(prev_election)]

rows <- list()
for (k in seq_len(nrow(el))) {
  cur <- cand[cand$election == el$election[k]]
  prv <- cand[cand$election == el$prev_election[k]]
  nm <- prv[!prv$party %in% MAJORS]
  if (!nrow(nm)) next
  tot <- nm[, .(prev_share = sum(pcv)), by = .(seat, party)]
  lead <- nm[order(-pcv)][, .SD[1], by = .(seat, party)][, .(seat, party, lead_key = pkey, lead_elected = elected)]
  cells <- lead[tot, on = .(seat, party)]
  cells <- cells[cells$prev_share >= MIN_PRIOR & cells$lead_elected %in% TRUE]
  cells <- cells[cells$seat %in% cur$seat]                       # seat still exists (renames drop)
  stood <- vapply(seq_len(nrow(cells)), function(i)
    cells$lead_key[i] %in% cur$pkey[cur$seat == cells$seat[i]], logical(1))
  cells <- cells[!stood]
  if (!nrow(cells)) next
  now <- cur[, .(now_share = sum(pcv)), by = .(seat, party)]
  cells <- now[cells, on = .(seat, party)]
  cells[is.na(now_share), now_share := 0]
  cells[, `:=`(election = el$election[k], prev_election = el$prev_election[k])]
  rows[[length(rows) + 1]] <- cells
}
D <- rbindlist(rows)
D[, election_date := as.Date(unname(election_dates(election)))]
stopifnot(nrow(D) > 0, !anyNA(D$election_date))

ratio_fit <- function(d) {
  if (!nrow(d)) return(list(rate = NA_real_, se = NA_real_, n = 0L, k = 0L))
  r <- sum(d$now_share) / sum(d$prev_share)
  e <- d$now_share - r * d$prev_share
  E <- tapply(e, d$election, sum); k <- length(E)
  se <- if (k > 1) sqrt(k / (k - 1) * sum(E^2)) / sum(d$prev_share) else NA_real_
  list(rate = r, se = se, n = nrow(d), k = k)
}

# ---- Anchor check: the whole corpus must reproduce the constant ----
a <- ratio_fit(D)
cat(sprintf("\nANCHOR  all cells: n = %d over %d elections, prev %.1f -> now %.1f, retention %.3f (SE %.3f). Review: n = 305, 0.38.\n",
            a$n, a$k, mean(D$prev_share), mean(D$now_share), a$rate, a$se))
print(D[, .N, by = party][order(-N)])

# ---- Time-forward, one row per target election ----
targets <- names(election_dates())
out <- rbindlist(lapply(targets, function(T) {
  tday <- as.Date(unname(election_dates(T)))
  f <- ratio_fit(D[D$election_date < tday])
  data.table(target = T, n_hist = f$n, k_hist = f$k,
             rate = if (f$n) f$rate else FALLBACK, se = f$se, fallback = f$n == 0)
}))
fwrite(out, "output/departed-rate-by-target.csv")
cat(sprintf("\nwrote output/departed-rate-by-target.csv: %d targets, %d fall back to %.2f\n",
            nrow(out), sum(out$fallback), FALLBACK))
print(out[, .(target, n_hist, k_hist, rate = round(rate, 3), se = round(se, 3), fallback)], nrows = 100)
