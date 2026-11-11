# VEC RESULTS WEBSITE -> night booth tables (the VEC refused the results feed, 11 Nov 2026: "monitor the VEC website").
#
# Parses one district's two "results by voting centre" pages in the 2026 site layout (first preferences, and the
# two-candidate count) into the schema the night model reads:
#   fp:  district, booth, booth_type, candidate, party, votes        (night_booth_update()'s `live`)
#   tcp: district, booth, vote_type, candidate, party_raw, votes      (night_tcp_obs()'s `tcp`)
# Layout (Nepean by-election, May 2026): ONE table; header cells hold "SURNAME, Given" then the party (blank for an
# independent); "Total first preference" and "Percentage of formal votes" rows come first; then sections
# "Ordinary votes" (one row per voting centre, then "Ordinary votes total"), "Early votes" (per centre or only a
# total), "Declaration votes" (Absent, Marked as voted, Postal, Provisional, then "Declaration votes total").
# The 2022 layout is scripts/fetch_booths_vic2022.R parse_vc().
#
#   Rscript scripts/vec_web_booths.R <fp.html> <2cp.html> <district> [out prefix]
#
# Checks (VWB1-VWB3): page complete; per candidate, the parsed rows sum to the page's own total row; at least one
# candidate column. A page with an empty count (election night before 6pm) parses to zero votes, not an error.
suppressMessages(library(data.table))

vw_cells <- function(r) {
  cc <- regmatches(r, gregexpr("(?s)<t[hd][^>]*>.*?</t[hd]>", r, perl = TRUE))[[1]]
  lapply(cc, function(x) {
    parts <- strsplit(gsub("(?s)<[^>]+>", "\u0001", x, perl = TRUE), "\u0001", fixed = TRUE)[[1]]
    parts <- trimws(gsub("\\s+", " ", gsub("&#39;|&rsquo;", "'", gsub("&amp;", "&", gsub("&nbsp;", " ", parts)))))
    parts[nzchar(parts)]
  })
}
vw_num <- function(x) suppressWarnings(as.integer(gsub(",", "", x)))

vw_parse <- function(f, district) {
  h <- paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl("</html>", h, fixed = TRUE)) stop("VWB1! ", district, " ", basename(f), ": page truncated (no closing tag)")
  tbls <- regmatches(h, gregexpr("(?s)<table.*?</table>", h, perl = TRUE))[[1]]
  if (length(tbls) != 1L) stop("VWB1! ", district, " ", basename(f), ": expected one results table, found ", length(tbls))
  rows <- regmatches(tbls, gregexpr("(?s)<tr.*?</tr>", tbls, perl = TRUE))[[1]]
  cells <- lapply(rows, vw_cells)
  hdr <- cells[[1]]
  cand_cols <- which(vapply(hdr, function(p) length(p) >= 1 && grepl(",", p[1]), logical(1)))
  if (!length(cand_cols)) stop("VWB3! ", district, " ", basename(f), ": no candidate columns in the header")
  cands <- vapply(hdr[cand_cols], function(p) p[1], "")
  parties <- vapply(hdr[cand_cols], function(p) if (length(p) >= 2) p[2] else "", "")
  first <- function(cl) if (length(cl[[1]])) cl[[1]][1] else ""
  val <- function(cl) vapply(cand_cols, function(j) if (j <= length(cl) && length(cl[[j]])) vw_num(cl[[j]][1]) else NA_integer_, 1L)
  section <- NA_character_; out <- list(); tot <- NULL
  dmap <- c("absent votes" = "absent", "postal votes" = "postal", "provisional votes" = "provisional",
            "marked as voted votes" = "marked_as_voted", "early votes total" = "early")
  for (cl in cells[-1]) {
    l <- tolower(first(cl))
    if (!nzchar(l)) next
    if (grepl("^total first preference|^total 2cp|^total two|^total$", l)) { tot <- val(cl); next }
    if (grepl("^percentage", l)) next
    # section headings: "Ordinary votes", "Early votes" / "Early voting centres" (the 2CP page), "Declaration votes"
    if (grepl("^(ordinary votes|early votes|early voting centres|declaration votes)$", l)) { section <- sub(" .*$", "", l); next }
    if (grepl("^(ordinary|declaration) votes total$", l)) next
    if (l == "early votes total") {
      if (!any(vapply(out, function(x) identical(x$booth_type[1], "early"), logical(1))))   # no per-centre early rows: the total is the unit
        out[[length(out) + 1]] <- data.table(booth = NA_character_, booth_type = "early", candidate = cands, party = parties, votes = val(cl))
      next
    }
    if (l %in% names(dmap)) { out[[length(out) + 1]] <- data.table(booth = NA_character_, booth_type = dmap[[l]], candidate = cands, party = parties, votes = val(cl)); next }
    if (identical(section, "ordinary") || identical(section, "early"))
      out[[length(out) + 1]] <- data.table(booth = first(cl), booth_type = section, candidate = cands, party = parties, votes = val(cl))
    else cat(sprintf("VWB2  %s %s: row '%s' outside a known section, skipped\n", district, basename(f), first(cl)))
  }
  if (is.null(tot)) stop("VWB2! ", district, " ", basename(f), ": no total row")
  if (!length(out)) {   # an empty count (before 6pm): no booth rows yet; fine only while the page's own total is nothing
    if (any(tot > 0, na.rm = TRUE)) stop("VWB2! ", district, " ", basename(f), ": no booth rows but the page total is ", paste(tot, collapse = ","))
    return(data.table(district = character(), booth = character(), booth_type = character(), candidate = character(), party = character(), votes = integer()))
  }
  d <- rbindlist(out); d[, district := district]
  ours <- d[, list(v = sum(votes, na.rm = TRUE)), by = candidate][match(cands, candidate)]$v
  if (!isTRUE(all(ours == tot, na.rm = TRUE)) || anyNA(tot) && any(ours > 0))
    stop("VWB2! ", district, " ", basename(f), ": parsed totals ", paste(ours, collapse = ","), " vs page ", paste(tot, collapse = ","))
  d[, list(district, booth, booth_type, candidate, party, votes)]
}

