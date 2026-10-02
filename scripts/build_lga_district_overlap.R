# Which councils cover which state districts, and how much of each -- every
# state, every ABS district vintage on disk.
#
# WHY. Council election results (scripts/parse_*_council.py) give a state
# candidate a measured local vote before the state election, but matching a
# council candidate to a state candidate by name alone pairs every John Smith
# with every other. A match is only kept when the candidate's council overlaps
# the district they later contest. Built 2026-10-02 for the local-elections
# features (Pete: "look into using local elections"); every state, so the
# feature is not a label for Victoria (CLAUDE.md, constant-in-subgroup).
#
# Councils: ABS LGA 2021 (external/reference/boundaries/LGA_2021). Council
# boundaries change little between amalgamations, and the check is only "does
# this council overlap this district", so one vintage serves 2005-2024.
# Districts: every SED vintage on disk (2011, 2016, 2021, 2022, 2024). Each
# state election is matched to the vintage whose district NAMES best cover its
# contested seats (output/candidacies.csv), reported per election.
#
# Writes output/lga-district-overlap.csv: election, region, sed_vintage,
# district, lga, share_of_district, share_of_lga; and prints, per election,
# the vintage chosen and its name coverage. Emits LO* codes.
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_lga_district_overlap.R'
suppressMessages({ library(sf); library(data.table) })
sf_use_s2(FALSE)
BD <- file.path("external", "reference", "boundaries")
STATES <- c(nsw = "New South Wales", vic = "Victoria", qld = "Queensland", sa = "South Australia", wa = "Western Australia")
CODE <- c(nsw = "1", vic = "2", qld = "3", sa = "4", wa = "5")
nm <- function(z) gsub("[^a-z]", "", tolower(z))

lga_all <- st_read(file.path(BD, "LGA_2021", "LGA_2021_AUST_GDA2020.shp"), quiet = TRUE)
lga_all <- lga_all[!grepl("^(Unincorporated|No usual|Migratory)", lga_all$LGA_NAME21) & !st_is_empty(lga_all), ]
lga_all <- st_transform(lga_all[, c("LGA_NAME21", "STE_NAME21", "geometry")], 3577)   # Australian Albers, metres
lga_all$l_area <- as.numeric(st_area(lga_all))

VINT <- c("2011" = file.path(BD, "SED_2011", "SED_2011_AUST.shp"), "2016" = file.path(BD, "SED_2016_AUST.shp"),
          "2021" = file.path(BD, "SED_2021_AUST_GDA2020.shp"), "2022" = file.path(BD, "SED_2022_AUST_GDA2020.shp"),
          "2024" = file.path(BD, "SED_2024_AUST_GDA2020.shp"))
ov <- list()
for (v in names(VINT)) {
  if (!file.exists(VINT[[v]])) { cat(sprintf("LO0! SED %s missing\n", v)); next }
  s <- st_read(VINT[[v]], quiet = TRUE)
  nc <- grep("^SED_NAME", names(s), value = TRUE)[1]; cc <- grep("^SED_CODE", names(s), value = TRUE)[1]
  for (rg in names(STATES)) {
    x <- s[substr(as.character(s[[cc]]), 1, 1) == CODE[[rg]] & !grepl("Migratory|No usual address", s[[nc]]) & !st_is_empty(s), ]
    if (nrow(x) < 20) next
    x$district <- trimws(sub("[ ]*[(].*$", "", x[[nc]]))
    x <- st_transform(x[, c("district", "geometry")], 3577); x$d_area <- as.numeric(st_area(x))
    l <- lga_all[lga_all$STE_NAME21 == STATES[[rg]], ]
    i <- suppressWarnings(st_intersection(st_buffer(x, 0), st_buffer(l, 0)))
    i$a <- as.numeric(st_area(i))
    d <- as.data.table(st_drop_geometry(i))[, .(region = rg, sed_vintage = v, district, lga = LGA_NAME21,
                                                share_of_district = a / d_area, share_of_lga = a / l_area)]
    ov[[paste(v, rg)]] <- d[share_of_district > 0.001]
  }
  cat(sprintf("LO1  SED %s done\n", v))
}
OV <- rbindlist(ov)

# pick, per state election, the vintage whose district names best cover its seats
cand <- fread(file.path("output", "candidacies.csv"), showProgress = FALSE, select = c("election", "region", "seat"))
cand <- unique(cand[region %in% names(STATES)])
out <- list()
for (el in sort(unique(cand$election))) {
  seats <- unique(cand[cand$election == el, seat]); rg <- cand[cand$election == el, region][1]
  best <- NULL; bcov <- -1
  for (v in unique(OV[region == rg, sed_vintage])) {
    dn <- unique(OV[region == rg & sed_vintage == v, district])
    cov <- mean(nm(seats) %in% nm(dn))
    if (cov > bcov) { bcov <- cov; best <- v }
  }
  cat(sprintf("LO2  %-8s %3d seats: SED %s covers %.0f%% of seat names\n", el, length(seats), best, 100 * bcov))
  out[[el]] <- cbind(election = el, OV[region == rg & sed_vintage == best])
}
res <- rbindlist(out)
fwrite(res, file.path("output", "lga-district-overlap.csv"))
cat(sprintf("LO9  wrote output/lga-district-overlap.csv (%d rows, %d elections)\n", nrow(res), uniqueN(res$election)))
