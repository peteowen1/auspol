# Build booth-to-district correspondences from coordinates, not from names.
#
# WHY. `fed_swing` is the strongest seat-level predictor in this model, and it
# can only be computed for a state cycle that has a booth-to-district
# correspondence. The anchor ships six, covering Victoria, NSW and SA.
# Queensland and Western Australia have none, which is 152 districts per cycle
# that no feature can currently be tested on.
#
# It also fixes a defect in the ones we have. The shipped correspondences map a
# booth to a district via a FEDERAL DIVISION NAME, and those names are keyed to
# whichever redistribution was current when the file was written -- so
# booths-2018vic.txt names Macnamara and Monash, which did not exist at the
# federal 2016 election that precedes the 2018 Victorian poll. Matching then
# falls back to booth names, and the resulting measure performed WORSE than
# uniform swing for exactly those two cycles
# (docs/reviews/fed-swing-coefficient-2026-08-20.md).
#
# Assigning by COORDINATE removes that failure mode at the root: a polling place
# lands in whichever state district contains it, and the federal division it
# happened to sit in is never consulted.
#
# VALIDATION IS THE POINT, again. ABS SED_2021 is a mid-2021 snapshot, so its
# Victorian districts are the 2018 boundaries and its NSW ones the 2019
# boundaries -- the same vintages two shipped correspondences describe. Those
# are reproduced here and compared booth by booth. If the method cannot recover
# a correspondence someone else built by hand, it cannot be trusted on
# Queensland, where there is nothing to check it against.
#
# Emits BC* codes.

options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(sf))
suppressMessages(library(data.table))

# Which ABS vintage holds which election's boundaries. These are snapshots, so
# the mapping is not "the year in the filename": SED_2021 is a mid-2021 snapshot
# and therefore predates the redistributions that took effect at the November
# 2022 Victorian and March 2023 NSW elections, which is why it carries Victoria
# on 2018 boundaries and NSW on 2019 boundaries. Verified by exact name match
# against each seat file rather than assumed.
SHP_2021 <- "external/reference/boundaries/SED_2021_AUST_GDA2020.shp"
SHP_2022 <- "external/reference/boundaries/SED_2022_AUST_GDA2020.shp"
SHP <- SHP_2021
RAW <- file.path("external", "reference", "aec", "booths")
CORR <- file.path("external", "aus-polling-analyser", "analysis", "Federal-State")
OUT <- file.path("external", "reference", "correspondences")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

STATE <- c(qld = "Queensland", vic = "Victoria", nsw = "New South Wales",
           wa = "Western Australia", sa = "South Australia")

districts <- function(region, shp = SHP) {
  s <- st_read(shp, quiet = TRUE)
  # The ABS suffixes its column names with the vintage year, so SED_2021 has
  # SED_NAME21 and SED_2022 has SED_NAME22 while both keep STE_NAME21. Reading
  # a fixed name silently selected ZERO districts from SED_2022, and the
  # completeness check below was written as got < want -- which is 1 < 0, and
  # therefore FALSE -- so three empty correspondence files were written and
  # reported as successes. Hence both the pattern lookup and the floor.
  nc <- grep("^SED_NAME", names(s), value = TRUE)[1]
  sc <- grep("^STE_NAME", names(s), value = TRUE)[1]
  if (is.na(nc) || is.na(sc)) {
    stop(basename(shp), " has no SED_NAME or STE_NAME column. Columns: ",
         paste(names(s), collapse = ", "))
  }
  s <- s[s[[sc]] == STATE[[region]], ]
  s <- s[!grepl("Migratory|No usual address", s[[nc]]), ]
  if (nrow(s) < 20) {
    stop(basename(shp), ": ", STATE[[region]], " resolved to ", nrow(s),
         " districts. No Australian state has fewer than 20.")
  }
  s$SED_NAME21 <- s[[nc]]
  # The ABS district names for WA carry an upper-house region in parentheses
  # that the seat files do not use; every other state is unaffected by the strip.
  s$district <- trimws(sub("[ ]*[(][^)]*[)]$", "", s$SED_NAME21))
  s[, c("district", "geometry")]
}

booths <- function(fed_year, region) {
  # The AEC both embeds stray double quotes mid-field (one premises address
  # reads Cnr" Rupert Ct) AND puts real commas inside quoted fields (Francis
  # Forde Blvd,), so neither default quoting nor quote = "" parses every row --
  # the first heals the stray quote by shifting columns, the second stops dead
  # on the legitimate one. Default quoting is used, and the coordinate is then
  # checked against Australia's bounding box: a row whose columns shifted puts a
  # postcode or a suburb name where the latitude should be, which fails the box
  # rather than becoming a plausible-looking point in the wrong district.
  d <- fread(file.path(RAW, sprintf("pp-fed%d.csv", fed_year)), skip = 1L,
             showProgress = FALSE)
  d[, `:=`(Latitude = suppressWarnings(as.numeric(Latitude)),
           Longitude = suppressWarnings(as.numeric(Longitude)))]
  d <- d[State == toupper(region)]
  # A polling place with no coordinate cannot be placed, and must be COUNTED as
  # unplaced rather than quietly dropped -- the point of the guards below is
  # that a shortfall is visible.
  n_all <- nrow(d)
  d <- d[is.finite(Latitude) & is.finite(Longitude) &
           Latitude > -44 & Latitude < -9 &
           Longitude > 112 & Longitude < 154]
  cat(sprintf("BC1  %s fed%d: %d polling places, %d inside Australia (%.1f%%)\n",
              toupper(region), fed_year, n_all, nrow(d), 100 * nrow(d) / n_all))
  st_as_sf(d, coords = c("Longitude", "Latitude"), crs = 7844)
}

