# Fetch one snapshot of the VEC results website for the night runner (the VEC refused the results feed, 11 Nov 2026,
# and pointed to the website, which it says matches the feed and updates as often).
#
#   Rscript scripts/fetch_vec_web_snapshot.R --index=<results page URL> --out=<snapshot root>
#       [--districts=external/reference/vec/2026/vec-candidates-2026.csv | Name1,Name2] [--every=0] [--max-cycles=0] [--parallel=4] [--retries=3]
#       [--cooldown=300] [--retry-pause=5,15,30]
#
# From --index it finds every district's two "results by voting centre" pages (first preferences, two-candidate):
# directly if the index links to them, else through the district result pages it links to (one level). Each district in
# the official list must be found; the names on the night come from that list, never from a page address. Writes
# <out>/<YYYYMMDD_HHMMSS>/ (Melbourne time, the stamp the night runner orders by): <slug>-fp.html, <slug>-2cp.html,
# manifest.csv (district, fp, tcp, fp_url, tcp_url) and DONE last, so the runner never reads a folder mid-fetch.
# Pages are saved exactly as received. Polite: one request at a time, a pause between them. --every=N repeats every N
# seconds (0 = once). Check codes VWF1-VWF7.
#
# The 2026 results URL is not known before the night: pass whatever results page lists the districts (tested on the
# Nepean 2026 by-election pages, 11 Nov 2026).
suppressMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default = NULL) { h <- grep(paste0("^--", name, "="), a, value = TRUE); if (length(h)) sub("^[^=]*=", "", h[1]) else default }
index <- flag("index"); out <- flag("out"); if (is.null(index) || is.null(out)) stop("VWF1! need --index and --out")
dsrc <- flag("districts", "external/reference/vec/2026/vec-candidates-2026.csv")
every <- as.numeric(flag("every", "0")); max_cycles <- as.integer(flag("max-cycles", "0")); pause <- as.numeric(flag("pause", "0.5"))
districts <- if (file.exists(dsrc)) sort(unique(sub(" District$", "", fread(dsrc, showProgress = FALSE)$district))) else trimws(strsplit(dsrc, ",")[[1]])
if (!length(districts)) stop("VWF1! no districts from ", dsrc)
slug <- function(x) gsub("^-|-$", "", gsub("[^a-z0-9]+", "-", tolower(x)))
base <- regmatches(index, regexpr("^https?://[^/]+", index))
UA <- "auspol election-night reader (personal, non-commercial; polls each page every few minutes)"
get <- function(u) { Sys.sleep(pause)
  r <- tryCatch({ con <- url(u, headers = c("User-Agent" = UA)); on.exit(close(con)); paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "\n") },
                error = function(e) NA_character_)
  if (is.na(r) || !grepl("</html>", r, fixed = TRUE)) NA_character_ else r }
