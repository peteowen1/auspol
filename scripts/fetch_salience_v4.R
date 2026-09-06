# Salience v4: batch ACROSS seats, not within them.
#
# THE PROBLEM v3 COULD NOT SOLVE. Google Trends renormalises 0-100 WITHIN each
# query, so two candidates queried separately are not comparable. Measured
# directly:
#
#   separate queries   Chaney 26.18 | Tink 25.22 | Dai Le  8.25
#   ONE query (truth)  Chaney 18.99 | Tink 12.74 | Dai Le 17.50
#
# Separate queries put Dai Le at a third of Chaney; in truth she is nearly level
# with her. Both Chaney and Tink read ~25 alone only because each topped their
# own query -- an artefact, not a measurement. Pete caught this: a per-seat
# design has no common reference and cannot be compared across seats.
#
# THE PM LINK RECOVERS THE ORDERING BUT LOSES RESOLUTION. Against Morrison the
# three read 1.18, 1.11 and 1.38 out of 100, integer-rounded -- the right
# ranking on a four-value scale.
#
# SO: BATCH ACROSS SEATS. Five seats' leading non-majors in one query gives
# direct comparability AND full resolution, and consumes no slot for an anchor.
# Batches are chained on an overlapping candidate to put every batch on one
# scale. Since only each seat's strongest non-major is needed for the hazard,
# this is ONE query per five seats -- cheaper than per-seat as well as better.
#
# THE OVERLAP IS THE LOUDEST SO FAR, never a quiet one: rescaling divides by the
# overlap's value in the new batch, and a near-zero divisor blows up every seat
# downstream. An overlap returning zero is reported and the batch is dropped.
#
# STATISTIC: `jump` = campaign mean - pre-campaign baseline. On the unbiased
# sample level and jump tie (0.925 / 0.921) and both beat ratio (0.880) and
# rise (0.857), but jump is the one that survives a namesake -- Cameron Smith
# the footballer outranks every teal on level and falls below them on jump.
#
# GEO: national. Weekly buckets keep quiet candidates above Google's publishing
# threshold nationally (Chandler-Mather 9.99, Dai Le 8.25), and a national geo
# removes the state-size effect that per-state measurement introduces.
#
# NO LEAKAGE: the window ends the day before polling day.
#
# Emits S4* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))

MAJ   <- c("ALP", "LNP", "NAT")
GEO   <- "AU"
SPAN  <- 300L
WEEKS <- 8L
MAXKW <- 5L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "5"))
MAX_BATCH <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAXBATCH", "12"))
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

POLL <- c(fed2010 = "2010-08-21", fed2013 = "2013-09-07", fed2016 = "2016-07-02",
          fed2019 = "2019-05-18", fed2022 = "2022-05-21", fed2025 = "2025-05-03",
          vic2018 = "2018-11-24", vic2022 = "2022-11-26", vic2026 = "2026-11-28")

qry <- function(kw, to) {
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("v4-%s-%s-%s", GEO, to, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = GEO,
                          time = paste(as.Date(to) - SPAN, to), onlyInterest = TRUE),
                  error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(12 * att)
  }
  if (is.null(r) || is.null(r$interest_over_time)) {
    saveRDS(list(empty = TRUE), f); return(NULL)
  }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  out <- d[, .(keyword, date, hits)]
  saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date()), f)  # RAW series
  out
}

jump_of <- function(series) {
  cutoff <- max(series$date) - WEEKS * 7L
  a <- series[date >  cutoff, .(camp = mean(hits)), by = keyword]
  b <- series[date <= cutoff, .(base = mean(hits)), by = keyword]
  m <- merge(a, b, by = "keyword", all.x = TRUE)[is.na(base), base := 0]
  m[, jump := camp - base][]
}

# ---- who to query -----------------------------------------------------------
C <- fread("output/candidacies.csv", showProgress = FALSE)
EL <- Sys.getenv("AUSPOL_SALIENCE_ELECTION", "fed2022")
yr <- as.integer(sub("^[a-z]+", "", EL)); rg <- sub("[0-9]+$", "", EL)
D <- C[region == rg & year == yr & !party %in% MAJ]
if (!nrow(D)) stop("no non-major candidates for ", EL)
D[, kw := search_form(given, surname, name)]

# ONE CANDIDATE PER SEAT: the hazard is a per-seat quantity and the surge lifts
# one candidate, so the seat's strongest non-major is what matters.
#
# PICK BY THE PREVIOUS ELECTION'S NON-MAJOR VOTE IN THAT SEAT, not by party
# class. Party priority (IND above GRN, unconditionally) missed FOUR of the
# eighteen non-major winners in fed2022, including Adam Bandt: Melbourne runs a
# no-hope independent, the rule ranked them above the sitting Greens MP, and the
# seat was queried for the wrong person. Bob Katter, Marion Scrymgour and Luke
# Gosling went the same way.
#
# LEAK-FREE: the prior election's result was published years earlier. Picking by
# THIS election's vote would be leakage.
prev_yr <- max(C[region == rg & year < yr, year], na.rm = TRUE)
PREV <- C[region == rg & year == prev_yr & !party %in% MAJ,
          .(seat, party, prev_pcv = pcv)]
