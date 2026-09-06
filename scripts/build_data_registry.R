# Generate docs/DATA-REGISTRY.md by SCANNING DISK.
#
# WHY THIS IS GENERATED AND NOT HAND-WRITTEN. On 2026-08-25 alone, three
# separate claims were made that data did not exist when it did: booth results
# and electoral boundaries (both sitting in external/reference/), and
# candidate-level federal first preferences for all seven elections (sitting in
# external/reference/aec/ since August, downloaded by fetch_preferences_fed.R
# and then aggregated away). Each cost real time and one of them produced a
# wrong recommendation.
#
# A hand-maintained list would drift the same way. CLAUDE.md already records the
# rule that hand-maintained reference data goes stale and that one wrong entry
# predicts siblings. So this reads the filesystem every time it runs, and the
# registry it writes is a snapshot with its own generation date on it.
#
# THE REGISTRY IS NOT AUTHORITATIVE ABOUT CONTENT, only about presence. It
# reports file sizes precisely so an empty or truncated file cannot masquerade
# as a working one -- ha-2018-03-17.json is 0 bytes and looks fine to
# file.exists().
#
# Emits DR* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "docs/DATA-REGISTRY.md"
today <- as.character(Sys.Date())

sz <- function(p) if (!file.exists(p)) NA_real_ else file.info(p)$size
human <- function(b) {
  if (is.na(b)) return("--")
  if (b == 0) return("**0 BYTES**")
  if (b < 1024) return(sprintf("%d B", b))
  if (b < 1024^2) return(sprintf("%.0f KB", b / 1024))
  sprintf("%.1f MB", b / 1024^2)
}

scan_dir <- function(d, pat = NULL) {
  if (!dir.exists(d)) return(data.table(file = character(), bytes = numeric()))
  f <- list.files(d, pattern = pat, full.names = TRUE, recursive = FALSE)
  f <- f[!dir.exists(f)]
  data.table(file = basename(f), bytes = vapply(f, sz, numeric(1)))
}

L <- c(sprintf("# Data registry\n"),
       sprintf("**Generated %s by `scripts/build_data_registry.R`. Do not hand-edit** --", today),
       "rerun the script instead. Regenerate it whenever you add or fetch data.\n",
       "This file exists because the same data has been declared missing three",
       "separate times while sitting on disk. **Check here before concluding we do",
       "not have something.** Sizes are shown so a zero-byte or truncated file",
       "cannot pass as a working one.\n")

# ---- election results, by region -------------------------------------------
L <- c(L, "## Election results (`external/elections/`)\n")
ed <- tryCatch(election_data_path(), error = function(e) "external/elections")
e <- scan_dir(ed, "\\.csv$")
if (nrow(e)) {
  e[, region := toupper(sub("^[a-z]+-(?:[0-9]{4}-)?([a-z]+)-.*$", "\\1", file))]
  e[!grepl("^[A-Z]+$", region), region := "other"]
  e[, kind := sub("^.*-([a-z]+)\\.csv$", "\\1", file)]
  L <- c(L, "| file | size |", "|---|---:|",
         sprintf("| `%s` | %s |", e$file, vapply(e$bytes, human, character(1))), "")
}

# ---- raw commission downloads ----------------------------------------------
L <- c(L, "## Raw commission downloads (`external/reference/`)\n")
for (d in c("aec", "vec", "nsw", "ecsa", "ecq", "waec", "trends",
            "boundaries", "census", "correspondences", "aef")) {
  p <- file.path("external", "reference", d)
  if (!dir.exists(p)) next
  f <- list.files(p, recursive = TRUE)
  if (!length(f)) { L <- c(L, sprintf("- **%s/** -- empty\n", d)); next }
  tot <- sum(file.info(list.files(p, recursive = TRUE, full.names = TRUE))$size,
             na.rm = TRUE)
  empt <- list.files(p, recursive = TRUE, full.names = TRUE)
  empt <- basename(empt[!is.na(file.info(empt)$size) & file.info(empt)$size == 0])
  L <- c(L, sprintf("- **%s/** -- %d files, %s%s", d, length(f), human(tot),
                    if (length(empt))
                      sprintf(". **%d ZERO-BYTE: %s**", length(empt),
                              paste(utils::head(empt, 5), collapse = ", ")) else ""))
  L <- c(L, sprintf("  - e.g. %s", paste(utils::head(sort(f), 4), collapse = ", ")))
}
L <- c(L, "")

# ---- what the candidacy corpus actually covers ------------------------------
L <- c(L, "## Candidate-level corpus (`output/candidacies.csv`)\n",
       "Built by `scripts/build_candidacies.R`. This is the only place candidate",
       "NAMES live -- the per-seat results files carry `seat, party, votes` only.\n")
cf <- "output/candidacies.csv"
if (file.exists(cf)) {
  C <- fread(cf, showProgress = FALSE)
  s <- C[, .(seats = uniqueN(seat), candidates = .N,
             ind = sum(party == "IND"),
             breakouts = sum(!party %in% c("ALP", "LNP", "NAT") & breakout)),
         by = .(election, region, year)][order(region, year)]
  L <- c(L, "| election | seats | candidates | IND | non-major breakouts |",
         "|---|---:|---:|---:|---:|",
         sprintf("| %s | %d | %d | %d | %d |", s$election, s$seats, s$candidates,
                 s$ind, s$breakouts),
         "",
         sprintf("**Total: %d candidacies, %d elections, %d non-major breakouts.**\n",
                 nrow(C), uniqueN(C$election), sum(!C$party %in% c("ALP","LNP","NAT") & C$breakout)))
} else L <- c(L, "_not built yet -- run `scripts/build_candidacies.R`_\n")

# ---- known gaps, stated rather than implied ---------------------------------
L <- c(L, "## Known gaps\n",
       "Listed so a gap is a recorded fact rather than something rediscovered:\n",
       "- **SA 2018** -- `external/reference/ecsa/ha-2018-03-17.json` is **0 bytes**,",
       "  a download that failed and was never noticed. Needs refetching.",
       "- **Victoria 2014 / 2018** -- only per-district HTML in",
       "  `external/reference/vec/2014` and `/2018`; no candidate extract yet.",
       "- **Queensland 2020 / 2024** -- XML on disk, not yet parsed to candidates.",
       "- **WA** -- per-seat JSON back to 1996, not yet parsed to candidates.",
       "- **Google Trends** -- only ~63 of the corpus has a cached response, and",
       "  every one is federal. No state candidacy has ever been queried.\n")

writeLines(L, OUT)
cat(sprintf("DR9  wrote %s (%d lines)\n", OUT, length(L)))
