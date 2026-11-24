# Early-vote panel: votes by vote type (early / postal / other) for every
# seat-election where a commission publishes the split, by party class.
#
# Run:  Rscript scripts/early_vote_panel.R
# Out:  output/early-vote/panel-seat.csv   one row per election x seat
#       output/early-vote/panel-party.csv  one row per election x seat x party x type
#
# LEAKAGE NOTE. Everything here is a RESULT (counted votes). Only the COUNTS
# by type (how many people voted early or by post in a seat) have a
# pre-election analogue: commissions publish early votes issued and postal
# applications daily. The PARTY split of early votes is never knowable before
# the count, so screen_early_vote.R only uses a party split from the PREVIOUS
# election. The denominator is formal votes (an outcome); the pre-election
# analogue is enrolment. Turnout is ~90% with little seat-to-seat spread.
suppressPackageStartupMessages(library(data.table))

type3 <- function(vt) {
  v <- tolower(vt)
  out <- rep("other", length(v))
  out[grepl("early|prepoll|pre-poll", v)] <- "early"
  # postal wins over "early votes (by post)"
  out[grepl("postal|by post", v)] <- "postal"
  out[v == "ordinary"] <- "ordinary"
  out
}

# elections whose booth file does not separate early votes from the rest
NO_SPLIT <- c("sa2018", "sa2022", "wa2025", "nsw2011", "qld2015", "qld2017")

cand <- fread("output/candidacies.csv", encoding = "UTF-8")
cat(sprintf("EVP1 candidacies: %d rows, %d elections\n", nrow(cand), uniqueN(cand$election)))

# ---- federal: declaration types are columns on the candidate file, but
# votes at pre-poll centres (PPVCs) are counted as ORDINARY there since 2010,
# so the in-person early vote comes from the polling-place files.
fed <- cand[election %in% paste0("fed", c(2010, 2013, 2016, 2019, 2022, 2025))]
pp <- rbindlist(lapply(c(2010, 2013, 2016, 2019, 2022, 2025), function(y) {
  fs <- list.files("external/reference/aec/booths", full.names = TRUE,
                   pattern = sprintf("^pp-fed%d-[A-Z]+[.]csv$", y))
  stopifnot(length(fs) == 8)
  x <- rbindlist(lapply(fs, fread, skip = 1, encoding = "UTF-8"), fill = TRUE)
  is_ppvc <- grepl("PPVC|PRE[-_ ]?POLL", x$PollingPlace, ignore.case = TRUE)
  out <- x[is_ppvc & toupper(Surname) != "INFORMAL", .(ppvc = sum(OrdinaryVotes)),
           by = .(seat = DivisionNm, surname = toupper(Surname), given = toupper(GivenNm))]
  out[, election := paste0("fed", y)]
  out
}))
fed[, `:=`(surname_u = toupper(surname), given_u = toupper(given))]
n_pp <- sum(pp$ppvc)
fed <- merge(fed, pp, by.x = c("election", "seat", "surname_u", "given_u"),
             by.y = c("election", "seat", "surname", "given"), all.x = TRUE)
cat(sprintf("EVP1b federal pre-poll-centre votes matched to a candidate: %d of %d (%.1f%%)
",
            sum(fed$ppvc, na.rm = TRUE), n_pp, 100 * sum(fed$ppvc, na.rm = TRUE) / n_pp))
stopifnot(sum(fed$ppvc, na.rm = TRUE) / n_pp > 0.99)
fed[is.na(ppvc), ppvc := 0]
fed[, `:=`(early_n = ppvc + prepoll, ord_n = ordinary - ppvc, oth_n = absent + provisional)]
fed_long <- melt(fed, id.vars = c("election", "seat", "name", "party"),
                 measure.vars = c("early_n", "ord_n", "oth_n", "postal"),
                 variable.name = "vt", value.name = "n")
fed_long[, type := c(early_n = "early", ord_n = "ordinary", oth_n = "other", postal = "postal")[as.character(vt)]]
fed_pt <- fed_long[, .(votes = sum(n, na.rm = TRUE)), by = .(election, seat, party, type)]

# ---- states: vote types are rows in the booth files ------------------------
files <- list.files("output/booths", pattern = "-booth-fp\\.csv$", full.names = TRUE)
files <- files[!grepl("^fed", basename(files))]
st <- rbindlist(lapply(files, function(f) {
  b <- fread(f, encoding = "UTF-8", colClasses = list(character = c("district", "booth", "vote_type", "candidate", "party_raw")))
  b[, .(votes = sum(votes, na.rm = TRUE)), by = .(election, seat = district, name = candidate, vote_type)]
}))
st <- st[!(election %in% NO_SPLIT)]
st[, type := type3(vote_type)]
key_c <- cand[!grepl("^fed", election), .(election, seat, name, party)]
key_c <- unique(key_c, by = c("election", "seat", "name"))
st <- merge(st, key_c, by = c("election", "seat", "name"), all.x = TRUE)
cov <- st[, .(votes = sum(votes), matched = sum(votes[!is.na(party)])), by = election]
cov[, pct := round(100 * matched / votes, 1)]
cat("EVP2 share of booth votes matched to a party class, by election (100 is complete):\n")
print(cov[order(election)])
bad <- cov[pct < 97]
if (nrow(bad)) cat("EVP2! elections under 97% matched, DROPPED:", paste(bad$election, collapse = " "), "\n")
st <- st[!(election %in% bad$election)]
# unmatched candidates still count toward a seat's vote-type totals
st[is.na(party), party := "UNMATCHED"]
st_pt <- st[, .(votes = sum(votes)), by = .(election, seat, party, type)]

pt <- rbind(fed_pt, st_pt)
pt <- pt[votes > 0]
seat <- dcast(pt[, .(votes = sum(votes)), by = .(election, seat, type)],
              election + seat ~ type, value.var = "votes", fill = 0)
seat[, tot := early + postal + ordinary + other]
# A seat published only as one "all votes" total (vic2014, vic2018 Ripon) has no
# split: zero early AND zero postal is "not reported", never "nobody voted early".
no_split <- seat[early + postal == 0]
if (nrow(no_split)) cat("EVP3! no vote-type split, DROPPED:", paste(no_split$election, no_split$seat, collapse = "; "), "\n")
seat <- seat[early + postal > 0]
pt <- pt[!no_split, on = c("election", "seat")]
stopifnot(all(seat$early > 0))
seat[, `:=`(early_sh = early / tot, postal_sh = postal / tot)]
seat[, juris := sub("[0-9]+$", "", election)]
seat[, year := as.integer(sub("^[a-z]+", "", election))]

cat("EVP3 panel coverage. early_sh / postal_sh = share of formal votes cast early in person / by post:\n")
print(seat[, .(seats = .N, votes = sum(tot), early_sh = round(sum(early) / sum(tot), 3),
               postal_sh = round(sum(postal) / sum(tot), 3),
               zero_early = sum(early == 0)), by = election][order(election)])
stopifnot(nrow(seat) > 1500)

dir.create("output/early-vote", showWarnings = FALSE)
fwrite(seat, "output/early-vote/panel-seat.csv")
fwrite(pt, "output/early-vote/panel-party.csv")
cat(sprintf("EVP4 wrote %d seat-elections (%d elections), %d party-type rows\n",
            nrow(seat), uniqueN(seat$election), nrow(pt)))
