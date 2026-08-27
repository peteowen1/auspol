# Salience v6: one window and one GEOGRAPHY per election.
#
# WHAT v5 GOT WRONG, in two ways that compounded.
#
# 1. SEARCH TERMS. search_form() built the query from the `given` and `surname`
#    fields and fell back to the raw combined string when either was missing --
#    and every state commission supplies ONE combined name field. So 7,505 of
#    14,953 rows went to Google surname-first: "Hood, Lucy", "Clancy Justin",
#    "Enoch, Leeanne". Fixed in 98cea79; this script inherits the fix.
#
# 2. ONE SHARED WINDOW. v5 put all four elections in 2021-2026 so they would be
#    directly comparable, and that destroyed the resolution the criterion needs.
#    The window's maximum is set by federal campaigns -- fed2022 reaches 92.22 --
#    so South Australian STATE candidates fall under Google's publishing
#    threshold: 104 of 109 returned exactly zero, including all four winners.
#    Six distinct values cannot rank 109 candidates.
#
# THE CRITERION NEVER NEEDED CROSS-ELECTION SCALE. It is a WITHIN-election AUC
# and a rank statistic is invariant to it; the shared window was built for the
# regression form that criterion replaced. So: one window per election ending
# the day before polling day, and a state election scoped to its own state,
# where its candidates are measured against each other rather than against
# national figures.
#
# Cross-seat chaining is unchanged and still necessary -- Google renormalises
# within each query, so five candidates asked separately are not comparable.
#
# RAW SERIES CACHED, per the keep-all-data rule.
#
# Emits S6* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))

MAJ   <- c("ALP", "LNP", "NAT")
MAXKW <- 5L
WEEKS <- 8L
SPAN  <- 400L          # above ~269 days keeps weekly buckets, and short enough
                       # that the campaign is a large share of the window
BASE_DAYS <- 300L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "4"))
MAX_BATCH <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAXBATCH", "200"))
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

# A FIXED ANCHOR IN EVERY BATCH, instead of chaining batch to batch.
#
# Chaining rescales each batch onto the previous one through a shared candidate,
# and it fails completely when that candidate returns zero. South Australia's
# chain anchored on Brandon Turton -- its strongest PRIOR non-major, who has no
# search presence at all -- so every rescale divided by zero and dropped four
# candidates. Ordering a chain by prior vote picks exactly the wrong person in a
# state where the previous non-major vote and current search interest are
# unrelated.
#
# A fixed anchor cannot fail that way: every candidate is measured against the
# SAME reference, there is no drift across batches, and one quiet batch cannot
# break the ones after it. The cost is compression -- a loud anchor pushes
# everyone toward zero -- and measured on the four SA winners the ORDERING
# survives intact (Thomas 1.14 > Fatchen 0.86 > Brock 0.00), which is all a
# within-election AUC needs.
#
# The anchor is a head of government: high and stable volume in that geography,
# and never a candidate in the seats being ranked.
ELS <- list(
  fed2022 = list(poll = "2022-05-21", geo = "AU",     prev = "fed2019",
                 anchor = "Anthony Albanese"),
  fed2025 = list(poll = "2025-05-03", geo = "AU",     prev = "fed2022",
                 anchor = "Anthony Albanese"),
  nsw2023 = list(poll = "2023-03-25", geo = "AU-NSW", prev = "nsw2019",
                 anchor = "Chris Minns"),
  sa2026  = list(poll = "2026-03-21", geo = "AU-SA",  prev = "sa2022",
                 anchor = "Peter Malinauskas"),
  # VICTORIA is the live target. 88 districts of ~50,000 voters sits between
  # South Australia's ~25,000, where 104 of 111 candidates never registered, and
  # a federal division's ~110,000, where the signal is strong. Whether Victoria
  # falls on the working side of that boundary is decidable from the FIELD
  # alone, with no outcome data: what share of candidates register at all.
  vic2022 = list(poll = "2022-11-26", geo = "AU-VIC", prev = "vic2018",
                 anchor = "Daniel Andrews"),
  vic2018 = list(poll = "2018-11-24", geo = "AU-VIC", prev = "vic2014",
                 anchor = "Daniel Andrews"))
WANT <- Sys.getenv("AUSPOL_SALIENCE_ELECTION", "")
if (nzchar(WANT)) ELS <- ELS[intersect(strsplit(WANT, ",")[[1]], names(ELS))]

qry <- function(kw, geo, from, to) {
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("v6-%s-%s-%s-%s", geo, from, to, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = geo, time = paste(from, to),
                          onlyInterest = TRUE), error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(10 * att)
  }
  # A FAILED REQUEST IS NOT "NO DATA". Caching a throttle as empty makes a
  # transient failure permanent and indistinguishable from a genuine zero.
  if (is.null(r)) { cat("S6!  request failed, NOT cached\n"); return(NULL) }
  if (is.null(r$interest_over_time)) { saveRDS(list(empty = TRUE), f); return(NULL) }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  out <- d[, .(keyword, date, hits)]
  saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date()), f)
  out
}