# What share of the two-party vote the placed booths actually carry. Booths is
# the wrong denominator -- the unplaced ones are disproportionately hospital
# teams and administrative entries, which are tiny -- so the floor is set on
# votes, and it is applied AFTER the unlocatable booths have been dropped
# rather than before, or it would pass on a set the join then discards.
vote_coverage <- function(fed_year, region, place_ids) {
  tpp <- fread(file.path(RAW, sprintf("tpp-fed%d.csv", fed_year)), skip = 1L,
               showProgress = FALSE)
  setnames(tpp, make.names(names(tpp)))
  tot <- tpp[StateAb == toupper(region),
             .(v = sum(as.numeric(TotalVotes))), by = .(id = PollingPlaceID)]
  list(kept = tot[id %in% place_ids, sum(v)], all = tot[, sum(v)])
}

assign_booths <- function(fed_year, region, shp = SHP) {
  dis <- districts(region, shp)
  bo <- booths(fed_year, region)
  j <- st_join(bo, dis, join = st_within)
  a <- as.data.table(st_drop_geometry(j))
  # A booth just off the coastline, or in a sliver where the ABS polygon and the
  # real boundary disagree, falls in no polygon and belongs to the district it
  # nearly sits in. But DISTANCE is what separates that from a booth with no
  # real location at all, and st_nearest_feature cannot tell them apart -- it
  # returns a confident district either way.
  #
  # Queensland fed2022 is why this matters. 61 booths fell outside, and all 61
  # sat at ONE identical point 698km from any district: the "EAV" and "COVID19
  # PPVC" entries, administrative records the AEC gives a placeholder
  # coordinate. Assigned by nearest feature they would have piled every one of
  # them into whichever district happened to be closest to that placeholder.
  a[, dist_m := 0]
  miss <- which(is.na(a$district))
  if (length(miss)) {
    near <- st_nearest_feature(bo[miss, ], dis)
    a$district[miss] <- dis$district[near]
    a$dist_m[miss] <- as.numeric(
      st_distance(bo[miss, ], dis[near, ], by_element = TRUE))
    cat(sprintf("BC1  %d booths outside every polygon: %.0fm median, %.0fm worst\n",
                length(miss), stats::median(a$dist_m[miss]), max(a$dist_m[miss])))
  }
  # 2km is generous for a genuine boundary sliver and nowhere near the 698km
  # placeholder, so the threshold does not need to be tuned to survive.
  bad <- a[dist_m > 2000]
  if (nrow(bad)) {
    cat(sprintf("BC1  DROPPING %d booths with no usable location (%.0fkm from any district):\n",
                nrow(bad), max(bad$dist_m) / 1000))
    print(head(bad[, .(DivisionNm, PollingPlaceNm, km = round(dist_m / 1000, 1))], 4))
    a <- a[dist_m <= 2000]
  }
  vc <- vote_coverage(fed_year, region, a$PollingPlaceID)
  cat(sprintf("BC1  placed booths carry %.1f%% of the two-party vote\n",
              100 * vc$kept / vc$all))
  if (vc$kept / vc$all < 0.9) {
    stop(toupper(region), " fed", fed_year, ": placed booths carry only ",
         round(100 * vc$kept / vc$all, 1), "% of the two-party votes. A district ",
         "swing built from that is not the district.")
  }
  a[, .(district, division = DivisionNm, booth = PollingPlaceNm,
        place_id = PollingPlaceID)]
}

read_corr <- function(f) {
  ln <- readLines(file.path(CORR, f), warn = FALSE); ln <- ln[nzchar(ln)]
  d <- NA_character_; out <- list()
  for (l in ln) {
    if (startsWith(l, "#")) { d <- substring(l, 2); next }
    p <- strsplit(l, ",", fixed = TRUE)[[1]]
    if (length(p) < 2 || is.na(d)) next
    out[[length(out) + 1L]] <- data.table(
      district = d, booth = trimws(paste(p[-1], collapse = ",")))
  }
  rbindlist(out)
}

