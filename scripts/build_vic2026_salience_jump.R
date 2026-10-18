# vic2026 salience `jump` for every candidate, from the CACHED raw series fetched by
# scripts/fetch_salience_vic2026_full.R (no Google calls). Same statistic and linking as
# scripts/fetch_salience_v6.R's run_pool(): jump = mean hits over the last WEEKS weeks minus the mean over
# the BASE_DAYS before that; each batch scaled to the anchor through its loudest member. The reference date
# is the SNAPSHOT end (AUSPOL_SALIENCE_TO, the fetch window's last day), not polling day: a pre-election
# snapshot measures the rise so far, and a later snapshot (refetch with a new AUSPOL_SALIENCE_TO) moves it
# toward the polling-day quantity the backtests use.
#   Rscript scripts/build_vic2026_salience_jump.R      -> output/vic2026-salience-jump.csv   (codes VJ0-VJ5)
suppressMessages(library(data.table))
WEEKS <- 8L; BASE_DAYS <- 300L; SPAN <- 400L; GEO <- "AU-VIC"   # as fetch_salience_v6.R:38-41
ANCHOR <- Sys.getenv("AUSPOL_SALIENCE_ANCHOR", "Jacinta Allan")   # the Premier; must match the fetcher's
TO <- as.Date(Sys.getenv("AUSPOL_SALIENCE_TO", "2026-10-06")); FROM <- TO - SPAN; REF <- TO + 1L
CACHE <- file.path("external", "reference", "trends")
mf <- sort(list.files(CACHE, pattern = "^vic2026-manifest-.*\\.csv$", full.names = TRUE), decreasing = TRUE)[1]
if (is.na(mf)) stop("VJ0! no vic2026 manifest in ", CACHE, " (run scripts/fetch_salience_vic2026_full.R)")
M <- fread(mf, showProgress = FALSE)
cat(sprintf("VJ0  %s: %d candidates, %d fetched, window %s to %s, reference %s\n", basename(mf), nrow(M),
            sum(M$status == "fetched"), FROM, TO, REF))
cache_file <- function(kw) {
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("v6-%s-%s-%s-%s", GEO, FROM, TO, paste(kw, collapse = "-")))
  file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
}
read_series <- function(kw) {
  f <- cache_file(kw); if (!file.exists(f)) return(NULL)
  z <- readRDS(f); if (isTRUE(z$empty)) NULL else as.data.table(z$series)
}
jump_of <- function(series) {     # fetch_salience_v6.R:278-285, at the snapshot's reference date
  camp <- series[date > REF - WEEKS * 7L & date <= REF, .(camp = mean(hits)), by = keyword]
  base <- series[date > REF - BASE_DAYS & date <= REF - WEEKS * 7L, .(base = mean(hits)), by = keyword]
  m <- merge(camp, base, by = "keyword", all.x = TRUE)[is.na(base), base := 0]
  m[, .(keyword, jump = camp - base)]
}
batches <- unique(M$batch[nzchar(M$batch)])
B <- list(); miss <- 0L
for (b in batches) {
  kw <- strsplit(b, "|", fixed = TRUE)[[1]]
  s <- read_series(kw)
  if (is.null(s)) { miss <- miss + 1L; next }
  j <- jump_of(s)
  rep_kw <- s[date > TO - 56, .(r = mean(hits)), by = keyword][which.max(r), keyword]   # the fetcher's representative
  B[[b]] <- list(j = j, rep = rep_kw)
}
cat(sprintf("VJ1  %d batches read from cache, %d missing\n", length(B), miss))
# linking: every cached (anchor, reps...) query in this window; each rep's jump relative to the anchor's
lf <- list.files(CACHE, pattern = paste0("^v6_", gsub("-", "_", GEO), "_", gsub("-", "_", FROM), "_", gsub("-", "_", TO),
                                         "_", gsub(" ", "_", ANCHOR), "_"), full.names = TRUE)
link <- rbindlist(lapply(lf, function(f) {
  z <- readRDS(f); if (isTRUE(z$empty)) return(NULL)
  m <- jump_of(as.data.table(z$series)); a <- m[keyword == ANCHOR, jump]
  if (!length(a) || !is.finite(a) || a <= 0) return(data.table(keyword = m[keyword != ANCHOR, keyword], rel = NA_real_))
  m[keyword != ANCHOR, .(keyword, rel = jump / a)]
}), fill = TRUE)
cat(sprintf("VJ2  %d linking queries, %d representatives linked, %d with a non-positive anchor rise (unlinked)\n",
            length(lf), sum(is.finite(link$rel)), sum(!is.finite(link$rel))))
out <- rbindlist(lapply(names(B), function(b) {
  x <- B[[b]]; own <- x$j[keyword == x$rep, jump]; v <- link[keyword == x$rep & is.finite(rel), rel]
  sc <- if (length(v) && length(own) && own > 0) max(v) / own else NA_real_
  x$j[, .(keyword, jump_raw = jump, jump = jump * sc, linked = is.finite(sc))]
}))
R <- merge(M[, .(seat, cand, party, keyword)], out, by = "keyword", all.x = TRUE)
cat(sprintf("VJ3  %d candidates: %d with a jump, %d linked to the anchor scale; %.0f%% of linked exactly zero or below\n",
            nrow(R), sum(is.finite(R$jump_raw)), sum(R$linked %in% TRUE),
            100 * mean(R$jump[R$linked %in% TRUE] <= 0)))
cat("VJ4  independents (jump on the anchor scale; NA = not linked):\n")
print(R[party == "IND"][order(-jump)][, .(seat, cand, jump = round(jump, 3), jump_raw = round(jump_raw, 2))], nrows = 40)
fwrite(R[, .(election = "vic2026", seat, cand, party, keyword, jump, jump_raw, linked, snapshot_to = TO)],
       file.path("output", "vic2026-salience-jump.csv"))
cat(sprintf("VJ5  wrote output/vic2026-salience-jump.csv (%d rows)\n", nrow(R)))
