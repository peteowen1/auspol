# Daily forecast job (forecast.yaml): the published full Wikipedia poll table with the live pages swapped for that
# morning's fresh parse, so the layered poll source (AUSPOL_POLL_SOURCE, R/poll_source.R) sees today's polls while
# past elections keep the published rows (the blend constant is fitted on them).
# Run: Rscript scripts/merge_live_poll_pages.R <published full csv> <fresh csv> <out csv>
# Emits PM* codes. Every page in the fresh parse replaces that page in the full table; nothing else changes.
suppressMessages(library(data.table))
a <- commandArgs(TRUE); stopifnot(length(a) == 3)
full <- fread(a[1], showProgress = FALSE, colClasses = "character")
fresh <- fread(a[2], showProgress = FALSE, colClasses = "character")
pages <- unique(fresh$page_key)
if (!length(pages) || !nrow(fresh)) stop("PM0! the fresh parse is empty: ", a[2])
kept <- full[!full$page_key %in% pages]
out <- rbind(kept, fresh, use.names = TRUE, fill = TRUE)
cat(sprintf("PM1 %d published rows kept; pages %s replaced: %d published rows -> %d fresh rows\n", nrow(kept), paste(pages, collapse = ","),
            sum(full$page_key %in% pages), nrow(fresh)))
if (nrow(out) < 0.9 * nrow(full)) stop("PM2! merged table lost more than 10% of the published rows: ", nrow(out), " vs ", nrow(full))
fwrite(out, a[3])
cat(sprintf("PM3 wrote %s (%d rows)\n", a[3], nrow(out)))
