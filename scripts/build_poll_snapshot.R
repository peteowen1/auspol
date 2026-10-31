# THE POLLS THE FORECAST ACTUALLY READ, as the published poll snapshot.
#
#   Rscript scripts/build_poll_snapshot.R <region> <out.csv>      e.g.  vic output/polls-vic-snapshot.csv
#
# forecast.yaml used to publish polls-<region>-snapshot.csv as a straight copy of the anchor's poll-data-<region>.csv.
# Since AUSPOL_POLL_SOURCE=layered (2026-10-13) the forecast reads our Wikipedia/BludgerTrack scrape layered over that
# file, so the copy left out every poll only we had: on 2026-10-31 the live site's "show polls" dots lacked Roy Morgan
# 8-9 Oct (One Nation 25) although the forecast used it. This writes load_polls(region) itself, in the anchor file's
# column layout (so the page reads it unchanged) plus two columns: Source (ae_only / ours / ours_only, from the
# layer's provenance) and Origin (ae, wiki, bludgertrack+wiki, ...). Check codes PSN1-PSN2.
options(auspol.root = normalizePath("."))
suppressMessages({ library(data.table); devtools::load_all(quiet = TRUE) })
source("scripts/harness_defaults.R")   # the published configuration (AUSPOL_POLL_SOURCE etc.), as the forecast applies it
a <- commandArgs(trailingOnly = TRUE)
if (length(a) != 2L) stop("PSN1! usage: Rscript scripts/build_poll_snapshot.R <region> <out.csv>")
region <- a[1]; out_f <- a[2]
p <- load_polls(region)
parties <- attr(p, "parties")
pv <- attr(p, "provenance")
if (!is.null(pv)) {
  if (nrow(pv) != nrow(p) || !identical(as.character(pv$date), as.character(p$date)) || !identical(pv$firm, p$firm))
    stop("PSN1! provenance rows do not line up with the polls: cannot label sources")
}
o <- data.table(MidDate = format(p$date, "%Y-%m-%d"), Firm = p$firm, Brand = "", `@TPP` = p$tpp_published)
for (pt in parties) o[[paste(pt, "FP")]] <- p[[pt]]
o$GLApp <- if ("gl_approve" %in% names(p)) p$gl_approve else NA_real_
o$GLDis <- if ("gl_disapprove" %in% names(p)) p$gl_disapprove else NA_real_
o$Comments <- ""
o$Source <- if (is.null(pv)) "ae_only" else pv$source
o$Origin <- if (is.null(pv)) "ae" else pv$origin
setorder(o, MidDate, Firm)
fwrite(o, out_f, na = "#N/A")
recent <- o[as.Date(MidDate) >= Sys.Date() - 60]
cat(sprintf("PSN2 %s: wrote %s, %d polls (%s to %s); last 60 days %d (%s)\n", region, out_f, nrow(o), min(o$MidDate), max(o$MidDate),
            nrow(recent), paste(sprintf("%s %d", names(table(recent$Source)), as.integer(table(recent$Source))), collapse = ", ")))
