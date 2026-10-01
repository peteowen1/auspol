# Which councils cover which Victorian state districts, and how much of each.
#
# WHY. Council election results (scripts/parse_vec_council.py) give a state
# candidate a measured local vote before the state election, but matching a
# council candidate to a state candidate by name alone pairs every John Smith
# with every other. A match is only kept when the candidate's council overlaps
# the district they later contest. Built 2026-10-02 for the local-elections
# features (Pete: "look into using local elections").
#
# Councils: ABS LGA 2021 (external/reference/boundaries/LGA_2021). Victoria's
# council boundaries have changed little since the 1994 amalgamations, so one
# vintage serves the 2008-2024 council elections.
# Districts, by state election: 2010 on SED_2011, 2014 and 2018 on SED_2016,
# 2022 and 2026 on SED_2021 (2026 is fought on the 2022 boundaries).
#
# Writes output/lga-district-overlap-vic.csv: election, district, lga,
# share_of_district (area share, 0-1), share_of_lga. Emits LO* codes; stops if
# any election's district count is not 88.
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_lga_district_overlap.R'
suppressMessages({ library(sf); library(data.table) })
sf_use_s2(FALSE)
BD <- file.path("external", "reference", "boundaries")
lga <- st_read(file.path(BD, "LGA_2021", "LGA_2021_AUST_GDA2020.shp"), quiet = TRUE)
lga <- lga[lga$STE_NAME21 == "Victoria" & !grepl("^(Unincorporated|No usual|Migratory)", lga$LGA_NAME21) & !st_is_empty(lga), ]
lga <- st_transform(lga[, c("LGA_NAME21", "geometry")], 3111)   # VicGrid, metres
cat(sprintf("LO0  %d Victorian councils\n", nrow(lga)))

seds <- list(
  list(els = "vic2010",            shp = file.path(BD, "SED_2011", "SED_2011_AUST.shp")),
  list(els = c("vic2014", "vic2018"), shp = file.path(BD, "SED_2016_AUST.shp")),
  list(els = c("vic2022", "vic2026"), shp = file.path(BD, "SED_2021_AUST_GDA2020.shp")))
out <- list()
for (S in seds) {
  s <- st_read(S$shp, quiet = TRUE)
  nc <- grep("^SED_NAME", names(s), value = TRUE)[1]; cc <- grep("^SED_CODE", names(s), value = TRUE)[1]
  sc <- grep("^STE_NAME", names(s), value = TRUE)[1]
  s <- if (!is.na(sc)) s[s[[sc]] == "Victoria", ] else s[substr(as.character(s[[cc]]), 1, 1) == "2", ]
  s <- s[!grepl("Migratory|No usual address", s[[nc]]) & !st_is_empty(s), ]
  s$district <- trimws(sub("[ ]*[(].*$", "", s[[nc]]))
  s <- st_transform(s[, c("district", "geometry")], 3111)
  if (nrow(s) != 88L) stop(basename(S$shp), ": ", nrow(s), " Victorian districts, expected 88")
  s$d_area <- as.numeric(st_area(s)); l2 <- lga; l2$l_area <- as.numeric(st_area(l2))
  x <- suppressWarnings(st_intersection(st_buffer(s, 0), st_buffer(l2, 0)))
  x$a <- as.numeric(st_area(x))
  d <- as.data.table(st_drop_geometry(x))[, .(district, lga = LGA_NAME21, share_of_district = a / d_area, share_of_lga = a / l_area)]
  d <- d[share_of_district > 0.001]
  for (e in S$els) out[[e]] <- cbind(election = e, d)
  cat(sprintf("LO1  %s: 88 districts, %d district-council overlaps (>0.1%% of the district)\n",
              paste(S$els, collapse = "/"), nrow(d)))
}
res <- rbindlist(out)
chk <- res[, .(cover = sum(share_of_district)), by = .(election, district)]
cat(sprintf("LO2  district area covered by councils: min %.3f, median %.3f (1 = fully covered)\n",
            min(chk$cover), median(chk$cover)))
fwrite(res, file.path("output", "lga-district-overlap-vic.csv"))
cat(sprintf("LO9  wrote output/lga-district-overlap-vic.csv (%d rows)\n", nrow(res)))
