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

# ADAPTIVE THROTTLE BACKOFF. Any error other than the specific "No data
# returned by the query" (a genuine all-silent batch) used to get 3 quick
# retries at 10/20/30s and then be silently dropped -- indistinguishable in
# the log from a one-off network blip, and the same code path a real rate
# limit hits. That conflation is exactly how "by then Google had throttled us
# out entirely" happened before (docs/DATA-DICTIONARY.md-adjacent incident,
# CLAUDE.md). THROTTLE_STATE tracks a rolling count of suspected-throttle
# errors across the WHOLE run (not just one call's retries) and both backs off
# per-call and slows every subsequent call down when the rate climbs.
THROTTLE_STATE <- new.env()
THROTTLE_STATE$consecutive <- 0L
THROTTLE_STATE$total_throttled <- 0L
is_throttle_error <- function(msg) {
  grepl("429|too many requests|quota|rate.?limit|temporarily blocked|403",
        msg, ignore.case = TRUE)
}
current_sleep <- function() {
  # Escalate the BASE between-batch sleep as consecutive suspected-throttle
  # events climb, so the run slows itself down before every batch starts
  # failing, rather than only reacting after the fact.
  SLEEP * (2 ^ min(THROTTLE_STATE$consecutive, 5))
}
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
  fed2019 = list(poll = "2019-05-18", geo = "AU",     prev = "fed2016",
                 anchor = "Scott Morrison"),
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
                 anchor = "Daniel Andrews"),

  # EVERYTHING BELOW: added 2026-08-27 to scrape the remaining elections
  # output/candidacies.csv already has results for, so the raw series is
  # cached even where it isn't yet used by any model (keep-raw-data rule,
  # CLAUDE.md). Anchors verified against Wikipedia/ABC/parlinfo/SBS, not
  # assumed from memory -- a wrong incumbent silently corrupts the whole
  # election's normalisation. `prev` election in comments marked (missing)
  # where candidacies.csv has no prior election on record: prev_pcv then comes
  # back 0 for every candidate, which degrades the top-2-per-seat SELECTION
  # (independents are still always included regardless -- `rk <= 2L | party ==
  # "IND"` -- so this mainly affects which single GRN/ONP/OTH_RIGHT candidate
  # gets picked in a seat with more than one) and makes that election's
  # `prev_party` column unusable as a feature. The raw jump series is still
  # valid and cached regardless; this is a downstream-usability note, not a
  # fetch-quality one.
  fed2007 = list(poll = "2007-11-24", geo = "AU", prev = "fed2004", # (missing)
                 anchor = "John Howard"),
  fed2010 = list(poll = "2010-08-21", geo = "AU", prev = "fed2007",
                 anchor = "Julia Gillard"),
  fed2013 = list(poll = "2013-09-07", geo = "AU", prev = "fed2010",
                 anchor = "Kevin Rudd"),
  fed2016 = list(poll = "2016-07-02", geo = "AU", prev = "fed2013",
                 anchor = "Malcolm Turnbull"),
  nsw2019 = list(poll = "2019-03-23", geo = "AU-NSW", prev = "nsw2015", # (missing)
                 anchor = "Gladys Berejiklian"),
  sa2022  = list(poll = "2022-03-19", geo = "AU-SA", prev = "sa2018", # (missing)
                 anchor = "Steven Marshall"),
  vic2014 = list(poll = "2014-11-29", geo = "AU-VIC", prev = "vic2010", # (missing)
                 anchor = "Denis Napthine"),
  qld2020 = list(poll = "2020-10-31", geo = "AU-QLD", prev = "qld2017", # (missing)
                 anchor = "Annastacia Palaszczuk"),
  qld2024 = list(poll = "2024-10-26", geo = "AU-QLD", prev = "qld2020",
                 anchor = "Steven Miles"),
  wa1996  = list(poll = "1996-12-14", geo = "AU-WA", prev = "wa1993", # (missing)
                 anchor = "Richard Court"),
  wa2001  = list(poll = "2001-02-10", geo = "AU-WA", prev = "wa1996",
                 anchor = "Richard Court"),
  wa2005  = list(poll = "2005-02-26", geo = "AU-WA", prev = "wa2001",
                 anchor = "Geoff Gallop"),
  wa2008  = list(poll = "2008-09-06", geo = "AU-WA", prev = "wa2005",
                 anchor = "Alan Carpenter"),
  wa2013  = list(poll = "2013-03-09", geo = "AU-WA", prev = "wa2008",
                 anchor = "Colin Barnett"),
  wa2017  = list(poll = "2017-03-11", geo = "AU-WA", prev = "wa2013",
                 anchor = "Colin Barnett"),
  wa2021  = list(poll = "2021-03-13", geo = "AU-WA", prev = "wa2017",
                 anchor = "Mark McGowan"),
  wa2025  = list(poll = "2025-03-08", geo = "AU-WA", prev = "wa2021",
                 anchor = "Roger Cook"))
