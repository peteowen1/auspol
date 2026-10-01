# Federal SENATE first preferences by party class, aggregated to (a) each STATE
# district through the federal-booth -> district maps and (b) each FEDERAL
# division directly. Every class, not just One Nation (Pete, 2026-10-01: "have
# we tested usefulness for ALP/LNP/GRN and any others as well?").
#
# The Senate vote is a party's vote with no local candidate attached, so it is
# a district's party base stripped of personal votes. First test against v56's
# remaining error (8 state elections): no signal for Labor or the Coalition,
# weak for the Greens (t 1.9), clear for the minor right (t 3.1).
#
# Reads external/reference/aec/booths/senate/fed<year>-<STATE>-*.csv (fetched
# by scripts/fetch_aec_senate_booths.sh), external/elections/fed-booth-map.csv
# and external/reference/correspondences/booths-2017qld.csv.
# Writes:
#   output/senate-by-district-class.csv -- region, cycle, fed, district, cls, v, senate_pct
#   output/senate-by-division-class.csv -- fed, state, division, cls, v, senate_pct
#
# Run from repo root: powershell.exe -Command 'Rscript scripts/build_senate_by_district.R'
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(data.table))

B <- file.path("external", "reference", "aec", "booths", "senate")
files <- list.files(B, pattern = "^fed[0-9]{4}-[A-Z]+-.*csv$", full.names = TRUE)
meta <- data.table(f = files, fed = as.integer(sub("^fed([0-9]{4})-.*", "\\1", basename(files))),
                   st = sub("^fed[0-9]{4}-([A-Z]+)-.*", "\\1", basename(files)))
cat(sprintf("SB0  %d Senate division files, federal elections %s\n", nrow(meta), paste(sort(unique(meta$fed)), collapse = ", ")))
read_set <- function(ff) {
  x <- rbindlist(lapply(ff, fread, skip = 1, showProgress = FALSE), fill = TRUE)
  x[, cls := classify_party(ifelse(is.na(PartyNm) | !nzchar(PartyNm), "Independent", PartyNm))]
  x
}

# ---- (b) federal divisions ----
divs <- rbindlist(lapply(split(meta, by = c("fed", "st")), function(m) {
  x <- read_set(m$f)
  d <- x[, .(v = sum(OrdinaryVotes)), by = .(division = DivisionNm, cls)]
  d[, senate_pct := 100 * v / sum(v), by = division][, `:=`(fed = m$fed[1], state = m$st[1])][]
}))
setcolorder(divs, c("fed", "state", "division", "cls", "v", "senate_pct"))
fwrite(divs, file.path("output", "senate-by-division-class.csv"))
cat(sprintf("SB1  federal divisions: %d division-elections over %d elections\n", uniqueN(divs[, .(fed, division)]), uniqueN(divs$fed)))

# ---- (a) state districts via the booth maps ----
bm <- fread(election_data_path("fed-booth-map.csv"), showProgress = FALSE)
bm[, place_id := as.character(place_id)]   # 1998 booths have text ids ("Division::Polling Place")
# Extra maps from scripts/build_extra_booth_maps.R (cycles the main
# transposition does not cover). The federal election each one uses:
# wa2001/2005/2013 are VENUE-NAME maps (scripts/build_wa_name_maps.py, no boundary
# files exist for those districts; validated 97.6-98.9% on wa2017/2025).
EXTRA <- list(qld2017 = 2016L, wa2008 = 2007L, wa2017 = 2016L, wa2025 = 2022L, vic2014 = 2013L,
              wa2001 = 1998L, wa2005 = 2004L, wa2013 = 2010L)
for (el in names(EXTRA)) {
  rg <- sub("[0-9]{4}$", "", el); yr <- as.integer(sub("^[a-z]+", "", el))
  f <- file.path("external", "reference", "correspondences", sprintf("booths-%d%s.csv", yr, rg))
  if (!file.exists(f)) { cat(sprintf("SB2! %s: no extra map (%s) -- run scripts/build_extra_booth_maps.R
", el, basename(f))); next }
  q <- fread(f, showProgress = FALSE, colClasses = list(character = "place_id"))
  bm <- rbind(bm, q[, .(region = rg, cycle = yr, fed = EXTRA[[el]], district, place_id)], fill = TRUE)
}
CY <- unique(bm[, .(region, cycle, fed)])
dist <- rbindlist(lapply(seq_len(nrow(CY)), function(i) {
  rg <- CY$region[i]; cy <- CY$cycle[i]; fy <- CY$fed[i]
  m <- meta[meta$fed == fy & meta$st == toupper(rg)]
  if (!nrow(m)) { cat(sprintf("SB2! %s %d: no Senate files for fed %d\n", rg, cy, fy)); return(NULL) }
  x <- read_set(m$f)
  b <- x[, .(v = sum(OrdinaryVotes)), by = .(place_id = as.character(PollingPlaceID), cls)]
  keep <- bm$region == rg & bm$cycle == cy & bm$fed == fy
  j <- merge(b, unique(bm[keep, .(district, place_id)]), by = "place_id")
  d <- j[, .(v = sum(v)), by = .(district, cls)][, senate_pct := 100 * v / sum(v), by = district]
  cat(sprintf("SB2  %s %d (fed %d): %d of %d booths mapped, %d districts\n", rg, cy, fy,
              uniqueN(j$place_id), uniqueN(b$place_id), uniqueN(d$district)))
  d[, `:=`(region = rg, cycle = cy, fed = fy)][]
}))
setcolorder(dist, c("region", "cycle", "fed", "district", "cls", "v", "senate_pct"))
fwrite(dist, file.path("output", "senate-by-district-class.csv"))
cat(sprintf("SB3  state districts: %d district-cycles over %d cycles\n", uniqueN(dist[, .(region, cycle, district)]), uniqueN(dist[, .(region, cycle)])))
