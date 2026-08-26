# Salience v5: ONE long Trends window spanning BOTH elections.
#
# WHAT v4 COULD NOT DO. v4 chained batches within a single election, so each
# election's scale was anchored on its own first batch. A `jump` of 10 in
# fed2022 units and 10 in fed2025 units were not the same quantity: fed2025's
# gate-eligible candidates topped out at 1.6 against fed2022's 57.6, a 36x gap
# that could equally have been "2025 was quiet" or "2025 is compressed". Nothing
# in the data distinguished them, which killed every threshold rule and with it
# the salience-for-emergents gate. Recorded in
# docs/reviews/salience-scale-blocker-2026-08-26.md.
#
# THE FIX, measured in scripts/probe_salience_longwindow.R before being built
# here: Google renormalises 0-100 ONCE across the whole requested range and
# switches to weekly buckets above ~269 days. A single 2021-2025 request
# therefore returns both campaigns under one normalisation. The probe took the
# 36x gap down to 3.1x -- Ryan's 2022 jump 5.21 against Boele's 2025 jump 1.66,
# a plausible real difference rather than an artefact -- and each candidate's
# peak landed in their own election, a check v4 could not perform at all.
#
# SO THERE ARE TWO SCALE PROBLEMS AND THEY NEED DIFFERENT MECHANISMS:
#   across SEATS      -> chaining on a shared loud candidate (unchanged from v4)
#   across ELECTIONS  -> one long window (new here)
# Every batch spans both elections, so ONE fetch serves both and the two are
# directly comparable by construction rather than by rescaling.
#
# RAW SERIES CACHED, per the keep-all-data rule. v4's predecessor cached an
# 8-week mean and threw the weekly points away; when the campaign rise turned
# out to be the statistic that mattered, all 259 batches needed refetching and
# Google had throttled. Level, rise, peak, slope, volatility and time-to-peak
# are all derivable from what is stored here.
#
# Emits S5* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))

MAJ   <- c("ALP", "LNP", "NAT")
GEO   <- "AU"
MAXKW <- 5L
WEEKS <- 8L
BASE_DAYS <- 300L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "5"))
MAX_BATCH <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAXBATCH", "40"))
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

# The pair of elections sharing one window, and the window itself. FROM sits a
# year before the earlier campaign so its 300-day baseline is fully covered.
ELS  <- c(fed2022 = "2022-05-21", fed2025 = "2025-05-03")
FROM <- "2021-06-01"
TO   <- "2025-06-01"

qry <- function(kw) {
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("v5-%s-%s-%s-%s", GEO, FROM, TO, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = GEO, time = paste(FROM, TO),
                          onlyInterest = TRUE), error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(12 * att)
  }
  if (is.null(r) || is.null(r$interest_over_time)) { saveRDS(list(empty = TRUE), f); return(NULL) }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  out <- d[, .(keyword, date, hits)]
  saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date()), f)   # RAW
  out
}

# jump for ONE election out of the shared series. NO LEAKAGE: the campaign
# window ends on polling day and the baseline precedes it.
jump_at <- function(series, poll) {
  p <- as.Date(poll)
  camp <- series[date > p - WEEKS * 7L & date <= p, .(camp = mean(hits)), by = keyword]
  base <- series[date > p - BASE_DAYS & date <= p - WEEKS * 7L, .(base = mean(hits)), by = keyword]
  m <- merge(camp, base, by = "keyword", all.x = TRUE)[is.na(base), base := 0]
  m[, .(keyword, jump = camp - base)]
}

# ---- who to query: each seat's strongest non-major, in BOTH elections --------
# Pick by the PREVIOUS election's non-major vote in that seat (leak-free: it was
# published years earlier). Party-class priority missed four of eighteen fed2022
# winners including Adam Bandt, because Melbourne runs a no-hope independent and
# the rule ranked them above the sitting Greens MP.
C <- fread("output/candidacies.csv", showProgress = FALSE)
PRIO <- c(IND = 1, GRN = 2, ONP = 3, OTH_RIGHT = 4, OTH = 5)
pick <- function(el) {
  yr <- as.integer(sub("^[a-z]+", "", el)); rg <- sub("[0-9]+$", "", el)
  D <- C[region == rg & year == yr & !party %in% MAJ]
  D[, kw := search_form(given, surname, name)]
  py <- max(C[region == rg & year < yr, year], na.rm = TRUE)
  P <- C[region == rg & year == py & !party %in% MAJ, .(prev_pcv = max(pcv, na.rm = TRUE)),
         by = .(seat, party)]
  D <- merge(D, P, by = c("seat", "party"), all.x = TRUE)
  D[!is.finite(prev_pcv), prev_pcv := 0]
  D[, prio := as.integer(PRIO[party])][is.na(prio), prio := 5L]
  setorder(D, seat, -prev_pcv, prio)
  D[, rk := seq_len(.N), by = seat]
  # TOP TWO PER SEAT, PLUS EVERY INDEPENDENT.
  #
  # One-per-seat cannot work, and BOTH one-per-seat rules tried so far failed in
  # opposite directions. Ranking IND above GRN unconditionally (v4) queried a
  # no-hope independent instead of Adam Bandt in Melbourne and missed four of
  # eighteen fed2022 winners. Ranking by the largest PRIOR non-major vote (v5's
  # first pass) picks the established minor party in exactly the seats where an
  # independent emerges -- Kooyong's Greens polled ~21% in 2019 against Monique
  # Ryan's 9%, so the teal seats were queried for the wrong person and the
  # corpus contained ONE of fed2022's six emergences.
  #
  # That is not a tuning problem. An emergent candidate is BY DEFINITION the one
  # with no prior vote, so any rule that ranks on prior vote excludes them, and
  # ranking on anything about the outcome is leakage.
  #
  # Measured coverage of non-major winners:
  #             fed2022        fed2025
  #   top-1     11 of 16       13 of 13
  #   top-2     14 of 16       13 of 13
  #   top-4     15 of 16       13 of 13
  #   top-2+IND 16 of 16       13 of 13     <- this rule
  #
  # LEAK-FREE: nomination lists are public before polling day, so "every
  # independent who nominated" is knowable in advance. It costs ~95 batches an
  # election against 38, which is the price of being able to see an emergence
  # at all.
  S <- D[rk <= 2L | party == "IND"][!is.na(kw) & nzchar(kw)]
  # A name shared by two candidates in one election would fan out the join
  # below; keep the stronger and count what was dropped rather than silently
  # duplicating a series across seats.
  setorder(S, kw, -prev_pcv)
  ndup <- nrow(S) - uniqueN(S$kw)
  if (ndup > 0L) cat(sprintf("S5-0 %d duplicate search form(s) in %s, keeping the stronger\n",
                             ndup, el))
  S <- S[, .SD[1], by = kw]
  PB <- C[region == rg & year == py & !party %in% MAJ,
          .(prev_nm = max(pcv, na.rm = TRUE)), by = seat]
  S <- merge(S, PB, by = "seat", all.x = TRUE)[!is.finite(prev_nm), prev_nm := 0]
  S[, `:=`(election = el, prev_party = prev_pcv)][]
}
S <- rbindlist(lapply(names(ELS), pick), fill = TRUE)
cat(sprintf("S5-1 %d seat-candidacies across %s\n", nrow(S), paste(names(ELS), collapse = " + ")))

