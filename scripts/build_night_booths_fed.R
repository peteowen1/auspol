# FEDERAL BOOTH TABLES IN THE NIGHT SCHEMA, for the election-night replay (scripts/night_replay_json.R).
#
#   Rscript scripts/build_night_booths_fed.R
#
# Writes, for fed2019, fed2022 and fed2025:
#   output/booths-fed<year>.csv            district, booth, booth_type, candidate, party, votes
#   output/booths/fed<year>-booth-tcp.csv  election, district, booth, vote_type, candidate, party_raw, votes  (2022, 2025)
#
# Sources, all AEC final results already on disk (no fetch here):
#   external/reference/aec/booths/pp-fed<year>-<STATE>.csv   first preferences by candidate by polling place (ordinary votes)
#   external/reference/aec/fed<year>-firstprefs.csv          first preferences by candidate by vote type (declaration votes)
#   external/reference/aec/booths/raw-tcp/HouseTcpByCandidateByPollingPlaceDownload-<event>.csv  two-candidate by polling place
#   external/reference/aec/fed<year>-tcp.csv                 two-candidate by vote type (declaration votes)
#
# Choices:
# - Every polling place, PRE-POLL VOTING CENTRES INCLUDED, is an "ordinary" unit keyed by its own name. PPVC votes are
#   ordinary votes (the AEC counts them as such, on the night), and a PPVC usually keeps its name between elections, so
#   keyed by name each one gets a like-for-like swing against the same centre last time, and a division's early vote
#   arrives as several centres through the evening rather than one lump. The replay's report order (small booths first,
#   by log size) already puts the big PPVCs late, as on the real night.
# - Declaration votes are one unit per division and type: PrePollVotes (pre-poll DECLARATION votes, not PPVC) -> "early",
#   PostalVotes -> "postal", AbsentVotes -> "absent", ProvisionalVotes -> "provisional".
# - party is the AEC's PartyNm. Informal rows are dropped. A candidate with a blank PartyNm (code NAFD, no ballot-paper
#   affiliation) is written "Non Affiliated": a blank name would classify IND, and the harness's results file
#   (external/elections/aec-fed-firstprefs.csv, scripts/fetch_preferences_fed.R) drops those candidates altogether, so
#   they were never part of any seat's IND forecast. They classify OTH here. Count printed (NBF3).
# Check codes: NBF1 (inputs), NBF2 (division totals), NBF3 (party classes), NBF4 (written).
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
A <- "external/reference/aec"
STATES <- c("ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA")
EV <- c(`2019` = 24310L, `2022` = 27966L, `2025` = 31496L)
read_aec <- function(f) fread(f, skip = 1L, showProgress = FALSE, encoding = "UTF-8")
# The night update classifies by NAME only (classify_party(party)); the results file used name + code. Where the two
# disagree (fed2022 "A.L.P.", fed2025 Queensland's bare "LNP") the name is prefixed with one that classifies as the code
# does, keeping the AEC's own name in brackets, so the night and the forecast agree on every candidate's class.
CANON <- c(ALP = "Australian Labor Party", LNP = "Liberal National Party", GRN = "The Greens", ONP = "One Nation", IND = "Independent")
fix_party <- function(p, code) {
  p <- ifelse(is.na(p) | !nzchar(trimws(p)), "Non Affiliated", p)
  a <- classify_party(p, code); b <- classify_party(p); d <- a != b & p != "Non Affiliated"
  if (any(d & !a %in% names(CANON))) stop("NBF3! no canonical name for class ", paste(unique(a[d & !a %in% names(CANON)]), collapse = ","))
  p[d] <- sprintf("%s (AEC name: %s)", CANON[a[d]], p[d])
  p
}
cand <- function(s, g) paste0(toupper(s), ", ", g)

