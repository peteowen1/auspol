# Departed-independent successor cells: the population for the successor flag.
#
# One row per (election, seat) where the previous election's leading IND
# candidate polled >= MIN_PRIOR and did not stand in this seat again, while at
# least one IND candidate did. These are the cells screened_slopes() decays at
# departed_rate (0.38), whose real retention runs 0.08 to 0.59
# (docs/reviews/departed-hold-sweep-2026-10-05.md). The successor flag
# (external/reference/successors/departed-ind-successors.csv, hand-coded with a
# source per row) is joined to this list.
#
# Matching is on seat NAME within a region's consecutive elections, so a seat
# renamed by redistribution drops out; the count is printed. "Did not stand
# again" keys on the person (surname + first initial), never the party class.
#
# Writes output/departed-ind-successors.csv.

suppressPackageStartupMessages(library(data.table))

MIN_PRIOR <- 10

cand <- fread("output/candidacies.csv", select = c("election", "region", "year", "seat",
                                                   "name", "party", "pcv", "elected"))
cat(sprintf("candidacies: %d rows, %d elections, years %d-%d\n",
            nrow(cand), uniqueN(cand$election), min(cand$year), max(cand$year)))

# "SURNAME, Given" and "Given Surname" both occur; key on surname + first initial.
person_key <- function(nm) {
  nm <- trimws(nm)
  comma <- grepl(",", nm, fixed = TRUE)
  sur <- ifelse(comma, sub(",.*$", "", nm), sub("^.*\\s", "", nm))
  giv <- ifelse(comma, trimws(sub("^[^,]*,", "", nm)),
                ifelse(grepl("\\s", nm), sub("\\s+\\S+$", "", nm), ""))  # surname-only (WA): no initial
  paste0(toupper(gsub("[^A-Za-z]", "", sur)), "_", toupper(substr(giv, 1, 1)))
}
cand[, pkey := person_key(name)]

# Previous election in the same region (federal is one region).
el <- unique(cand[, .(election, region, year)])[order(region, year)]
el[, prev_election := shift(election), by = region]
el <- el[!is.na(prev_election)]

rows <- list()
for (k in seq_len(nrow(el))) {
  cur_el <- el$election[k]; prv_el <- el$prev_election[k]
  cur <- cand[cand$election == cur_el]
  prv <- cand[cand$election == prv_el]
  lead <- prv[prv$party == "IND"][order(-pcv)][, .SD[1], by = seat]
  lead <- lead[lead$pcv >= MIN_PRIOR]
  if (!nrow(lead)) next
  prior_ind <- prv[prv$party == "IND", .(prior_ind_total = sum(pcv)), by = seat]
  for (j in seq_len(nrow(lead))) {
    s <- lead$seat[j]
    here <- cur[cur$seat == s]
    if (!nrow(here)) next                      # seat absent now (renamed / abolished)
    if (lead$pkey[j] %in% here$pkey) next      # leader stood again, any label
    succ <- here[here$party == "IND"][order(-pcv)]
    if (!nrow(succ)) next                      # no IND successor: nothing to flag
    rows[[length(rows) + 1]] <- data.table(
      election = cur_el, prev_election = prv_el, seat = s,
      departed = lead$name[j], departed_pcv = lead$pcv[j],
      departed_elected = lead$elected[j],
      prior_ind_total = prior_ind$prior_ind_total[prior_ind$seat == s],
      successor = succ$name[1], successor_pcv = succ$pcv[1],
      n_ind_now = nrow(succ), ind_total_now = sum(succ$pcv))
  }
}
out <- rbindlist(rows)
out[, retention := ind_total_now / prior_ind_total]
# The live election (vic2026) has candidates but no votes: kept, because the
# published forecast needs its flags too, but left out of the summary below.
out[, scored := !is.na(retention)]
cat(sprintf("cells with no result yet (live): %d, %s\n", sum(!out$scored),
            paste(unique(out$election[!out$scored]), collapse = ",")))

# Leader rows in seats absent at the next election: how many dropped out unmatched.
n_lead_all <- sum(vapply(seq_len(nrow(el)), function(k) {
  p <- cand[cand$election == el$prev_election[k] & cand$party == "IND"]
  p <- p[order(-pcv)][, .SD[1], by = seat]
  nrow(p[p$pcv >= MIN_PRIOR & !p$seat %in% cand$seat[cand$election == el$election[k]]])
}, integer(1)))

stopifnot(nrow(out) > 0, !anyDuplicated(out[, .(election, seat)]))
cat(sprintf("successor cells: %d across %d elections; prior-leader seats lost to renaming: %d\n",
            nrow(out), uniqueN(out$election), n_lead_all))
r <- out$retention[out$scored]
cat(sprintf("retention on %d scored cells (IND total now / IND total before): median %.2f, quartiles %.2f-%.2f, range %.2f-%.2f\n",
            length(r), median(r), quantile(r, 0.25), quantile(r, 0.75), min(r), max(r)))
fwrite(out[order(election, seat)], "output/departed-ind-successors.csv")
print(out[order(-retention), .(election, seat, departed, departed_pcv = round(departed_pcv, 1),
                              successor, successor_pcv = round(successor_pcv, 1),
                              retention = round(retention, 2))], nrows = 200)
