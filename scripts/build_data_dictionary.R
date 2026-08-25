# Generate docs/DATA-DICTIONARY.md by reading the COLUMNS of every dataset.
#
# WHY THIS EXISTS, AND WHY IT IS SEPARATE FROM THE REGISTRY.
# docs/DATA-REGISTRY.md answers "do we have this file". It cannot answer "do we
# have this FIELD", and on 2026-08-25/26 that distinction cost four separate
# wrong claims:
#
#   1. booth results        -- on disk, only the anchor archive was searched
#   2. electoral boundaries -- on disk, same
#   3. candidate NAMES      -- downloaded by fetch_preferences_fed.R since
#                              August and aggregated away. A whole plan was
#                              written around acquiring them.
#   4. seat-level SWING     -- the AEC ships a `Swing` column in every
#                              first-preferences file. Same fetcher, same
#                              aggregation, same loss.
#
# Cases 3 and 4 are the dangerous kind: the file IS in the registry, so the
# registry says we have it, and the field is gone anyway. **A column that is
# downloaded and dropped is invisible to every check we had.** So this reads
# columns, and it explicitly diffs each raw source against what the processed
# extract kept.
#
# Generated, never hand-edited: a hand-maintained dictionary drifts exactly the
# way the thing it documents drifts.
#
# Emits DD* codes.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

OUT <- "docs/DATA-DICTIONARY.md"
today <- as.character(Sys.Date())

hdr <- function(p) {
  # Read only what is needed to learn the shape. Some of these files are 17 MB.
  tryCatch({
    first <- readLines(p, n = 1L, warn = FALSE)
    skip <- if (length(first) && grepl("Election|Download|Report|generated", first,
                                       ignore.case = TRUE) && !grepl("^seat,|^election,", first)) 1L else 0L
    d <- fread(p, nrows = 5L, skip = skip, showProgress = FALSE)
    list(cols = names(d), ok = TRUE)
  }, error = function(e) list(cols = character(), ok = FALSE))
}
nrows_of <- function(p) {
  tryCatch(length(readLines(p, warn = FALSE)) - 1L, error = function(e) NA_integer_)
}

L <- c("# Data dictionary",
       "",
       sprintf("**Generated %s by `scripts/build_data_dictionary.R`. Do not hand-edit.**", today),
       "",
       "Companion to `docs/DATA-REGISTRY.md`. The registry answers *do we have this",
       "file*; this answers *do we have this field*. Four wrong \"we don't have it\"",
       "claims in two days came from the second question, and two of them were",
       "fields we download and then throw away. **Check here before concluding a",
       "column does not exist.**",
       "")

# ---- processed election data -----------------------------------------------
ED <- tryCatch(election_data_path(), error = function(e) "external/elections")
L <- c(L, "## Processed election data (`external/elections/`)", "")
f <- sort(list.files(ED, pattern = "[.]csv$", full.names = TRUE))
grp <- sub("^([a-z]+).*$", "\\1", basename(f))
L <- c(L, "| file | rows | columns |", "|---|---:|---|")
for (p in f) {
  h <- hdr(p)
  L <- c(L, sprintf("| `%s` | %s | %s |", basename(p),
                    format(nrows_of(p), big.mark = ","),
                    if (h$ok) paste0("`", paste(h$cols, collapse = "`, `"), "`") else "unreadable"))
}
L <- c(L, "")

# ---- raw commission downloads ----------------------------------------------
L <- c(L, "## Raw downloads (`external/reference/`)", "",
       "The originals, before any aggregation. **This is where dropped columns live.**", "")
