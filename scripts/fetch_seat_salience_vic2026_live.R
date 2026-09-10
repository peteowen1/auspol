# LIVE Google Trends salience for Victoria 2026, using the pre-nomination
# candidate list (scripts/fetch_candidates_vic2026_prenomination.R) -- NOT
# the historical dry-run (scripts/victoria_salience_dryrun.R, which replays
# vic2022 as a rehearsal). This is the real thing, run before official
# nominations close (9 Nov 2026), so it necessarily only covers whoever is
# already publicly named. Re-running this after the candidate fetcher grows
# its list is safe and cheap -- cached batches are skipped, same as
# fetch_seat_salience_v6.R's discipline.
#
# WHY "to = yesterday" AND NOT THE ELECTION DATE. victoria_salience_dryrun.R
# uses POLL-1 as its cutoff because it is replaying a COMPLETED election
# (2022-11-26), where "the day before polling day" is a fixed date in the
# past. This run is happening on a date BEFORE the actual 2026-11-28 poll,
# so the only valid cutoff is today -- Google Trends has no data for a date
# that has not happened yet.
#
# Emits VL* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))

CANDIDATES <- "output/vic2026-prenomination-candidates.csv"
if (!file.exists(CANDIDATES)) stop("Run scripts/fetch_candidates_vic2026_prenomination.R first")

GEO   <- "AU-VIC"
SPAN  <- 300L
WEEKS <- 8L
MAXKW <- 5L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "10"))
MAX_SEATS <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAX", "60"))
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

C <- fread(CANDIDATES, showProgress = FALSE)
# Scoped to the classes this exercise is actually about -- IND/ONP/OTH_RIGHT,
# the residual classes the xgb investigation found collapsing. GRN/ALP/LNP/OTH
# (Socialists etc.) are not the live question here and would roughly triple
# the Trends call volume for no purpose this session needs.
C <- C[party %in% c("IND", "ONP", "OTH_RIGHT")]
C[, kw := normalise_name(cand)]
cat(sprintf("VL1  %d candidates (IND/ONP/OTH_RIGHT only) in %d seats\n", nrow(C), uniqueN(C$seat)))

TO <- Sys.Date() - 1L

batch <- function(kw) {
  from <- TO - SPAN
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("ssL-%s-%s-%s", GEO, TO, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$m) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = GEO, time = paste(from, TO),
                          onlyInterest = TRUE), error = function(e) NULL)
    if (!is.null(r) && !is.null(r$interest_over_time)) break
    Sys.sleep(15 * att)
  }
  if (is.null(r) || is.null(r$interest_over_time)) {
    saveRDS(list(empty = TRUE), f); return(NULL)
  }
  d <- as.data.table(r$interest_over_time)
  d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
  d[, date := as.Date(date)]
  m <- d[date > max(date) - WEEKS * 7L, .(hits = mean(hits)), by = keyword]
  out <- setNames(m$hits, m$keyword)
  saveRDS(list(m = out, empty = FALSE), f)
  out
}

seat_salience <- function(kw) {
  kw <- unique(kw)
  if (length(kw) <= MAXKW) return(batch(kw))
  acc <- batch(kw[1:MAXKW]); if (is.null(acc)) return(NULL)
  rest <- kw[-(1:MAXKW)]
  while (length(rest)) {
    ov <- names(acc)[which.max(acc)]
    take <- utils::head(rest, MAXKW - 1L)
    v <- batch(c(ov, take))
    if (is.null(v) || !ov %in% names(v) || !is.finite(v[[ov]]) || v[[ov]] <= 0) {
      cat(sprintf("VL!  stitch failed on %s; %d dropped\n", ov, length(take)))
      rest <- rest[-seq_along(take)]; next
    }
    acc <- c(acc, v[setdiff(names(v), ov)] * (acc[[ov]] / v[[ov]]))
    rest <- rest[-seq_along(take)]
    Sys.sleep(SLEEP)
  }
  acc
}

seats <- sort(unique(C$seat)); out <- list(); fetched <- 0L
for (s in seats) {
  d <- C[seat == s]
  probe <- gsub("[^A-Za-z0-9]", "_",
                sprintf("ssL-%s-%s-%s", GEO, TO,
                        paste(utils::head(unique(d$kw), MAXKW), collapse = "-")))
  seen <- file.exists(file.path(CACHE, paste0(substr(probe, 1, 150), ".rds")))
  if (!seen) { if (fetched >= MAX_SEATS) { cat(sprintf("VL!  %s: MAX_SEATS reached, skipped -- resume by rerunning\n", s)); next }; fetched <- fetched + 1L }
  v <- seat_salience(d$kw)
  if (is.null(v)) { cat(sprintf("VL!  %s: no data\n", s)); next }
  d[, sal := as.numeric(v[kw])][is.na(sal), sal := 0]
  tot <- sum(d$sal)
  d[, sal_share := if (tot > 0) 100 * sal / tot else 0]
  out[[s]] <- d[, .(seat, cand, party, sal_share, sal_raw = sal)]
  if (!seen) Sys.sleep(SLEEP)
}
if (!length(out)) { cat("VL9  nothing fetched yet\n"); quit(save = "no") }

R <- rbindlist(out)
R[, fetched_at := as.character(Sys.Date())]
fwrite(R, "output/vic2026-live-salience.csv")
cat(sprintf("\nVL8  %d candidates across %d seats -- output/vic2026-live-salience.csv\n",
            nrow(R), uniqueN(R$seat)))

cat("\nVL9  by salience share, all classes, today's partial candidate list\n")
print(R[order(-sal_share)][, .(seat, cand, party, sal_share = round(sal_share, 1), sal_raw = round(sal_raw, 2))],
      row.names = FALSE)
cat(sprintf("\nVL9  above 20%% share: %d | above 40%%: %d | raw signal at exactly zero: %d of %d\n",
            sum(R$sal_share > 20), sum(R$sal_share > 40), sum(R$sal_raw == 0), nrow(R)))
