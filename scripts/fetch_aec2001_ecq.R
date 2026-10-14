# Federal 2001 (AEC statistics release) and Queensland 2004-2017 (ECQ results zips):
# first preferences, two-candidate-preferred and, for federal 2001, the full
# preference distribution, as NEW files that leave the existing combined files alone.
#
# WHY. Track A of docs/plans/coverage-program-2026-10-13.md found that the real gap
# for the older elections is preference distributions and commission-grade first
# preferences, not winners (the anchor clone's results_<year>*.csv already has
# those). This script closes the two sources the inventory found live:
#   * AEC 2001 statistics zip: data/import/hppdop.txt is a count-by-count
#     distribution at polling-place level; summing polling places gives the
#     division distribution. hcands.txt carries candidate first preferences.
#   * ECQ results.ecq.qld.gov.au/elections/state/<State|state><year>/results/public.zip,
#     one publicResults.xml per election with booth-level primaries. Two-candidate
#     figures (n2cpVotes) exist only for 2004 and 2012; 2006, 2009, 2015 and 2017
#     carry none, and none has preference rounds (Queensland was optional preferential).
#
# OUTPUTS (all new; nothing existing is touched)
#   external/elections/aec-fed-2001-{firstprefs,tcp,transfers}.csv   same columns as aec-fed-*.csv
#   external/elections/ecq-<y>-qld-firstprefs.csv  (seat,party,votes)  y = 2004,2006,2009,2012,2015
#   external/elections/ecq-<y>-qld-tcp.csv         (seat,party,votes)  y = 2004,2012 only
#   external/reference/aec/raw/2001/               raw files + every field, parsed
#   external/reference/ecq/raw/<y>/                public.zip, publicResults.xml, candidates.csv, booths.csv
# 2017 already exists as ecq-2017-qld-firstprefs.csv: it is compared, never overwritten.
#
# Emits QA* codes. Read by a human; run: Rscript scripts/fetch_aec2001_ecq.R

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- "auspol-research-fetch/1.0 (academic election forecasting; polite 1 req/s)"
OUT <- election_data_path()
AE_DIR <- file.path("external", "aus-polling-analyser", "analysis", "Archived", "elections")
STATS_ZIP <- file.path("external", "reference", "aec", "stats", "aec-2001-election-statistics.zip")
STATS_URL <- "https://www.aec.gov.au/About_AEC/Publications/statistics/files/aec-2001-election-statistics.zip"
RAW01 <- file.path("external", "reference", "aec", "raw", "2001")
dir.create(RAW01, recursive = TRUE, showWarnings = FALSE)

SUMMARY <- list()
note <- function(election, check, ok, detail) {
  SUMMARY[[length(SUMMARY) + 1L]] <<- data.table(election = election, check = check,
                                                 ok = ok, detail = detail)
  cat(sprintf("QA %-8s %-4s %s | %s\n", election, if (ok) "PASS" else "FAIL", check, detail))
}

# ---- AE archived results (cross-check only) --------------------------------
read_ae <- function(f) {
  L <- readLines(f, warn = FALSE, encoding = "UTF-8")
  res <- list(); seat <- NA; sec <- NA
  for (l in L) {
    if (startsWith(l, "Seat,")) { seat <- sub("^Seat,", "", l); sec <- NA; next }
    if (l %in% c("fp", "tcp")) { sec <- l; next }
    p <- strsplit(l, ",", fixed = TRUE)[[1]]
    if (is.na(seat) || is.na(sec) || length(p) < 3) next
    res[[length(res) + 1L]] <- list(seat = seat, sec = sec, name = p[1], party = p[2],
                                    votes = suppressWarnings(as.numeric(p[3])))
  }
  rbindlist(res)
}
norm <- function(s) gsub("[^a-z]", "", tolower(iconv(s, to = "ASCII//TRANSLIT")))
norm_seat <- function(s) gsub("[^a-z]", "", tolower(s))

# winner per seat from AE: top of the tcp block when there is one, else the fp leader
ae_winner <- function(ae) {
  w1 <- ae[sec == "tcp", .SD[which.max(votes)], by = seat]
  w2 <- ae[sec == "fp" & !seat %in% w1$seat, .SD[which.max(votes)], by = seat]
  rbind(w1, w2)[, .(seat, ae_name = name)]
}

