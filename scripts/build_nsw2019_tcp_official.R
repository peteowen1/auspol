# nsw2019 declared two-candidate result per seat, from NSWEC's own
# distribution-of-preferences pages already cached under
# external/reference/nsw/dop/SG1901-<slug>.html (fetch_transfers_nsw.R).
#
# WHY: the TCP-vs-AEF prereg (docs/reviews/tcp-mae-vs-aef-2026-11-07.md,
# section 5) needs nsw2019 TCP MAE as a second metric, and
# aef7-final-two-and-tcp-reference.csv covers only the AEF-7 elections.
# Same parser as nsw2023 in build_aef7_tcp_official.R (the page layout is
# shared). Writes output/nsw2019-tcp-official.csv: one row per finalist,
# every field the page gives (name, party code, our class, final-count %).
#
# Emits N19-0..N19-3 log codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table)); suppressMessages(library(rvest))

# The 2019 pages are NOT the 2023 layout (no div.prcc-data; one plain table,
# party code glued to the name: "PARKER JamieGRN", "ZHANG Wenjie (Ben)LIB").
# Regex parse as in measure_nsw_flows.R. A finalist row is one whose last cell
# is "NN.NN %"; its last progressive total (prefixed "ELECTED" for the winner)
# is kept as votes so the % can be checked against it.
strip <- function(x) trimws(gsub("[[:space:]]+", " ", gsub("<[^>]+>", "", x)))
num <- function(s) suppressWarnings(as.numeric(gsub("[^0-9]", "", s)))
parse_nsw_dop <- function(fp) {
  h <- paste(readLines(fp, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  tb <- regmatches(h, regexpr("(?s)<table.*?</table>", h, perl = TRUE))
  if (!length(tb)) return(NULL)
  trs <- regmatches(tb, gregexpr("(?s)<tr.*?</tr>", tb, perl = TRUE))[[1]]
  rbindlist(lapply(trs, function(tr) {
    r <- strip(regmatches(tr, gregexpr("(?s)<t[hd].*?</t[hd]>", tr, perl = TRUE))[[1]])
    if (length(r) < 3 || !grepl("%$", r[length(r)]) || !nzchar(r[1])) return(NULL)
    if (grepl("^(Candidates|Total|Exhausted|Informal|Counts)", r[1])) return(NULL)
    vals <- r[-c(1, length(r))]
    vals <- vals[nzchar(vals) & vals != "EXCLUDED"]
    code <- sub("^.*[a-z)]", "", r[1])
    data.table(name = trimws(substr(r[1], 1, nchar(r[1]) - nchar(code))),
               code = if (nzchar(code)) code else NA_character_,
               elected = grepl("ELECTED", tail(vals, 1)),
               votes = num(tail(vals, 1)),
               pct = as.numeric(trimws(sub("%", "", r[length(r)]))))
  }), fill = TRUE)
}

files <- list.files(file.path("external", "reference", "nsw", "dop"),
                    pattern = "^SG1901-.*\\.html$", full.names = TRUE)
files <- files[!grepl("index", files)]
cat(sprintf("N19-0 %d SG1901 pages on disk\n", length(files)))

fails <- character(0)
res <- rbindlist(lapply(files, function(f) {
  slug <- sub("^SG1901-", "", sub("\\.html$", "", basename(f)))
  d <- tryCatch(parse_nsw_dop(f), error = function(e) NULL)
  if (is.null(d) || nrow(d) != 2) {
    fails <<- c(fails, sprintf("%s (%d rows)", slug, if (is.null(d)) 0L else nrow(d)))
    return(NULL)
  }
  d[, `:=`(seat = tools::toTitleCase(gsub("-", " ", slug)), slug = slug)]
}), fill = TRUE)

if (length(fails)) cat(sprintf("N19-1! %d page(s) without exactly two finalists: %s\n",
                               length(fails), paste(fails, collapse = ", ")))
stopifnot(nrow(res) > 0)
# NSWEC 2019 codes: "LAB" is Labor and "CLP" is COUNTRY LABOR (19 seats), which
# classify_party() deliberately will not read from the code ("CLP" is the
# Country Liberals in the NT). Pass the party NAME for those two; the rest
# (LIB, NAT, GRN, SFF, IND) are codes it already reads.
nm <- fifelse(res$code %in% c("LAB", "CLP"), "Australian Labor Party", NA_character_)
res[, cls := classify_party(nm, fifelse(code %in% c("LAB", "CLP"), NA_character_, code))]
stopifnot(res[code %in% c("LAB", "CLP"), all(cls == "ALP")])
res[, total := sum(pct), by = seat]
res[, pct_votes := round(100 * votes / sum(votes), 2), by = seat]
bad_v <- res[abs(pct_votes - pct) > 0.05, unique(seat)]
if (length(bad_v)) stop("N19-2 page % disagrees with its own final totals: ", paste(bad_v, collapse = ", "))
bad_e <- res[, sum(elected), by = seat][V1 != 1L, seat]
if (length(bad_e)) stop("N19-2 not exactly one ELECTED finalist: ", paste(bad_e, collapse = ", "))
bad_tot <- res[abs(total - 100) > 0.2, unique(seat)]
if (length(bad_tot)) stop("N19-2 finalists do not sum to 100%: ", paste(bad_tot, collapse = ", "))
res[, rk := frank(-pct, ties.method = "first"), by = seat]
setorder(res, seat, rk)
cat(sprintf("N19-2 %d seats resolved (%d finalist rows); class pairs:\n", uniqueN(res$seat), nrow(res)))
print(res[, .(pair = paste(sort(cls), collapse = "-")), by = seat][, .N, by = pair][order(-N)])
if (anyNA(res$cls)) cat(sprintf("N19-2! %d finalist(s) with no class\n", sum(is.na(res$cls))))

out <- res[, .(pair = "nsw2019", seat, slug, rank = rk, name, code, cls, elected, votes, pct)]
fwrite(out, file.path("output", "nsw2019-tcp-official.csv"))
cat(sprintf("N19-3 wrote output/nsw2019-tcp-official.csv (%d rows)\n", nrow(out)))
