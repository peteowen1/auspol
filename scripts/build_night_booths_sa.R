# NIGHT-SCHEMA BOOTH TABLES FOR sa (issue #160 follow-on, replay of other elections).
#
#   Rscript scripts/build_night_booths_sa.R
#
# Converts output/booths/<pair>-booth-fp.csv (and -booth-tcp.csv where it exists) into the schema the night model reads:
#   output/booths-<pair>.csv      district, booth, booth_type, candidate, party, votes
#   output/booths-<pair>-2cp.csv  district, booth, vote_type, candidate, party_raw, votes   (night_tcp_obs() columns)
# booth_type from vote_type (the mapping is printed): ordinary, early (pre-poll and, in NSW, iVote), postal,
# absent, provisional (every other declaration vote).
# party is NOT the raw code: classify_party() on a bare code such as "LIB", "LNP" or "ONP" files it OTH, so the party
# column holds the candidate's CLASS from output/candidacies.csv written as a name classify_party() recognises
# (the candidacy's own full party name where that already classifies to the same class). Candidates not in candidacies
# fall back to classify_party(raw, code = raw) and are counted in the log.
suppressMessages(library(data.table))
source("R/parties.R")
REGION <- "sa"
PAIRS <- c('sa2022','sa2026')
canon <- c(ALP = "Australian Labor Party", LNP = "Liberal National Party", GRN = "The Greens", ONP = "One Nation",
           IND = "Independent", OTH = "Other", OTH_RIGHT = "Family First")
stopifnot(identical(unname(classify_party(canon)), names(canon)))
map_type <- function(vt) {
  v <- tolower(trimws(vt))
  out <- rep("provisional", length(v))
  out[grepl("absent", v)] <- "absent"
  out[v %in% c("prepoll", "early", "ivote")] <- "early"
  out[grepl("^postal", v)] <- "postal"
  out[v == "ordinary"] <- "ordinary"
  out
}
cand <- fread("output/candidacies.csv", showProgress = FALSE)
pub <- unique(fread("output/published-predictions.csv", select = c("pair", "seat"), showProgress = FALSE))
conv <- function(path, pair, fp = TRUE) {
  d <- fread(path, showProgress = FALSE)
  cat(sprintf("\n== %s %s: %d rows, %d votes, %d districts\n", pair, basename(path), nrow(d), sum(d$votes, na.rm = TRUE), uniqueN(d$district)))
  d[, booth_type := map_type(vote_type)]
  m <- unique(d[, .(vote_type, booth_type)])[order(booth_type, vote_type)]
  cat("vote_type -> booth_type:\n"); print(m, nrows = 100)
  cc <- cand[cand$election == pair, .(district = seat, candidate = name, cls = party)]
  cc <- unique(cc, by = c("district", "candidate"))
  d <- merge(d, cc, by = c("district", "candidate"), all.x = TRUE, sort = FALSE)
  fb <- is.na(d$cls)
  rawp <- ifelse(is.na(d$party_raw), "", d$party_raw)
  d$cls[fb] <- classify_party(rawp[fb], code = rawp[fb])
  d$cls[fb & toupper(rawp) == "LAB"] <- "ALP"
  cat(sprintf("class from candidacies: %d rows; fallback by code: %d rows (%d votes)\n", sum(!fb), sum(fb), sum(d$votes[fb], na.rm = TRUE)))
  if (any(fb)) print(head(d[fb, .(n = .N, v = sum(votes)), by = .(party_raw, cls)][order(-v)], 10))
  full <- ifelse(classify_party(rawp) == d$cls & nzchar(rawp) & nchar(rawp) > 6, rawp, unname(canon[d$cls]))
  d[, party := full]
  stopifnot(all(classify_party(d$party) == d$cls))
  d
}
for (pr in PAIRS) {
  d <- conv(sprintf("output/booths/%s-booth-fp.csv", pr), pr)
  out <- d[, .(district, booth, booth_type, candidate, party, votes)]
  fwrite(out, sprintf("output/booths-%s.csv", pr))
  # district names and totals
  seats <- pub$seat[pub$pair == pr]
  cand_tot <- cand[cand$election == pr, .(ct = sum(votes, na.rm = TRUE)), by = .(district = seat)]
  bt <- d[, .(bt = sum(votes, na.rm = TRUE)), by = district]
  chk <- merge(bt, cand_tot, by = "district", all = TRUE)
  cat(sprintf("%s: %d booth districts, %d candidacy districts, %d published seats\n", pr, nrow(bt), nrow(cand_tot), length(seats)))
  cat("districts missing from booths (in published/candidacies):", paste(setdiff(union(seats, cand_tot$district), bt$district), collapse = ", "), "\n")
  cat("booth districts not in published seats:", paste(setdiff(bt$district, seats), collapse = ", "), "\n")
  chk[, diff := bt - ct]
  cat(sprintf("booth sum vs candidacy total: %d districts differ, max abs diff %s, total booth %d vs candidacy %d\n",
              sum(chk$diff != 0, na.rm = TRUE), format(max(abs(chk$diff), na.rm = TRUE)), sum(chk$bt, na.rm = TRUE), sum(chk$ct, na.rm = TRUE)))
  if (any(chk$diff != 0, na.rm = TRUE)) print(head(chk[diff != 0][order(-abs(diff))], 10))
  cat("votes by booth_type:\n"); print(out[, .(votes = sum(votes, na.rm = TRUE)), by = booth_type])
  tf <- sprintf("output/booths/%s-booth-tcp.csv", pr)
  if (file.exists(tf)) {
    t2 <- conv(tf, pr)
    o2 <- t2[, .(district, booth, vote_type = booth_type, candidate, party_raw = party, votes)]
    fwrite(o2, sprintf("output/booths-%s-2cp.csv", pr))
    cat(sprintf("2CP: %d rows, %d districts, %d votes\n", nrow(o2), uniqueN(o2$district), sum(o2$votes, na.rm = TRUE)))
  }
}
for (pr in PAIRS) {   # the replay reads the previous election's table too
  cat(pr, "written:", file.exists(sprintf("output/booths-%s.csv", pr)), "\n")
}
