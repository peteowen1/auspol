# Outcome-blind input for hand-coding the departed-independent successor flag.
#
# LEAKAGE GUARD: the coder (a person or an agent with web search) must not see
# what happened. So this file carries no votes, no elected flag, no retention,
# and is NOT ordered by votes: picking "the successor" as the top-polling
# independent would itself be the outcome. Every IND candidate in the cell is
# listed and coded, alphabetically.
#
# `prior_mp_in_our_data` is mechanical, from our own corpus: elected at an
# EARLIER election, any seat. Those are sitting or former MPs (Cregan Kavel
# 2022, Duluk Waite 2022) whose vote is the defector machinery's question, not
# succession, so the coder does not need to judge them.
#
# Reads output/departed-ind-successors.csv (scripts/build_departed_successors.R).
# Writes external/reference/successors/coding-input.csv.

suppressPackageStartupMessages({library(data.table); devtools::load_all(quiet = TRUE)})

cells <- fread("output/departed-ind-successors.csv")
cand <- fread("output/candidacies.csv",
              select = c("election", "region", "year", "seat", "name", "party", "elected"))

person_key <- function(nm) {
  nm <- trimws(nm)
  comma <- grepl(",", nm, fixed = TRUE)
  sur <- ifelse(comma, sub(",.*$", "", nm), sub("^.*\\s", "", nm))
  giv <- ifelse(comma, trimws(sub("^[^,]*,", "", nm)),
                ifelse(grepl("\\s", nm), sub("\\s+\\S+$", "", nm), ""))  # surname-only (WA): no initial
  paste0(toupper(gsub("[^A-Za-z]", "", sur)), "_", toupper(substr(giv, 1, 1)))
}
cand[, pkey := person_key(name)]

ind <- cand[cand$party == "IND"][cells[, .(election, seat, departed)],
                                 on = .(election, seat), nomatch = 0]
# Same jurisdiction only (Sandy Bolton, Noosa Qld, is not Sue Bolton, Pascoe
# Vale Vic), and the same seat when the corpus has no given name (WA rows are
# surname only: "BROWN" Bassendean is not "BROWN" Stirling). Still a hint, not
# a fact: the coder verifies every TRUE with a source.
won <- cand[cand$elected %in% TRUE, .(won_key = pkey, won_year = year, won_region = region, won_seat = seat)]
ind[, prior_mp := vapply(seq_len(.N), function(i) {
  hit <- won$won_key == ind$pkey[i] & won$won_year < ind$year[i] & won$won_region == ind$region[i]
  if (grepl("_$", ind$pkey[i])) hit <- hit & won$won_seat == ind$seat[i]
  any(hit)
}, logical(1))]
ind[, election_date := as.Date(unname(election_dates(election)))]

out <- ind[order(election, seat, name),
           .(election, election_date, seat, departed_member = departed,
             candidate = name, prior_mp_in_our_data = prior_mp)]
stopifnot(uniqueN(out[, .(election, seat)]) == nrow(cells), !anyNA(out$election_date))
fwrite(out, "external/reference/successors/coding-input.csv")
cat(sprintf("%d candidate rows over %d cells; %d prior MP (mechanical)\n",
            nrow(out), uniqueN(out[, .(election, seat)]), sum(out$prior_mp_in_our_data)))
print(out[out$prior_mp_in_our_data == TRUE, .(election, seat, candidate)])
