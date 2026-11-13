# Links the vic2026 salience batches to ONE scale through a LADDER of overlapping queries, in place of the single
# anchor (Pete, 13 Nov 2026: fix the coarse anchor scale before the final snapshot; DECISIONS 2026-11-12).
#
# Why: next to the anchor (the Premier) the median batch representative peaked at 1 on Google's 0-100 scale and 99% of
# the 179 averaged under 5 (13 Nov, 11 Nov snapshot), so the anchor link was Google's rounding floor: linked jumps came
# in steps of 0.0607 and 17 candidates with raw rises 2.3 to 32.1 tied. A quieter anchor does not fix it: beside
# Tim Pallas (not a candidate, ~5x quieter than the Premier) the median representative was still zero in 56 of 58 weeks.
# Any term louder than these candidates flattens them; only terms of similar loudness resolve each other.
#
# So: the representatives (each batch's loudest, the fetcher's rule) are sorted by loudness (their level and peak in
# the anchor linking queries, coarse but enough to order them) and queried 5 at a time, each query sharing its 2
# quietest members with the next. build_vic2026_salience_jump.R chains the scale down the ladder through the shared
# members' levels (mean hits over the whole window), which are resolved because neighbours are of similar loudness.
#
# Same cache scheme as fetch_salience_vic2026_full.R (raw series, one file per query, resume-safe; stops after 3
# throttle signals). Writes external/reference/trends/vic2026-ladder-<TO>.csv (query order and members), nothing
# to output/. Run AFTER fetch_salience_vic2026_full.R for the same AUSPOL_SALIENCE_TO.   Codes LF0-LF9.
suppressMessages(library(data.table)); suppressMessages(library(gtrendsR))
MAXKW <- 5L; OVERLAP <- 2L; SPAN <- 400L; GEO <- "AU-VIC"
ANCHOR <- Sys.getenv("AUSPOL_SALIENCE_ANCHOR", "Ben Carroll")
SLEEP <- as.numeric(Sys.getenv("AUSPOL_SALIENCE_SLEEP", "4")); STOP_AFTER <- 3L
CACHE <- file.path("external", "reference", "trends")
TO <- as.Date(Sys.getenv("AUSPOL_SALIENCE_TO", "2026-10-06")); FROM <- TO - SPAN
st <- new.env(); st$consec <- 0L; st$hit <- FALSE

key_file <- function(kw) {
  key <- gsub("[^A-Za-z0-9]", "_", sprintf("v6-%s-%s-%s-%s", GEO, FROM, TO, paste(kw, collapse = "-")))
  file.path(CACHE, paste0(substr(key, 1, 150), ".rds"))
}
qry <- function(kw) {   # fetch_salience_vic2026_full.R's qry(), keeping the whole gtrends reply as well
  f <- key_file(kw); st$hit <- file.exists(f)
  if (file.exists(f)) { z <- readRDS(f); return(if (isTRUE(z$empty)) NULL else as.data.table(z$series)) }
  for (att in 1:3) {
    msg <- NULL
    r <- tryCatch(gtrends(keyword = kw, geo = GEO, time = paste(FROM, TO), onlyInterest = TRUE),
                  error = function(e) { msg <<- conditionMessage(e); NULL })
    if (!is.null(msg) && grepl("No data returned", msg, fixed = TRUE)) {
      out <- CJ(keyword = kw, date = seq(FROM, TO, by = "week"))[, hits := 0]
      saveRDS(list(series = out, empty = FALSE, allzero = TRUE, fetched = Sys.Date()), f); st$consec <- 0L; return(out[])
    }
    if (!is.null(r) && !is.null(r$interest_over_time)) {
      d <- as.data.table(r$interest_over_time)
      d[, hits := suppressWarnings(as.numeric(gsub("<", "", hits)))][is.na(hits), hits := 0]; d[, date := as.Date(date)]
      out <- d[, .(keyword, date, hits)]
      saveRDS(list(series = out, empty = FALSE, fetched = Sys.Date(), raw = r), f); st$consec <- 0L; return(out)
    }
    cat(sprintf("LF!  attempt %d failed: %s\n", att, if (is.null(msg)) "NULL result" else msg))
    if (!is.null(msg) && grepl("429|too many|quota|rate|blocked|403", msg, ignore.case = TRUE)) {
      st$consec <- st$consec + 1L
      if (st$consec >= STOP_AFTER) { cat("LF!! THROTTLED: stopping (rerun later; cached queries are kept). ", msg, "\n"); quit(save = "no", status = 3) }
      Sys.sleep(60 * 2^st$consec)
    } else Sys.sleep(10 * att)
  }
  NULL
}