# =============================================================================
# PART 1. FEDERAL 2001
# =============================================================================
need01 <- c("divs.txt", "hcands.txt", "hppdop.txt", "htppbypp.txt", "scands.txt", "sppvote.txt")
inzip <- if (file.exists(STATS_ZIP)) utils::unzip(STATS_ZIP, list = TRUE) else NULL
# A zip that lists its members can still be truncated; the central directory is read
# first, so test that the sizes of the files we need match what the directory claims.
if (is.null(inzip) || !all(paste0("data/import/", need01) %in% inzip$Name)) {
  if (file.exists(STATS_ZIP)) unlink(STATS_ZIP)
  utils::download.file(STATS_URL, STATS_ZIP, mode = "wb", quiet = TRUE,
                       headers = c("User-Agent" = UA))
  inzip <- utils::unzip(STATS_ZIP, list = TRUE)
}
miss <- setdiff(paste0("data/import/", need01), inzip$Name)
if (length(miss)) stop("AEC 2001 zip lacks: ", paste(miss, collapse = ", "))
for (f in need01) {
  dest <- file.path(RAW01, f)
  want <- inzip$Length[inzip$Name == paste0("data/import/", f)]
  if (!file.exists(dest) || file.info(dest)$size != want) {
    utils::unzip(STATS_ZIP, files = paste0("data/import/", f), exdir = RAW01, junkpaths = TRUE)
  }
  if (file.info(dest)$size != want) stop(f, ": extracted size differs from the zip directory")
}
note("fed2001", "QA1", TRUE, sprintf("zip %s opens; %d members; %d needed files extracted to %s at the listed sizes",
                                    basename(STATS_ZIP), nrow(inzip), length(need01), RAW01))

rd <- function(f) fread(file.path(RAW01, f), sep = ";", encoding = "Latin-1",
                        colClasses = "character", showProgress = FALSE)
hc <- rd("hcands.txt"); setnames(hc, make.names(names(hc)))
hc[, `:=`(pos = as.integer(Ballot.Position), vote = as.numeric(Vote))]
dv <- rd("divs.txt"); setnames(dv, make.names(names(dv)))
hp <- rd("hppdop.txt"); setnames(hp, make.names(names(hp)))
hp[, `:=`(cnt = as.integer(Count), pos = as.integer(Ballot.Position),
          dist = suppressWarnings(as.numeric(Vote.Distributed)),
          vote = suppressWarnings(as.numeric(Vote)),
          exh = suppressWarnings(as.numeric(Exhausted.Transfer)))]
cat(sprintf("QA2 loaded hcands %d rows x %d cols, divs %d, hppdop %d rows (%d divisions, %d polling places)\n",
            nrow(hc), ncol(hc), nrow(dv), nrow(hp), uniqueN(hp$Division),
            uniqueN(hp[, .(Division, Polling.Place)])))

# party class: AEC codes -> a name classify_party() understands. HAN is One Nation's
# registered code in this release; the others pass as their own code so they land in OTH
# unless the classifier knows them. Blank party is an ungrouped independent.
code_name <- c(LP = "Liberal Party", NP = "National Party", CLP = "Country Liberal Party",
               HAN = "One Nation", ALP = "Australian Labor Party", GRN = "The Greens",
               DEM = "Australian Democrats", IND = "")
hc[, code := ifelse(is.na(Party) | Party == "", "IND", Party)]
nm <- ifelse(hc$code %in% names(code_name), unname(code_name[hc$code]), hc$code)
hc[, party_class := classify_party(nm, ifelse(hc$code == "HAN", "ONP", hc$code))]
cat("QA3 party code -> class used for 2001:\n")
print(hc[, .N, by = .(code, party_class)][order(party_class, -N)][, .(code, party_class, N)], row.names = FALSE)

# ---- first preferences ------------------------------------------------------
fp01 <- hc[, .(votes = sum(vote)), by = .(seat = Division, party = party_class)][votes > 0]
fp01[, election := "fed2001"]
ok1 <- uniqueN(fp01$seat) == 150L
note("fed2001", "QA4", ok1, sprintf("%d divisions with first preferences (expected 150), %s formal votes",
                                   uniqueN(fp01$seat), format(sum(fp01$votes), big.mark = ",")))
