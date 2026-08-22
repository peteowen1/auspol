# Western Australian state election results, from the WAEC's own results API.
#
# The access chain is recorded in docs/plans/waec-data-access.md and is not
# repeated here. Base: https://eis.waec.wa.gov.au/api, no key, no auth.
#
# WHY. The binding constraint on nearly every measurement in this repo is the
# number of ELECTIONS, not seats. Queensland took the flow matrix from 746
# exclusion events to 1,496 and moved Victoria's One Nation median from 5 seats
# to 9. Western Australia offers up to eight more elections, and One Nation has
# contested there since 1997.
#
# HOW A ROUND IS READ. `resultsFullDistribution` gives, per round, one row per
# candidate. The EXCLUDED candidate's row is NEGATIVE -- that is their pile
# leaving -- and every positive row is what that candidate received. The
# excluded candidate is not named anywhere else, so the sign IS the
# identification.
#
# EXHAUSTION IS CHECKED, NOT ASSUMED. Adding compulsory-preferential Queensland
# transfers to optional-preferential NSW cost 0.194 of log score earlier today.
# Western Australia's Legislative Assembly is full preferential and should
# exhaust almost nothing, but the rows carry an exhausted count, so the rate is
# measured per election and a material one aborts rather than quietly polluting
# the matrix.
#
# Emits WF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

API <- "https://eis.waec.wa.gov.au/api"
RAW <- file.path("external", "reference", "waec")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)
# Recent elections first: 2017->2021 and 2021->2025 are the backtest pairs, and
# 2025wa.txt already exists as a seat file. Earlier ones are reachable the same
# way and can be appended here.
WANT <- strsplit(Sys.getenv("AUSPOL_WA_ELECTIONS", "sg2017,sg2021,sg2025"), ",")[[1]]
EXHAUST_LIMIT <- 0.02

get_json <- function(path, cache) {
  f <- file.path(RAW, cache)
  if (!file.exists(f) || file.info(f)$size < 200) {
    utils::download.file(paste0(API, path), f, quiet = TRUE, mode = "wb")
    Sys.sleep(0.15)   # be polite: this runs to ~180 calls
  }
  jsonlite::fromJSON(f, simplifyVector = FALSE)
}

# WESTERN AUSTRALIA PUBLISHES A CODE AND NO PARTY NAME. classify_party() works
# mostly on names, so a bare code reaches none of its rules and lands in OTH --
# silently, because OTH is a legitimate class rather than an error. In 2025
# that swallowed the Nationals' six won seats, 27 independents, the Shooters in
# 26 districts and Australian Christians in 54.
#
# So each code is expanded to a party NAME before classifying. The values are
# not invented: they are the strings the WAEC itself publishes in
# LASeatsByParty, and WF1c refuses any that is not. That check cannot prove a
# code means a particular name -- only that the name is the commission's own --
# which is why the declared-seat anchor in WF5 exists as well.
WA_PARTY <- c(
  # 1996-2008 the commission wrote "Australian Labor Party" and "NATIONAL
  # PARTY"; from 2013 "WA Labor" and "THE NATIONALS". The spelling moves, so
  # WF1c checks names against the union across elections, not one election.
  ALP    = "Australian Labor Party", LIB  = "Liberal Party",
  NP     = "NATIONAL PARTY",         NAT  = "THE NATIONALS",
  NATS   = "The Nationals WA",       GRN  = "The Greens (WA)",
  IND    = "Independent",
  # One Nation appears under THREE codes across the eight elections, which is
  # the single most important thing this map gets right: PHO in 2001 is 54
  # candidates and ONP in 2005 is 45, and either one lost to OTH would remove
  # most of the One Nation preference evidence Western Australia exists to add.
  PHO    = "Pauline Hanson's ONE NATION",
  ONP    = "ONE NATION",
  PHON   = "Pauline Hanson's One Nation",
  # Christian and other minor-right.
  AC     = "Australian Christians",  ACP  = "Australian Christians",
  CDP    = "Christian Democratic Party WA",
  CTA    = "Call To Australia (WA)", FFP  = "Family First",
  CEC    = "CITIZENS ELECTORAL COUNCIL",
  NCO    = "New Country Party",      AFP  = "Australia First Party",
  SFF    = "SFFPWA",                 SFFP = "Shooters, Fishers and Farmers",
  LDP    = "Liberal Democrats",      Libertarian = "Libertarian",
  # Everything below lands in OTH, and does so deliberately rather than by
  # falling through: see WF6, which prints the OTH members every run.
  AD     = "Australian Democrats",   DEM  = "Australian Democrats",
  AJP    = "Animal Justice Party",   AMP  = "Australian Marijuana Party",
  APP    = "The Australian People's Party",
  ARP    = "Australian Reform Party WA",
  CLM    = "CALM Resistance Movement",
  FLUX   = "Flux The System!",       LCWA = "Legalise Cannabis Party WA",
  LFC    = "Liberals For Climate",   MBP  = "Micro Business Party",
  SA     = "Socialist Alliance",
  SAPSOC = "SUSTAINABLE AUSTRALIA PARTY - STOP OVERDEVELOPMENT / CORRUPTION",
  SPPk   = "Stop Pedophiles! Protect kiddies!",
  WAP    = "WESTERN AUSTRALIA PARTY",
  # NO MANDATORY VACCINATION ran 59 candidates in 2021 and WAxit 48. Both are
  # right-populist in flavour and both sit in OTH because no rule names them.
  # Moving them is a modelling decision with real consequences for the OTH row
  # of the flow matrix, so it is left for a measured one rather than taken here.
  NMV    = "NO MANDATORY VACCINATION", WAXIT = "WAxit")

