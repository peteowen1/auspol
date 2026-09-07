# Queensland 2017: Legislative Assembly first preferences and declared winners.
#
# WHY A SECOND QUEENSLAND FETCHER. scripts/fetch_preferences_qld.R reads the
# ECQ's current results feed, whose index only reaches back to the 2020 general
# election. The commission's older results site published a complete package per
# election at
#
#   results.ecq.qld.gov.au/elections/state/state<YEAR>/results/public.zip
#
# and the Internet Archive has state2012, state2015 and state2017. The 2017 file
# is a single publicResults.xml on a SCHEMA UNRELATED to the 2020/2024 feed --
# election > districts > district > candidates > candidate, with the declared
# winner as an attribute of the district -- so it needs its own parser rather
# than a branch in the other one.
#
# WHAT IT UNLOCKS. qld2017 is the missing prior side of a qld2017 -> qld2020
# pair. Queensland has our worst seat log loss of any jurisdiction and exactly
# one pair to learn from, so a second one is worth more here than anywhere else.
#
# THE SNAPSHOT DATE IS PART OF THE DATA, as it was for Victoria 2010. The
# archive's first capture of this file is 25 November 2017 -- polling day -- at
# 343,563 bytes against 406,320 from 4 December on. A late capture is used and
# the file has to PROVE it is final: every district must carry a declared
# winner, and the counts must reconcile to 93 districts.
#
# ONE CLASSIFICATION CAVEAT, STATED RATHER THAN BURIED. The 2017 feed codes
# every candidate without a registered party as "ZZZ", labelled "Other
# Candidates", and 95 of the 453 candidates carry it. The commission's own
# candidate listing shows the same blank, because in Queensland a candidate is
# printed with a party only if a registered party endorsed them. So "ZZZ" is
# read as INDEPENDENT here -- which is what the ballot paper said and what the
# voter saw. The eight largest are all well-known independents (Sandy Bolton,
# who won Noosa; Margaret Strelow; Rob Pyne; Peter Dowling), so the significant
# cases are right. The risk is the small ones: a candidate belonging to a party
# that was not registered in 2017 appears here as an independent, where the 2020
# feed would have given them a party code. Anything comparing IND across that
# pair has to know this.
#
# Emits Q17* codes.

options(auspol.root = normalizePath("."))
options(timeout = max(600, getOption("timeout")))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "ecq")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

SRC <- "https://results.ecq.qld.gov.au/elections/state/state2017/results/public.zip"
ZIP <- file.path(RAW, "qld2017-public.zip")
XML <- file.path(RAW, "qld2017.xml")