jump_of <- function(series, poll) {
  p <- as.Date(poll)
  camp <- series[date > p - WEEKS * 7L & date <= p, .(camp = mean(hits)), by = keyword]
  base <- series[date > p - BASE_DAYS & date <= p - WEEKS * 7L,
                 .(base = mean(hits)), by = keyword]
  m <- merge(camp, base, by = "keyword", all.x = TRUE)[is.na(base), base := 0]
  m[, .(keyword, jump = camp - base)]
}

C <- fread("output/candidacies.csv", showProgress = FALSE)
PRIO <- c(IND = 1, GRN = 2, ONP = 3, OTH_RIGHT = 4, OTH = 5)
all_rows <- list()

for (el in names(ELS)) {
  E <- ELS[[el]]
  yr <- as.integer(sub("^[a-z]+", "", el)); rg <- sub("[0-9]+$", "", el)
  to <- as.Date(E$poll) - 1; from <- to - SPAN
  D <- C[region == rg & year == yr & !party %in% MAJ]
  if (!nrow(D)) { cat(sprintf("S6!  no candidates for %s\n", el)); next }
  D[, kw := search_form(given, surname, name)]
  py <- as.integer(sub("^[a-z]+", "", E$prev))
  P <- C[region == rg & year == py & !party %in% MAJ,
         .(prev_pcv = max(pcv, na.rm = TRUE)), by = .(seat, party)]
  D <- merge(D, P, by = c("seat", "party"), all.x = TRUE)
  D[!is.finite(prev_pcv), prev_pcv := 0]
  D[, prio := as.integer(PRIO[party])][is.na(prio), prio := 5L]
  setorder(D, seat, -prev_pcv, prio)
  D[, rk := seq_len(.N), by = seat]
  # TOP TWO PER SEAT PLUS EVERY INDEPENDENT: 16 of 16 fed2022 non-major winners
  # against 11 for one-per-seat. An emergent candidate is by definition the one
  # with no prior vote, so any rule ranking on prior vote excludes them.
  S <- D[rk <= 2L | party == "IND"][!is.na(kw) & nzchar(kw)]
  setorder(S, kw, -prev_pcv)
  S <- S[, .SD[1], by = kw]
  PB <- C[region == rg & year == py & !party %in% MAJ,
          .(prev_nm = max(pcv, na.rm = TRUE)), by = seat]
  S <- merge(S, PB, by = "seat", all.x = TRUE)[!is.finite(prev_nm), prev_nm := 0]
  setorder(S, -prev_nm)
  cat(sprintf("\nS6-1 %s | geo %s | %s to %s | %d candidates\n",
              el, E$geo, as.character(from), as.character(to), nrow(S)))

  kws <- setdiff(unique(S$kw), E$anchor)
  acc <- NULL; nb <- 0L; gran <- NA_integer_; failed <- 0L
  for (i in seq(1L, length(kws), by = MAXKW - 1L)) {
    take <- kws[i:min(i + MAXKW - 2L, length(kws))]
    s <- qry(c(E$anchor, take), E$geo, as.character(from), as.character(to))
    nb <- nb + 1L
    if (is.null(s)) { failed <- failed + length(take); next }
    if (is.na(gran)) gran <- as.integer(stats::median(diff(sort(unique(s$date)))))
    m <- jump_of(s, E$poll)
    a <- m[keyword == E$anchor, jump]
    # The anchor is the SAME term in every batch, so its own value is the scale.
    # Guard anyway: an anchor returning zero would divide by nothing, which is
    # exactly how the chain broke in South Australia.
    if (!length(a) || !is.finite(a) || a <= 0) {
      cat(sprintf("S6!  anchor '%s' returned %s in batch %d, %d dropped\n",
                  E$anchor, if (length(a)) sprintf("%.2f", a) else "NA", nb, length(take)))
      failed <- failed + length(take); next
    }
    acc <- rbind(acc, m[keyword != E$anchor][, jump := jump / a])
    if (nb %% 20 == 0) cat(sprintf("S6-3 %d batches | %d done\n", nb, i))
    Sys.sleep(SLEEP)
  }
  if (is.null(acc)) { cat(sprintf("S6!  %s: nothing scaled, skipped\n", el)); next }
  cat(sprintf("S6-2 %d batches | granularity %s | %d candidates dropped\n", nb,
              if (is.na(gran)) "?" else if (gran >= 26) "MONTHLY -- UNUSABLE"
              else if (gran >= 6) "weekly" else "daily", failed))
  R <- merge(S[, .(election = el, seat, keyword = kw, party, pcv, elected,
                   prev_party = prev_pcv)], acc, by = "keyword")
  cat(sprintf("S6-4 %s: %d scaled | %d distinct jump values | %d%% zero | max %.2f\n",
              el, nrow(R), uniqueN(round(R$jump, 3)),
              round(100 * mean(R$jump <= 0)), max(R$jump)))
  all_rows[[el]] <- R
}
if (length(all_rows)) {
  OUT <- rbindlist(all_rows, fill = TRUE)
  fwrite(OUT, "output/salience-v6.csv")
  cat(sprintf("\nS6-9 wrote output/salience-v6.csv (%d rows, %d elections)\n",
              nrow(OUT), uniqueN(OUT$election)))
}