# One spelling for both sides of the join. The distribution writes an
# independent as a bare surname and upper-cases every party code; the candidate
# list keeps the code's own case and stores the party separately. Comparing
# them raw silently loses whoever differs.
# NOT ifelse(). `ifelse(test, yes, no)` returns a vector shaped like TEST, so
# with a scalar `party` it returned ONE element regardless of how many names it
# was given -- truncating every distribution round to its first recipient and
# taking the WA transfer file from 5,770 rows to 1,658. It was caught by the
# row count moving, not by any check, which is why WF1b now guards `to` as well.
norm_key <- function(name, party) {
  nm <- toupper(trimws(name))
  p  <- toupper(trimws(ifelse(is.na(party), "", party)))
  if (length(p) == 1L) p <- rep(p, length(nm))
  has <- nzchar(p)
  nm[has] <- sprintf("%s - %s", nm[has], p[has])
  nm
}

# Expand, then classify. An UNKNOWN CODE ABORTS rather than becoming OTH --
# that is the entire point, since the failure being prevented is a silent OTH.
wa_class <- function(codes, election) {
  cd <- ifelse(is.na(codes) | !nzchar(trimws(codes)), "IND", trimws(codes))
  miss <- setdiff(unique(cd), names(WA_PARTY))
  if (length(miss)) {
    stop(election, ": party code(s) absent from WA_PARTY: ",
         paste(miss, collapse = ", "),
         ". Add each with the name the WAEC publishes in LASeatsByParty. ",
         "Left alone they classify as OTH, which is a real class and so ",
         "reports as success.")
  }
  classify_party(unname(WA_PARTY[cd]), cd)
}


