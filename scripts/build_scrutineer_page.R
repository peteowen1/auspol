# Renders scripts/scrutineer-template.html + output/fed2025-browse-table.csv
# into a publishable HTML page.
#
# WHY A TEMPLATE FILE EXISTS AT ALL. The Scrutineer artifact was originally
# authored once, by hand, inside the Artifact tool -- design and data baked
# into one file with no source in the repo. That made the 2026-09-03 salience
# update a manual patch of a fetched copy. scripts/scrutineer-template.html is
# that page with the CSV block removed and a placeholder in its place, so page
# and data are now two things instead of one, and the page survives a rebuild
# of the data (as it will for Victoria 2026) without anyone re-authoring HTML.
#
# The template's own CSV-derived stats -- statSeats, statCands etc. -- are
# computed by the page's own JS at load time from whatever CSV is embedded, so
# nothing here needs to duplicate that arithmetic.
#
# Emits SP* codes.

options(auspol.root = normalizePath("."))
suppressMessages(library(data.table))

TEMPLATE <- "scripts/scrutineer-template.html"
CSV      <- "output/fed2025-browse-table.csv"
OUT      <- "output/scrutineer.html"
MARKER   <- "<!--CSV_DATA_GOES_HERE-->"

if (!file.exists(TEMPLATE)) stop("SP! missing ", TEMPLATE)
if (!file.exists(CSV))      stop("SP! missing ", CSV, " -- run scripts/build_fed2025_browse_table.R first")

tpl <- paste(readLines(TEMPLATE, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
n_marker <- lengths(regmatches(tpl, gregexpr(MARKER, tpl, fixed = TRUE)))
if (n_marker != 1L) {
  stop("SP! expected exactly 1 occurrence of the CSV marker in the template, found ", n_marker)
}

csv_raw <- paste(readLines(CSV, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
# A raw '</script>' inside the CSV text would close the tag early and truncate
# the embedded data mid-page -- the HTML-in-a-<script>-block hazard. No column
# here is free text, but this is cheap insurance against a future one that is.
if (grepl("</script", csv_raw, fixed = TRUE)) {
  stop("SP! ", CSV, " contains a literal '</script>' -- would truncate the embed")
}

block <- paste0('<script type="text/csv" id="csv-data">\n', csv_raw, '\n</script>')
page <- sub(MARKER, block, tpl, fixed = TRUE)

# Confirm the swap actually happened rather than silently no-op'ing on a
# mismatched template -- the "experiment that never ran" hazard applied to a
# string substitution.
if (!grepl('id="csv-data"', page, fixed = TRUE)) {
  stop("SP! substitution did not take -- page has no csv-data block")
}

writeLines(page, OUT, useBytes = TRUE)
n_rows <- length(readLines(CSV, warn = FALSE)) - 1L
cat(sprintf("SP1  wrote %s: %d rows embedded, %.0f KB\n", OUT, n_rows,
            file.info(OUT)$size / 1024))
cat("SP2  publish with the Artifact tool: file_path =", OUT, "\n")
