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
ANCHOR <- Sys.getenv("AUSPOL_SALIENCE_ANCHOR", "Ben Carroll")   # the Premier (since 28 Jul 2026); must match the fetcher's
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
# LADDER linking (13 Nov 2026, scripts/fetch_salience_vic2026_ladder.R), used whenever its file exists for this
# window: the anchor link above is Google's rounding floor for almost every representative (median peak 1 beside the
# Premier). Each ladder query holds 5 representatives of similar loudness and shares 2 with the next; the scale is
# chained down the ladder through the shared members' LEVELS (mean hits over the whole window), and a batch's factor
# is its representative's ladder level over its level in its own batch. Only the order within vic2026 survives
# link_vic2026_salience.R's rank mapping, so the ladder's top-of-scale needs no tie to the anchor.
# AUSPOL_SALIENCE_LINK=anchor forces the old link.
lad_f <- file.path(CACHE, sprintf("vic2026-ladder-%s.csv", TO))
LINK <- Sys.getenv("AUSPOL_SALIENCE_LINK", if (file.exists(lad_f)) "ladder" else "anchor")
if (identical(LINK, "ladder")) {
  if (!file.exists(lad_f)) stop("VJ6! AUSPOL_SALIENCE_LINK=ladder but no ", lad_f)
  Q <- fread(lad_f, showProgress = FALSE)
  qn <- sort(unique(Q$query))
  lev <- lapply(qn, function(q) {
    f <- file.path(CACHE, Q$file[Q$query == q][1]); if (!file.exists(f)) return(NULL)
    z <- readRDS(f); if (isTRUE(z$empty)) return(NULL)
    as.data.table(z$series)[, .(level = mean(hits), nz = sum(hits > 0), peak = max(hits)), by = keyword]
  })
  scale <- rep(NA_real_, length(qn)); scale[1] <- if (is.null(lev[[1]])) NA_real_ else 1
  steps <- list()
  for (i in seq_along(qn)[-1]) {
    a <- lev[[i - 1L]]; b <- lev[[i]]
    if (is.null(a) || is.null(b) || !is.finite(scale[i - 1L])) next
    sh <- merge(a, b, by = "keyword", suffixes = c("_prev", "_this"))[level_prev > 0 & level_this > 0]
    if (nrow(sh)) scale[i] <- scale[i - 1L] * exp(mean(log(sh$level_prev / sh$level_this)))
    r <- sh$level_prev / sh$level_this
    steps[[i]] <- data.table(query = qn[i], n_shared = nrow(sh), min_level = if (nrow(sh)) min(c(sh$level_prev, sh$level_this)) else NA_real_,
                             min_nz = if (nrow(sh)) min(pmin(sh$nz_prev, sh$nz_this)) else NA_integer_,
                             min_peak = if (nrow(sh)) min(pmin(sh$peak_prev, sh$peak_this)) else NA_real_,
                             spread = if (length(r) > 1) max(r) / min(r) else NA_real_)
  }
  steps <- rbindlist(steps)
  if (nrow(steps)) {
    cat(sprintf("VJ6  ladder %s: %d queries, %d on the chained scale; shared members per step: %s; smallest shared level %.2f (0-100)\n",
                basename(lad_f), length(qn), sum(is.finite(scale)), paste(names(table(steps$n_shared)), table(steps$n_shared), sep = "x", collapse = " "),
                min(steps$min_level, na.rm = TRUE)))
    # how well each link is measured: a shared member's spike height is Google's integer, so a low peak is a coarse ratio
    cat(sprintf("VJ6  link quality: shared peak (lower of the pair, 0-100) median %.0f, under 10 at %d of %d steps; non-zero weeks 1-2 at %d; shared-ratio spread over 1.5x at %d\n",
                median(steps$min_peak, na.rm = TRUE), sum(steps$min_peak < 10, na.rm = TRUE), nrow(steps), sum(steps$min_nz <= 2, na.rm = TRUE),
                sum(steps$spread > 1.5, na.rm = TRUE)))
  }
  if (any(!is.finite(scale))) cat(sprintf("VJ6! chain broken at query %s: later representatives unlinked\n", qn[which(!is.finite(scale))[1]]))
  lad <- rbindlist(lapply(seq_along(qn), function(i) if (!is.null(lev[[i]]) && is.finite(scale[i])) lev[[i]][, .(keyword, v = level * scale[i])]))
  lad <- lad[v > 0, .(ladder = exp(mean(log(v)))), by = keyword]
  out <- rbindlist(lapply(names(B), function(b) {
    x <- B[[b]]; s <- read_series(strsplit(b, "|", fixed = TRUE)[[1]])
    own_lev <- s[keyword == x$rep, mean(hits)]; lv <- lad[keyword == x$rep, ladder]
    sc <- if (length(lv) && length(own_lev) && own_lev > 0) lv / own_lev else NA_real_
    x$j[, .(keyword, jump_raw = jump, jump = jump * sc, linked = is.finite(sc))]
  }))
} else {
out <- rbindlist(lapply(names(B), function(b) {
  x <- B[[b]]; own <- x$j[keyword == x$rep, jump]; v <- link[keyword == x$rep & is.finite(rel), rel]
  sc <- if (length(v) && length(own) && own > 0) max(v) / own else NA_real_
  x$j[, .(keyword, jump_raw = jump, jump = jump * sc, linked = is.finite(sc))]
}))
}
.lp <- out[linked %in% TRUE & jump > 0, jump]
cat(sprintf("VJ7  link = %s; linked positive jumps: %d, distinct values %d, largest tied block %d; linked exactly zero %.0f%%\n",
            LINK, length(.lp), uniqueN(round(.lp, 10)), if (length(.lp)) max(table(round(.lp, 10))) else 0L,
            100 * mean(out[linked %in% TRUE, jump] == 0)))
R <- merge(M[, .(seat, cand, party, keyword)], out, by = "keyword", all.x = TRUE)
cat(sprintf("VJ3  %d candidates: %d with a jump, %d linked to the anchor scale; %.0f%% of linked exactly zero or below\n",
            nrow(R), sum(is.finite(R$jump_raw)), sum(R$linked %in% TRUE),
            100 * mean(R$jump[R$linked %in% TRUE] <= 0)))
cat("VJ4  independents (jump on the anchor scale; NA = not linked):\n")
print(R[party == "IND"][order(-jump)][, .(seat, cand, jump = round(jump, 3), jump_raw = round(jump_raw, 2))], nrows = 40)
fwrite(R[, .(election = "vic2026", seat, cand, party, keyword, jump, jump_raw, linked, snapshot_to = TO)],
       file.path("output", "vic2026-salience-jump.csv"))
cat(sprintf("VJ5  wrote output/vic2026-salience-jump.csv (%d rows)\n", nrow(R)))