# ---- fetch, from a capture well after polling day -------------------------
if (!file.exists(XML) || file.info(XML)$size < 1e6) {
  if (!file.exists(ZIP) || file.info(ZIP)$size < 3e5) {
    q <- paste0("http://web.archive.org/cdx/search/cdx?url=",
                sub("^https?://", "", SRC),
                "&output=text&fl=timestamp,length&filter=statuscode:200&limit=40")
    cdx <- file.path(RAW, "qld2017-cdx.txt")
    for (k in 1:4) {
      try(utils::download.file(q, cdx, quiet = TRUE, headers = c("User-Agent" = UA)),
          silent = TRUE)
      # A CACHED ERROR PAGE IS NOT AN INDEX. The archive answers overload with
      # an HTML page that downloads perfectly happily and reads back as data.
      if (file.exists(cdx) &&
          any(grepl("^[0-9]{14}", readLines(cdx, warn = FALSE)))) break
      if (file.exists(cdx)) unlink(cdx)
      Sys.sleep(c(5, 15, 30, 60)[k])
    }
    if (!file.exists(cdx)) stop("Could not read the archive index for ", SRC)
    snaps <- readLines(cdx, warn = FALSE)
    snaps <- snaps[grepl("^[0-9]{14} ", snaps)]
    ts <- sub(" .*$", "", snaps)
    # Polling day was 2017-11-25 and the count ran into December. Anything from
    # 2018 on is unambiguously after the declaration, and the earliest such
    # capture is preferred so a later site rebuild cannot creep in.
    ts <- sort(ts[ts >= "2018"])
    if (!length(ts)) stop("No capture of ", SRC, " from 2018 or later")
    for (t in ts) {
      try(utils::download.file(sprintf("https://web.archive.org/web/%sid_/%s", t, SRC),
                               ZIP, quiet = TRUE, mode = "wb",
                               headers = c("User-Agent" = UA)), silent = TRUE)
      if (file.exists(ZIP) && file.info(ZIP)$size > 3e5) {
        cat(sprintf("Q171 fetched the results package from the %s capture (%d bytes)\n",
                    t, file.info(ZIP)$size))
        break
      }
      if (file.exists(ZIP)) unlink(ZIP)
      Sys.sleep(5)
    }
    if (!file.exists(ZIP)) stop("Could not download ", SRC)
  }
  nm <- utils::unzip(ZIP, list = TRUE)$Name
  if (!"publicResults.xml" %in% nm)
    stop("The package does not contain publicResults.xml; it holds: ",
         paste(nm, collapse = ", "))
  utils::unzip(ZIP, files = "publicResults.xml", exdir = RAW)
  file.rename(file.path(RAW, "publicResults.xml"), XML)
}
x <- paste(readLines(XML, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
cat(sprintf("Q171 %s: %.1f MB\n", XML, file.info(XML)$size / 1e6))

gen <- regmatches(x, regexpr("<generationDateTime>[^<]*", x))
gen <- sub("<generationDateTime>", "", gen)
cat(sprintf("Q171 generated %s (polling day was 2017-11-25)\n", gen))
if (length(gen) && substr(gen, 1, 10) <= "2017-11-30")
  stop("This capture was generated ", gen, ", within days of polling day. ",
       "The archive's election-day capture is a PROVISIONAL count and looks ",
       "complete; use a later one.")

# ---- parse ----------------------------------------------------------------
attr_of <- function(s, a) {
  m <- regmatches(s, regexpr(sprintf('%s="[^"]*"', a), s))
  if (!length(m)) return(NA_character_)
  sub('"$', "", sub(sprintf('^%s="', a), "", m))
}
districts <- regmatches(x, gregexpr("(?s)<district\\b.*?</district>", x, perl = TRUE))[[1]]
cat(sprintf("Q172 %d districts in the file\n", length(districts)))
if (length(districts) != 93L)
  stop("Queensland had 93 districts in 2017 and this file has ", length(districts))

# The party CODE table the file publishes for itself. "ZZZ" is deliberately
# mapped to an empty name so classify_party() reaches its independent branch --
# see the caveat in the header. Every other code is passed with its registered
# name, because a code with no name is bucketed as IND and that is a wrong
# answer rather than a partial one.
pm <- regmatches(x, gregexpr('<party code="[^"]*" name="[^"]*"', x))[[1]]
# Both halves need the trailing quote stripped: the match ends ON the closing
# quote of name=, so a bare sub() leaves it attached and every party name gains
# a stray character.
PARTY <- stats::setNames(sub('"$', "", sub('.*name="', "", pm)),
                         sub('".*', "", sub('<party code="', "", pm)))
PARTY[["ZZZ"]] <- ""
cat(sprintf("Q172 party codes in the file: %s\n",
            paste(sprintf("%s=%s", names(PARTY), ifelse(nzchar(PARTY), PARTY, "(no registered party)")),
                  collapse = " | ")))

rows <- rbindlist(lapply(districts, function(d) {
  head_d <- regmatches(d, regexpr("<district[^>]*>", d))
  seat <- attr_of(head_d, "name")
  decl <- attr_of(head_d, "declaredPartyCode")
  # STRIP THE CLOSING TAG TOO. A non-greedy ".*?</count>" match ends WITH
  # "</count>" still attached, so as.numeric() on it is NA -- and an NA total
  # compared against an NA sum is NA, which the check below reports as a
  # mismatch in all 93 districts rather than as a parse failure.
  formal <- as.numeric(sub("</count>.*$", "",
                           sub(".*<count>", "",
                               regmatches(d, regexpr("(?s)<formalVotes>.*?</count>", d, perl = TRUE)))))
  cands <- regmatches(d, gregexpr("(?s)<candidate\\b.*?</candidate>", d, perl = TRUE))[[1]]
  if (!length(cands)) return(NULL)
  code <- vapply(cands, function(z) attr_of(regmatches(z, regexpr("<candidate[^>]*>", z)), "party"),
                 character(1), USE.NAMES = FALSE)
  votes <- vapply(cands, function(z) {
    m <- regmatches(z, regexpr("(?s)<primaryVotes>.*?<count>[0-9]+</count>", z, perl = TRUE))
    if (!length(m)) return(NA_real_)
    as.numeric(sub("</count>.*$", "", sub(".*<count>", "", m)))
  }, numeric(1), USE.NAMES = FALSE)
  data.table(seat = seat, declared = decl, formal = formal,
             ballot = vapply(cands, function(z) attr_of(regmatches(z, regexpr("<candidate[^>]*>", z)), "ballotName"),
                             character(1), USE.NAMES = FALSE),
             code = code, votes = votes)
}))

# Every district must name a declared winner. That is this file's own statement
# that the count finished, and it is the check the Victorian provisional capture
# would have failed.
nod <- rows[is.na(declared) | !nzchar(declared), unique(seat)]
if (length(nod))
  stop(length(nod), " district(s) carry no declared winner, so this capture is ",
       "not a final count: ", paste(utils::head(nod, 6), collapse = ", "))

unk <- setdiff(unique(rows$code), names(PARTY))
if (length(unk))
  stop("Candidate party code(s) with no entry in the file's own party table: ",
       paste(unk, collapse = ", "),
       ". Classifying them without a name would silently make them IND.")

rows[, party := classify_party(unname(PARTY[code]), ifelse(code == "ZZZ", "", code))]
cat(sprintf("Q173 %d candidates; %d carry no registered party and are read as independents\n",
            nrow(rows), rows[code == "ZZZ", .N]))

# Each district's primary votes must add to the formal-vote count it reports.
# No is.finite() escape hatch: a district with no figure to check against is
# unverifiable, not passing.
chk <- rows[, .(sum_votes = sum(votes), formal = formal[1]), by = seat][
  !is.finite(formal) | !is.finite(sum_votes) | sum_votes != formal]
if (nrow(chk))
  stop("Primary votes do not add to the reported formal-vote count in ", nrow(chk),
       " district(s): ",
       paste(sprintf("%s %.0f vs %.0f", chk$seat, chk$sum_votes, chk$formal), collapse = "; "))
cat("Q174 every district's primary votes add to the formal-vote count it reports\n")

fp <- rows[, .(votes = sum(votes)), by = .(seat, party)]
fwrite(fp[order(seat, party)], file.path(OUT, "ecq-2017-qld-firstprefs.csv"))
cat(sprintf("Q175 wrote %s (%d rows, %d seats)\n",
            file.path(OUT, "ecq-2017-qld-firstprefs.csv"), nrow(fp), uniqueN(fp$seat)))

st <- fp[, .(v = sum(votes)), by = party][, pct := round(100 * v / sum(v), 2)][order(-pct)]
cat("\nQ176 statewide first preferences\n")
print(st)

win <- unique(rows[, .(seat, code = declared)])
win[, winner := classify_party(unname(PARTY[code]), ifelse(code == "ZZZ", "", code))]
fwrite(win[order(seat), .(election = "qld2017", seat, winner)],
       file.path(OUT, "ecq-2017-qld-winners.csv"))
cat(sprintf("\nQ177 wrote %s\n", file.path(OUT, "ecq-2017-qld-winners.csv")))
print(win[, .N, by = winner][order(-N)])