D <- merge(D, PREV, by = c("seat", "party"), all.x = TRUE)
D[!is.finite(prev_pcv), prev_pcv := 0]
# Ties, and seats with no prior non-major at all, fall back to party class so
# the choice is never arbitrary.
PRIO <- c(IND = 1, GRN = 2, ONP = 3, OTH_RIGHT = 4, OTH = 5)
D[, prio := as.integer(PRIO[party])][is.na(prio), prio := 5L]
setorder(D, seat, -prev_pcv, prio)
S <- D[, .SD[1], by = seat]
S <- S[!is.na(kw) & nzchar(kw)]
cat(sprintf("S4-0 per-seat pick by %d non-major vote (ties -> party class)
", prev_yr))

# ORDER THE CHAIN BY PRIOR NON-MAJOR STRENGTH, not by seat name. Every batch is
# rescaled onto the FIRST batch's scale, so if the chain starts on five obscure
# candidates the entire national scale is anchored on near-zero values and every
# rescale divides by noise. Alphabetically the chain would have begun with
# Adelaide, Aston and Ballarat -- three Greens candidates polling 2-20% with no
# search presence.
#
# LEAK-FREE: the ordering uses the PREVIOUS election's non-major vote in that
# seat, published years earlier. Ordering by THIS election's vote would be
# leakage; ordering by how loud they turn out to be would be circular.
PB <- C[region == rg & year == prev_yr & !party %in% MAJ,
        .(prev_nm = max(pcv, na.rm = TRUE)), by = seat]
S <- merge(S, PB, by = "seat", all.x = TRUE)
S[!is.finite(prev_nm), prev_nm := 0]
setorder(S, -prev_nm)
cat(sprintf("S4-0 chain ordered by %d non-major vote; starts with %s (%.1f%%)
",
            prev_yr, S$kw[1], S$prev_nm[1]))
cat(sprintf("S4-1 %s: %d seats, one non-major each | 5 per query, chained\n",
            EL, nrow(S)))

to <- as.Date(POLL[[EL]]) - 1
kws <- unique(S$kw)
first <- qry(utils::head(kws, MAXKW), to)
if (is.null(first)) stop("the first batch returned nothing; cannot anchor the chain")
acc <- jump_of(first)[, .(keyword, jump)]
rest <- kws[-seq_len(min(MAXKW, length(kws)))]
nb <- 1L
while (length(rest) && nb < MAX_BATCH) {
  ov <- acc[which.max(jump), keyword]     # loudest so far: never divide by ~0
  take <- utils::head(rest, MAXKW - 1L)
  s <- qry(c(ov, take), to)
  nb <- nb + 1L
  if (is.null(s)) {
    cat(sprintf("S4!  batch failed; %d candidate(s) dropped\n", length(take)))
    rest <- rest[-seq_along(take)]; next
  }
  m <- jump_of(s)
  ovv <- m[keyword == ov, jump]
  if (!length(ovv) || !is.finite(ovv) || ovv <= 0) {
    cat(sprintf("S4!  overlap %s came back %.2f -- cannot rescale, %d dropped\n",
                ov, if (length(ovv)) ovv else NA_real_, length(take)))
    rest <- rest[-seq_along(take)]; next
  }
  sc <- acc[keyword == ov, jump] / ovv
  add <- m[keyword != ov, .(keyword, jump = jump * sc)]
  acc <- rbind(acc, add)
  rest <- rest[-seq_along(take)]
  Sys.sleep(SLEEP)
}
cat(sprintf("S4-2 %d batches | %d candidates on one scale | %d not reached\n",
            nb, nrow(acc), length(rest)))

R <- merge(S[, .(seat, keyword = kw, party, pcv, elected)], acc, by = "keyword")
R[, election := EL]
fwrite(R, sprintf("output/salience-v4-%s.csv", EL))
setorder(R, -jump)
cat("\nS4-9 loudest 20, one scale, comparable across seats\n")
print(utils::head(R[, .(seat, keyword, party, pct = round(pcv, 1),
                        won = elected, jump = round(jump, 2))], 20),
      row.names = FALSE)
if (uniqueN(R$elected) > 1) {
  n1 <- sum(R$elected, na.rm = TRUE); n0 <- nrow(R) - n1
  rk <- rank(R$jump)
  cat(sprintf("\nS4-9 AUC %.3f over %d winners and %d others\n",
              (sum(rk[which(R$elected)]) - n1 * (n1 + 1) / 2) / (n1 * n0), n1, n0))
}