for (d in c("aec", "nsw", "vec", "ecsa", "ecq", "waec")) {
  dir_d <- file.path("external", "reference", d)
  if (!dir.exists(dir_d)) next
  ff <- list.files(dir_d, pattern = "[.]csv$", full.names = TRUE)
  if (!length(ff)) { L <- c(L, sprintf("- **%s/** — no CSVs (see registry for other formats)", d)); next }
  L <- c(L, sprintf("### %s/", d), "", "| file | rows | columns |", "|---|---:|---|")
  for (p in utils::head(ff, 12)) {
    h <- hdr(p)
    L <- c(L, sprintf("| `%s` | %s | %s |", basename(p),
                      format(nrows_of(p), big.mark = ","),
                      if (h$ok) paste0("`", paste(h$cols, collapse = "`, `"), "`") else "unreadable"))
  }
  if (length(ff) > 12) L <- c(L, sprintf("| _(+%d more of the same shape)_ | | |", length(ff) - 12))
  L <- c(L, "")
}

# ---- THE DIFF: what the raw file has that the processed extract does not ----
L <- c(L, "## Columns we download and DROP", "",
       "Each row is a field present in the raw download and absent from the",
       "processed extract. Every one is recoverable without a new fetch.", "")
# RENAMES ARE NOT DROPS. DivisionNm becomes `seat`, PartyNm becomes `party`,
# TotalVotes becomes `votes`. Reporting those as losses buries the four columns
# that genuinely vanished among eighteen that did not, which defeats the point
# of the section. The map is explicit so a future rename that is NOT listed
# shows up as a drop and gets looked at, rather than being assumed benign.
RENAMED <- list(
  "aec-fed-firstprefs.csv" = c("DivisionNm", "PartyNm", "TotalVotes",
                               "OrdinaryVotes", "AbsentVotes", "ProvisionalVotes",
                               "PrePollVotes", "PostalVotes"))
pairs <- list(
  list(raw = file.path("external", "reference", "aec", "fed2022-firstprefs.csv"),
       proc = file.path(ED, "aec-fed-firstprefs.csv"),
       note = "AEC House first preferences by candidate"))
L <- c(L, "| raw source | processed as | genuinely dropped | renamed/aggregated |",
       "|---|---|---|---|")
for (q in pairs) {
  if (!file.exists(q$raw) || !file.exists(q$proc)) next
  a <- hdr(q$raw)$cols; b <- hdr(q$proc)$cols
  known <- RENAMED[[basename(q$proc)]]
  drop <- setdiff(setdiff(a, b), known)
  L <- c(L, sprintf("| `%s` | `%s` | %s | %s |", basename(q$raw), basename(q$proc),
                    if (length(drop)) paste0("**`", paste(drop, collapse = "`, `"), "`**") else "none",
                    if (length(known)) paste0("`", paste(intersect(known, a), collapse = "`, `"), "`") else "-"))
}
L <- c(L, "",
       "**Known consequences of the two that mattered:**", "",
       "- `Surname` / `GivenNm` — cost a plan written around *acquiring* candidate",
       "  names that were already downloaded. Now recovered by",
       "  `scripts/build_candidacies.R` into `output/candidacies.csv`.",
       "- `Swing` — the AEC's own seat-level swing, per candidate per division,",
       "  for all seven elections. `backtest_candidate_fed.R` records that it",
       "  \"cannot test\" the seat-swing port for want of a swing predictor.",
       "- `Elected` / `HistoricElected` — incumbency, which the published model",
       "  has no candidate-level feature for at all.",
       "")

# ---- derived outputs --------------------------------------------------------
L <- c(L, "## Derived outputs (`output/`)", "")
of <- sort(list.files("output", pattern = "[.]csv$", full.names = TRUE))
keep <- of[!grepl("backtest-", basename(of))]
L <- c(L, "| file | rows | columns |", "|---|---:|---|")
for (p in utils::head(keep, 30)) {
  h <- hdr(p)
  L <- c(L, sprintf("| `%s` | %s | %s |", basename(p),
                    format(nrows_of(p), big.mark = ","),
                    if (h$ok) paste0("`", paste(h$cols, collapse = "`, `"), "`") else "unreadable"))
}
L <- c(L, "", sprintf("_(%d `backtest-*.csv` arm outputs omitted; they share one shape.)_",
                      sum(grepl("backtest-", basename(of)))), "")

writeLines(L, OUT)
cat(sprintf("DD9  wrote %s (%d lines)\n", OUT, length(L)))
