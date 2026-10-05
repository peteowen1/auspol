# Booth -> WA state district correspondences for the two WA cycles the seat-swing
# port (R/seat_swing_port.R) needs and nothing else built: wa2013 and wa2021.
# (wa2008, wa2017 and wa2025 come from scripts/build_extra_booth_maps.R.)
# Built 2026-10-05 for AUSPOL_SEAT_SWING_PORT_WA; consumed by
# scripts/transpose_fed_swing.R with TRANSPOSE_REGION=wa.
#
#   wa2021 <- fed2019 booths on ABS SED 2021 (WA boundaries of the 2019
#             redistribution): all 59 district names match the seat file exactly.
#   wa2013 <- fed2010 booths on ABS SED 2011 (the 2007 boundaries). APPROXIMATE:
#             the ABS published no state boundary vintage for the 2011 WA
#             redistribution, so the 2007 districts stand in for the 2011 ones,
#             with the four 2011 renames applied (Nollamara -> Mirrabooka,
#             North West -> North West Central, Blackwood-Stirling ->
#             Warren-Blackwood, Mindarie -> Butler). Border booths can sit in a
#             neighbour; the booth-level agreement with the older name-matched
#             booths-2013wa.csv is printed as a sanity check.
#
# Reuses build_correspondence.R's assign_booths() (coordinate placement, the 2km
# no-location guard, the 90%-of-votes coverage floor), as build_extra_booth_maps.R
# does. A map is only written if its district names equal the election's seats.
#
# Env: AUSPOL_DATA_ROOT (read root, default "."), WA_CORR_DIR (write dir,
# default <root>/external/reference/correspondences).
# Run: powershell.exe -Command 'Rscript scripts/build_wa_swing_correspondences.R'
suppressMessages({ library(sf); library(data.table) })
ROOT <- Sys.getenv("AUSPOL_DATA_ROOT", ".")
OUT <- Sys.getenv("WA_CORR_DIR", file.path(ROOT, "external", "reference", "correspondences"))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
RAW <- file.path(ROOT, "external", "reference", "aec", "booths")
STATE <- c(wa = "Western Australia")
# Function DEFINITIONS parsed from this repo's own build_correspondence.R (not
# external input), reused rather than copied -- same pattern as
# build_extra_booth_maps.R.
ex <- parse("scripts/build_correspondence.R")
for (e in ex) if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
                  as.character(e[[2]]) %in% c("booths", "vote_coverage", "assign_booths")) eval(e)
districts <- function(region, shp) {
  s <- st_read(shp, quiet = TRUE)
  nc <- grep("^SED_NAME", names(s), value = TRUE)[1]
  sc <- grep("^STE_NAME", names(s), value = TRUE)[1]
  cc <- grep("^SED_CODE", names(s), value = TRUE)[1]
  # The 2011 and 2016 ABS files have no state-name column: the first digit of the SED code is the state (5 = WA).
  s <- if (!is.na(sc)) s[s[[sc]] == STATE[[region]], ] else s[substr(as.character(s[[cc]]), 1, 1) == "5", ]
  s <- s[!grepl("Migratory|No usual address", s[[nc]]) & !st_is_empty(s), ]
  if (nrow(s) < 50) stop(basename(shp), ": WA resolved to ", nrow(s), " districts")
  s$district <- trimws(sub("[ ]*[(].*$", "", s[[nc]]))
  st_transform(s[, c("district", "geometry")], 7844)
}
BD <- file.path(ROOT, "external", "reference", "boundaries")
tp <- fread(file.path(ROOT, "output", "seat-tpp-estimates.csv"), showProgress = FALSE)
nm <- function(z) gsub("[^a-z]", "", tolower(z))
RENAME_2011 <- c("Nollamara" = "Mirrabooka", "North West" = "North West Central",
                 "Blackwood-Stirling" = "Warren-Blackwood", "Mindarie" = "Butler")
JOBS <- list(
  list(el = "wa2021", fed = 2019, shp = "SED_2021_AUST_GDA2020.shp", file = "booths-2021wa.csv", ren = NULL),
  list(el = "wa2013", fed = 2010, shp = file.path("SED_2011", "SED_2011_AUST.shp"), file = "booths-2013wa-coord.csv", ren = RENAME_2011))
for (J in JOBS) {
  a <- assign_booths(J$fed, "wa", file.path(BD, J$shp))
  if (!is.null(J$ren)) a[district %in% names(J$ren), district := unname(J$ren[district])]
  s <- unique(tp[tp$election == J$el, s])
  miss <- setdiff(nm(s), nm(a$district)); extra <- setdiff(nm(a$district), nm(s))
  if (length(miss) || length(extra) || anyNA(a$district)) {
    stop(J$el, ": district names do not equal the seat file (map-only ", paste(extra, collapse = ","),
         "; seats-only ", paste(miss, collapse = ","), ")")
  }
  cat(sprintf("WAC1 %s <- fed%d: %d booths into %d districts (%d seats in the seat file)\n",
              J$el, J$fed, nrow(a), uniqueN(a$district), length(s)))
  if (J$el == "wa2013") {
    if (!file.exists(file.path(ROOT, "external", "reference", "correspondences", "booths-2013wa.csv")))
      cat("WAC2 no older name-matched file to compare\n") else {
      old <- fread(file.path(ROOT, "external", "reference", "correspondences", "booths-2013wa.csv"), showProgress = FALSE)
      cmp <- merge(a[, .(place_id = as.character(place_id), mine = nm(district))],
                   old[, .(place_id = as.character(place_id), theirs = nm(district))], by = "place_id")
      cat(sprintf("WAC2 vs the older name-matched booths-2013wa.csv: %d shared place ids, agreement %.1f%%\n",
                  nrow(cmp), 100 * mean(cmp$mine == cmp$theirs)))
    }
  }
  fwrite(a[, .(district, division, booth, place_id)], file.path(OUT, J$file))
  cat(sprintf("WAC3 wrote %s\n", file.path(OUT, J$file)))
}
