# Candidate-level results for every by-election in byelection-winners.csv that byelection-results.csv lacks
# (8 Nov 2026: 78 of 133 missing, 24 of them changed hands -- e.g. Frome 2009, where the sitting independent
# Geoff Brock was then forecast at 2.8% in 2010 because no row named him).
#
#   Rscript scripts/fetch_byelection_results.R            fetch (cached), parse, write the supplement
#   Rscript scripts/fetch_byelection_results.R --merge    also append the parsed rows to byelection-results.csv
#
# Raw page per by-election, exactly as received, under external/reference/byelections/raw/ (fetched once; a later
# run re-parses the cache). Page title guessed as "<year> <seat> state by-election" (federal: "<year> <seat>
# by-election"), else Wikipedia's search. Parses the first wikitable whose header has Candidate/Party and Votes.
# Refuses a page whose parsed % do not sum to 95-105 or that has fewer than 2 candidates. Writes
# external/reference/byelections/byelection-results-supplement.csv (every parsed row, with page title and status)
# Emits BYR codes.
suppressMessages(library(data.table)); suppressMessages(library(rvest)); suppressMessages(library(jsonlite))
RAW <- file.path("external", "reference", "byelections", "raw"); dir.create(RAW, recursive = TRUE, showWarnings = FALSE)
UA <- "auspol-research/1.0 (election forecast backtests; contact via github.com/peteowen1/auspol)"
w <- fread(file.path("external", "reference", "byelections", "byelection-winners.csv"))
r <- fread(file.path("external", "reference", "byelections", "byelection-results.csv"))
key <- function(d) paste(d$region, d$seat, d$date)
todo <- w[!key(w) %in% key(r)]
cat(sprintf("BYR0 %d by-elections in the winners table, %d without results rows\n", nrow(w), nrow(todo)))

fetch_text <- function(url) {
  tmp <- tempfile(fileext = ".html")
  ok <- tryCatch({ utils::download.file(url, tmp, quiet = TRUE, headers = c("User-Agent" = UA)); TRUE }, error = function(e) FALSE)
  if (!ok || !file.exists(tmp) || file.size(tmp) < 500) return(NULL)
  tmp
}
page_for <- function(region, seat, yr) {
  slug <- function(t) gsub(" ", "_", t)
  cands <- if (region == "fed") sprintf("%s %s by-election", yr, seat) else
    c(sprintf("%s %s state by-election", yr, seat), sprintf("%s %s by-election", yr, seat))
  for (t in cands) {
    u <- paste0("https://en.wikipedia.org/wiki/", utils::URLencode(slug(t), reserved = TRUE))
    f <- fetch_text(u); Sys.sleep(1)
    if (!is.null(f) && any(grepl("by-election", readLines(f, warn = FALSE, n = 200), ignore.case = TRUE))) return(list(file = f, title = t))
  }
  q <- utils::URLencode(sprintf("%s %s by-election", yr, seat), reserved = TRUE)
  s <- tryCatch(fromJSON(sprintf("https://en.wikipedia.org/w/api.php?action=query&list=search&format=json&srlimit=3&srsearch=%s", q)), error = function(e) NULL)
  Sys.sleep(1)
  hit <- if (!is.null(s)) s$query$search$title else character(0)
  hit <- hit[grepl(as.character(yr), hit) & grepl(seat, hit, fixed = TRUE) & grepl("by-election", hit)]
  if (!length(hit)) return(NULL)
  u <- paste0("https://en.wikipedia.org/wiki/", utils::URLencode(slug(hit[1]), reserved = TRUE))
  f <- fetch_text(u); Sys.sleep(1)
  if (is.null(f)) NULL else list(file = f, title = hit[1])
}
num <- function(x) suppressWarnings(as.numeric(gsub("[^0-9.]", "", x)))
parse_page <- function(f) {
  doc <- read_html(f, encoding = "UTF-8")
  for (tb in html_elements(doc, "table.wikitable")) {
    t <- tryCatch(html_table(tb, fill = TRUE), error = function(e) NULL)
    if (is.null(t) || !nrow(t)) next
    h <- tolower(paste(names(t), collapse = " "))
    if (!grepl("votes", h) || !grepl("candidate|party", h)) next
    t <- as.data.frame(t, check.names = FALSE); nm <- tolower(names(t))
    ci <- which(grepl("candidate", nm))[1]; pi <- which(grepl("party", nm)); vi <- which(nm == "votes" | grepl("^votes", nm))[1]
    pc <- which(nm == "%" | grepl("%", nm, fixed = TRUE))[1]
    if (is.na(ci) || is.na(vi)) next
    pcol <- if (length(pi)) pi[length(pi)] else NA
    # FIRST PREFERENCES ONLY. A Wikipedia results table lists the primary rows, then "Total formal votes" /
    # "Informal" / "Turnout", then the two-candidate-preferred rows: cut at the first of those, or every
    # page sums to 200% (8 Nov 2026 first run: 72 of 77).
    rowtxt <- tolower(apply(t, 1, paste, collapse = " "))
    stop_at <- which(grepl("formal|informal|turnout|two-candidate|two-party|after distribution", rowtxt))[1]
    if (!is.na(stop_at)) t <- t[seq_len(stop_at - 1L), , drop = FALSE]
    if (!nrow(t)) next
    out <- data.table(candidate = trimws(as.character(t[[ci]])), party_raw = if (!is.na(pcol)) trimws(as.character(t[[pcol]])) else NA_character_,
                      votes = num(t[[vi]]), pct = if (!is.na(pc)) num(t[[pc]]) else NA_real_)
    out <- out[is.finite(votes) & votes > 0 & nzchar(candidate) &
               !grepl("total|formal|informal|turnout|two-candidate|two-party|registered|swing|hold|gain", tolower(paste(candidate, party_raw)))]
    if (nrow(out) >= 2) { if (anyNA(out$pct)) out[, pct := round(100 * votes / sum(votes), 2)]; return(out) }
  }
  NULL
}