chk <- merge(hc[, .(fp = sum(vote)), by = Division],
             dv[, .(Division, formal = as.numeric(Formal.Vote))], by = "Division")
bad <- chk[fp != formal]
note("fed2001", "QA5", nrow(bad) == 0L,
     sprintf("per-division first-preference sum equals divs.txt Formal Vote in %d of %d divisions%s",
             nrow(chk) - nrow(bad), nrow(chk),
             if (nrow(bad)) paste0(" (differ: ", paste(head(bad$Division, 5), collapse = ", "), ")") else ""))
alp <- fp01[party == "ALP", sum(votes)] / sum(fp01$votes)
note("fed2001", "QA6", alp > 0.36 && alp < 0.42,
     sprintf("national ALP first-preference share %.2f%% (2001 actual 37.8%%)", 100 * alp))

# ---- distribution at division level -----------------------------------------
# Same polling places must run the same counts within a division, or summing them is wrong.
pp_max <- hp[, .(mx = max(cnt)), by = .(Division, Polling.Place)]
mixed <- pp_max[, .(n = uniqueN(mx)), by = Division][n > 1]
note("fed2001", "QA7", nrow(mixed) == 0L,
     sprintf("every polling place in a division reaches the same final count: %d of %d divisions inconsistent%s",
             nrow(mixed), uniqueN(hp$Division),
             if (nrow(mixed)) paste0(" (", paste(head(mixed$Division, 5), collapse = ", "), ")") else ""))
hp[, st := Candidate.Status]
# hppdop.txt carries a "DIVISION SUMMARY" pseudo polling place that already totals every
# other row (ordinary booths plus ABSENT, POSTAL, PRE POLL, PROVISIONAL). Summing it with
# the real polling places double counts. The summary is used, and the real rows are summed
# separately to prove the summary is what it says.
is_sum <- toupper(hp$Polling.Place) == "DIVISION SUMMARY"
note("fed2001", "QA7b", uniqueN(hp[is_sum, Division]) == 150L,
     sprintf("a DIVISION SUMMARY pseudo polling place exists in %d of 150 divisions (%d rows)",
             uniqueN(hp[is_sum, Division]), sum(is_sum)))
agg <- function(h) h[, .(vote = sum(vote, na.rm = TRUE), dist = sum(dist, na.rm = TRUE),
                        exh = sum(exh, na.rm = TRUE),
                        st = if (any(st == "X")) "X" else if (any(st == "E")) "E" else "R",
                        npp = .N), by = .(Division, cnt, pos)]
dd <- agg(hp[is_sum]); pps <- agg(hp[!is_sum])
mm <- merge(dd[, .(Division, cnt, pos, v1 = vote, d1 = dist)], pps[, .(Division, cnt, pos, v2 = vote, d2 = dist)],
            by = c("Division", "cnt", "pos"), all = TRUE)
note("fed2001", "QA7c", !anyNA(mm$v1) && !anyNA(mm$v2) && all(mm$v1 == mm$v2) && all(mm$d1 == mm$d2),
     sprintf("DIVISION SUMMARY equals the sum of the real polling places in %d of %d division-count-candidate cells (votes and transfers)",
             sum(mm$v1 == mm$v2 & mm$d1 == mm$d2, na.rm = TRUE), nrow(mm)))
dd <- merge(dd, hc[, .(Division, pos, candidate = Candidate, party_code = code,
                       party_class, hc_vote = vote)],
            by = c("Division", "pos"), all.x = TRUE)
if (anyNA(dd$party_class)) stop("distribution rows with a ballot position not in hcands.txt")
# count 1 must reproduce hcands first preferences exactly
c1 <- dd[cnt == 1, .(Division, pos, vote, hc_vote)]
note("fed2001", "QA8", all(c1$vote == c1$hc_vote),
     sprintf("count-1 polling-place sums equal hcands first preferences for %d of %d candidate rows",
             sum(c1$vote == c1$hc_vote), nrow(c1)))
fwrite(dd[order(Division, cnt, pos)], file.path(RAW01, "parsed-division-distribution.csv"))
fwrite(hc, file.path(RAW01, "parsed-candidates.csv"))