mf <- sort(list.files(CACHE, pattern = "^vic2026-manifest-.*\\.csv$", full.names = TRUE), decreasing = TRUE)[1]
if (is.na(mf)) stop("LF0! no vic2026 manifest (run scripts/fetch_salience_vic2026_full.R first)")
M <- fread(mf, showProgress = FALSE)
if (!all(M$window == paste(FROM, TO))) stop("LF0! manifest ", basename(mf), " is for window ", M$window[1], ", not ", FROM, " ", TO)
# representatives: each cached batch's loudest member over the last 8 weeks (the fetcher's and the builder's rule).
# Not the whole-window loudest: tried 13 Nov, that picks famous namesakes loud all year (Paul Kelly, Steve Martin),
# which stretch the ladder; 41 representatives chained to 0 and linked candidates fell 561 -> 516.
reps <- unique(unlist(lapply(unique(M$batch[nzchar(M$batch)]), function(b) {
  f <- key_file(strsplit(b, "|", fixed = TRUE)[[1]]); if (!file.exists(f)) return(NULL)
  z <- readRDS(f); if (isTRUE(z$empty)) return(NULL); s <- as.data.table(z$series)
  s[date > TO - 56, .(r = mean(hits)), by = keyword][which.max(r), keyword]
})))
reps <- setdiff(reps, ANCHOR)
# order by loudness beside the anchor (level, then peak): coarse, but it puts similar terms next to each other
lf <- list.files(CACHE, pattern = paste0("^v6_", gsub("-", "_", GEO), "_", gsub("-", "_", FROM), "_", gsub("-", "_", TO),
                                         "_", gsub(" ", "_", ANCHOR), "_"), full.names = TRUE)
L <- rbindlist(lapply(lf, function(f) { z <- readRDS(f); if (isTRUE(z$empty)) return(NULL)
  as.data.table(z$series)[keyword != ANCHOR, .(level = mean(hits), peak = max(hits)), by = keyword] }))
L <- L[, .(level = max(level), peak = max(peak)), by = keyword]
O <- merge(data.table(keyword = reps), L, by = "keyword", all.x = TRUE)
O[is.na(level), `:=`(level = 0, peak = 0)]
setorder(O, -level, -peak, keyword)
cat(sprintf("LF1  %s: %d representatives, %d with an anchor-link level (%d linking files); loudest %s, %d at level 0\n",
            basename(mf), nrow(O), sum(O$keyword %in% L$keyword), length(lf), O$keyword[1], sum(O$level == 0)))