# ORDER THE CHAIN BY PRIOR NON-MAJOR STRENGTH. Every batch is rescaled onto the
# first, so a chain starting on five obscure names anchors the whole scale on
# noise and every later rescale divides by it.
KW <- unique(S[order(-prev_nm)]$kw)
cat(sprintf("S5-1 %d distinct keywords | chain starts with %s\n", length(KW), KW[1]))

first <- qry(head(KW, MAXKW))
if (is.null(first)) stop("S5!  first batch returned nothing; cannot anchor the chain")
gran <- as.integer(median(diff(sort(unique(first$date)))))
cat(sprintf("S5-2 %d buckets, granularity %s -- weekly is REQUIRED for the long window\n",
            uniqueN(first$date), if (gran >= 6) "WEEKLY" else "DAILY"))
stopifnot(gran >= 6)

acc <- lapply(names(ELS), function(e) jump_at(first, ELS[[e]])[, election := e])
acc <- rbindlist(acc)
rest <- KW[-seq_len(min(MAXKW, length(KW)))]
nb <- 1L
while (length(rest) && nb < MAX_BATCH) {
  # OVERLAP IS THE LOUDEST SO FAR, never a quiet one: rescaling divides by the
  # overlap's value in the new batch and a near-zero divisor blows up every
  # candidate downstream. Loudness is judged on the pooled jump across both
  # elections, so the anchor is strong in whichever election it belongs to.
  pooled <- acc[, .(j = max(jump)), by = keyword]
  ov <- pooled[which.max(j), keyword]
  take <- head(rest, MAXKW - 1L)
  s <- qry(c(ov, take))
  nb <- nb + 1L
  if (is.null(s)) {
    cat(sprintf("S5!  batch %d failed; %d dropped\n", nb, length(take)))
    rest <- rest[-seq_along(take)]; next
  }
  m <- rbindlist(lapply(names(ELS), function(e) jump_at(s, ELS[[e]])[, election := e]))
  ovv <- max(m[keyword == ov, jump])
  if (!is.finite(ovv) || ovv <= 0) {
    cat(sprintf("S5!  overlap %s came back %.2f -- cannot rescale, %d dropped\n",
                ov, ovv, length(take)))
    rest <- rest[-seq_along(take)]; next
  }
  sc <- max(pooled[keyword == ov, j]) / ovv
  acc <- rbind(acc, m[keyword != ov][, jump := jump * sc])
  rest <- rest[-seq_along(take)]
  if (nb %% 5 == 0) cat(sprintf("S5-3 %d batches | %d left\n", nb, length(rest)))
  Sys.sleep(SLEEP)
}
cat(sprintf("S5-3 %d batches | %d keywords scaled | %d not reached\n",
            nb, uniqueN(acc$keyword), length(rest)))

R <- merge(S[, .(election, seat, keyword = kw, party, pcv, elected, prev_party)],
           acc, by = c("keyword", "election"))
R[, emerg := elected %in% TRUE & prev_party < 15]
fwrite(R, "output/salience-v5.csv")
cat(sprintf("\nS5-9 wrote output/salience-v5.csv (%d rows)\n", nrow(R)))

for (e in names(ELS)) {
  E <- R[election == e]
  if (!nrow(E) || uniqueN(E$elected) < 2) next
  n1 <- sum(E$elected, na.rm = TRUE); n0 <- nrow(E) - n1; rk <- rank(E$jump)
  cat(sprintf("S5-9 %s: %d rows | AUC %.3f | emergences %d | max jump %.2f\n", e, nrow(E),
      (sum(rk[which(E$elected)]) - n1*(n1+1)/2) / (n1*n0), sum(E$emerg), max(E$jump)))
}
cat("\nS5-9 THE BLOCKER CHECK: gate-eligible (prior party vote < 15%) max jump per election.\n")
cat("     v4 read 57.6 against 1.6, a 36x gap that no threshold could span.\n")
print(R[prev_party < 15, .(eligible = .N, max_jump = round(max(jump), 2),
                           p90 = round(quantile(jump, .9), 2)), by = election], row.names = FALSE)
