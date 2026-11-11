# Fetch one snapshot of the VEC results website for the night runner (the VEC refused the results feed, 11 Nov 2026,
# and pointed to the website, which it says matches the feed and updates as often).
#
#   Rscript scripts/fetch_vec_web_snapshot.R --index=<results page URL> --out=<snapshot root>
#       [--districts=external/reference/vec/2026/vec-candidates-2026.csv | Name1,Name2] [--every=0] [--max-cycles=0]
#
# From --index it finds every district's two "results by voting centre" pages (first preferences, two-candidate):
# directly if the index links to them, else through the district result pages it links to (one level). Each district in
# the official list must be found; the names on the night come from that list, never from a page address. Writes
# <out>/<YYYYMMDD_HHMMSS>/ (Melbourne time, the stamp the night runner orders by): <slug>-fp.html, <slug>-2cp.html,
# manifest.csv (district, fp, tcp, fp_url, tcp_url) and DONE last, so the runner never reads a folder mid-fetch.
# Pages are saved exactly as received. Polite: one request at a time, a pause between them. --every=N repeats every N
# seconds (0 = once). Check codes VWF1-VWF4.
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
links <- function(h) { l <- regmatches(h, gregexpr('href="[^"#]+"', h))[[1]]; l <- unique(gsub('^href="|"$', "", l))
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
    for (u in dl) { hh <- get(u); if (is.na(hh)) next; vv <- vc_links(links(hh)); v$fp <- c(v$fp, vv$fp); v$tcp <- c(v$tcp, vv$tcp) }
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
  for (i in seq_len(nrow(m))) for (k in c("fp", "tcp")) {
    u <- m[[paste0(k, "_url")]][i]; f <- sprintf("%s-%s.html", m$s[i], if (k == "fp") "fp" else "2cp")
    h <- get(u); if (is.na(h)) { bad <- c(bad, paste(m$district[i], k)); next }
    writeLines(h, file.path(d, f), useBytes = TRUE)
  }
  if (length(bad)) { cat(sprintf("VWF3! %s: %d page(s) failed (%s); no DONE, the runner keeps the previous snapshot\n", stamp, length(bad),
                                 paste(utils::head(bad, 5), collapse = "; "))); return(invisible(FALSE)) }
  fwrite(m[, list(district, fp = paste0(s, "-fp.html"), tcp = paste0(s, "-2cp.html"), fp_url, tcp_url)], file.path(d, "manifest.csv"))
  writeLines(format(Sys.time(), tz = "Australia/Melbourne", usetz = TRUE), file.path(d, "DONE"))
  cat(sprintf("VWF4 %s: %d districts, %d pages saved\n", stamp, nrow(m), 2L * nrow(m)))
  invisible(TRUE)
}

m <- discover(); n <- 0L
repeat {
  one_snapshot(m); n <- n + 1L
  if (every <= 0 || (max_cycles > 0 && n >= max_cycles)) break
  Sys.sleep(every)
}
