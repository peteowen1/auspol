# Night-schema booth tables for WA (wa2021, wa2025) from output/booths/wa<year>-booth-fp.csv.
# booth_type mapping from vote_type: "ordinary" -> ordinary; "count centre: Absent Votes" -> absent;
# "count centre: Early Votes (In Person)" -> early; "count centre: Early Votes (by Post)" and
# "count centre: Postal Votes" -> postal; "count centre: Provisional Votes" -> provisional.
# PARTY: WA publishes party CODES only (ALP, LIB, PHON ...). The night code classifies by NAME alone
# (classify_party(party)), which sends every code except "Libertarian" to OTH (first replay: Labor 11 seats).
# So `party` holds a canonical name for the class that classify_party(code, code=code) gives the code, the same
# classification the harness uses; classes ALP/LNP/GRN/ONP/IND/OTH_RIGHT get a name, OTH keeps its raw code.
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
nm <- c(ALP = "Australian Labor Party", LNP = "Liberal Party of Australia", GRN = "Australian Greens",
        ONP = "Pauline Hanson's One Nation", IND = "Independent", OTH_RIGHT = "Shooters Fishers and Farmers Party")
mp <- c("ordinary" = "ordinary", "count centre: Absent Votes" = "absent",
        "count centre: Early Votes (In Person)" = "early", "count centre: Early Votes (by Post)" = "postal",
        "count centre: Postal Votes" = "postal", "count centre: Provisional Votes" = "provisional")
for (y in c(2021, 2025)) {
  d <- fread(sprintf("output/booths/wa%d-booth-fp.csv", y))
  bt <- unname(mp[d$vote_type])
  if (anyNA(bt)) stop("unmapped vote_type: ", paste(unique(d$vote_type[is.na(bt)]), collapse = "|"))
  o <- d[, .(district, booth, booth_type = bt, candidate, party = party_raw, votes)]
  o[is.na(party), party := ""]
  cls <- classify_party(o$party, code = o$party)
  o[, party := ifelse(cls %in% names(nm), nm[cls], party)]
  stopifnot(identical(classify_party(o$party), cls))   # name-only classification must reproduce the code-based one
  fwrite(o, sprintf("output/booths-wa%d.csv", y))
  cat(sprintf("wa%d: %d rows, %d districts, %d votes\n", y, nrow(o), uniqueN(o$district), sum(o$votes)))
  print(o[, .(votes = sum(votes)), booth_type])
}
