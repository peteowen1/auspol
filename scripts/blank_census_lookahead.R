# Blank census rows that post-date their election (Pete, 2026-10-14: "Fix: use the earlier census").
# census-features.csv tags a row "LOOKAHEAD: ..." when its census was taken AFTER polling day (renamed seats
# matched by name to a later census, and wa2001/wa2005, which have no census on disk before 2006). An earlier
# census by name was already tried first by build_census_features_vintage.R (sources A-C), so what is left has
# no pre-election census: its seven features are set to NA (xgboost treats NA as missing; no consumer requires
# a value) and the note says so. Idempotent. Sourced at the end of build_census_features_vintage.R so a rebuild
# cannot bring the rows back; run on its own to fix the files on disk:
#   Rscript scripts/blank_census_lookahead.R
suppressMessages(library(data.table))
CENSUS_FEATS <- c("yr12_pct", "born_aus_pct", "indig_pct", "over55_pct", "under35_pct", "lang_other_pct", "edu_25plus_pct")
blank_census_lookahead <- function(x, label = "") {
  la <- grepl("^LOOKAHEAD", x$vintage_note)
  if (any(la)) {
    for (f in intersect(CENSUS_FEATS, names(x))) set(x, which(la), f, NA_real_)
    set(x, which(la), "vintage_note", paste0("BLANKED (no census before polling day; was ", x$vintage_note[la], ")"))
  }
  cat(sprintf("BCL1 %s: %d of %d rows blanked (census after polling day); %d rows previously blanked\n", label,
              sum(la), nrow(x), sum(grepl("^BLANKED", x$vintage_note)) - sum(la)))
  x
}
if (sys.nframe() == 0L) {
  for (f in file.path("output", c("census-features.csv", "census-features-vintage.csv"))) {
    if (!file.exists(f)) next
    x <- fread(f, showProgress = FALSE)
    n0 <- nrow(x)
    x <- blank_census_lookahead(x, basename(f))
    stopifnot(nrow(x) == n0, !any(grepl("^LOOKAHEAD", x$vintage_note)))
    fwrite(x, f)
  }
}