# The shared members are chosen AFTER each query: its OVERLAP quietest members with non-zero volume carry on to the
# next. A fixed overlap broke the chain on 13 Nov (first build): past the 20 representatives the anchor link reads as
# 0 the order is alphabetical, and two zero-volume members were the only link between queries 36 and 37.
run_ladder <- function(order_kw) {
  n_new <- 0L; todo <- order_kw; carry <- character(); Q <- list(); q <- 0L
  while (length(todo)) {
    q <- q + 1L
    take <- c(carry, head(todo, MAXKW - length(carry))); todo <- setdiff(todo, take)
    s <- qry(take)
    if (!st$hit) { n_new <- n_new + 1L; Sys.sleep(SLEEP) }
    Q[[q]] <- data.table(query = q, pos = seq_along(take), keyword = take, file = basename(key_file(take)))
    lv <- if (is.null(s)) data.table(keyword = take, level = 0) else s[, .(level = mean(hits)), by = keyword]
    nz <- lv[level > 0][order(level)]
    carry <- if (nrow(nz)) head(nz$keyword, OVERLAP) else carry   # none audible: carry the last carry again
    if (!nrow(nz)) cat(sprintf("LF4! query %d: no member with non-zero volume; carrying %s again\n", q, paste(carry, collapse = ", ")))
    if (q %% 10 == 0) cat(sprintf("LF3  query %d (%d representatives left, %d new requests so far)\n", q, length(todo), n_new))
  }
  Q <- rbindlist(Q)
  Q[, cached := file.exists(file.path(CACHE, file))]
  attr(Q, "n_new") <- n_new
  Q
}
# Chained level of every member, query 1's units (the same algebra as build_vic2026_salience_jump.R's VJ6).
chain_levels <- function(Q) {
  qn <- sort(unique(Q$query))
  lev <- lapply(qn, function(q) as.data.table(readRDS(file.path(CACHE, Q$file[Q$query == q][1]))$series)[, .(level = mean(hits)), by = keyword])
  sc <- rep(NA_real_, length(qn)); sc[1] <- 1
  for (i in seq_along(qn)[-1]) {
    sh <- merge(lev[[i - 1L]], lev[[i]], by = "keyword")[level.x > 0 & level.y > 0]
    if (nrow(sh) && is.finite(sc[i - 1L])) sc[i] <- sc[i - 1L] * exp(mean(log(sh$level.x / sh$level.y)))
  }
  rbindlist(lapply(seq_along(qn), function(i) lev[[i]][, .(keyword, v = level * sc[i])]))[, .(level = if (any(is.finite(v) & v > 0)) exp(mean(log(v[is.finite(v) & v > 0]))) else 0), by = keyword]
}
# Pass 1 orders by the anchor link; past ~20 representatives that reads 0 and the order is alphabetical, so a loud
# member can sit beside quiet ones and flatten them to 1-2 spike weeks (review, 13 Nov: 42 of 48 links rested on
# members with 1-2 non-zero weeks). Pass 2 re-orders by pass 1's chained levels, so neighbours really are of similar
# loudness. AUSPOL_LADDER_PASSES (default 2). Each pass is kept as vic2026-ladder-<TO>-pass<k>.csv; the last is also
# written as vic2026-ladder-<TO>.csv, the file build_vic2026_salience_jump.R reads.
PASSES <- as.integer(Sys.getenv("AUSPOL_LADDER_PASSES", "2"))
ord <- O$keyword
for (p in seq_len(PASSES)) {
  Q <- run_ladder(ord)
  pf <- file.path(CACHE, sprintf("vic2026-ladder-%s-pass%d.csv", TO, p))
  fwrite(Q[, .(query, pos, keyword, file, cached, window = paste(FROM, TO), pass = p)], pf)
  cat(sprintf("LF2  pass %d: %d queries, %d new requests, %d of %d cached -> %s\n", p, max(Q$query), attr(Q, "n_new"),
              uniqueN(Q[cached == TRUE, query]), max(Q$query), basename(pf)))
  if (p < PASSES) {
    cl <- chain_levels(Q); miss <- setdiff(O$keyword, cl$keyword)
    ord <- c(cl[order(-level, keyword), keyword], miss)
    cat(sprintf("LF5  pass %d chained levels: %d representatives, %d at 0; pass %d order starts %s\n", p, nrow(cl), sum(cl$level == 0),
                p + 1L, paste(head(ord, 4), collapse = ", ")))
  }
}
fwrite(Q[, .(query, pos, keyword, file, cached, window = paste(FROM, TO), pass = PASSES)], file.path(CACHE, sprintf("vic2026-ladder-%s.csv", TO)))
cat(sprintf("LF9  wrote %s (pass %d)\n", file.path(CACHE, sprintf("vic2026-ladder-%s.csv", TO)), PASSES))
