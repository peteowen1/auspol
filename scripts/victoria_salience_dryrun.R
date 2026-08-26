# DRY RUN of the 9 November 2026 pipeline, on Victoria 2022.
#
# WHY A DRY RUN AND NOT THE REAL PARSER. Victorian nominations close 12 noon on
# Monday 9 November 2026. docs/NEXT-STEPS.md records that the pre-election
# nomination-list URL is NOT yet discoverable -- it does not exist for 2026, and
# web.archive.org is blocked from here so a 2022 snapshot cannot be recovered.
# So a parser cannot be written against a live page today.
#
# What CAN be tested is everything downstream of that page.
# `vec-2022-vic-candidates.csv` holds all 88 districts and 731 candidates in the
# exact shape a nomination list arrives in: seat, candidate, party. Running the
# salience pipeline over it end to end proves the November run is a fetch rather
# than a development day, and does it against an election whose answer is known.
#
# On the day, the only new code is the fetch: replace CANDIDATES with the
# nomination list and change POLL to 2026-11-28.
#
# WHAT THIS TESTS THAT THE FEDERAL WORK DOES NOT:
#   - Victoria specifically, which is the live target and has never been tested.
#   - A STATE election, where the corrected method has never been applied.
#   - 88 seats at once, which is the real operational load.
#   - Whether the pipeline flags the right seats WITHOUT knowing the result.
#
# Emits VD* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))
suppressMessages(library(gtrendsR))

# On 9 November 2026 these two lines change and nothing else does.
CANDIDATES <- file.path(election_data_path(), "vec-2022-vic-candidates.csv")
POLL       <- as.Date("2022-11-26")   # -> "2026-11-28"

GEO   <- "AU-VIC"
SPAN  <- 300L
WEEKS <- 8L
MAXKW <- 5L
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "10"))
MAX_SEATS <- as.integer(Sys.getenv("AUSPOL_SALIENCE_MAX", "10"))
CACHE <- file.path("external", "reference", "trends")
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(CANDIDATES)) stop("no candidate list at ", CANDIDATES)
C <- fread(CANDIDATES, showProgress = FALSE)
setnames(C, tolower(names(C)))
nm_col <- intersect(c("cand", "candidate", "name"), names(C))[1]
if (is.na(nm_col)) stop("no candidate-name column in ", CANDIDATES)
setnames(C, nm_col, "cand")
# A nomination list has no votes. Anything downstream that needs them is not
# available on 9 November either, so this deliberately uses NONE.
C[, kw := normalise_name(cand)]

cat(sprintf("VD1  %d candidates in %d districts | poll %s | geo %s\n",
            nrow(C), uniqueN(C$seat), POLL, GEO))
cat(sprintf("VD1  independents nominated: %d in %d districts\n",
            sum(C$party == "IND"), uniqueN(C[party == "IND", seat])))

batch <- function(kw) {
  to <- POLL - 1; from <- to - SPAN
  key <- gsub("[^A-Za-z0-9]", "_",
              sprintf("ss-%s-%s-%s", GEO, to, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$m) }
  r <- NULL
  for (att in 1:3) {
    r <- tryCatch(gtrends(keyword = kw, geo = GEO, time = paste(from, to),
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
    ov <- names(acc)[which.max(acc)]        # loudest: never divide by ~0
    take <- utils::head(rest, MAXKW - 1L)
    v <- batch(c(ov, take))
    if (is.null(v) || !ov %in% names(v) || !is.finite(v[[ov]]) || v[[ov]] <= 0) {
      cat(sprintf("VD!  stitch failed on %s; %d dropped\n", ov, length(take)))
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
                sprintf("ss-%s-%s-%s", GEO, POLL - 1,
                        paste(utils::head(unique(d$kw), MAXKW), collapse = "-")))
  seen <- file.exists(file.path(CACHE, paste0(substr(probe, 1, 150), ".rds")))
  if (!seen) { if (fetched >= MAX_SEATS) next; fetched <- fetched + 1L }
  v <- seat_salience(d$kw)
  if (is.null(v)) { cat(sprintf("VD!  %s: no data\n", s)); next }
  d[, sal := as.numeric(v[kw])][is.na(sal), sal := 0]
  tot <- sum(d$sal)
  d[, sal_share := if (tot > 0) 100 * sal / tot else 0]
  out[[s]] <- d[, .(seat, cand, party, sal_share)]
  if (!seen) Sys.sleep(SLEEP)
}
if (!length(out)) { cat("VD9  nothing fetched yet\n"); quit(save = "no") }

R <- rbindlist(out)
fwrite(R, "output/vic-salience-dryrun.csv")
cat(sprintf("\nVD8  %d candidates across %d districts\n", nrow(R), uniqueN(R$seat)))

# THE OPERATIONAL QUESTION: which districts would this flag, knowing only the
# nomination list? Reported WITHOUT reference to the result, because that is all
# November will have.
ind <- R[party == "IND"][order(-sal_share)]
cat("\nVD9  independents by salience share -- the November output\n")
print(utils::head(ind[, .(seat, cand, sal_share = round(sal_share, 1))], 15),
      row.names = FALSE)
cat(sprintf("\nVD9  independents above 20%% share: %d | above 40%%: %d | at zero: %d of %d\n",
            sum(ind$sal_share > 20), sum(ind$sal_share > 40),
            sum(ind$sal_share == 0), nrow(ind)))