WANT <- Sys.getenv("AUSPOL_SALIENCE_ELECTION", "")
if (nzchar(WANT)) ELS <- ELS[intersect(strsplit(WANT, ",")[[1]], names(ELS))]

qry <- function(kw, geo, from, to) {
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("v6-%s-%s-%s-%s", geo, from, to, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  # THREE OUTCOMES, and conflating the last two cost 92% of the resolution.
  #   - request succeeds with a series      -> data
  #   - request succeeds with no series     -> genuine zeros
  #   - gtrends THROWS "No data returned by the query" when EVERY term in the
  #     batch is silent                     -> ALSO genuine zeros, not a failure
  #
  # Treating the third as a failed request is why an anchor looked mandatory: a
  # batch of five quiet candidates could not be queried at all. With an anchor
  # present the batch always returns, and the anchor then takes 100 and crushes
  # everyone else -- Geoff Brock reads 96 unanchored and 7 alongside
  # Malinauskas, Chantelle Thomas 100 and 8. The anchor was solving what was
  # really an error-handling bug, at the cost of most of the signal.
  r <- NULL; allzero <- FALSE; throttled <- FALSE
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = geo, time = paste(from, to),
                          onlyInterest = TRUE),
                  error = function(e) {
                    msg <- conditionMessage(e)
                    if (grepl("No data returned", msg, fixed = TRUE)) {
                      allzero <<- TRUE
                    } else if (is_throttle_error(msg)) {
                      throttled <<- TRUE
                    }
                    NULL
                  })
    if (allzero || (!is.null(r) && !is.null(r$interest_over_time))) break
    if (throttled) {
      # A REAL rate-limit signal, not a generic blip: back off far longer than
      # the ordinary 10/20/30s retry, and record it so every SUBSEQUENT call
      # (not just this one) slows down too.
      THROTTLE_STATE$consecutive <- THROTTLE_STATE$consecutive + 1L
      THROTTLE_STATE$total_throttled <- THROTTLE_STATE$total_throttled + 1L
      wait <- 30 * (2 ^ min(THROTTLE_STATE$consecutive, 5))
      cat(sprintf("S6T  throttle signal (consecutive %d, total %d this run) -- backing off %ds\n",
                  THROTTLE_STATE$consecutive, THROTTLE_STATE$total_throttled, wait))
      Sys.sleep(wait)
      throttled <- FALSE
      next
    }
    Sys.sleep(10 * att)
  }
  # A request that got here without hitting `throttled` succeeded (or hit the
  # genuine-zero path) -- relax the adaptive slowdown so a past bad patch
  # doesn't keep every later, healthy batch artificially slow.
  THROTTLE_STATE$consecutive <- 0L
  if (allzero) {
    # Every term silent across the window. Recorded as zeros rather than
    # dropped, so the candidates are ZERO instead of missing.
    out <- data.table::CJ(keyword = kw,
                          date = seq(as.Date(from), as.Date(to), by = "week"))
    out[, hits := 0]
    saveRDS(list(series = out, empty = FALSE, allzero = TRUE, fetched = Sys.Date()), f)
    return(out[])
  }
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

  # TWO STAGES, now that an all-silent batch is data rather than an error.
  #
  #   1. Batches of five candidates, NO anchor. Each is normalised on its own
  #      loudest member, so a quiet field keeps its full range instead of being
  #      crushed against a head of government.
  #   2. One extra pass over each batch's loudest member, putting the
  #      representatives on a single scale. Each batch is then multiplied by its
  #      own representative's value in that pass.
  #
  # A batch that is silent throughout contributes zeros and needs no link. The
  # anchor is retained ONLY for the linking pass, where every member is a
  # batch's loudest candidate and a zero would otherwise break the scale.
  kws <- unique(S$kw)
  nb <- 0L; gran <- NA_integer_; failed <- 0L; batches <- list()
  for (i in seq(1L, length(kws), by = MAXKW)) {
    take <- kws[i:min(i + MAXKW - 1L, length(kws))]
    s <- qry(take, E$geo, as.character(from), as.character(to))
    nb <- nb + 1L
    if (is.null(s)) { failed <- failed + length(take); next }
    if (is.na(gran)) {
      d <- sort(unique(s$date))
      if (length(d) > 1L) gran <- as.integer(stats::median(diff(d)))
    }
    batches[[length(batches) + 1L]] <- jump_of(s, E$poll)
    if (nb %% 20 == 0) cat(sprintf("S6-3 stage 1: %d batches | %d of %d done\n",
                                   nb, i, length(kws)))
    Sys.sleep(current_sleep())
  }
  if (!length(batches)) { cat(sprintf("S6!  %s: nothing measured, skipped\n", el)); next }
  cat(sprintf("S6-2 stage 1: %d batches | granularity %s | %d dropped\n", nb,
              if (is.na(gran)) "?" else if (gran >= 26) "MONTHLY -- UNUSABLE"
              else if (gran >= 6) "weekly" else "daily", failed))

  reps <- vapply(batches, function(b) b[which.max(jump), keyword], "")
  live <- vapply(batches, function(b) max(b$jump) > 0, TRUE)
  cat(sprintf("S6-5 stage 2: linking %d live batches (%d silent throughout)\n",
              sum(live), sum(!live)))
  scale <- rep(1, length(batches))
  if (sum(live) > 1L) {
    rl <- unique(reps[live]); link <- NULL
    for (i in seq(1L, length(rl), by = MAXKW - 1L)) {
      take <- rl[i:min(i + MAXKW - 2L, length(rl))]
      s <- qry(c(E$anchor, take), E$geo, as.character(from), as.character(to))
      if (is.null(s)) next
      m <- jump_of(s, E$poll)
      a <- m[keyword == E$anchor, jump]
      if (!length(a) || !is.finite(a) || a <= 0) next
      link <- rbind(link, m[keyword != E$anchor][, jump := jump / a])
      Sys.sleep(current_sleep())
    }
    if (!is.null(link)) {
      link <- link[, .(jump = max(jump)), by = keyword]
      for (j in seq_along(batches)) {
        if (!live[j]) next
        v <- link[keyword == reps[j], jump]
        own <- batches[[j]][keyword == reps[j], jump]
        if (!length(v) || !length(own) || own <= 0) {
          cat(sprintf("S6!  no link for batch %d (rep '%s')\n", j, reps[j])); next
        }
        scale[j] <- v / own
      }
    }
  }
  acc <- rbindlist(lapply(seq_along(batches), function(j)
    batches[[j]][, .(keyword, jump = jump * scale[j])]))
  R <- merge(S[, .(election = el, seat, keyword = kw, party, pcv, elected,
                   prev_party = prev_pcv)], acc, by = "keyword")
  cat(sprintf("S6-4 %s: %d scaled | %d distinct jump values | %d%% zero | max %.2f\n",
              el, nrow(R), uniqueN(round(R$jump, 3)),
              round(100 * mean(R$jump <= 0)), max(R$jump)))
  all_rows[[el]] <- R
}
if (length(all_rows)) {
  OUT <- rbindlist(all_rows, fill = TRUE)
  # MERGE, never overwrite. Running one election at a time via
  # AUSPOL_SALIENCE_ELECTION and writing the whole file each time destroyed the
  # previous election's results: the Victorian run wiped South Australia's, and
  # a figure quoted afterwards silently came from the older, broken-terms
  # corpus. Same class as the CAL_TAG collisions -- two runs, one filename.
  f <- "output/salience-v6.csv"
  if (file.exists(f)) {
    prev <- fread(f, showProgress = FALSE)
    keep <- prev[!election %in% unique(OUT$election)]
    if (nrow(keep)) {
      cat(sprintf("S6-8 keeping %d rows from %s already on disk
",
                  nrow(keep), paste(sort(unique(keep$election)), collapse = ", ")))
      OUT <- rbindlist(list(keep, OUT), fill = TRUE)
    }
  }
  fwrite(OUT, f)
  cat(sprintf("\nS6-9 wrote output/salience-v6.csv (%d rows, %d elections)\n",
              nrow(OUT), uniqueN(OUT$election)))
}