res <- list(); status <- list()
for (i in seq_len(nrow(todo))) {
  x <- todo[i]; yr <- substr(x$date, 1, 4)
  rawf <- file.path(RAW, sprintf("%s-%s-%s.html", x$region, gsub("[^A-Za-z0-9]+", "-", x$seat), x$date))
  title <- NA_character_
  if (!file.exists(rawf)) {
    pg <- page_for(x$region, x$seat, yr)
    if (is.null(pg)) { status[[i]] <- data.table(region = x$region, seat = x$seat, date = x$date, status = "no page"); next }
    file.copy(pg$file, rawf); title <- pg$title
    writeLines(title, paste0(rawf, ".title"))
  } else if (file.exists(paste0(rawf, ".title"))) title <- readLines(paste0(rawf, ".title"), warn = FALSE)[1]
  p <- tryCatch(parse_page(rawf), error = function(e) NULL)
  if (is.null(p)) { status[[i]] <- data.table(region = x$region, seat = x$seat, date = x$date, status = "no results table"); next }
  tot <- sum(p$pct, na.rm = TRUE)
  st <- if (tot < 95 || tot > 105) sprintf("pct sums to %.1f", tot) else "ok"
  status[[i]] <- data.table(region = x$region, seat = x$seat, date = x$date, status = st, n = nrow(p), title = title)
  res[[i]] <- p[, `:=`(region = x$region, seat = x$seat, date = x$date, source = paste0("https://en.wikipedia.org/wiki/", gsub(" ", "_", title)), status = st)]
}
S <- rbindlist(status, fill = TRUE); R <- rbindlist(res, fill = TRUE)
cat("BYR1 status:\n"); print(S[, .N, by = status])
if (nrow(S[status != "ok"])) { cat("BYR2! not usable:\n"); print(S[status != "ok"]) }
fwrite(R, file.path("external", "reference", "byelections", "byelection-results-supplement.csv"))
cat(sprintf("BYR3 wrote byelection-results-supplement.csv: %d rows for %d by-elections (%d ok)\n", nrow(R), uniqueN(R[, paste(region, seat, date)]), S[status == "ok", .N]))
if ("--merge" %in% commandArgs(trailingOnly = TRUE)) {
  add <- R[status == "ok", .(region, seat, date, candidate, party_raw, votes, pct, source)]
  m <- rbind(r, add, fill = TRUE)
  stopifnot(!anyDuplicated(m[, paste(region, seat, date, candidate)]))
  fwrite(m, file.path("external", "reference", "byelections", "byelection-results.csv"))
  cat(sprintf("BYR4 merged %d rows (%d by-elections) into byelection-results.csv: %d -> %d rows\n", nrow(add), uniqueN(add[, paste(region, seat, date)]), nrow(r), nrow(m)))
}