all_fp <- list(); all_tx <- list(); all_win <- list(); exh <- list()
unmatched <- character(0); no_excl <- 0L; multi_excl <- 0L; no_to <- 0L; no_recip <- 0L; seats_by_party <- list(); codes_seen <- list(); three_c <- list(); n_dist <- list()
for (E in WANT) {
  mem <- get_json(sprintf("/sgElections/%s/LAElectedMembers", E),
                  sprintf("%s-members.json", E))
  # NOTE THE SPELLING: the field is ElelctorateType in their payload, and a
  # correct spelling silently matches nothing and yields zero districts.
  els <- Filter(function(x) identical(x$ElelctorateType, "District"), mem$electorates)
  codes <- vapply(els, function(x) x$ElectorateCode, character(1))
  names(codes) <- vapply(els, function(x) x$ElectorateName, character(1))
  cat(sprintf("\nWF1  %s: %d districts\n", E, length(codes)))
  # The commission's own declared seats per party, which WF5 checks against.
  sbp <- mem$LASeatsByParty
  seats_by_party[[E]] <- data.table(
    election = sub("^sg", "wa", E),
    name = vapply(sbp, function(x) x$NAME %||% "", character(1)),
    seats = as.integer(vapply(sbp, function(x) x$NUMBER_OF_SEATS %||% 0, numeric(1))))
  n_dist[[sub("^sg", "wa", E)]] <- length(codes)
  if (length(codes) < 50L) {
    stop(E, ": only ", length(codes), " districts. Western Australia has 59; ",
         "the ElelctorateType filter has probably stopped matching.")
  }

  for (i in seq_along(codes)) {
    seat <- names(codes)[i]; code <- codes[[i]]
    r <- get_json(sprintf("/sgElections/%s/%s/results", E, code),
                  sprintf("%s-%s.json", E, code))
    cands <- r$resultsCandidates
    if (!length(cands)) next
    # BALLOT_PAPER_NAME in the distribution is "SURNAME - CODE"; the candidate
    # list splits the two, so the key is rebuilt rather than parsed back out.
    # Rebuilt through norm_key(), because the two sides do not agree on form:
    # an INDEPENDENT has no party suffix at all in the distribution ("BELL",
    # not "BELL - "), and the distribution upper-cases the code ("LING - SPPK"
    # against the candidate list's "SPPk"). Those two differences dropped 42
    # exclusion rounds, silently, until WF1b was made to abort on them.
    key <- vapply(cands, function(c)
      norm_key(c$BALLOT_PAPER_NAME %||% "", c$PARTY_AFFILIATION %||% ""),
      character(1))
    raw <- vapply(cands, function(c) c$PARTY_AFFILIATION %||% "", character(1))
    codes_seen[[length(codes_seen) + 1L]] <- data.table(election = E, code = raw)
    # THREE-CORNERED SEATS, against docs/plans/prereg-wa-three-cornered.md.
    # A seat where both a Liberal and a National contested. WA runs them
    # against each other in rural seats, so the pair surviving the late rounds
    # is often two Coalition candidates and nearly every transfer resolves to
    # LNP by construction -- which is what refusal W2 measured and what the
    # refused WA arm was diagnosed on. Marked per SEAT here so the filter can
    # be applied downstream without re-deriving it from raw payloads.
    three_c[[length(three_c) + 1L]] <- data.table(
      election = sub("^sg", "wa", E), seat = seat,
      three_cornered = any(raw %in% "LIB") &&
                       any(raw %in% c("NAT", "NATS", "NP")))
    cls <- wa_class(raw, E)
    look <- setNames(cls, key)

    all_fp[[length(all_fp) + 1L]] <- data.table(
      election = sub("^sg", "wa", E), seat = seat,
      party = unname(cls),
      votes = as.numeric(vapply(cands, function(c) c$Votes_Counted %||% 0, numeric(1))))

    fd <- r$resultsFullDistribution
    if (length(fd)) {
      lv <- vapply(fd, function(x) x$DISTRIBUTION_LEVEL %||% "", character(1))
      for (L in grep("^Distribution ", unique(lv), value = TRUE)) {
        rows <- fd[lv == L]
        val <- vapply(rows, function(x) as.numeric(x$FORMAL_LAST_PUBLISHED_NUMBER_ENTERED %||% 0), numeric(1))
        nm  <- vapply(rows, function(x) x$BALLOT_PAPER_NAME %||% "", character(1))
        ex  <- max(vapply(rows, function(x) as.numeric(x$EXHAUSTED_LAST_PUBLISHED_NUMBER_ENTERED %||% 0), numeric(1)))
        out <- which(val < 0)
        # Two silent skips used to live here. Every Distribution round should
        # carry exactly ONE negative row -- the excluded candidate's pile
        # leaving -- so neither zero nor two is expected, and a round dropped
        # for either reason shrinks the transfer pool with nothing to show it.
        # Counted, and both counts are asserted at WF1b.
        if (length(out) == 0L) { no_excl <- no_excl + 1L; next }
        if (length(out) > 1L)  { multi_excl <- multi_excl + 1L; next }
        # SINGLE bracket. `look[["missing"]]` THROWS on an atomic vector, so a
        # name the candidate list does not carry kills the run rather than
        # skipping a round -- the trap CLAUDE.md records. Unmatched names are
        # collected and ABORTED ON at WF1b below -- a stronger claim than the
        # comment that used to sit here made, and unlike it, a true one.
        from <- unname(look[norm_key(nm[out], "")])
        got <- which(val > 0)
        # TWO conditions, counted apart. An unmatched name is a parse failure;
        # a round with no positive recipient is every remaining vote in the
        # pile exhausting at once, which full-preferential voting makes rare
        # but not impossible. Reporting both as "unmatched name" would send a
        # future reader after the wrong cause -- the same misdiagnosis this
        # file just fixed in score_wa_flows.R.
        if (is.na(from)) { unmatched <- c(unmatched, nm[out]); next }
        if (!length(got)) { no_recip <- no_recip + 1L; next }
        exh[[length(exh) + 1L]] <- data.table(
          election = sub("^sg", "wa", E), pile = abs(val[out]), exhausted = ex)
        to <- unname(look[norm_key(nm[got], "")])
        # An unmatched RECIPIENT was dropped by the !is.na(to) filter below with
        # nothing to show for it, which is how the ifelse() truncation above
        # survived a run. Counted here and aborted on at WF1b.
        no_to <- no_to + sum(is.na(to))
        all_tx[[length(all_tx) + 1L]] <- data.table(
          election = sub("^sg", "wa", E), seat = seat,
          round = as.integer(sub("Distribution ", "", L)),
          from = from, to = to, votes = val[got])
      }
    }

    tcp <- r$results2CP
    if (length(tcp) >= 2L) {
      v <- vapply(tcp, function(x) as.numeric(x$Votes_Counted %||% 0), numeric(1))
      n <- vapply(tcp, function(x) x$Ballot_Paper_Name %||% "", character(1))
      w <- unname(look[norm_key(n[which.max(v)], "")])
      if (!is.na(w)) all_win[[length(all_win) + 1L]] <- data.table(
        election = sub("^sg", "wa", E), seat = seat, winner = w)
    }
  }
}