# transfers
ex <- dd[st == "X", .(Division, cnt, ex_pos = pos, ex_party = party_class)]
nex <- ex[, .N, by = .(Division, cnt)]
last_c <- dd[, .(last = max(cnt)), by = Division]
ncounts <- dd[cnt > 1, uniqueN(cnt), by = Division]
exdc <- ex[, uniqueN(cnt), by = Division]
cnts_chk <- merge(last_c, merge(exdc, ncounts, by = "Division", all = TRUE,
                                suffixes = c("_ex", "_cnt")), by = "Division", all.x = TRUE)
# a division of k candidates runs to k-1 exclusions then the last count is 'elected'
okx <- max(nex$N) == 1L
note("fed2001", "QA9", okx,
     sprintf("exactly one exclusion per count (max %d); %d exclusions over %d divisions",
             max(nex$N), nrow(ex), uniqueN(ex$Division)))
prev <- dd[, .(Division, cnt = cnt + 1L, ex_pos = pos, prev_vote = vote)]
ex <- merge(ex, prev, by = c("Division", "cnt", "ex_pos"), all.x = TRUE)
rec <- dd[st %in% c("R", "E") & cnt > 1 & dist > 0, .(Division, cnt, to = party_class, votes = dist, pos)]
moved <- rec[, .(moved = sum(votes)), by = .(Division, cnt)]
bal <- merge(ex, moved, by = c("Division", "cnt"), all.x = TRUE)
bal[is.na(moved), moved := 0]
bal[, gap := prev_vote - moved]
note("fed2001", "QA10", all(bal$gap == 0),
     sprintf("votes leaving each excluded candidate equal votes arriving, in %d of %d exclusions (largest gap %d)",
             sum(bal$gap == 0), nrow(bal), as.integer(max(abs(bal$gap)))))
tx01 <- merge(rec, ex[, .(Division, cnt, from = ex_party)], by = c("Division", "cnt"))
tx01 <- tx01[, .(votes = sum(votes)), by = .(seat = Division, round = cnt, from, to)]
tx01[, election := "fed2001"]
setcolorder(tx01, c("election", "seat", "round", "from", "to", "votes"))

# winner and two-candidate-preferred from the final count
fin <- dd[last_c, on = .(Division, cnt = last)][st %in% c("R", "E") & vote > 0]
win01 <- fin[st == "E", .(Division, win_pos = pos, win_cand = candidate, win_class = party_class)]
note("fed2001", "QA11", nrow(win01) == 150L && uniqueN(win01$Division) == 150L,
     sprintf("one declared (Elected) candidate in each of %d divisions", uniqueN(win01$Division)))
tcp01 <- fin[, .(election = "fed2001", seat = Division, party = party_class, votes = vote)]
tcp_n <- fin[, .N, by = Division]
note("fed2001", "QA12", all(tcp_n$N == 2L),
     sprintf("final count has exactly two candidates in %d of %d divisions", sum(tcp_n$N == 2L), nrow(tcp_n)))
tpp <- merge(fin[, .(tcp = sum(vote)), by = Division],
             dv[, .(Division, tpp = as.numeric(ALP.TPP.Vote) + as.numeric(Coalition.TPP.Vote))], by = "Division")
badt <- tpp[tcp != tpp]
note("fed2001", "QA13", nrow(badt) == 0L,
     sprintf("final-count two-candidate total equals divs.txt ALP+Coalition TPP in %d of %d divisions%s",
             nrow(tpp) - nrow(badt), nrow(tpp),
             if (nrow(badt)) paste0(" (", paste(head(badt$Division, 6), collapse = ", "), ")") else ""))
# sanity anchors on flows
g <- tx01[from == "GRN" & to %in% c("ALP", "LNP"), .(v = sum(votes)), by = to]
gpc <- 100 * g[to == "ALP", v] / sum(g$v)
note("fed2001", "QA14", gpc > 70 && gpc < 92, sprintf("Greens to Labor flow %.1f%% (anchor band 70-92)", gpc))
o <- tx01[from == "ONP" & to %in% c("ALP", "LNP"), .(v = sum(votes)), by = to]
note("fed2001", "QA15", TRUE, sprintf("One Nation to Labor flow %.1f%% of ALP+LNP (n = %s votes)",
                                     100 * o[to == "ALP", v] / sum(o$v), format(sum(o$v), big.mark = ",")))

