# Federal booth -> state district maps for the cycles the main transposition
# (scripts/transpose_fed_swing.R -> fed-booth-map.csv) does not cover, so the
# Senate features reach every backtest election that has Senate booth data.
# Built 2026-10-01 for the all-party Senate feature (Pete: "use it for each
# election").
#
#   qld2017 <- fed2016 booths on ABS SED 2021 (Qld 2017 boundaries)
#   wa2008  <- fed2007 booths on ABS SED 2011 (WA 2007 boundaries)
#   wa2017  <- fed2016 booths on ABS SED 2016 (WA 2015 boundaries)
#   wa2025  <- fed2022 booths on ABS SED 2024 (WA 2023 boundaries)
#   vic2014 <- fed2013 booths on ABS SED 2016 (Vic 2013 boundaries)
#
# Not possible: wa2013 (the ABS published no state boundaries between 2011 and
# 2016, and the 2011 redistribution renamed four districts); wa2001, wa2005 and
# fed2007 (the AEC serves no Senate booth results before 2007).
#
# Every map must match the election's contested seat names exactly or it is
# not written. Uses build_correspondence.R's assign_booths() (placement, the
# 2km no-location guard, the 90% two-party coverage floor); districts() is
# replaced here because the 2011 and 2016 ABS files have no state-name column
# (the first digit of the SED code is the state) and the 2016 file truncates
# long names mid-bracket.
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_extra_booth_maps.R'
suppressMessages({ library(sf); library(data.table) })
# eval() of function DEFINITIONS parsed from this repo's own build_correspondence.R
# (not external input), so its placement code is reused rather than copied.
ex <- parse("scripts/build_correspondence.R")
for (e in ex) if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
                  as.character(e[[2]]) %in% c("RAW", "STATE", "booths", "vote_coverage", "assign_booths")) eval(e)
districts <- function(region, shp) {
  s <- st_read(shp, quiet = TRUE)
  nc <- grep("^SED_NAME", names(s), value = TRUE)[1]; cc <- grep("^SED_CODE", names(s), value = TRUE)[1]
  sc <- grep("^STE_NAME", names(s), value = TRUE)[1]
  code <- c(nsw = "1", vic = "2", qld = "3", sa = "4", wa = "5")[[region]]
  s <- if (!is.na(sc)) s[s[[sc]] == STATE[[region]], ] else s[substr(as.character(s[[cc]]), 1, 1) == code, ]
  s <- s[!grepl("Migratory|No usual address", s[[nc]]) & !st_is_empty(s), ]
  if (nrow(s) < 20) stop(basename(shp), ": ", region, " resolved to ", nrow(s), " districts")
  s$district <- trimws(sub("[ ]*[(].*$", "", s[[nc]]))
  st_transform(s[, c("district", "geometry")], 7844)
}
BD <- file.path("external", "reference", "boundaries")
JOBS <- list(list(el = "qld2017", fed = 2016, shp = file.path(BD, "SED_2021_AUST_GDA2020.shp")),
             list(el = "wa2008",  fed = 2007, shp = file.path(BD, "SED_2011", "SED_2011_AUST.shp")),
             list(el = "wa2017",  fed = 2016, shp = file.path(BD, "SED_2016_AUST.shp")),
             list(el = "wa2025",  fed = 2022, shp = file.path(BD, "SED_2024_AUST_GDA2020.shp")),
             list(el = "vic2014", fed = 2013, shp = file.path(BD, "SED_2016_AUST.shp")))
cand <- fread(file.path("output", "candidacies.csv"), showProgress = FALSE)
nm <- function(z) gsub("[^a-z]", "", tolower(z))
for (J in JOBS) {
  rg <- sub("[0-9]{4}$", "", J$el); yr <- as.integer(sub("^[a-z]+", "", J$el))
  if (!file.exists(J$shp)) { cat(sprintf("EBM! %s: boundary file %s missing -- skipped\n", J$el, J$shp)); next }
  a <- assign_booths(J$fed, rg, J$shp)
  s <- unique(cand[cand$election == J$el, seat])
  miss <- setdiff(nm(s), nm(unique(a$district))); extra <- setdiff(nm(unique(a$district)), nm(s))
  if (length(miss) || length(extra)) {
    cat(sprintf("EBM! %s: names do not match (map-only %s; seats-only %s) -- NOT written\n", J$el,
                paste(extra, collapse = ","), paste(miss, collapse = ",")))
    next
  }
  f <- file.path("external", "reference", "correspondences", sprintf("booths-%d%s.csv", yr, rg))
  fwrite(a, f)
  cat(sprintf("EBM1 %s: %d booths into %d districts, all %d seat names match -> %s\n", J$el, nrow(a), uniqueN(a$district), length(s), basename(f)))
}