if (sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) < 3) stop("usage: vec_web_booths.R <fp.html> <2cp.html> <district> [out prefix]")
  fp <- vw_parse(a[1], a[3]); tc <- vw_parse(a[2], a[3])
  # The 2CP page's party labels are NOT trusted: Nepean 2026's labels the independent Tracee Hutchison "Liberal"
  # (the first-preference page has her blank). Each candidate's party comes from the first-preference page.
  fpp <- unique(fp[, list(candidate, party_fp = party)])
  if (anyDuplicated(fpp$candidate)) stop("VWB4! ", a[3], ": a candidate name appears twice on the first-preference page")
  tc <- merge(tc, fpp, by = "candidate", all.x = TRUE, sort = FALSE)
  if (anyNA(tc$party_fp)) stop("VWB4! ", a[3], ": 2CP candidate(s) not on the first-preference page: ", paste(unique(tc$candidate[is.na(tc$party_fp)]), collapse = ", "))
  bad <- unique(tc[tc$party != tc$party_fp, list(candidate, party, party_fp)])
  if (nrow(bad)) cat(sprintf("VWB4  %s: 2CP page party differs from the first-preference page, first-preference used: %s\n", a[3],
                             paste(sprintf("%s ('%s' -> '%s')", bad$candidate, bad$party, bad$party_fp), collapse = "; ")))
  tc <- tc[, list(district, booth, vote_type = booth_type, candidate, party_raw = party_fp, votes)]
  for (x in list(list("fp", fp), list("2cp", tc))) {
    d <- x[[2]]
    cat(sprintf("VWB3 %s %s: %d rows, %d ordinary booths, types %s, %d candidates, %d votes\n", a[3], x[[1]], nrow(d),
                uniqueN(d$booth[!is.na(d$booth)]), paste(unique(d[[3]]), collapse = "/"), uniqueN(d$candidate), sum(d$votes, na.rm = TRUE)))
  }
  if (length(a) >= 4) { fwrite(fp, paste0(a[4], "-fp.csv")); fwrite(tc, paste0(a[4], "-2cp.csv")) }
}