FP <- rbindlist(all_fp)[!is.na(party), .(votes = sum(votes)), by = .(election, seat, party)]
TX <- rbindlist(all_tx)[!is.na(from) & !is.na(to) & votes > 0,
                        .(votes = sum(votes)), by = .(election, seat, round, from, to)]

# T2 of the pre-registration: the marker is EMITTED and PRINTED. A flag that
# silently marked nothing would make the filtered arm identical to the already-
# refused whole-WA arm, and their scores alone could not tell the two apart.
TC <- rbindlist(three_c)
TX <- merge(TX, TC, by = c("election", "seat"), all.x = TRUE)
# A TRIP-WIRE, not a live check: TC and TX are built in the same loop behind
# the same guard, so every seat with transfers necessarily has a marker and
# this cannot currently fire. It is here so a future refactor that breaks
# that invariant fails loudly, and it must not be read as evidence the
# coverage logic was tested.
if (anyNA(TX$three_cornered)) {
  stop("Transfers exist for seats with no three-cornered marker, so the 
       filter would drop or keep them by accident.")
}
cat("\nWF3b three-cornered seats: both a Liberal and a National contested\n")
print(TC[, .(seats = .N, three_cornered = sum(three_cornered),
             pct = round(100 * mean(three_cornered))), by = election][order(election)])
cat(sprintf("WF3b %d of %d seats are three-cornered (%.0f%%)\n",
            sum(TC$three_cornered), nrow(TC), 100 * mean(TC$three_cornered)))
if (!any(TC$three_cornered)) {
  stop("No seat is marked three-cornered, which cannot be true of Western 
       Australia and would make the filtered arm a copy of the unfiltered one.")
}
WIN <- rbindlist(all_win)
CODES <- rbindlist(codes_seen)
EX <- rbindlist(exh)[, .(pile = sum(pile), exhausted = sum(exhausted)), by = election]
EX[, rate := exhausted / pile]

# WF1b  THE SKIPS, REPORTED. `unmatched` was collected and never printed, while
# the comment beside it claimed it was reported at the end -- so a round whose
# excluded candidate could not be matched to a party vanished from the transfer
# pool and the WF4 row count still read as complete. That is the exact failure
# this repo keeps meeting, occurring inside the code written to avoid it.
#
# All FIVE counts are ZERO across the eight elections as of 2026-08-21, which
# is why they abort rather than warn: there is no known-good nonzero value, so
# any of them appearing means the parse has changed.
cat(sprintf("\nWF1b skipped: %d unmatched excluded name, %d unmatched recipient,\n%d rounds with no recipient, %d with no exclusion, %d with several\n",
            length(unmatched), no_to, no_recip, no_excl, multi_excl))
if (length(unmatched) || no_to || no_recip || no_excl || multi_excl) {
  stop("Rounds were dropped from the transfer pool. Unmatched name(s): ",
       if (length(unmatched)) paste(unique(unmatched), collapse = ", ") else "none",
       "; unmatched recipients: ", no_to,
       "; rounds where the whole pile exhausted: ", no_recip,
       "; rounds with no negative row: ", no_excl,
       "; rounds with more than one: ", multi_excl,
       ". Each silently shrinks the matrix, and all three were zero when this ",
       "check was written.")
}

cat("\nWF2  exhaustion, which decides whether these may be pooled at all\n")
print(EX[, .(election, pile = format(pile, big.mark = ","),
             exhausted = format(exhausted, big.mark = ","),
             rate = sprintf("%.3f%%", 100 * rate))])
# 2001 exhausts 2.27%, against 0.15-0.88% in the other seven. It is systemic
# rather than a few odd districts -- the median district is 2.27% and 36 of 57
# are over the limit -- and no mechanism for it has been established.
#
# THE LIMIT IS NOT MOVED. Raising it to 3% would admit exactly the election
# that fails, chosen after seeing which one that was, which is the shape of
# rationalisation this repo has been caught by twice. So 2001 is named as an
# exclusion instead, and only its TRANSFERS are dropped: exhaustion cannot
# affect first preferences or declared winners, so those eight elections stay
# whole. Whether including it actually hurts is an open question and belongs in
# a pre-registered run scored the way New South Wales was, not in a threshold.
TRANSFERS_EXCLUDED <- c("wa2001")

bad <- EX[rate > EXHAUST_LIMIT]
unexpected <- setdiff(bad$election, TRANSFERS_EXCLUDED)
if (length(unexpected)) {
  stop("Exhaustion above ", 100 * EXHAUST_LIMIT, "% in: ",
       paste(unexpected, collapse = ", "),
       ". Those transfers may describe a different voting system and must not ",
       "be pooled with full-preferential ones -- the NSW mistake, in reverse. ",
       "Name it in TRANSFERS_EXCLUDED with the rate and a reason, or establish ",
       "why the limit is wrong. Do not raise the limit to fit it.")
}
# An exclusion that quietly stops applying is worse than none, so a named
# election that no longer breaches is reported rather than left in the list.
stale <- setdiff(TRANSFERS_EXCLUDED, c(bad$election, setdiff(TRANSFERS_EXCLUDED, EX$election)))
if (length(stale)) {
  stop("TRANSFERS_EXCLUDED names ", paste(stale, collapse = ", "),
       ", which no longer exceeds the limit. Remove it and re-measure.")
}
drop <- intersect(TRANSFERS_EXCLUDED, EX$election)
if (length(drop)) {
  cat(sprintf("WF2  EXCLUDED from the transfer matrix: %s\n",
              paste(sprintf("%s (%.2f%%)", drop,
                            100 * EX[election %in% drop]$rate), collapse = ", ")))
  cat("WF2  their first preferences and winners are kept -- exhaustion cannot\n")
  cat("WF2  affect either.\n")
}
cat(sprintf("WF2  %d election(s) under %.0f%%: full preferential, safe to pool.\n",
            nrow(EX) - length(drop), 100 * EXHAUST_LIMIT))
TX <- TX[!election %in% TRANSFERS_EXCLUDED]

# COUNTED HERE, after wa2001 is dropped, because this is the table that gets
# written and filtered downstream. Counted before, it described a pool that
# never ships -- a diagnostic reporting something other than what ran, which
# is the failure T2 of the pre-registration exists to prevent.
cat(sprintf("WF3c %d of %d exclusion events sit in a three-cornered seat\n",
            uniqueN(TX[three_cornered == TRUE, paste(election, seat, round)]),
            uniqueN(TX[, paste(election, seat, round)])))

for (E in unique(FP$election)) {
  st <- FP[election == E, .(v = sum(votes)), by = party][, .(party, pct = round(100 * v / sum(v), 2))]
  setorder(st, -pct)
  cat(sprintf("\nWF3  %s: %s formal votes, %d seats\n", E,
              format(FP[election == E, sum(votes)], big.mark = ","),
              uniqueN(FP[election == E, seat])))
  print(st)
  cat(sprintf("WF3  won: %s | %s\n",
              paste(sprintf("%s %d", names(table(WIN[election == E, winner])),
                            as.integer(table(WIN[election == E, winner]))), collapse = ", "),
              if (E %in% TRANSFERS_EXCLUDED) "transfers EXCLUDED (see WF2)" else
                sprintf("%d exclusion events",
                        uniqueN(TX[election == E, paste(seat, round)]))))
}


# WF1c  Are the names in WA_PARTY the commission's own? A name that never
# appears in its published party list is one we invented, and an invented name
# is how a code quietly acquires the wrong class.
#
# Checked against the UNION over elections rather than per election, because
# the WAEC respells parties between polls -- "Legalise Cannabis Western
# Australia Party" in 2021 is "Legalise Cannabis Party WA" in 2025, and
# "Australian Labor Party" becomes "WA Labor" in 2013. Per-election matching
# would therefore reject correct entries. The per-election exactness lives in
# WF5, which compares declared seat counts.
SB <- rbindlist(seats_by_party)
known <- unique(SB$name)
gap <- setdiff(unname(WA_PARTY[unique(CODES$code[nzchar(CODES$code)])]), known)
gap <- gap[!is.na(gap)]
if (length(gap)) {
  stop("WA_PARTY name(s) the WAEC never publishes: ", paste(gap, collapse = "; "),
       ". Use the commission's own spelling, from LASeatsByParty.")
}
cat(sprintf("\nWF1c all %d WA_PARTY names in use are the WAEC's own spelling.\n",
            length(unique(unname(WA_PARTY[unique(CODES$code[nzchar(CODES$code)])])))))

# WF5  THE ANCHOR. The WAEC declares how many seats each party won. Classify
# ITS numbers the way we classify ours, and the two tables must agree exactly.
#
# This is the check that matters, because every bug found here was invisible:
# the Nationals' six seats read as OTH 6 against a true LNP 13, and nothing in
# the output looked wrong -- OTH winning six rural WA seats is entirely
# plausible if you do not already know the answer.
# The commission's published name is classified the same way a candidate is:
# through its code where the name maps back to one (SFFPWA only reaches
# OTH_RIGHT via its code), and by name alone otherwise. "WA Labor" has no code
# in WA_PARTY because candidates there carry ALP, and the name is enough.
rev <- setNames(names(WA_PARTY), unname(WA_PARTY))
SB[, code := rev[name]][is.na(code), code := ""]
SB[, class := classify_party(name, code)]
# A party that WON something and still lands in OTH is the failure this whole
# check exists for: OTH is a real class, so nothing downstream would object.
orphan <- SB[seats > 0 & class == "OTH"]
if (nrow(orphan)) {
  stop("Parties won seats but classify as OTH, so the class is untested: ",
       paste(unique(orphan$name), collapse = "; "),
       ". Give the code a name in WA_PARTY, or a rule to classify_party().")
}
want <- SB[seats > 0, .(want = sum(seats)), by = .(election, class)]
got  <- WIN[, .(got = .N), by = .(election, class = winner)]
cmp  <- merge(want, got, by = c("election", "class"), all = TRUE)
cmp[is.na(want), want := 0L][is.na(got), got := 0L]
setorder(cmp, election, -want)
cat(sprintf("\nWF5  our winners against the WAEC's own declared seat counts\n"))
print(cmp)
if (nrow(cmp[want != got])) {
  stop("WF5 FAILED. Our seat counts disagree with the commission's for: ",
       paste(sprintf("%s %s (theirs %d, ours %d)", cmp[want != got]$election,
                     cmp[want != got]$class, cmp[want != got]$want,
                     cmp[want != got]$got), collapse = "; "))
}
tot <- cmp[, .(n = sum(got)), by = election]
# WA had 57 districts until 2008 and 59 since, so the count is taken from the
# districts actually returned rather than written down as a constant.
tot[, want := unlist(n_dist)[election]]
if (nrow(tot[n != want])) {
  stop("Seat totals wrong in: ",
       paste(sprintf("%s (%d of %d)", tot[n != want]$election,
                     tot[n != want]$n, tot[n != want]$want), collapse = ", "))
}
cat(sprintf("\nWF5  every election matches, %s.\n",
            paste(sprintf("%s %d seats", tot$election, tot$n), collapse = ", ")))

# WF6  What each code became, printed every run. A classification nobody looks
# at is a classification nobody checks, and this table is where the Nationals
# sitting in OTH would have been visible from the first run.
cat(sprintf("\nWF6  party code -> class, with candidate counts\n"))
ct <- CODES[, .(candidates = .N), by = .(code)][order(-candidates)]
ct[, name := unname(WA_PARTY[ifelse(nzchar(code), code, "IND")])]
ct[, class := classify_party(name, ifelse(nzchar(code), code, "IND"))]
print(ct[, .(code, name = substr(name, 1, 34), class, candidates)])
if (nrow(ct[class == "OTH"])) {
  cat(sprintf("WF6  in OTH deliberately: %s\n",
              paste(ct[class == "OTH", code], collapse = ", ")))
}

# Two elections cannot share a statewide vote -- the guard Queensland needed.
w <- dcast(FP[, .(v = sum(votes)), by = .(election, party)][
  , pct := 100 * v / sum(v), by = election], party ~ election, value.var = "pct")
if (ncol(w) > 2L) {
  for (i in 2:(ncol(w) - 1L)) for (j in (i + 1L):ncol(w)) {
    if (isTRUE(all.equal(w[[i]], w[[j]], tolerance = 1e-6))) {
      stop("Elections ", names(w)[i], " and ", names(w)[j], " have identical ",
           "statewide first preferences, which cannot be true.")
    }
  }
}
for (E in unique(FP$election)) {
  fwrite(FP[election == E, .(seat, party, votes)],
         file.path(OUT, sprintf("waec-%s-wa-firstprefs.csv", sub("^wa", "", E))))
}
fwrite(TX, file.path(OUT, "waec-wa-transfers.csv"))
fwrite(WIN, file.path(OUT, "waec-wa-winners.csv"))
cat(sprintf("\nWF4  wrote %d transfer rows and %d winners across %d elections\n",
            nrow(TX), nrow(WIN), uniqueN(FP$election)))