# ---- THE VALIDATION --------------------------------------------------------
# SED_2021 holds Victoria on 2018 boundaries and NSW on 2019 boundaries, the
# vintages that booths-2018vic.txt and booths-2019nsw.txt describe.
cat("\nBC2  reproduction test -- can coordinates recover a hand-built correspondence?\n")
ok <- TRUE
for (V in list(list("vic", 2016L, "booths-2018vic.txt"),
               list("nsw", 2016L, "booths-2019nsw.txt"))) {
  mine <- assign_booths(V[[2]], V[[1]])
  theirs <- read_corr(V[[3]])
  # Compared on booth NAME, which is all the shipped files carry. A name that
  # appears twice in either source is excluded from the agreement rate rather
  # than counted as a disagreement, because the comparison genuinely cannot
  # resolve it -- and the number excluded is reported.
  dup <- union(mine[, .N, by = booth][N > 1L, booth],
               theirs[, .N, by = booth][N > 1L, booth])
  m <- merge(mine[!booth %in% dup, .(booth, mine = district)],
             theirs[!booth %in% dup, .(booth, theirs = district)], by = "booth")
  agree <- mean(m$mine == m$theirs)
  cat(sprintf("BC2  %s: %d comparable booths (%d ambiguous names excluded), agreement %.1f%%\n",
              V[[3]], nrow(m), length(dup), 100 * agree))
  if (nrow(m) < 200L) {
    cat("BC2  too few comparable booths to conclude anything\n"); ok <- FALSE
  }
  if (agree < 0.95) {
    ok <- FALSE
    cat("BC2  DISAGREEMENTS, first 10:\n")
    print(head(m[mine != theirs], 10))
  }
}
if (!ok) {
  stop("Coordinate assignment does not reproduce the hand-built correspondences. ",
       "It cannot be trusted on Queensland, where there is nothing to check it ",
       "against.")
}
cat("BC2  the method recovers both hand-built correspondences.\n")

# ---- build the ones that do not exist --------------------------------------
# Queensland votes in October, so the federal election preceding its 2020 poll
# is 2019. QLD has had no redistribution since 2017, so SED_2021 is the right
# vintage for both the 2020 and the 2024 state election.
cat("\nBC3  building correspondences\n")
# Every cycle the anchor ships a correspondence for is rebuilt here too, not
# just the Queensland ones that were missing. The shipped files need 192 and 224
# name-fallback matches respectively for Victoria; these need none, because a
# coordinate does not care what a federal division was called.
#
# Western Australia is ABSENT and cannot be added. Its 2023 redistribution
# postdates every ABS vintage published so far -- SED_2021 and SED_2022 both
# carry the pre-redistribution 59 districts, six of which (Bibra Lake,
# Girrawheen, Mid-West, Mindarie, Oakford, Secret Harbour) do not exist in them
# at all. Building it needs a WAEC shapefile, not another ABS download.
for (J in list(list(region = "vic", cycle = 2018L, fed = 2016L, shp = SHP_2021),
               list(region = "nsw", cycle = 2019L, fed = 2016L, shp = SHP_2021),
               list(region = "qld", cycle = 2020L, fed = 2019L, shp = SHP_2021),
               list(region = "vic", cycle = 2022L, fed = 2022L, shp = SHP_2022),
               list(region = "nsw", cycle = 2023L, fed = 2022L, shp = SHP_2022),
               list(region = "qld", cycle = 2024L, fed = 2022L, shp = SHP_2022))) {
  a <- assign_booths(J$fed, J$region, J$shp)
  want <- nrow(districts(J$region, J$shp))
  got <- uniqueN(a$district)
  cat(sprintf("BC3  %s %d <- fed%d: %d booths across %d of %d districts\n",
              toupper(J$region), J$cycle, J$fed, nrow(a), got, want))
  # Written as != rather than < deliberately. The < form cannot fire when the
  # district set comes back empty, which is exactly the case it needed to catch.
  if (got != want || anyNA(a$district)) {
    stop(J$region, J$cycle, ": ", got, " districts received a booth against ",
         want, " in the boundary file", if (anyNA(a$district))
           ", and some booths were assigned no district" else "", ".")
  }
  # Two outputs on purpose. The .txt matches the anchor's format so the file can
  # be read and eyeballed beside the six shipped ones. The .csv carries
  # PollingPlaceID, and that is what the transposition actually joins on --
  # matching booths by NAME across two files is the class of bug this whole
  # script exists to remove, so it is not reintroduced at the last step.
  f <- file.path(OUT, sprintf("booths-%d%s.txt", J$cycle, J$region))
  con <- file(f, "w")
  for (d in sort(unique(a$district))) {
    writeLines(paste0("#", d), con)
    writeLines(a[district == d, paste(division, booth, sep = ",")], con)
  }
  close(con)
  g <- file.path(OUT, sprintf("booths-%d%s.csv", J$cycle, J$region))
  fwrite(a[, .(district, division, booth, place_id, region = J$region,
               cycle = J$cycle, fed = J$fed)], g)
  cat(sprintf("BC3  wrote %s and %s\n", f, g))
}
