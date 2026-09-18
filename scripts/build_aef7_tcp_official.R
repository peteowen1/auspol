# Replaces the 232 fsrc="derived" rows in aef7-final-two-and-tcp-reference.csv
# (nsw2023 87, qld2024 93, wa2025 52) with the REAL declared two-candidate
# result, parsed straight from each state's own electoral commission source
# that was already sitting on disk, unread by any script:
#   nsw2023  external/reference/nsw/dop/SG2301-<slug>.html  (NSWEC's own
#            distribution-of-preferences page, static HTML despite the
#            noscript warning -- the count table renders without JS)
#   qld2024  external/reference/ecq/qld2024.xml              (ECQ's own
#            declared results, <twoCandidateVotes> per district)
#   wa2025   external/reference/waec/sg2025-<code>.json       (WAEC's own
#            resultsFullDistribution, final "Progressive Total N" round)
#
# WHY: found 2026-09-18 while checking whether to scrape ABC's site for
# independent TCP verification -- ABC's own guide page is real per-candidate
# data (not a secondary aggregation), but before scraping a third party for
# something we could check for ourselves: does the source itself carry the
# declared 2-candidate result already? It does, for all three of these
# elections; only vic2022 has no equivalent VEC archive on disk (its 78 seats
# stay fsrc="derived"/"aef-cache" until that's fetched separately).
#
# Both this file's output and scripts/fetch_abc_seat_guides.R's scrape verify
# the SAME 232 seats from two independent sources -- run both and diff before
# trusting either at scale, per CLAUDE.md's "prove a check works before
# trusting it" rule.
#
# Party is expressed as OUR class (ALP/LNP/GRN/...) via classify_party(), the
# same scheme every other fsrc="official" row already uses -- so an
# intra-Coalition seat still collapses to "LNP" vs "LNP" here exactly as it
# does everywhere else in this table. Real per-candidate detail (which of the
# two Coalition candidates actually won) is printed to the log but not stored
# in the class-keyed reference; that comparison isn't meaningful at the class
# level and the existing intra-coalition-excluded rows are correct as they
# stand for the class-level TCP metric this file feeds.
#
# Emits OFF0-OFF4 log codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(rvest))
suppressMessages(library(xml2)); suppressMessages(library(jsonlite))

OUT <- "output"
ref <- fread(file.path(OUT, "aef7-final-two-and-tcp-reference.csv"), showProgress = FALSE)

# ---- nsw2023: NSWEC distribution-of-preferences pages -----------------
parse_nsw_dop <- function(fp) {
  doc <- read_html(fp, encoding = "UTF-8")
  rows <- html_elements(doc, "div.prcc-data table tbody tr")
  if (!length(rows)) return(NULL)
  out <- rbindlist(lapply(rows, function(tr) {
    tds <- html_elements(tr, "td")
    if (length(tds) < 3) return(NULL)
    namecell <- html_text2(tds[[1]])
    if (!nzchar(trimws(namecell))) return(NULL)
    lastcell <- trimws(html_text2(tds[[length(tds)]]))
    if (!grepl("%$", lastcell)) return(NULL)
    parts <- strsplit(namecell, "\n")[[1]]
    data.table(name = trimws(parts[1]),
               code = if (length(parts) > 1) trimws(parts[2]) else NA_character_,
               pct = as.numeric(sub("%", "", lastcell)))
  }), fill = TRUE)
  out
}

nsw_files <- list.files(file.path("external", "reference", "nsw", "dop"),
                         pattern = "^SG2301-.*\\.html$", full.names = TRUE)
nsw_files <- nsw_files[!grepl("index", nsw_files)]
nsw_res <- rbindlist(lapply(nsw_files, function(f) {
  seat <- tools::toTitleCase(gsub("-", " ", sub("^SG2301-", "", sub("\\.html$", "", basename(f)))))
  d <- tryCatch(parse_nsw_dop(f), error = function(e) NULL)
  if (is.null(d) || nrow(d) != 2) { cat(sprintf("OFF1! nsw2023/%s: %d finalist rows (want 2)\n", seat, if (is.null(d)) 0L else nrow(d))); return(NULL) }
  d[, seat := seat]
}), fill = TRUE)
cat(sprintf("OFF0 nsw2023: %d of %d seats resolved from NSWEC DOP pages\n", uniqueN(nsw_res$seat), length(nsw_files)))

# ---- qld2024: ECQ declared-results XML ---------------------------------
doc <- read_xml(file.path("external", "reference", "ecq", "qld2024.xml"))
districts <- xml_find_all(doc, ".//district")
qld_res <- rbindlist(lapply(districts, function(d) {
  seat <- xml_attr(d, "districtName")
  rounds <- xml_find_all(d, ".//countRound[twoCandidateVotes]")
  if (!length(rounds)) return(NULL)  # e.g. Ipswich City Division 4 -- a local-council row in the same file, not a state seat
  rnums <- as.integer(xml_attr(rounds, "round"))
  r <- rounds[[which.max(rnums)]]
  cands <- xml_find_all(r, "./twoCandidateVotes/candidate")
  if (length(cands) != 2) return(NULL)
  ord <- xml_attr(cands, "ballotOrderNumber")
  cand_defs <- xml_find_all(d, sprintf(".//candidates/candidate[@ballotOrderNumber='%s']", ord))
  party <- vapply(seq_along(cands), function(i) {
    cd <- xml_find_first(d, sprintf(".//candidates/candidate[@ballotOrderNumber='%s']", ord[i]))
    if (is.na(cd)) NA_character_ else xml_attr(cd, "party")
  }, character(1))
  code <- vapply(seq_along(cands), function(i) {
    cd <- xml_find_first(d, sprintf(".//candidates/candidate[@ballotOrderNumber='%s']", ord[i]))
    if (is.na(cd)) NA_character_ else xml_attr(cd, "partyCode")
  }, character(1))
  data.table(seat = seat, name = xml_attr(cands, "ballotName"), party = party, code = code,
             pct = as.numeric(xml_text(xml_find_first(cands, "./percentage"))))
}), fill = TRUE)
cat(sprintf("OFF0 qld2024: %d of %d districts resolved from ECQ XML\n", uniqueN(qld_res$seat), length(districts)))

