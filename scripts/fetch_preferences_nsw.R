# NSW Legislative Assembly first preferences, 2019 and 2023, from the NSWEC.
#
# WHY: the candidate-level seat model swings each seat's primaries off THAT
# SEAT's first preferences at the previous election. The repo held exactly one
# such dataset (Victoria 2022), and it is the input to the live forecast -- so
# there was nothing to score and the candidate model had never been backtested.
# NSW 2019 -> 2023 gives a genuine out-of-sample pair, in a different state, and
# a change of government rather than a landslide hold.
#
# The NSWEC publishes one state-wide workbook per election rather than 93
# district pages:
#   https://pastvtr.elections.nsw.gov.au/SG1901/LA/state/SGE 2019 LA Final Votes.xlsx
#   https://pastvtr.elections.nsw.gov.au/SG2301/LA/state/SGE 2023 LA Final Votes.xlsx
# Its "Data" sheet is booth-level: District, Vote Type, Venue, Formal/Informal,
# Candidate, Party Acronym, Party Name, Final FP Votes.
#
# The site 403s a default user agent, so a browser one is set. Downloads land in
# external/reference/nsw/ and outputs in external/elections/, both GITIGNORED --
# no commission data is committed, the same treatment the VEC and SA data get.
#
# Emits NF* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "nsw")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

SRC <- list(
  list(year = 2019, code = "SG1901", file = "SGE 2019 LA Final Votes.xlsx"),
  list(year = 2023, code = "SG2301", file = "SGE 2023 LA Final Votes.xlsx"))

for (s in SRC) {
  dest <- file.path(RAW, sprintf("sge%d-la-final-votes.xlsx", s$year))
  if (!file.exists(dest)) {
    url <- sprintf("https://pastvtr.elections.nsw.gov.au/%s/LA/state/%s",
                   s$code, utils::URLencode(s$file))
    cat(sprintf("fetching %d ...\n", s$year))
    utils::download.file(url, dest, mode = "wb", quiet = TRUE,
                         headers = c("User-Agent" = UA))
  }
  # A truncated download is the hazard here: this repo lost a seat once to a
  # file that was exactly 65536 bytes and passed a size floor. An xlsx is a zip,
  # so ask the zip whether it is intact rather than how big it is.
  sheets <- tryCatch(readxl::excel_sheets(dest), error = function(e) character(0))
  if (!"Data" %in% sheets) {
    stop("Download for ", s$year, " is not a readable workbook with a Data ",
         "sheet (found: ", paste(sheets, collapse = ", "), "). Delete ", dest,
         " and re-run; do NOT trust its size as evidence it arrived whole.")
  }

  d <- as.data.table(readxl::read_excel(dest, sheet = "Data"))
  setnames(d, make.names(names(d)))
  stopifnot(all(c("District", "Formal.Informal", "Party.Acronym",
                  "Party.Name", "Final.FP.Votes") %in% names(d)))
  cat(sprintf("\nNF1  %d: %d booth rows, %d districts\n",
              s$year, nrow(d), uniqueN(d$District)))

  # Informal votes are not a party's first preferences and must not be counted
  # as one. Dropped explicitly rather than left to a party classifier that would
  # bucket them as OTH.
  n_all <- nrow(d)
  d <- d[Formal.Informal == "Formal"]
  cat(sprintf("NF1  dropped %d informal rows, %d formal remain\n",
              n_all - nrow(d), nrow(d)))

  d[, votes := as.numeric(Final.FP.Votes)]
  d <- d[is.finite(votes)]
  # Classify OUTSIDE the brackets: `party` would otherwise be both a new column
  # and a symbol inside `[`, the shadowing trap this repo has hit six times.
  cls <- classify_party(d$Party.Name, d$Party.Acronym)
  d[, party_class := cls]
  agg <- d[, .(votes = sum(votes)), by = .(seat = District, party = party_class)]
  agg <- agg[votes > 0][order(seat, party)]

  # Anchor checks. A party classifier silently bucketing a major party as OTH
  # is exactly the failure that looks like a working file.
  cat(sprintf("NF2  %d: %d districts, %d seat-party rows, %s total formal votes\n",
              s$year, uniqueN(agg$seat), nrow(agg),
              format(sum(agg$votes), big.mark = ",")))
  print(agg[, .(votes = sum(votes), pct = round(100 * sum(votes) / sum(agg$votes), 2)),
            by = party][order(-votes)])
  if (uniqueN(agg$seat) != 93L) {
    stop("Expected 93 NSW districts for ", s$year, ", got ", uniqueN(agg$seat))
  }
  for (p in c("ALP", "LNP", "GRN")) {
    if (!p %in% agg$party) stop("No ", p, " votes classified for ", s$year,
                                " -- the party mapping is wrong.")
  }
  share <- agg[, .(v = sum(votes)), by = party][, setNames(v / sum(v) * 100, party)]
  if (share[["ALP"]] < 25 || share[["ALP"]] > 50) {
    stop("ALP statewide first preference of ", round(share[["ALP"]], 1),
         "% for ", s$year, " is outside any plausible range; the classifier ",
         "or the informal filter is wrong.")
  }
  f <- file.path(OUT, sprintf("nswec-%d-nsw-firstprefs.csv", s$year))
  fwrite(agg, f)
  cat(sprintf("NF3  wrote %s\n", f))
}
cat("\nNF4  done. Both files are in external/elections/, which is gitignored.\n")
