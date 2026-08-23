# Archived forecasts and official results from Australian Election Forecasts
# (aeforecasts.com), so this repo has something real to score itself against.
#
# WHY THIS EXISTS. docs/ANCHOR-MODEL.md has always said our accuracy has never
# been tested against either reference model -- AE Forecasts or theswingison.
# It could not be: we had AE Forecasts' CODE (it is open source) but not their
# actual forecasts, and a mechanism argument is not a comparison. Their site
# publishes eight archived elections through a small REST API: the final
# pre-election forecast (seat win frequencies, first-preference trend) and the
# eventual official result, for each. scripts/score_aeforecasts.R reads what
# this script downloads.
#
# THE ACCESS CHAIN, found by trial and error and not worth re-deriving:
#
#   Base:      https://www.aeforecasts.com/forecast-api/
#   Endpoints: election-results/<code>/          -> top-level key "results"
#              election-summary/<code>/regular   -> top-level key "report"
#   Codes:     2022vic 2022fed 2022sa 2023nsw 2024qld 2025wa 2025fed 2026sa
#
# THE "www." PREFIX IS REQUIRED. The apex domain aeforecasts.com does not
# resolve from this environment at all -- DNS_PROBE_FINISHED_NXDOMAIN, not a
# redirect or a certificate error -- while www.aeforecasts.com resolves fine.
# Dropping the prefix looks like a network outage, not a wrong URL, and it
# cost real time to work out which one it was. Recorded here so it is not
# re-discovered.
#
# "?format=json" IS REQUIRED. This API is Django REST Framework, and DRF's
# default content negotiation serves its own browsable-API HTML page to a
# plain GET rather than the JSON payload -- no error, no wrong status code,
# just a page that is not what was asked for. Appending ?format=json forces
# the JSON renderer.
#
# THE GUARD THIS SCRIPT CARES MOST ABOUT. CLAUDE.md records a truncated
# 65536-byte download that sailed past a `> 2000` size-floor guard, parsed to
# zero rows, and dropped a seat silently. A size floor cannot tell a genuine
# JSON payload from a DRF HTML page or a half-written file that happens to be
# long enough -- both "look" like data by size alone. So nothing here is
# accepted on size: every file, cached or freshly downloaded, must actually
# parse as JSON AND carry the expected top-level key ("results" or "report")
# before it counts as fetched. A file that fails that check is re-downloaded
# once (the failure might be a stale half-write from an earlier interrupted
# run); if it fails again, the run ABORTS naming that exact file rather than
# warning and moving on.
#
# external/ is gitignored, so none of what this script writes is committed --
# same as the external/aus-polling-analyser anchor clone and the WAEC/ECQ raw
# dumps under external/reference/.
#
# Emits AF* codes. (Grepped ARCHITECTURE.md and scripts/ first: AF is free --
# WF is Western Australia, QF is Queensland, AE is score_aeforecasts.R.)

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(jsonlite))

BASE <- "https://www.aeforecasts.com/forecast-api/"
RAW  <- file.path("external", "reference", "aef")
dir.create(RAW, showWarnings = FALSE, recursive = TRUE)

CODES <- c("2022vic", "2022fed", "2022sa", "2023nsw",
           "2024qld", "2025wa", "2025fed", "2026sa")

# One entry per endpoint kind. `path` is a sprintf() template taking the code;
# `key` is the top-level JSON key that must be present for the file to count
# as real data rather than an error page or a stub.
ENDPOINTS <- list(
  results = list(path = "election-results/%s/",        key = "results"),
  summary = list(path = "election-summary/%s/regular",  key = "report")
)

# Does this file parse as JSON and carry the expected top-level key? A parse
# failure (e.g. the DRF browsable-HTML page, or a half-written file) is caught
# here rather than allowed to propagate as a cryptic fromJSON() error later.
looks_valid <- function(path, key) {
  if (!file.exists(path)) return(FALSE)
  parsed <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                     error = function(e) NULL)
  !is.null(parsed) && is.list(parsed) && key %in% names(parsed)
}