# compare with AE archive
ae <- read_ae(file.path(AE_DIR, "results_2001fed.csv"))
aw <- ae_winner(ae)
cmp <- merge(win01[, .(seat = Division, win_cand)], aw, by = "seat", all = TRUE)
cmp[, hit := mapply(function(a, b) grepl(norm(sub(",.*$", "", a)), norm(b), fixed = TRUE), win_cand, ae_name)]
note("fed2001", "QA16", sum(cmp$hit, na.rm = TRUE) == 150L && !anyNA(cmp$hit),
     sprintf("AEC winner matches AE archive winner in %d of %d divisions%s", sum(cmp$hit, na.rm = TRUE), nrow(cmp),
             if (any(!cmp$hit | is.na(cmp$hit))) paste0(" (differ: ", paste(head(cmp[!hit | is.na(hit), seat], 6), collapse = ", "), ")") else ""))
aefp <- ae[sec == "fp", .(ae_votes = sum(votes)), by = seat]
cv <- merge(aefp, hc[, .(votes = sum(vote)), by = .(seat = Division)], by = "seat")
note("fed2001", "QA17", TRUE, sprintf("AE archive first-preference totals within 0.2%% of AEC in %d of %d divisions (informational)",
                                     sum(abs(cv$ae_votes / cv$votes - 1) < 0.002), nrow(cv)))

if (all(SUMMARY[[length(SUMMARY)]]$ok, TRUE) && all(rbindlist(SUMMARY)[election == "fed2001" & check %in% paste0("QA", c(4, 5, 8, 9, 11, 12)), ok])) {
  fwrite(fp01[order(seat, party)][, .(seat, party, votes, election)], file.path(OUT, "aec-fed-2001-firstprefs.csv"))
  fwrite(tcp01[order(seat, party)], file.path(OUT, "aec-fed-2001-tcp.csv"))
  fwrite(tx01[order(seat, round, from, to)], file.path(OUT, "aec-fed-2001-transfers.csv"))
  cat(sprintf("QA18 wrote aec-fed-2001-firstprefs (%d rows), -tcp (%d), -transfers (%d)\n",
              nrow(fp01), nrow(tcp01), nrow(tx01)))
} else cat("QA18! fed2001 internal checks failed; NOT writing output files\n")

# =============================================================================
# PART 2. QUEENSLAND (ECQ)
# =============================================================================
attr_of <- function(s, a) {
  m <- regmatches(s, regexpr(sprintf('\\b%s="[^"]*"', a), s))
  if (!length(m)) return(NA_character_)
  sub('"$', "", sub(sprintf('^%s="', a), "", m))
}
num_in <- function(z, tag) {   # count inside <tag>...<count>N</count> or plain <tag>N</tag>
  m <- regmatches(z, regexpr(sprintf("(?s)<%s>.*?</%s>", tag, tag), z, perl = TRUE))
  if (!length(m)) return(NA_real_)
  inner <- sub(sprintf("</%s>$", tag), "", sub(sprintf("^<%s>", tag), "", m))
  c <- regmatches(inner, regexpr("<count>[0-9]+</count>", inner))
  as.numeric(gsub("[^0-9]", "", if (length(c)) c else inner))
}
QLD <- list(list(y = 2004, cap = "state", seats = 89), list(y = 2006, cap = "state", seats = 89),
            list(y = 2009, cap = "state", seats = 89), list(y = 2012, cap = "State", seats = 89),
            list(y = 2015, cap = "State", seats = 89), list(y = 2017, cap = "State", seats = 93))