# --parallel=N (default 4; Pete, 21 Nov 2026): up to N pages in flight at once. One at a time a snapshot of 174 pages
# took 297 s (1.7 s a page), so the night refreshed every 5 minutes. --parallel=1 is the old one-at-a-time path with
# its pause. Same completeness rule either way: a page without its closing </html> counts as failed.
par_n <- max(1L, as.integer(flag("parallel", "4")))
retries <- suppressWarnings(as.integer(flag("retries", "3"))); if (is.na(retries)) stop("VWF1! --retries must be a whole number")
retries <- max(0L, retries)   # retry rounds for the failed pages of a snapshot; 0 = none
# --retry-pause=a,b,c: seconds before retry round 1, 2, 3 (the last repeats). Default 5,15,30 (the laptop). The GitHub
# backup uses 120: the site serves a runner ~110 pages then refuses the rest for a while (24 Nov, run 45189369953:
# 110-124 of 174 a snapshot, different districts each time), so the missing pages are fetched in the next window and
# the pages already in hand are kept.
retry_pause <- suppressWarnings(as.numeric(strsplit(flag("retry-pause", "5,15,30"), ",", fixed = TRUE)[[1]]))
if (!length(retry_pause) || anyNA(retry_pause) || any(retry_pause < 0)) stop("VWF1! --retry-pause must be seconds, comma-separated")
get_many <- function(urls) {
  if (par_n <= 1L || length(urls) <= 1L) return(vapply(urls, get, character(1), USE.NAMES = FALSE))
  res <- rep(NA_character_, length(urls)); why <- rep("no reply", length(urls))
  # multiplex off: with it on, each connection carries up to 10 HTTP/2 streams, so "4" could be 40 pages in flight
  pool <- curl::new_pool(total_con = par_n, host_con = par_n, multiplex = FALSE)
  # GROUPS of N, each run to the end before the next is added. Adding every page at once left the ones waiting for a
  # free connection to hit curl's 10 s connect clock while still queued: 46 of 87 pages "timed out" (21 Nov 2026).
  for (g in split(seq_along(urls), ceiling(seq_along(urls) / par_n))) {
    for (i in g) local({ k <- i
      h <- curl::new_handle(url = urls[k], useragent = UA, timeout = 60)
      curl::multi_add(h, pool = pool,
        # an error in here (rawToChar on a body holding a NUL byte) would abort multi_run and the whole --every loop,
        # so it costs that one page instead: NA, then VWF3 and no DONE, as the one-at-a-time path does
        done = function(r) tryCatch({ if (r$status_code == 200L) { s <- rawToChar(r$content); Encoding(s) <- "UTF-8"
                               if (grepl("</html>", s, fixed = TRUE)) res[k] <<- s else why[k] <<- sprintf("HTTP 200 without </html> (%d bytes)", length(r$content))
                             } else why[k] <<- paste("HTTP", r$status_code) }, error = function(e) why[k] <<- paste("unreadable body:", conditionMessage(e))),
        fail = function(e) why[k] <<- as.character(e)[1]) })
    curl::multi_run(pool = pool)
  }
  # WHY a page failed, counted by cause (22 Nov 2026: from a GitHub runner 52-74 of 174 pages failed every snapshot
  # and the cause had been thrown away, so the log could not say whether it was a block, a timeout or a short page)
  if (anyNA(res)) { t <- sort(table(why[is.na(res)]), decreasing = TRUE)
    cat(sprintf("VWF5! %d of %d page(s) failed: %s\n", sum(is.na(res)), length(urls), paste(sprintf("%d x %s", as.integer(t), names(t)), collapse = "; "))) }
  res
}
links <- function(h) { l <- regmatches(h, gregexpr('href="[^"#]+"', h))[[1]]; l <- unique(gsub('^href="|"$', "", l))
  # "//other-host/..." is another site (the page's read-aloud link carries this page's own address in its query, so it
  # passed the "district" + "result" filter and was fetched from the VEC as a path: HTTP 500, 21 Nov rehearsal)
  l <- l[!startsWith(l, "//")]
  ifelse(grepl("^https?://", l), l, paste0(base, ifelse(startsWith(l, "/"), "", "/"), l)) }
vc_links <- function(l) list(fp = l[grepl("district-results-by-voting-centre$", l, ignore.case = TRUE)],
                             tcp = l[grepl("2cp-results-by-voting-centre$", l, ignore.case = TRUE)])
# the district a voting-centre link belongs to: the slug before "-district-results-by-..." or "-2cp-results-by-..."
link_slug <- function(u) slug(sub("-(district|2cp)-results-by-voting-centre$", "", basename(u), ignore.case = TRUE))

discover <- function() {
  h <- get(index); if (is.na(h)) stop("VWF2! could not read the index page ", index)
  l <- links(h); v <- vc_links(l)
  if (!length(v$fp)) {   # one level down: the district result pages
    dl <- l[grepl("district", l, ignore.case = TRUE) & grepl("result", l, ignore.case = TRUE) & !grepl("voting-centre", l, ignore.case = TRUE)]
    dl <- dl[startsWith(dl, base)]
    cat(sprintf("VWF2 index has no voting-centre links; following %d district result page(s)\n", length(dl)))
    for (hh in get_many(dl)) { if (is.na(hh)) next; vv <- vc_links(links(hh)); v$fp <- c(v$fp, vv$fp); v$tcp <- c(v$tcp, vv$tcp) }
  }
  fp <- unique(v$fp); tcp <- unique(v$tcp)
  m <- data.table(district = districts, s = slug(districts))
  m[, fp_url := fp[match(s, link_slug(fp))]][, tcp_url := tcp[match(s, link_slug(tcp))]]
  miss <- m[is.na(fp_url) | is.na(tcp_url)]
  cat(sprintf("VWF2 %d of %d districts have both pages linked\n", nrow(m) - nrow(miss), nrow(m)))
  if (nrow(miss)) stop("VWF2! no voting-centre pages found for: ", paste(utils::head(miss$district, 10), collapse = ", "),
                       if (nrow(miss) > 10) sprintf(" (+%d more)", nrow(miss) - 10) else "")
  m
}

