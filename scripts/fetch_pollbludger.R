#!/usr/bin/env Rscript
# Fetch The Poll Bludger's posts for each election's final weeks, as raw HTML.
#
# WHY: Pete's end game is to stop using AE's hand-authored poll files
# (docs/reviews/ae-dependence-audit-2026-10-13.md). After our Wikipedia scrape,
# 71 final-month polls still carry AE's numbers, mostly fed2007 and fed2010,
# and Wikipedia covers neither well. Poll Bludger posted on nearly every poll
# with the primaries in the text, back to 2004.
#
# WHAT: the five post sitemaps list every post URL (dated in the path). We keep
# the posts dated within --days (default 90) before each polling day in
# election_dates(), from 2004 on (the blog's first post is July 2004), and fetch
# the DAY archive page for each such date, because one day page holds every post
# of that day without the comment threads (about 110 KB against megabytes).
#
# RAW FIRST (CLAUDE.md "Store the raw response"): every page lands in
# external/reference/polls/pollbludger/raw/days/<YYYY-MM-DD>[-pN].html and is
# never refetched while on disk. The extractor (extract_pollbludger.R) reads
# only these files, so an extractor fix needs no refetch.
#
# COMPLETENESS (a size floor is not a completeness check): a page counts only
# if it ends in </html>, and a day counts only if every post the sitemap lists
# for it appears on the page; otherwise the next archive page (/page/2/) is
# fetched. The manifest records each day's sitemap and found post counts.
#
# Usage: Rscript scripts/fetch_pollbludger.R [--days=90] [--dry-run] [--max=N]
# Check codes: BG1 sitemap, BG2 plan, BG3 progress, BG4 summary, BG5! incomplete day.

suppressPackageStartupMessages({ library(data.table); library(curl) })
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))

args    <- commandArgs(trailingOnly = TRUE)
arg_val <- function(k, d) { a <- grep(paste0("^--", k, "="), args, value = TRUE); if (length(a)) sub(".*=", "", a[1]) else d }
days    <- as.integer(arg_val("days", "90"))
max_n   <- as.integer(arg_val("max", "100000"))
dry     <- "--dry-run" %in% args