# Fetch one (code, endpoint) pair. Returns a one-row list describing what
# happened -- used both for the per-file AF3 report and the AF4/AF5 summary
# at the end. Never throws: a failure is RECORDED so every code can be tried
# before the run decides whether to abort, and so one dead endpoint does not
# hide the state of the other fifteen files.
fetch_one <- function(code, kind) {
  ep   <- ENDPOINTS[[kind]]
  dest <- file.path(RAW, sprintf("%s-%s.json", code, kind))
  url  <- paste0(BASE, sprintf(ep$path, code), "?format=json")

  status <- NA_character_
  ok <- FALSE

  if (file.exists(dest) && looks_valid(dest, ep$key)) {
    status <- "cached"
    ok <- TRUE
  } else {
    if (file.exists(dest)) {
      cat(sprintf("AF2  %s-%s.json exists but is not valid JSON with a '%s' key; re-downloading once\n",
                  code, kind, ep$key))
    }
    dl_err <- tryCatch({
      utils::download.file(url, dest, mode = "wb", quiet = TRUE)
      NULL
    }, error = function(e) conditionMessage(e), warning = function(w) conditionMessage(w))
    Sys.sleep(0.4)   # be polite: 16 requests to one small site
    if (is.null(dl_err) && looks_valid(dest, ep$key)) {
      status <- "downloaded"
      ok <- TRUE
    } else {
      status <- if (!is.null(dl_err)) paste("download failed:", dl_err) else
        sprintf("downloaded but not valid JSON with a '%s' key -- likely the DRF HTML page (missing ?format=json handling upstream) or a truncated file", ep$key)
      ok <- FALSE
    }
  }

  size <- if (file.exists(dest)) file.info(dest)$size else NA_integer_
  cat(sprintf("AF3  %-22s %-12s %10s bytes\n",
              basename(dest), status, if (is.na(size)) "NA" else format(size, big.mark = ",")))

  list(code = code, kind = kind, file = basename(dest), path = dest,
       ok = ok, status = status, size = size)
}

cat(sprintf("AF1  fetching %d codes x %d endpoints (%d files) from %s\n",
            length(CODES), length(ENDPOINTS), length(CODES) * length(ENDPOINTS), BASE))

rows <- list()
for (code in CODES) {
  for (kind in names(ENDPOINTS)) {
    rows[[length(rows) + 1L]] <- fetch_one(code, kind)
  }
}

# AF2 (the abort): any file that never became valid JSON with its expected
# key -- named individually, because "some of 16 files failed" is not
# actionable and this repo's recurring failure mode is exactly this kind of
# silent partial success.
bad <- Filter(function(r) !r$ok, rows)
if (length(bad)) {
  stop("AF2 FAILED. ", length(bad), " of ", length(rows),
       " file(s) never validated as JSON with the expected top-level key:\n  ",
       paste(sprintf("%s (%s)", vapply(bad, `[[`, character(1), "file"),
                     vapply(bad, `[[`, character(1), "status")),
             collapse = "\n  "),
       "\nA size check would not have caught this -- see the header comment. ",
       "Nothing downstream should trust these files until this is fixed.")
}

# AF4: every one of the 8 codes must yield BOTH files. This is a second,
# independent pass over the filesystem rather than a re-read of `rows`, so it
# would still catch a code silently dropped from CODES or an endpoint typo
# that made fetch_one() never get called for it.
want <- as.vector(outer(CODES, names(ENDPOINTS),
                         function(c, k) sprintf("%s-%s.json", c, k)))
missing <- want[!file.exists(file.path(RAW, want))]
if (length(missing)) {
  stop("AF4 FAILED. Missing from ", RAW, " after this run: ",
       paste(missing, collapse = ", "),
       ". Every one of the ", length(CODES), " codes must yield both a ",
       "results and a summary file.")
}
cat(sprintf("AF4  all %d codes have both files present.\n", length(CODES)))

# AF5: final summary.
total_bytes <- sum(vapply(rows, function(r) if (is.na(r$size)) 0 else r$size, numeric(1)))
n_cached <- sum(vapply(rows, function(r) identical(r$status, "cached"), logical(1)))
n_downloaded <- sum(vapply(rows, function(r) identical(r$status, "downloaded"), logical(1)))
cat(sprintf("\nAF5  %d files present (%d from cache, %d downloaded), %s bytes total, in %s\n",
            length(rows), n_cached, n_downloaded, format(total_bytes, big.mark = ","), RAW))