one_snapshot <- function(m) {
  stamp <- format(as.POSIXct(Sys.time(), tz = "Australia/Melbourne"), "%Y%m%d_%H%M%S", tz = "Australia/Melbourne")
  d <- file.path(out, stamp); dir.create(d, recursive = TRUE, showWarnings = FALSE)
  bad <- character(0)
  jobs <- rbind(m[, list(district, u = fp_url, f = paste0(s, "-fp.html"), k = "fp")], m[, list(district, u = tcp_url, f = paste0(s, "-2cp.html"), k = "tcp")])
  pages <- get_many(jobs$u)
  # RETRY ONLY THE FAILED PAGES (22 Nov 2026): one failed page of 174 voids the whole snapshot, and the VEC site
  # answers bursts with HTTP 999 (4 to 74 pages a snapshot from a GitHub runner). Up to --retries rounds (default 3),
  # waiting 5, 15, then 30 s first. Pages that arrived are never fetched again, so a clean snapshot is unchanged.
  # A round that recovers NOTHING ends the retries (24 Nov 2026: a GitHub runner, refused on every page, retried 3 times
  # a snapshot every 90 s for 45 minutes and stayed blocked); the main loop then cools down before the next snapshot.
  refused <- FALSE
  for (r in seq_len(retries)) {
    again <- which(is.na(pages)); if (!length(again)) break
    Sys.sleep(retry_pause[min(r, length(retry_pause))])
    pages[again] <- get_many(jobs$u[again])
    cat(sprintf("VWF6 %s: retry %d of %d page(s), %d still failed\n", stamp, r, length(again), sum(is.na(pages))))
    # refused = nothing recovered AND a quarter or more of the snapshot still missing: a wholesale block. A few pages
    # that stay missing (one not yet published) keep the old short retries and --every (review, 24 Nov: one 404 among
    # 174 would otherwise cost the laptop a 5-20 minute cooldown on the night)
    if (sum(is.na(pages)) == length(again)) { refused <- length(again) >= 0.25 * nrow(jobs); break }
  }
  for (i in seq_len(nrow(jobs))) {
    if (is.na(pages[i])) { bad <- c(bad, paste(jobs$district[i], jobs$k[i])); next }
    writeLines(pages[i], file.path(d, jobs$f[i]), useBytes = TRUE)
  }
  if (length(bad)) { cat(sprintf("VWF3! %s: %d page(s) failed (%s); no DONE, the runner keeps the previous snapshot\n", stamp, length(bad),
                                 paste(utils::head(bad, 5), collapse = "; ")))
    return(invisible(if (refused) "refused" else FALSE)) }
  fwrite(m[, list(district, fp = paste0(s, "-fp.html"), tcp = paste0(s, "-2cp.html"), fp_url, tcp_url)], file.path(d, "manifest.csv"))
  writeLines(format(Sys.time(), tz = "Australia/Melbourne", usetz = TRUE), file.path(d, "DONE"))
  cat(sprintf("VWF4 %s: %d districts, %d pages saved\n", stamp, nrow(m), 2L * nrow(m)))
  invisible(TRUE)
}

# --cooldown=N (default 300 s): after a snapshot whose last retry recovered nothing with a quarter or more of its pages
# missing (the site refusing us), wait N seconds (or --every if longer) before the next one, doubling each time it
# happens again (to 4N), back to --every after any other result.
cooldown <- as.numeric(flag("cooldown", "300")); if (is.na(cooldown) || cooldown < 0) stop("VWF1! --cooldown must be a number of seconds")
m <- discover(); n <- 0L; strikes <- 0L
repeat {
  ok <- one_snapshot(m); n <- n + 1L
  if (every <= 0 || (max_cycles > 0 && n >= max_cycles)) break
  if (identical(ok, "refused")) {
    strikes <- strikes + 1L; wait <- max(every, cooldown * 2^min(strikes - 1L, 2L))
    cat(sprintf("VWF7! the site refused a whole retry round (%d time(s) running): waiting %.0f s before the next snapshot\n", strikes, wait))
  } else { strikes <- 0L; wait <- every }
  Sys.sleep(wait)
}