base    <- "external/reference/polls/pollbludger"
sm_dir  <- file.path(base, "raw", "sitemaps")
day_dir <- file.path(base, "raw", "days")
dir.create(sm_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(day_dir, recursive = TRUE, showWarnings = FALSE)
UA <- "Mozilla/5.0 (auspol election research; one request a second)"

get_page <- function(url) {
  h <- new_handle(useragent = UA, timeout = 60, followlocation = TRUE)
  r <- tryCatch(curl_fetch_memory(url, handle = h), error = function(e) NULL)
  Sys.sleep(1)
  if (is.null(r)) return(list(status = NA_integer_, body = NULL))
  list(status = r$status_code, body = r$content)
}
# The site's cache appends "<!-- Page cached by LiteSpeed ... -->" after </html>, so trailing comments are allowed.
complete_html <- function(b) !is.null(b) && grepl("</html>\\s*(<!--.*?-->\\s*)*$", rawToChar(utils::tail(b, 400)), perl = TRUE)

## 1. Sitemaps, named by the index (which is refetched each run). post-sitemap1 holds the newest posts,
## so it is refetched too; the older ones are fixed once written. (Asking past the last one returns an
## empty urlset, not a 404.)
r <- get_page("https://www.pollbludger.net/sitemaps.xml")
if (!identical(r$status, 200L) || !grepl("</sitemapindex>", rawToChar(r$body)))
  stop("BG1! sitemap index failed: HTTP ", r$status, call. = FALSE)
writeBin(r$body, file.path(sm_dir, "sitemaps.xml"))
idx <- rawToChar(r$body)
sm_urls <- gsub("</?loc>", "", regmatches(idx, gregexpr("<loc>[^<]*post-sitemap\\d+\\.xml</loc>", idx))[[1]])
if (!length(sm_urls)) stop("BG1! no post sitemaps in the index", call. = FALSE)
sm_files <- character(0)
for (u in sm_urls) {
  f <- file.path(sm_dir, basename(u))
  if (!file.exists(f) || basename(u) == "post-sitemap1.xml") {
    r <- get_page(u)
    if (!identical(r$status, 200L) || !grepl("</urlset>", rawToChar(r$body)) || !grepl("<loc>", rawToChar(r$body)))
      stop("BG1! sitemap ", basename(u), " failed or empty: HTTP ", r$status, call. = FALSE)
    writeBin(r$body, f)
  }
  sm_files <- c(sm_files, f)
}
posts <- rbindlist(lapply(sm_files, function(f) {
  x <- readLines(f, warn = FALSE, encoding = "UTF-8"); x <- paste(x, collapse = "")
  u <- regmatches(x, gregexpr("<loc>[^<]+</loc>", x))[[1]]
  data.table(url = gsub("</?loc>", "", u), sitemap = basename(f))
}))
posts <- posts[grepl("/\\d{4}/\\d{2}/\\d{2}/", url)]
posts[, date := as.Date(sub(".*/(\\d{4})/(\\d{2})/(\\d{2})/.*", "\\1-\\2-\\3", url))]
posts[, slug := sub(".*/\\d{4}/\\d{2}/\\d{2}/([^/]+)/?$", "\\1", url)]
if (anyDuplicated(posts$url)) stop("BG1! duplicate post URLs across sitemaps", call. = FALSE)
cat(sprintf("BG1 sitemaps: %d files, %d dated posts, %s to %s\n", length(sm_files), nrow(posts),
            min(posts$date), max(posts$date)))

## 2. Which days: posts within `days` of a polling day (live cycles: up to today).
eds <- election_dates(); eds <- eds[eds >= as.Date("2004-07-01")]
win <- data.table(election = names(eds), end = pmin(as.Date(eds), Sys.Date()))
win[, start := as.Date(eds) - days]
win <- win[start <= Sys.Date()]
posts[, election := NA_character_]
for (k in seq_len(nrow(win))) {
  m <- posts$date >= win$start[k] & posts$date <= win$end[k]
  posts[m & is.na(election), election := win$election[k]]
}
want <- posts[!is.na(election)]
day_tab <- want[, .(n_posts = .N, elections = paste(unique(election), collapse = ",")), by = date][order(date)]
cat(sprintf("BG2 plan: %d posts on %d days across %d elections (window %d days)\n",
            nrow(want), nrow(day_tab), uniqueN(want$election), days))
print(want[, .(posts = .N, days = uniqueN(date)), by = election][order(election)])
fwrite(posts, file.path(base, "post_index.csv"))
if (dry) quit(save = "no")

## 3. Day pages, raw, never refetched while complete on disk.
day_file <- function(d, p) file.path(day_dir, if (p == 1L) sprintf("%s.html", d) else sprintf("%s-p%d.html", d, p))
day_url  <- function(d, p) sprintf("https://www.pollbludger.net/%s/%s", format(d, "%Y/%m/%d"), if (p == 1L) "" else sprintf("page/%d/", p))
man <- vector("list", nrow(day_tab)); n_get <- 0L; t0 <- Sys.time()
for (k in seq_len(min(nrow(day_tab), max_n))) {
  d <- day_tab$date[k]; slugs <- want[date == d, slug]
  found <- character(0); pages <- 0L; status <- "ok"; on_page <- 0L
  for (p in 1:10) {
    f <- day_file(d, p)
    if (!file.exists(f) || !complete_html(readBin(f, "raw", file.info(f)$size))) {
      r <- get_page(day_url(d, p)); n_get <- n_get + 1L
      if (identical(r$status, 404L)) { if (p == 1L) status <- "404"; break }
      if (!identical(r$status, 200L) || !complete_html(r$body)) { status <- paste0("http_", r$status); break }
      writeBin(r$body, f)
    }
    pages <- p
    txt <- rawToChar(readBin(f, "raw", file.info(f)$size))
    on_page <- on_page + sum(gregexpr("<article id=\"post-", txt, fixed = TRUE)[[1]] > 0)
    found <- union(found, slugs[vapply(slugs, function(s) grepl(paste0("/", s, "/"), txt, fixed = TRUE), TRUE)])
    if (all(slugs %in% found)) break
  }
  if (status == "ok" && !all(slugs %in% found)) status <- "incomplete"
  man[[k]] <- data.table(date = d, elections = day_tab$elections[k], sitemap_posts = length(slugs),
                         found_posts = length(found), articles_on_pages = on_page, pages = pages, status = status)
  if (k %% 100 == 0) cat(sprintf("BG3 %d / %d days, %d requests, %.1f min\n", k, nrow(day_tab), n_get,
                                 as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
man <- rbindlist(man)
fwrite(man, file.path(base, "days_manifest.csv"))
bad <- man[status != "ok"]
cat(sprintf("BG4 days %d: ok %d, not ok %d; posts %d of %d found; %d requests in %.1f min\n",
            nrow(man), sum(man$status == "ok"), nrow(bad), sum(man$found_posts), sum(man$sitemap_posts),
            n_get, as.numeric(difftime(Sys.time(), t0, units = "mins"))))
if (nrow(bad)) { cat("BG5! days not fully fetched:\n"); print(bad) }