RES <- fread("external/elections/aec-fed-firstprefs.csv", showProgress = FALSE)
for (yr in names(EV)) {
  y <- as.integer(yr); lab <- sprintf("fed%d", y)
  fs <- file.path(A, "booths", sprintf("pp-fed%d-%s.csv", y, STATES))
  if (!all(file.exists(fs))) stop("NBF1! missing ", paste(fs[!file.exists(fs)], collapse = ", "))
  PP <- rbindlist(lapply(fs, read_aec))
  VT <- read_aec(file.path(A, sprintf("fed%d-firstprefs.csv", y)))
  cat(sprintf("NBF1  %s: %d polling-place rows from %d state files, %d vote-type rows\n", lab, nrow(PP), length(fs), nrow(VT)))
  PP <- PP[PP$Surname != "Informal" & PP$PartyNm != "Informal"]
  VT <- VT[VT$Surname != "Informal" & VT$PartyNm != "Informal"]
  n_nafd <- sum(is.na(VT$PartyNm) | !nzchar(VT$PartyNm))
  ord <- PP[, list(district = DivisionNm, booth = PollingPlace, booth_type = "ordinary",
                   candidate = cand(Surname, GivenNm), party = fix_party(PartyNm, PartyAb), votes = as.numeric(OrdinaryVotes))]
  # one row per booth x candidate: polling places are unique by ID; two IDs sharing a name in one division are merged
  ord <- ord[, list(votes = sum(votes)), by = c("district", "booth", "booth_type", "candidate", "party")]
  dec <- rbindlist(lapply(list(c("PrePollVotes", "early"), c("PostalVotes", "postal"), c("AbsentVotes", "absent"),
                               c("ProvisionalVotes", "provisional")), function(z)
    VT[, list(district = DivisionNm, booth = z[2], booth_type = z[2], candidate = cand(Surname, GivenNm),
              party = fix_party(PartyNm, PartyAb), votes = as.numeric(get(z[1])))]))
  B <- rbind(ord, dec)
  # NBF2: every division present; ordinary booths sum to the vote-type file's OrdinaryVotes; all types to TotalVotes;
  # and, net of the non-affiliated candidates, to the harness's results file.
  vt_tot <- VT[, list(ordv = sum(OrdinaryVotes), totv = sum(TotalVotes),
                      tot_aff = sum(TotalVotes[!(is.na(PartyNm) | !nzchar(PartyNm))])), by = list(district = DivisionNm)]
  b_tot <- B[, list(ordb = sum(votes[booth_type == "ordinary"]), totb = sum(votes),
                    tot_aff_b = sum(votes[party != "Non Affiliated"])), by = "district"]
  keep_res <- RES$election == lab
  r_tot <- RES[keep_res, list(res = sum(votes)), by = list(district = seat)]
  K <- merge(merge(vt_tot, b_tot, by = "district", all = TRUE), r_tot, by = "district", all = TRUE)
  bad <- K[is.na(ordb) | is.na(ordv) | is.na(res) | ordb != ordv | totb != totv | tot_aff_b != res]
  cat(sprintf("NBF2  %s: %d divisions (%d in the results file); %s formal votes; ordinary %s (%.1f%% of formal); mismatched divisions: %d\n",
              lab, uniqueN(B$district), nrow(r_tot), format(sum(B$votes), big.mark = ","),
              format(sum(B$votes[B$booth_type == "ordinary"]), big.mark = ","), 100 * sum(B$votes[B$booth_type == "ordinary"]) / sum(B$votes), nrow(bad)))
  if (nrow(bad)) { print(bad); stop("NBF2! ", lab, ": booth sums do not match the division totals") }
  if (anyNA(B$party) || anyNA(B$votes)) stop("NBF2! ", lab, ": NA party or votes")
  # NBF3: the night update classifies by NAME only; compare with name + code (how the results file classified them)
  VT[, cls_nc := classify_party(PartyNm, PartyAb)]; VT[, cls_n := classify_party(fix_party(PartyNm, PartyAb))]
  dif <- unique(VT[VT$cls_nc != VT$cls_n & !(is.na(VT$PartyNm) | !nzchar(VT$PartyNm)), list(PartyNm, PartyAb, cls_nc, cls_n)])
  cls <- B[, list(v = sum(votes)), by = list(cls = classify_party(party))][, pct := round(100 * v / sum(v), 2)][order(-v)]
  cat(sprintf("NBF3  %s: %d non-affiliated candidate rows (-> OTH); name-only vs name+code class differences: %d; classes: %s\n",
              lab, n_nafd, nrow(dif), paste(sprintf("%s %.1f", cls$cls, cls$pct), collapse = ", ")))
  if (nrow(dif)) { print(dif); stop("NBF3! ", lab, ": the written party names classify differently from name + code") }
  rn <- unique(VT[VT$cls_nc != classify_party(VT$PartyNm), list(PartyNm, PartyAb, cls_nc)])
  if (nrow(rn)) cat(sprintf("NBF3  %s: renamed so the name classifies as the code does: %s
", lab,
                            paste(sprintf("%s/%s -> %s", rn$PartyNm, rn$PartyAb, rn$cls_nc), collapse = "; ")))
  n_ppvc <- uniqueN(ord[grepl("PPVC|PREPOLL", ord$booth, ignore.case = TRUE), list(district, booth)])
  cat(sprintf("NBF3  %s: %d ordinary units (%d of them pre-poll voting centres), %d rows\n", lab,
              uniqueN(ord[, list(district, booth)]), n_ppvc, nrow(B)))
  fwrite(B, file.path("output", sprintf("booths-%s.csv", lab)))

  if (y >= 2022) {
    tf <- file.path(A, "booths", "raw-tcp", sprintf("HouseTcpByCandidateByPollingPlaceDownload-%d.csv", EV[[yr]]))
    if (!file.exists(tf)) stop("NBF1! missing ", tf)
    TP <- read_aec(tf); TV <- read_aec(file.path(A, sprintf("fed%d-tcp.csv", y)))
    to <- TP[, list(election = lab, district = DivisionNm, booth = PollingPlace, vote_type = "ordinary",
                    candidate = cand(Surname, GivenNm), party_raw = fix_party(PartyNm, PartyAb), votes = as.numeric(OrdinaryVotes))]
    to <- to[, list(votes = sum(votes)), by = c("election", "district", "booth", "vote_type", "candidate", "party_raw")]
    td <- rbindlist(lapply(list(c("PrePollVotes", "early"), c("PostalVotes", "postal"), c("AbsentVotes", "absent"),
                                c("ProvisionalVotes", "provisional")), function(z)
      TV[, list(election = lab, district = DivisionNm, booth = z[2], vote_type = z[2], candidate = cand(Surname, GivenNm),
                party_raw = fix_party(PartyNm, PartyAb), votes = as.numeric(get(z[1])))]))
    TT <- rbind(to, td)
    tv_tot <- TV[, list(t1 = sum(TotalVotes)), by = list(district = DivisionNm)]
    tt_tot <- TT[, list(t2 = sum(votes), nc = uniqueN(candidate)), by = "district"]
    KT <- merge(tv_tot, tt_tot, by = "district", all = TRUE)
    badt <- KT[is.na(t1) | is.na(t2) | t1 != t2 | nc != 2L]
    # the 2CP total should equal the formal first-preference total of the same division
    KF <- merge(tt_tot, b_tot, by = "district")
    cat(sprintf("NBF2  %s 2CP: %d divisions, mismatched against the vote-type 2CP file: %d; 2CP total != formal total in %d\n",
                lab, nrow(tt_tot), nrow(badt), sum(KF$t2 != KF$totb)))
    if (nrow(badt)) { print(badt); stop("NBF2! ", lab, ": 2CP booth sums do not match") }
    dir.create("output/booths", showWarnings = FALSE)
    fwrite(TT, file.path("output", "booths", sprintf("%s-booth-tcp.csv", lab)))
    cat(sprintf("NBF4  %s: wrote output/booths/%s-booth-tcp.csv (%d rows)\n", lab, lab, nrow(TT)))
  }
  cat(sprintf("NBF4  %s: wrote output/booths-%s.csv\n", lab, lab))
}
