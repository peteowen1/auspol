# Raw weekly Google Trends series for EVERY vic2026 candidate (data fetch only;
# no model change). Same query construction as fetch_salience_v6.R: search_form()
# keyword, geo AU-VIC, batches of 5 with no anchor, then a linking pass over each
# batch's loudest member against a fixed anchor. Cache key scheme "v6-..." so files
# land as external/reference/trends/v6_AU_VIC_<from>_<to>_<names>.rds.
# Window ends TODAY (pre-election snapshot). Majors and minors are batched in
# separate pools (as v6 does) so minors are not crushed under a major's 100.
# Resume-safe: qry() skips any batch already cached; every batch persists at once.
# Stops (does not hammer) after STOP_AFTER consecutive throttle signals.
# Writes external/reference/trends/vic2026-manifest-<date>.csv, nothing to output/.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(gtrendsR))
MAXKW <- 5L; SPAN <- 400L; GEO <- "AU-VIC"; ANCHOR <- "Daniel Andrews"
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "4")); STOP_AFTER <- 3L
CACHE <- file.path("external", "reference", "trends")
# The window END is pinned (AUSPOL_SALIENCE_TO, default the first snapshot's date
# 2026-10-06), so a rerun on a later day after a Google 429 resumes the SAME
# snapshot and reuses its cached batches instead of re-keying every file. A new
# snapshot is a deliberate choice: set AUSPOL_SALIENCE_TO to the new end date.
TO <- as.Date(Sys.getenv("AUSPOL_SALIENCE_TO", "2026-10-06")); FROM <- TO - SPAN; TODAY <- as.character(Sys.Date())
st <- new.env(); st$consec <- 0L; st$total <- 0L; st$failed <- character()

qry <- function(kw) {
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("v6-%s-%s-%s-%s", GEO, FROM, TO, paste(kw, collapse = "-")))
  f <- file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else z$series) }
  for (att in 1:3) {
    msg <- NULL
    r <- tryCatch(gtrends(keyword = kw, geo = GEO, time = paste(FROM, TO), onlyInterest = TRUE),
                  error = function(e) { msg <<- conditionMessage(e); NULL })
    if (!is.null(msg) && grepl("No data returned", msg, fixed = TRUE)) {
      out <- CJ(keyword = kw, date = seq(FROM, TO, by = "week"))[, hits := 0]
      saveRDS(list(series = out, empty = FALSE, allzero = TRUE, fetched = Sys.Date()), f)
      st$consec <- 0L; return(out[])
    }
    if (!is.null(r) && !is.null(r$interest_over_time)) {
      d <- as.data.table(r$interest_over_time)
      d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]
      d[, date := as.Date(date)]
      out <- d[, .(keyword, date, hits)]
      saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date()), f)
      st$consec <- 0L; return(out)
    }
    cat(sprintf("VF!  attempt %d failed: %s\n", att, if (is.null(msg)) "NULL result" else msg))
    if (!is.null(msg) && grepl("429|too many|quota|rate|blocked|403", msg, ignore.case = TRUE)) {
      st$consec <- st$consec + 1L; st$total <- st$total + 1L
      if (st$consec >= STOP_AFTER) {
        cat("VF!! THROTTLED: stopping. Last error: ", msg, "\n"); write_manifest(); quit(save = "no", status = 3)
      }
      Sys.sleep(60 * 2^st$consec)
    } else Sys.sleep(10 * att)
  }
  st$failed <- c(st$failed, paste(kw, collapse = "|")); NULL
}

C <- fread("output/candidacies.csv", showProgress = FALSE)[election == "vic2026"]
C[, kw := search_form(given, surname, name)]
cat(sprintf("VF1 %d rows, %d distinct keywords, %d with empty keyword\n", nrow(C), uniqueN(C$kw), sum(!nzchar(C$kw) | is.na(C$kw))))
C <- C[!is.na(kw) & nzchar(kw)]
MAJ <- c("ALP", "LNP", "NAT")
pools <- list(minor = unique(C[!party %in% MAJ, kw]), major = unique(C[party %in% MAJ, kw]))
pools$major <- setdiff(pools$major, ANCHOR)

status <- new.env(); reps <- character(); bid <- 0L; kw_batch <- list()
write_manifest <- function() {
  M <- unique(C[, .(seat, cand = name, party, keyword = kw)])
  M[, batch := unlist(kw_batch)[keyword]]
  M[, status := ifelse(is.na(batch), "missing", ifelse(batch %in% st$failed, "failed", "fetched"))]
  M[, fetch_date := TODAY][, window := paste(FROM, TO)]
  fwrite(M, file.path(CACHE, sprintf("vic2026-manifest-%s.csv", TODAY)))
  cat(sprintf("VF8 manifest: %s\n", paste(names(table(M$status)), table(M$status), collapse = ", ")))
}
for (p in names(pools)) {
  kws <- pools[[p]]
  for (i in seq(1L, length(kws), by = MAXKW)) {
    take <- kws[i:min(i + MAXKW - 1L, length(kws))]; bid <- bid + 1L
    s <- qry(take)
    for (k in take) kw_batch[[k]] <- paste(take, collapse = "|")
    if (!is.null(s)) { m <- s[date > TO - 56, .(r = mean(hits)), by = keyword]; reps <- c(reps, m[which.max(r), keyword]) }
    if (bid %% 10 == 0) cat(sprintf("VF2 [%s] batch %d, %d/%d keywords\n", p, bid, min(i + MAXKW - 1L, length(kws)), length(kws)))
    Sys.sleep(SLEEP * 2^min(st$consec, 5))
  }
}
reps <- setdiff(unique(reps), ANCHOR)
cat(sprintf("VF3 linking %d batch representatives against %s\n", length(reps), ANCHOR))
for (i in seq(1L, length(reps), by = MAXKW - 1L)) {
  take <- reps[i:min(i + MAXKW - 2L, length(reps))]
  qry(c(ANCHOR, take)); Sys.sleep(SLEEP)
}
write_manifest()
cat(sprintf("VF9 throttle signals this run: %d; failed batches: %d\n", st$total, length(st$failed)))
