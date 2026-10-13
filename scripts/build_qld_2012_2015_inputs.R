# Queensland 2012 and 2015 harness inputs from the ECQ results files already on disk
# (external/reference/ecq/raw/<year>/candidates.csv, parsed from the commission's publicResults.xml).
#
# Writes NEW files only, to external/reference/ecq/ (never over an existing file):
#   ecq-2012-qld-firstprefs-kapfix.csv   seat, party, votes -- 2012 first preferences with Katter's party in OTH_RIGHT
#   ecq-qld-winners-2012-2015.csv        election, seat, winner (class of the declared member)
#
# WHY A SECOND 2012 FIRST-PREFERENCE FILE. external/elections/ecq-2012-qld-firstprefs.csv files Katter's
# party under OTH (all 76 of its candidates): the 2012 results file names the party "The Australian Party",
# which classify_party() does not recognise as Katter's. Every other Queensland file (2015, 2017, 2020, 2024)
# files it under OTH_RIGHT, and the 2015 pair would swing a 2012 OTH column toward a 2015 OTH_RIGHT column
# that does not share its voters. Check QC1 below reproduces the existing file exactly once that one mapping
# is applied, so nothing else differs.
#
# Check codes QC1-QC5.
suppressMessages(library(data.table))
OUT <- file.path("external", "reference", "ecq")
RAW <- file.path(OUT, "raw")
# code -> class. ALP/LNP/GRN/ONP map to themselves.
CLS <- c(KAP = "OTH_RIGHT", FFP = "OTH_RIGHT", PUP = "OTH_RIGHT", ZZZ = "IND")
cls_of <- function(code) ifelse(code %in% names(CLS), unname(CLS[code]), code)
say <- function(...) cat(sprintf(...), "\n", sep = "")

W <- list()
for (y in c(2012L, 2015L)) {
  x <- fread(file.path(RAW, y, "candidates.csv"), showProgress = FALSE)
  bad <- setdiff(unique(x$code), c("ALP", "LNP", "GRN", "ONP", names(CLS)))
  stopifnot(length(bad) == 0)   # a party code this script has not been told how to class
  x[, party := cls_of(code)]
  fp <- x[, .(votes = sum(votes)), by = .(seat, party)][order(seat, party)]
  stopifnot(uniqueN(fp$seat) == 89L)
  # QC1: reproduce the existing file (2015 exactly; 2012 once its OTH is folded into OTH_RIGHT)
  old <- fread(file.path("external", "elections", sprintf("ecq-%d-qld-firstprefs.csv", y)), showProgress = FALSE)
  if (y == 2012L) old[party == "OTH", party := "OTH_RIGHT"]
  old <- old[, .(votes = sum(votes)), by = .(seat, party)]
  j <- merge(fp, old, by = c("seat", "party"), all = TRUE, suffixes = c(".new", ".old"))
  nbad <- j[is.na(votes.new) | is.na(votes.old) | votes.new != votes.old, .N]
  say("QC1  qld%d: %d seat-party cells, %d differ from the existing file%s", y, nrow(j), nbad,
      if (y == 2012L) " (after folding its OTH into OTH_RIGHT)" else "")
  stopifnot(nbad == 0)
  if (y == 2012L) {
    f <- file.path(OUT, "ecq-2012-qld-firstprefs-kapfix.csv")
    stopifnot(!file.exists(f)); fwrite(fp, f)
    say("QC2  wrote %s: %d rows, party counts %s", f, nrow(fp),
        paste(names(table(fp$party)), table(fp$party), sep = "=", collapse = " "))
  }
  # winners: the candidate the commission declared elected
  w <- x[ballot_name == declared, .(seat, winner = party, code)]
  stopifnot(nrow(w) == 89L, uniqueN(w$seat) == 89L)
  say("QC3  qld%d winners: %s", y, paste(names(table(w$winner)), table(w$winner), sep = "=", collapse = " "))
  # QC4: the declared winner stood in the seat and polled at least as many first preferences as anyone
  #      with the same class in it (a gross wrong-row check, not a count check)
  lead <- x[, .(top = max(votes)), by = seat]
  wv <- x[ballot_name == declared, .(seat, wv = votes)]
  m <- merge(wv, lead, by = "seat")
  say("QC4  qld%d: declared winner led the first-preference count in %d of 89 seats (the rest are preference wins)", y, m[wv == top, .N])
  stopifnot(m[wv == top, .N] > 60L)
  W[[as.character(y)]] <- w[, .(election = sprintf("qld%d", y), seat, winner)]
}
wf <- file.path(OUT, "ecq-qld-winners-2012-2015.csv")
stopifnot(!file.exists(wf)); fwrite(rbindlist(W), wf)
say("QC5  wrote %s (%d rows)", wf, sum(vapply(W, nrow, 1L)))
