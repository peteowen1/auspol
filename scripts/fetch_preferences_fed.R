# Federal House of Representatives first preferences and distributions of
# preferences, every election 2007-2025, from the AEC.
#
# WHY THIS IS THE BIGGEST SINGLE UNBLOCK AVAILABLE. The poll layer knows 78
# election cycles. The seat layer knows FOUR elections' first preferences, of
# which exactly one consecutive pair exists (NSW 2019 -> 2023). Every blocked
# piece of work traces to that: the candidate-model backtest ran on 88 seats,
# the seat-swing coefficients could not be shown stable across two elections,
# preference-flow uncertainty had one matrix, and the independent-emergence
# recontest rate was fitted on NINE seats.
#
# The AEC publishes both files for seven elections in a consistent format, no
# scraping: ~150 divisions each, so six consecutive pairs and roughly 900
# seat-observations against the 88 we have.
#
#   results.aec.gov.au/{id}/Website/Downloads/HouseFirstPrefsByCandidateByVoteTypeDownload-{id}.csv
#   results.aec.gov.au/{id}/Website/Downloads/HouseDopByDivisionDownload-{id}.csv
#
# 2004 (id 12246) does not use this pattern and is skipped; it is recorded here
# so nobody re-derives that from scratch.
#
# Outputs land in external/elections/, GITIGNORED -- no commission data is
# committed, the same treatment the VEC, NSWEC and SA data get.
#
# Emits FD* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

UA <- paste("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "(KHTML, like Gecko) Chrome/120 Safari/537.36")
RAW <- file.path("external", "reference", "aec")
OUT <- election_data_path()
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

ELECTIONS <- list(
  list(year = 2007, id = 13745), list(year = 2010, id = 15508),
  list(year = 2013, id = 17496), list(year = 2016, id = 20499),
  list(year = 2019, id = 24310), list(year = 2022, id = 27966),
  list(year = 2025, id = 31496))

grab <- function(url, dest) {
  if (file.exists(dest) && file.info(dest)$size > 10000) return(invisible(TRUE))
  utils::download.file(url, dest, mode = "wb", quiet = TRUE,
                       headers = c("User-Agent" = UA))
  invisible(TRUE)
}

# The AEC prefixes these files with a one-line banner before the header row.
read_aec <- function(path) {
  first <- readLines(path, n = 1L, warn = FALSE)
  skip <- if (grepl("^\\s*$", first) || !grepl(",", first)) 1L else
    if (grepl("Download|Report|generated", first, ignore.case = TRUE)) 1L else 0L
  fread(path, skip = skip, showProgress = FALSE)
}

fp_all <- list(); tx_all <- list()
for (E in ELECTIONS) {
  fpf <- file.path(RAW, sprintf("fed%d-firstprefs.csv", E$year))
  dpf <- file.path(RAW, sprintf("fed%d-dop.csv", E$year))
  grab(sprintf("https://results.aec.gov.au/%d/Website/Downloads/HouseFirstPrefsByCandidateByVoteTypeDownload-%d.csv",
               E$id, E$id), fpf)
  grab(sprintf("https://results.aec.gov.au/%d/Website/Downloads/HouseDopByDivisionDownload-%d.csv",
               E$id, E$id), dpf)

  fp <- read_aec(fpf); setnames(fp, make.names(names(fp)))
  need <- c("DivisionNm", "PartyNm", "TotalVotes")
  miss <- setdiff(need, names(fp))
  if (length(miss)) {
    stop("First-preference file for ", E$year, " lacks column(s): ",
         paste(miss, collapse = ", "), ". Columns present: ",
         paste(names(fp), collapse = ", "))
  }
  fp <- fp[!is.na(TotalVotes)]
  # Informal rows carry no party and must not be classified as a party's vote.
  fp <- fp[!(is.na(PartyNm) | PartyNm == "" | grepl("^Informal$", PartyNm, ignore.case = TRUE))]
  cls <- classify_party(fp$PartyNm, if ("PartyAb" %in% names(fp)) fp$PartyAb else NULL)
  fp[, party_class := cls]
  agg <- fp[, .(votes = sum(as.numeric(TotalVotes))),
            by = .(seat = DivisionNm, party = party_class)][votes > 0]
  agg[, election := sprintf("fed%d", E$year)]
  sh <- agg[, .(v = sum(votes)), by = party][, .(party, pct = 100 * v / sum(v))]
  cat(sprintf("\nFD1  %d: %d divisions, %s formal votes\n", E$year,
              uniqueN(agg$seat), format(sum(agg$votes), big.mark = ",")))
  print(sh[order(-pct)][, .(party, pct = round(pct, 2))])
  # Anchor: a national ALP first preference outside 25-50% means the classifier
  # or the informal filter is wrong, whatever the file looks like.
  a <- sh[party == "ALP", pct]
  if (!length(a) || a < 25 || a > 50) {
    stop("Federal ", E$year, " ALP first preference of ",
         if (length(a)) round(a, 1) else "NA",
         "% is outside any plausible range.")
  }
  if (uniqueN(agg$seat) < 140 || uniqueN(agg$seat) > 155) {
    stop("Federal ", E$year, " has ", uniqueN(agg$seat),
         " divisions, which is outside the plausible 140-155.")
  }
  fp_all[[length(fp_all) + 1L]] <- agg

  dp <- read_aec(dpf); setnames(dp, make.names(names(dp)))
  tx_all[[length(tx_all) + 1L]] <- list(year = E$year, dt = dp)
  cat(sprintf("FD1  %d preference-distribution rows, columns: %s\n", nrow(dp),
              paste(head(names(dp), 12), collapse = ", ")))
}

fp <- rbindlist(fp_all)
fwrite(fp, file.path(OUT, "aec-fed-firstprefs.csv"))
cat(sprintf("\nFD2  wrote %s: %d rows across %d elections, %d division-elections\n",
            file.path(OUT, "aec-fed-firstprefs.csv"), nrow(fp),
            uniqueN(fp$election), uniqueN(paste(fp$election, fp$seat))))
saveRDS(tx_all, file.path(RAW, "dop-raw.rds"))
cat("FD2  raw preference distributions cached; parsing them is the next step.\n")