# ---- wa2025: WAEC resultsFullDistribution --------------------------------
wa_files <- list.files(file.path("external", "reference", "waec"),
                        pattern = "^sg2025-[A-Z]+\\.json$", full.names = TRUE)
wa_res <- rbindlist(lapply(wa_files, function(fp) {
  j <- tryCatch(fromJSON(fp, simplifyVector = FALSE), error = function(e) NULL)
  fd <- j$resultsFullDistribution
  if (is.null(fd) || !length(fd)) return(NULL)
  dt <- rbindlist(lapply(fd, function(r) {
    data.table(dist_level = r$DISTRIBUTION_LEVEL, name = r$BALLOT_PAPER_NAME,
               val = r$FORMAL_LAST_PUBLISHED_NUMBER_ENTERED)
  }), fill = TRUE)
  dt <- dt[grepl("^Progressive Total", dist_level)]
  if (!nrow(dt)) return(NULL)
  dt[, lvl := as.integer(sub("Progressive Total ", "", dist_level))]
  final <- dt[lvl == max(lvl) & !is.na(val) & val > 0]
  if (nrow(final) != 2) return(NULL)
  final[, pct := round(100 * val / sum(val), 2)]
  seat <- j$currentElectorate$ElectorateName
  if (is.null(seat)) seat <- j$electorates[[1]]$ElectorateName
  parts <- lapply(strsplit(final$name, " - "), trimws)
  final[, `:=`(seat = seat, code = vapply(parts, function(p) tail(p, 1), character(1)))]
  final[, .(seat, name, code, pct)]
}), fill = TRUE)
cat(sprintf("OFF0 wa2025: %d of %d electorates resolved from WAEC JSON\n", uniqueN(wa_res$seat), length(wa_files)))

# ---- reduce each to f1 (winner class)/f2 (runner-up class)/f2cp, and merge
to_f1f2 <- function(dt, name_col = "code", party_col = NULL) {
  dt[, cls := if (!is.null(party_col)) classify_party(get(party_col), get(name_col)) else classify_party(rep(NA_character_, .N), get(name_col))]
  dt[, rk := frank(-pct), by = seat]
  wide <- dcast(dt, seat ~ rk, value.var = c("cls", "pct"))
  setnames(wide, c("cls_1", "cls_2", "pct_1"), c("f1", "f2", "f2cp"))
  wide[, .(seat, f1, f2, f2cp = round(f2cp, 1))]
}

nsw_f <- to_f1f2(copy(nsw_res), name_col = "code")[, pair := "nsw2023"]
qld_f <- to_f1f2(copy(qld_res), name_col = "code", party_col = "party")[, pair := "qld2024"]
wa_f  <- to_f1f2(copy(wa_res),  name_col = "code")[, pair := "wa2025"]

official <- rbindlist(list(nsw_f, qld_f, wa_f), fill = TRUE)
official[, fsrc := "official"]

# Same-class finalists (an intra-Coalition Liberal-vs-National contest, which
# classify_party() collapses to LNP on both sides) must NOT overwrite the
# existing fsrc="intra-coalition-excluded" rows -- these official sources give
# the real per-candidate split, but at the CLASS level this table is keyed on
# it is still "LNP vs LNP", which build_aef7_tcp_backfill.R already excludes
# for good reason (a class-level TCP metric can't score a same-class pair).
# Without this filter the join below silently re-populates Port Macquarie and
# Roe with a degenerate f1==f2=="LNP" row -- caught only by checking those two
# seats by name after the first run of this script.
n_intra <- official[f1 == f2, .N]
if (n_intra) cat(sprintf("OFF1! dropping %d intra-Coalition (same-class) official row(s) from the merge: %s\n",
                          n_intra, paste(official[f1 == f2]$seat, collapse = ", ")))
official <- official[f1 != f2]

n_before <- ref[pair %in% c("nsw2023", "qld2024", "wa2025") & fsrc == "derived", .N]
ref[official, on = c("pair", "seat"), `:=`(f1 = i.f1, f2 = i.f2, f2cp = i.f2cp, fsrc = i.fsrc)]
n_after <- ref[pair %in% c("nsw2023", "qld2024", "wa2025") & fsrc == "derived", .N]

cat(sprintf("OFF2 nsw2023/qld2024/wa2025 'derived' rows: %d before, %d after (%d upgraded to official)\n",
            n_before, n_after, n_before - n_after))
cat("OFF3 fsrc breakdown after merge:\n")
print(ref[, .N, by = .(pair, fsrc)][order(pair, fsrc)])

fwrite(ref, file.path(OUT, "aef7-final-two-and-tcp-reference.csv"))
cat(sprintf("OFF4 wrote %s\n", file.path(OUT, "aef7-final-two-and-tcp-reference.csv")))