run_qld <- function(E) {
  y <- E$y; el <- sprintf("qld%d", y)
  rawd <- file.path("external", "reference", "ecq", "raw", y)
  dir.create(rawd, recursive = TRUE, showWarnings = FALSE)
  zip <- file.path(rawd, "public.zip"); xml <- file.path(rawd, "publicResults.xml")
  url <- sprintf("https://results.ecq.qld.gov.au/elections/state/%s%d/results/public.zip", E$cap, y)
  ok_zip <- function() file.exists(zip) && file.info(zip)$size > 5e4 &&
    !inherits(try(utils::unzip(zip, list = TRUE), silent = TRUE), "try-error")
  if (!ok_zip()) {
    if (file.exists(zip)) unlink(zip)
    Sys.sleep(1)
    utils::download.file(url, zip, mode = "wb", quiet = TRUE, headers = c("User-Agent" = UA))
  }
  if (!ok_zip()) { note(el, "QA20", FALSE, paste("could not fetch a valid zip from", url)); return(invisible()) }
  zl <- utils::unzip(zip, list = TRUE)
  if (!"publicResults.xml" %in% zl$Name) { note(el, "QA20", FALSE, "zip has no publicResults.xml"); return(invisible()) }
  if (!file.exists(xml) || file.info(xml)$size != zl$Length[zl$Name == "publicResults.xml"])
    utils::unzip(zip, files = "publicResults.xml", exdir = rawd)
  x <- paste(readLines(xml, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  closed <- grepl("</election>\\s*$", x)
  note(el, "QA20", closed && file.info(xml)$size == zl$Length[zl$Name == "publicResults.xml"],
       sprintf("zip valid (%d bytes), xml %.2f MB, closing </election> tag %s, generated %s",
               file.info(zip)$size, file.info(xml)$size / 1e6, if (closed) "present" else "MISSING",
               sub("<.*", "", sub(".*<generationDateTime>", "", x))))
  pm <- regmatches(x, gregexpr('<party code="[^"]*" name="[^"]*"', x))[[1]]
  PARTY <- setNames(sub('"$', "", sub('.*name="', "", pm)), sub('".*', "", sub('<party code="', "", pm)))
  PARTY[["ZZZ"]] <- ""
  dists <- regmatches(x, gregexpr("(?s)<district\\b.*?</district>", x, perl = TRUE))[[1]]
  cand_rows <- list(); booth_rows <- list()
  for (d in dists) {
    hd <- regmatches(d, regexpr("<district[^>]*>", d))
    seat <- attr_of(hd, "name"); declared <- attr_of(hd, "declaredBallotName")
    dpc <- attr_of(hd, "declaredPartyCode")
    formal <- num_in(sub("(?s)<booths.*$", "", d, perl = TRUE), "formalVotes")
    cs <- regmatches(d, gregexpr("(?s)<candidate\\b.*?</candidate>", d, perl = TRUE))[[1]]
    cand_rows[[length(cand_rows) + 1L]] <- rbindlist(lapply(cs, function(z) {
      h <- regmatches(z, regexpr("<candidate[^>]*>", z))
      data.table(seat = seat, formal = formal, declared = declared, declared_party = dpc,
                 pos = as.integer(attr_of(h, "ballotOrderNumber")),
                 ballot_name = attr_of(h, "ballotName"), code = attr_of(h, "party"),
                 sitting = attr_of(h, "sitting"), gender = attr_of(h, "gender"),
                 surname = sub("</surname>.*", "", sub(".*<surname>", "", z)),
                 given = sub("</givenNames>.*", "", sub(".*<givenNames>", "", z)),
                 votes = num_in(z, "primaryVotes"), n2cp = num_in(z, "n2cpVotes"))
    }))
    bs <- regmatches(d, gregexpr("(?s)<booth\\b.*?</booth>", d, perl = TRUE))[[1]]
    booth_rows[[length(booth_rows) + 1L]] <- rbindlist(lapply(bs, function(z) {
      h <- regmatches(z, regexpr("<booth[^>]*>", z))
      bc <- regmatches(z, gregexpr('<boothCandidate ballotOrderNumber="[0-9]+"><primaryVotes>[0-9]+', z))[[1]]
      data.table(seat = seat, booth_id = attr_of(h, "id"), booth = attr_of(h, "name"),
                 booth_in = attr_of(h, "in"), type = attr_of(h, "typeCode"),
                 formal = num_in(z, "formalVotes"), informal = num_in(z, "informalVotes"),
                 pos = as.integer(sub('".*', "", sub('.*ballotOrderNumber="', "", bc))),
                 votes = as.numeric(sub(".*>", "", bc)))
    }), fill = TRUE)
  }
  cd <- rbindlist(cand_rows); bt <- rbindlist(booth_rows, fill = TRUE)
  fwrite(cd, file.path(rawd, "candidates.csv")); fwrite(bt, file.path(rawd, "booths.csv"))
  nseat <- uniqueN(cd$seat)
  note(el, "QA21", nseat == E$seats, sprintf("%d districts parsed (expected %d), %d candidates, %s booth-candidate rows",
                                            nseat, E$seats, nrow(cd), format(nrow(bt), big.mark = ",")))
  unk <- setdiff(unique(cd$code), names(PARTY))
  if (length(unk)) { note(el, "QA22", FALSE, paste("party codes missing from the file's table:", paste(unk, collapse = ","))); return(invisible()) }
  cd[, party := classify_party(unname(PARTY[code]), ifelse(code == "ZZZ", "", code))]
  cat(sprintf("QA22 %s party codes -> classes: %s\n", el,
              paste(unique(cd[, paste0(code, "=", party)]), collapse = " ")))
  chk <- cd[, .(s = sum(votes), formal = formal[1]), by = seat][!is.finite(formal) | s != formal]
  note(el, "QA23", nrow(chk) == 0L,
       sprintf("candidate primaries sum to the district formal-vote count in %d of %d districts%s", nseat - nrow(chk), nseat,
               if (nrow(chk)) paste0(" (", paste(sprintf("%s %s vs %s", head(chk$seat, 4), head(chk$s, 4), head(chk$formal, 4)), collapse = "; "), ")") else ""))
  bsum <- merge(bt[, .(bs = sum(votes)), by = seat], cd[, .(cs = sum(votes)), by = seat], by = "seat")
  note(el, "QA24", TRUE, sprintf("booth rows sum to the candidate total in %d of %d districts (informational; booths exclude some vote types in places)",
                                sum(bsum$bs == bsum$cs), nrow(bsum)))
  fp <- cd[, .(votes = sum(votes)), by = .(seat, party)][votes > 0][order(seat, party)]
  # winner: declared attribute when present, else two-candidate leader
  has_tcp <- cd[, any(!is.na(n2cp))]
  w_decl <- cd[!is.na(declared) & ballot_name == declared, .(seat, win = surname)]
  w_tcp <- if (has_tcp) cd[!is.na(n2cp), .SD[which.max(n2cp)], by = seat][, .(seat, win_tcp = surname)] else NULL
  win <- if (nrow(w_decl) == nseat) w_decl else NULL
  winsrc <- "declared attribute"
  if (is.null(win) && has_tcp) {
    # No declared attribute (2004). Two-candidate leader where the file has figures; a seat
    # with none is one where the leader took a majority of first preferences, which is
    # asserted rather than assumed.
    nt <- setdiff(unique(cd$seat), w_tcp$seat)
    pl <- cd[seat %in% nt, .SD[which.max(votes)], by = seat][, .(seat, win = surname, share = votes / formal)]
    note(el, "QA25b", all(pl$share > 0.5),
         sprintf("%d seats have no two-candidate figures; the first-preference leader holds >50%% in %d of them (min %.1f%%): %s",
                 length(nt), sum(pl$share > 0.5), 100 * min(pl$share), paste(nt, collapse = ", ")))
    win <- rbind(w_tcp[, .(seat, win = win_tcp)], pl[, .(seat, win)])
    winsrc <- "two-candidate leader, else majority first-preference leader"
  }
  if (!is.null(w_tcp) && nrow(w_decl) == nseat) {
    m <- merge(w_decl, w_tcp, by = "seat")
    note(el, "QA25", all(m$win == m$win_tcp), sprintf("declared winner equals two-candidate leader in %d of %d districts with both", sum(m$win == m$win_tcp), nrow(m)))
  }
  # AE cross-check
  ae <- read_ae(file.path(AE_DIR, sprintf("results_%dqld.csv", y)))
  ae[, seat_k := norm_seat(seat)]
  cd[, seat_k := norm_seat(seat)]
  aw <- ae_winner(ae); aw[, seat_k := norm_seat(seat)]
  if (!is.null(win)) {
    win[, seat_k := norm_seat(seat)]
    cmp <- merge(win[, .(seat_k, seat, win)], aw[, .(seat_k, ae_name)], by = "seat_k", all = TRUE)
    cmp[, hit := mapply(function(a, b) !is.na(a) && !is.na(b) && grepl(norm(a), norm(b), fixed = TRUE), win, ae_name)]
    note(el, "QA26", all(cmp$hit), sprintf("winner (%s) matches AE archive winner in %d of %d seats%s", winsrc, sum(cmp$hit), nrow(cmp),
                                           if (any(!cmp$hit)) paste0(" (differ: ", paste(head(cmp[hit == FALSE, ifelse(is.na(seat), seat_k, seat)], 6), collapse = ", "), ")") else ""))
  } else note(el, "QA26", FALSE, "no declared winner and no two-candidate figures in this file")
  afp <- ae[sec == "fp", .(ae_votes = sum(votes)), by = seat_k]
  cv <- merge(afp, cd[, .(votes = sum(votes)), by = seat_k], by = "seat_k")
  note(el, "QA27", TRUE, sprintf("AE archive first-preference totals within 0.2%% of ECQ in %d of %d seats; exactly equal in %d (informational)",
                                sum(abs(cv$ae_votes / cv$votes - 1) < 0.002), nrow(cv), sum(cv$ae_votes == cv$votes)))
  # candidate-level agreement with AE: same vote count appears for the candidate surname
  aefp <- ae[sec == "fp"]
  aefp[, k := paste(seat_k, votes)]
  cd[, k := paste(seat_k, votes)]
  note(el, "QA28", TRUE, sprintf("candidate vote counts present in the AE archive for %d of %d ECQ candidates (informational)", sum(cd$k %in% aefp$k), nrow(cd)))
  if (has_tcp) {
    tcq <- cd[!is.na(n2cp), .(ecq = sum(n2cp)), by = seat_k]
    atc <- ae[sec == "tcp", .(ae_tcp = sum(votes)), by = seat_k]
    m <- merge(tcq, atc, by = "seat_k")
    r <- m$ecq / m$ae_tcp
    note(el, "QA28b", TRUE, sprintf("ECQ two-candidate total vs AE archive two-candidate total: equal in %d of %d seats, median ratio %.3f, min %.3f (informational)",
                                   sum(m$ecq == m$ae_tcp), nrow(m), median(r), min(r)))
  }
  if (y == 2017) {
    old <- fread(file.path(OUT, "ecq-2017-qld-firstprefs.csv"))
    m <- merge(old, fp, by = c("seat", "party"), all = TRUE, suffixes = c("_old", "_new"))
    same <- m[, sum(votes_old == votes_new, na.rm = TRUE)]
    note(el, "QA29", nrow(m) == same && !anyNA(m$votes_old) && !anyNA(m$votes_new),
         sprintf("new ECQ download equals existing ecq-2017-qld-firstprefs.csv in %d of %d seat-party rows; not overwritten", same, nrow(m)))
    return(invisible())
  }
  if (sum(rbindlist(SUMMARY)[election == el & check %in% c("QA20", "QA21", "QA23"), !ok]) == 0L) {
    fwrite(fp, file.path(OUT, sprintf("ecq-%d-qld-firstprefs.csv", y)))
    cat(sprintf("QA30 wrote ecq-%d-qld-firstprefs.csv (%d rows, %d seats)\n", y, nrow(fp), uniqueN(fp$seat)))
    if (has_tcp) {
      tc <- cd[!is.na(n2cp), .(seat, party, votes = n2cp)][order(seat, -votes)]
      per <- tc[, .N, by = seat]
      note(el, "QA31", all(per$N == 2L),
           sprintf("two-candidate rows: %d of %d seats carry figures, %d of those with exactly two candidates; seats without are left out of the tcp file", nrow(per), nseat, sum(per$N == 2L)))
      fwrite(tc, file.path(OUT, sprintf("ecq-%d-qld-tcp.csv", y)))
      cat(sprintf("QA32 wrote ecq-%d-qld-tcp.csv (%d rows)\n", y, nrow(tc)))
    } else note(el, "QA31", TRUE, "no two-candidate figures (n2cpVotes) in this file; no tcp file written")
  } else cat("QA30! internal checks failed; NOT writing outputs for", el, "\n")
  invisible()
}
for (E in QLD) { Sys.sleep(1); tryCatch(run_qld(E), error = function(e) note(sprintf("qld%d", E$y), "QAERR", FALSE, conditionMessage(e))) }

S <- rbindlist(SUMMARY)
fwrite(S, file.path("external", "reference", "ecq", "raw", "verification-summary.csv"))
cat(sprintf("\nQA99 %d checks, %d failed\n", nrow(S), sum(!S$ok)))
print(S[ok == FALSE, .(election, check, detail)], row.names = FALSE)
