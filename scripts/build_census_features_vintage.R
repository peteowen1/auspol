# Census features with the vintage that PRECEDES each election (no look-ahead).
#
# THE ONLY WRITER OF output/census-features.csv (Pete, 2026-10-25). It builds from
# raw census inputs alone and reads no earlier census-features output.
# scripts/build_census_features.R was retired that day. It gave every older pair a
# 2016 or 2021 census (fed2007-fed2016 took census-ced-2016, and every pre-2022 state
# pair took a "2021"-labelled SED file that is in fact the 2016 census reaggregated:
# the label is the BOUNDARY year), so its backtest gain on pre-2016 pairs included
# look-ahead. It also stopped on the Northern Territory (CF2!). Until 2026-10-25 this
# script read its source-B rows from output/census-features.csv, which since the
# 13-15 Oct swap was this script's own previous output. So a rebuild depended on
# whatever the last rebuild had written, and a run without the AUSPOL_CENSUS_VINTAGE_BASE
# copy re-labelled qld2017/sa2018 rows (filled by the old builder from another
# boundary vintage) as "on election boundaries". Source B now reads the reaggregated
# files directly, and it labels a borrowed boundary vintage as borrowed.
#
# RULE (Pete, 2026-10-13): census taken BEFORE the election. 2006 census
# (8 Aug 2006) for elections 2007-2010, 2011 (9 Aug 2011) for 2011-2015, 2016
# (9 Aug 2016) for 2016-2020, 2021 (10 Aug 2021) after. Applied by DATE, not by
# year, so fed2016 (2 Jul 2016, five weeks BEFORE the 2016 census) takes 2011
# and wa2021 (13 Mar 2021) takes 2016. Flip a pair with PREF_OVERRIDE below.
# Refined 2026-10-14: the census must be PUBLISHED before polling day (CENSUS_RELEASE).
# Elections before the 2006 census (wa2001, wa2005) have no earlier census on
# disk (2001 not fetched): they are EMPTY ON PURPOSE (Pete, 14 Oct; every row is
# blanked by scripts/blank_census_lookahead.R, and CHECK CW10 stops the build if
# one of them ever carries a value).
#
# WRITES <out>/census-features.csv: pair, seat, vintage, exact, the 7 features,
# vintage_note. `vintage` is the CENSUS YEAR OF THE DATA (the retired file's state
# `vintage` was a boundary year). exact = the census geography's boundaries equal
# the election's (seat sets identical), or for reaggregated rows, the election is
# in REAG_EXACT below. vintage_note starts with LOOKAHEAD when the census post-dates
# the election (then BLANKED by blank_census_lookahead.R), so no row carries
# look-ahead silently.
#
# USAGE (from the repo root):
#   Rscript scripts/build_census_features_vintage.R [--root=DIR] [--out=DIR] [--compare=FILE]
#     --root     where output/candidacies.csv and external/reference/ are read (default ".")
#     --out      where census-features.csv is written (default <root>/output)
#     --compare  a census-features table to diff the new build against, cell by cell
#                (CHECK CW9; default the file this build replaces). Printed, never read
#                into the build.
#
# SEAT UNIVERSE per pair: its contested seats (candidacies.csv), plus the PREVIOUS
# election's seats filed under the current pair. The harnesses project each seat's
# previous primaries forward, so a division abolished at a redistribution still needs
# a row. Until 2026-10-27 only the retired builder's 25 pairs got previous-election
# rows; Pete chose (27 Oct) to extend it to all pairs. CW3b now prints nothing to add.
#
# SOURCE ORDER per (pair, seat):
#   A  the preferred census's own geography, when the pair's contested seat set
#      EQUALS that geography's seat set (boundaries match). exact = TRUE.
#   B  (state pairs in REAG_FOR, preferred census >= 2016 only) the 2016 census
#      reaggregated onto later ABS SED boundaries (census-sed-2016-reaggregated-to-
#      <year>.csv, scripts/build_census_correspondence.R): the pair's own boundary
#      year first, else the nearest other boundary year (earlier on a tie), which is
#      labelled BORROWED. Older census on (near-)election boundaries; used because
#      2021 was never reaggregated.
#   C  the preferred census, matched by seat NAME (boundaries differ: exact FALSE).
#   D  the nearest LATER census, matched by name (LOOKAHEAD).
#   F  federal only: the 2006 census on 2004 boundaries, by name.
#   (E, "the existing file's row", was removed 2026-10-25 with the base file; the
#   15 Oct file used it for no row.)
#
# FEATURE MAPPING. ABS 2011 BCP table B01 and 2006 BCP table B01 ("Selected
# Person Characteristics by Sex") carry the same 108 cells in the same order as
# the 2016/2021 G01 columns, with the same column names in 2011. 2006 columns
# are called B1..B108; they are renamed POSITIONALLY to the 2011 B01 names and
# the seven features' cells are asserted against the 2006 cell descriptions
# (BCP2006_cell_desc_dp.xls) -- see CHECK CW1. derive() is the only copy of the
# feature definitions:
#   yr12_pct        Yr 12 / (Yr 12+11+10+9+8-or-below)  B01 Highest year of school
#   born_aus_pct    Birthplace_Australia_P / Tot_P_P     B01 Birthplace
#   indig_pct       Indigenous_P_Tot_P / Tot_P_P         B01 Indigenous total
#   over55_pct      Age 55-64, 65-74, 75-84 / Tot_P_P    B01 Age groups
#   under35_pct     Age 15-19, 20-24, 25-34 / Tot_P_P    B01 Age groups
#   lang_other_pct  Lang_spoken_home_Oth_Lang_P / Tot_P_P B01 Language at home
#   edu_25plus_pct  Age_psns_att_edu_inst_25_ov_P / Tot_P_P B01 Educ. institution
#
# NO INCOME FEATURE, deliberately (carried over from the retired builder, 2026-09-12).
# The federal CED files carry income and housing medians; the state SED
# reaggregations carry none (G01 counts only: a median cannot be reaggregated by
# weighted summing). An income column would be real for federal pairs and filler for
# state pairs, which is a jurisdiction label a tree splits on (the state-deviation
# block lost 0.056 RMSE that way). To revisit: reaggregate G02 from SA1 medians.
#
# Check codes: CW.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({library(data.table); library(readxl)})

.args <- commandArgs(trailingOnly = TRUE)
.unknown <- setdiff(sub("=.*$", "", .args), c("--root", "--out", "--compare"))
if (length(.unknown)) stop("CW0! unknown argument(s): ", paste(.unknown, collapse = ", "))
.arg <- function(name, default) {
  a <- grep(sprintf("^--%s=", name), .args, value = TRUE)
  if (length(a)) sub(sprintf("^--%s=", name), "", a[length(a)]) else default
}
ROOT <- .arg("root", ".")
OUT <- file.path(ROOT, "output")                       # inputs (candidacies.csv)
OUT_DIR <- .arg("out", OUT)                            # where the table is written
COMPARE <- .arg("compare", file.path(OUT_DIR, "census-features.csv"))
CEN <- file.path(ROOT, "external/reference/census")
RAW <- file.path(ROOT, "external/reference/abs/raw")
cat(sprintf("CW0  reading inputs under %s | writing %s | comparing against %s\n",
            normalizePath(ROOT), file.path(OUT_DIR, "census-features.csv"), COMPARE))

CENSUS_DATE <- c("2006" = "2006-08-08", "2011" = "2011-08-09",
                 "2016" = "2016-08-09", "2021" = "2021-08-10")
# PUBLICATION dates (Pete 2026-10-14: only a census PUBLISHED before polling day may be used). First release of the
# General Community Profile tables these features come from. UNVERIFIED -- entered from memory, not from the ABS
# release calendar; check before relying on an election within a few weeks of one of these dates.
CENSUS_RELEASE <- c("2006" = "2007-06-27", "2011" = "2012-06-21",
                    "2016" = "2017-06-27", "2021" = "2022-06-28")
FEATS <- c("yr12_pct", "born_aus_pct", "indig_pct", "over55_pct",
           "under35_pct", "lang_other_pct", "edu_25plus_pct")
# Name a pair here to force its census year (character, e.g. c(fed2016 = "2016")).
PREF_OVERRIDE <- c(
  # nt2016 (27 Aug 2016) is 18 days AFTER census night (9 Aug 2016), but the 2016 data
  # were not published until June 2017, so they were not available to anyone forecasting
  # the election. Pete's rule is the census RELEASED before polling day: 2011.
  nt2016 = "2011",
  # qld2012 (24 Mar 2012): the 2011 census was taken 9 Aug 2011 but first published in
  # June 2012, after this election. 2006 is the latest census released before polling day.
  qld2012 = "2006")
# Pairs added 2026-10-13 (the coverage program). Their polling days are not yet in
# election_dates() on this branch, so they are given here and merged below.
NEW_DATES <- c(nsw2011 = "2011-03-26", nsw2015 = "2015-03-28", qld2012 = "2012-03-24",
               qld2015 = "2015-01-31", qld2017 = "2017-11-25", sa2010 = "2010-03-20",
               sa2014 = "2014-03-15", sa2018 = "2018-03-17", nt2016 = "2016-08-27",
               nt2020 = "2020-08-22", nt2024 = "2024-08-24")
# Live pairs whose boundaries are the predecessor's (vic2026 = vic2022, nsw2027 = nsw2023).
SAME_BOUNDS <- c(vic2026 = "vic2022", nsw2027 = "nsw2023")

# SOURCE B MAPS, moved from the retired build_census_features.R (its VINTAGE / EXACT,
# unchanged). The value is the ABS SED BOUNDARY year whose 2016-census reaggregation
# serves the pair; REAG_EXACT lists the pairs whose own boundaries that file is.
# A pair NOT named here gets no source-B row: qld2017 and sa2018 used to, through the
# retired builder's nearest-vintage fill, and were labelled "on election boundaries"
# although the file was built for another boundary year. (Checked 2026-10-25 against
# the ABS correspondences: Queensland's SED boundaries do not move 2021 -> 2025, so the
# 2021 file IS qld2017's 93 districts; South Australia's 2021 file is sa2022's, not
# sa2018's. Adding qld2017 here would move its census inputs: Pete's call.)
# ADDED 2026-10-27 (Pete: GO): qld2017 = "2021", in REAG_EXACT, for that reason.
REAG_FOR <- c(qld2017 = "2021",
              wa2021 = "2021", vic2022 = "2022", sa2022 = "2022", sa2026 = "2025",
              nsw2023 = "2022", qld2024 = "2024", wa2025 = "2025",
              vic2018 = "2021", vic2014 = "2021", nsw2019 = "2021",
              qld2020 = "2021", wa2017 = "2021", wa2013 = "2021",
              wa2008 = "2021", wa2005 = "2021", wa2001 = "2021",
              # Victoria's boundaries have not moved since the 2021 redistribution.
              vic2026 = "2022",
              # NSW 2027 keeps the 2021 redistribution's boundaries.
              nsw2027 = "2022")
REAG_EXACT <- c("qld2017", "wa2021", "vic2022", "sa2022", "nsw2023", "qld2024", "wa2025", "sa2026",
                "vic2026", "nsw2027")

.sum_cols <- function(d, cols) {
  if (!all(cols %in% names(d))) return(rep(NA_real_, nrow(d)))
  rowSums(as.matrix(d[, cols, with = FALSE]), na.rm = TRUE)
}
derive <- function(d) {
  d <- data.table::copy(d)
  sch <- c("High_yr_schl_comp_Yr_12_eq_P", "High_yr_schl_comp_Yr_11_eq_P",
           "High_yr_schl_comp_Yr_10_eq_P", "High_yr_schl_comp_Yr_9_eq_P",
           "High_yr_schl_comp_Yr_8_belw_P")
  if (!"Tot_P_P" %in% names(d)) {
    cat("CW0! Tot_P_P absent -- features will be NA\n"); tot <- rep(NA_real_, nrow(d))
  } else tot <- as.numeric(d$Tot_P_P)
  d[, yr12_pct := 100 * .sum_cols(d, sch[1]) / .sum_cols(d, sch)]
  d[, born_aus_pct := 100 * .sum_cols(d, "Birthplace_Australia_P") / tot]
  d[, indig_pct := 100 * .sum_cols(d, "Indigenous_P_Tot_P") / tot]
  d[, over55_pct := 100 * .sum_cols(d, c("Age_55_64_yr_P", "Age_65_74_yr_P",
                                         "Age_75_84_yr_P")) / tot]
  d[, under35_pct := 100 * .sum_cols(d, c("Age_15_19_yr_P", "Age_20_24_yr_P",
                                          "Age_25_34_yr_P")) / tot]
  # SED files say Lang_spoken_home_*, CED files Lang_used_home_*, for the same quantity.
  lang <- intersect(c("Lang_spoken_home_Oth_Lang_P", "Lang_used_home_Oth_Lang_P"), names(d))
  d[, lang_other_pct := if (length(lang)) 100 * .sum_cols(d, lang[1]) / tot else NA_real_]
  d[, edu_25plus_pct := 100 * .sum_cols(d, "Age_psns_att_edu_inst_25_ov_P") / tot]
  d
}

# ---- seat keys -------------------------------------------------------------
.state_sfx <- "(NSW|Vic|VIC|Qld|QLD|SA|WA|Tas|TAS|NT|ACT)"
seat_key <- function(x) {
  x <- sub("\\s*\\(CED07\\)\\s*$", "", x)
  x <- sub(paste0(",\\s*", .state_sfx, "\\s*$"), "", x)
  # The optional ")" matters: the raw 2016 SED file truncates long Victorian names
  # mid-bracket ("Narre Warren North (South Eastern Metrop"), which a closed-bracket
  # strip leaves unmatched.
  x <- trimws(sub("\\s*\\([^)]*\\)?\\s*$", "", x))
  normalise_seat(x)
}
.special <- "No usual address|Migratory|Offshore|Shipping|Other Territories|Unincorporated|Outside|Not applicable|Not Applicable"
REGION_OF <- c("1" = "nsw", "2" = "vic", "3" = "qld", "4" = "sa", "5" = "wa",
               "6" = "tas", "7" = "nt", "8" = "act")

# ---- checks, as functions so a deliberately broken table can be fed to them ----
# CW7: a note may claim the election's own boundaries only on an exact row, and an
# exact row must say which boundaries it is on. Returns the offending rows.
exact_label_violations <- function(x) {
  claims <- grepl("onto election boundaries|seat set identical", x$vintage_note)
  x[(claims & !(x$exact %in% TRUE)) | (!claims & (x$exact %in% TRUE))]
}
# CW10: a pair polled before the first census release on disk must carry no census
# value (wa2001, wa2005: empty on purpose). Returns the offending pairs.
pre_census_violations <- function(x, polling_day, first_release) {
  early <- names(polling_day)[polling_day < first_release]
  rows <- x$pair %in% early
  has <- Reduce(`|`, lapply(FEATS, function(f) is.finite(x[[f]][rows])), FALSE)
  list(early = early, bad = unique(x$pair[rows][has]))
}
# CW11: every row carrying any census value must name a census year that was PUBLISHED
# before its election's polling day. Independent of the LOOKAHEAD note text: it reads
# only vintage, the release dates and the polling dates, so a row mislabelled or missed
# by the blanking cannot pass. An unknown vintage or polling day on a valued row fails.
lookahead_violations <- function(x, polling_day, release) {
  has <- Reduce(`|`, lapply(FEATS, function(f) is.finite(x[[f]])), rep(FALSE, nrow(x)))
  rel <- as.Date(unname(release[as.character(x$vintage)]))
  pd <- as.Date(unname(polling_day[as.character(x$pair)]))
  x[has & (is.na(rel) | is.na(pd) | !(rel < pd))]
}
# CW9: cell-by-cell difference between two census-features tables, keyed on (pair, seat key).
census_diff <- function(new, old) {
  cols <- c("seat", "vintage", "exact", FEATS, "vintage_note")
  kn <- paste(new$pair, seat_key(new$seat)); ko <- paste(old$pair, seat_key(old$seat))
  only_new <- new[!kn %in% ko, .(pair, seat)]; only_old <- old[!ko %in% kn, .(pair, seat)]
  m <- match(kn, ko); i_new <- which(!is.na(m)); i_old <- m[i_new]
  cells <- rbindlist(lapply(cols, function(cl) {
    a <- new[[cl]][i_new]; b <- old[[cl]][i_old]
    if (cl %in% FEATS) {
      a <- as.numeric(a); b <- as.numeric(b)
      same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & abs(a - b) <= 1e-9 * pmax(1, abs(b)))
    } else {
      a <- as.character(a); b <- as.character(b)
      same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
    }
    j <- which(!same)
    data.table(pair = new$pair[i_new][j], seat = new$seat[i_new][j], column = rep(cl, length(j)),
               old = as.character(b[j]), new = as.character(a[j]))
  }))
  list(n_new = nrow(new), n_old = nrow(old), common = length(i_new),
       only_new = only_new, only_old = only_old, cells = cells)
}

# ---- 2011: B01 straight from the zip, names from the geog_desc sheet --------
read_2011 <- function(g) {
  z <- sprintf("%s/2011/2011_BCP_%s_for_AUST_short-header.zip", RAW, g)
  l <- unzip(z, list = TRUE)$Name
  f <- l[grepl("Census_B01_", l)]; stopifnot(length(f) == 1)
  d <- fread(cmd = sprintf('unzip -p "%s" "%s"', z, f), showProgress = FALSE)
  gf <- l[grepl("geog_desc", l)]; td <- tempfile(); dir.create(td)
  unzip(z, files = gf, exdir = td, junkpaths = TRUE)
  gd <- suppressWarnings(as.data.table(read_excel(list.files(td, full.names = TRUE)[1],
                                                  col_types = "text")))
  gd <- gd[gd$Level == g, c("Code", "Label")]
  list(d = d, names = gd)
}
# ---- 2006: B01 per state folder, positional rename to the 2011 names --------
read_2006 <- function(folder, prefix, lvl, n11) {
  fs <- list.files(file.path(RAW, "2006/bcp-cgia", folder), pattern = "_B01\\.csv$",
                   recursive = TRUE, full.names = TRUE)
  d <- rbindlist(lapply(fs, fread, showProgress = FALSE))
  stopifnot(ncol(d) == 109L, identical(names(d)[2:109], paste0("B", 1:108)))
  setnames(d, paste0("B", 1:108), n11)
  M <- file.path(RAW, "2006/metadata/Metadata")
  g06 <- suppressWarnings(as.data.table(read_excel(file.path(M, "Census2006_geog_desc.xls"),
                                                   col_types = "text")))
  list(d = d, names = g06[g06$Level == lvl, c("Code", "Label")])
}
tidy_geo <- function(d, nm, census, kind) {
  d <- merge(d, unique(nm, by = "Code"), by.x = "region_id", by.y = "Code", all.x = TRUE)
  d <- d[!is.na(d$Label) & !grepl(.special, d$Label, ignore.case = TRUE)]
  num <- suppressWarnings(as.integer(sub("^[A-Za-z]+", "", d$region_id)))
  if (kind == "sed") {
    d <- d[num %% 10000L < 9000L]              # 79494 / 99191 style codes are non-geographic
    reg <- REGION_OF[substr(as.character(num[num %% 10000L < 9000L]), 1, 1)]
  } else reg <- rep("fed", nrow(d))
  d <- derive(d)
  data.table(census = census, kind = kind, region = unname(reg),
             skey = seat_key(d$Label), label = d$Label)[, (FEATS) := d[, FEATS, with = FALSE]][]
}

z11 <- read_2011("SED"); n11 <- names(z11$d)[-1]
c11s <- read_2011("CED")
stopifnot(identical(names(c11s$d)[-1], n11))
s06 <- read_2006("SED", "SED", "SED", n11)
c06 <- read_2006("CED_2007", "CED07", "CED07", n11)
c04 <- read_2006("CED_2004", "CED", "CED", n11)   # 2006 census on 2004 boundaries (fallback only)

# CW1: the 2006 positional rename is right for every cell the seven features use.
cd <- suppressWarnings(as.data.table(read_excel(
  file.path(RAW, "2006/metadata/Metadata/BCP2006_cell_desc_dp.xls"), col_types = "text")))
cd <- cd[cd$Table == "B01"]
EXPECT <- c(Tot_P_P = "Total Persons,Persons",
            Age_15_19_yr_P = "15-19 years,Persons", Age_20_24_yr_P = "20-24 years,Persons",
            Age_25_34_yr_P = "25-34 years,Persons", Age_55_64_yr_P = "55-64 years,Persons",
            Age_65_74_yr_P = "65-74 years,Persons", Age_75_84_yr_P = "75-84 years,Persons",
            Indigenous_P_Tot_P = "Indigenous Persons: Total,Persons",
            Birthplace_Australia_P = "Birthplace:Australia,Persons",
            Lang_spoken_home_Oth_Lang_P = "Other Language,Persons",
            Age_psns_att_edu_inst_25_ov_P = "25 years and over,Persons",
            High_yr_schl_comp_Yr_12_eq_P = "Year 12 or equivalent,Persons",
            High_yr_schl_comp_Yr_11_eq_P = "Year 11 or equivalent,Persons",
            High_yr_schl_comp_Yr_10_eq_P = "Year 10 or equivalent,Persons",
            High_yr_schl_comp_Yr_9_eq_P = "Year 9 or equivalent,Persons",
            High_yr_schl_comp_Yr_8_belw_P = "Year 8 or below,Persons")
bad <- 0L
for (nm in names(EXPECT)) {
  id <- paste0("B", match(nm, n11))
  desc <- cd$Cell_desc_long[cd$Cell_Id == id]
  ok <- length(desc) == 1 && grepl(EXPECT[[nm]], desc, fixed = TRUE)
  if (!ok) { bad <- bad + 1L; cat(sprintf("CW1! %-32s -> 2006 %-5s '%s' does not match '%s'\n", nm, id, desc, EXPECT[[nm]])) }
}
stopifnot(bad == 0L)
cat(sprintf("CW1  2006 B1..B108 -> 2011 B01 names: all %d cells the features read verified against the 2006 cell descriptions\n", length(EXPECT)))
chk <- function(d, lbl) {
  ok <- all(d$Tot_P_M + d$Tot_P_F == d$Tot_P_P, na.rm = TRUE)
  cat(sprintf("CW1  %-10s rows %3d | male+female==persons: %s | summed Tot_P_P %s\n",
              lbl, nrow(d), ok, format(sum(d$Tot_P_P), big.mark = ",")))
  stopifnot(ok)
}
chk(s06$d, "SED 2006"); chk(c06$d, "CED07 2006"); chk(z11$d, "SED 2011"); chk(c11s$d, "CED 2011")

GEO <- rbindlist(list(
  tidy_geo(s06$d, s06$names, "2006", "sed"),
  tidy_geo(c06$d, c06$names, "2006", "ced"),
  tidy_geo(c04$d, c04$names, "2006", "ced04"),
  tidy_geo(z11$d, z11$names, "2011", "sed"),
  tidy_geo(c11s$d, c11s$names, "2011", "ced")))
for (v in c("2016", "2021")) {
  s <- fread(file.path(CEN, sprintf("census-sed-%s.csv", v)), showProgress = FALSE)
  s <- s[!grepl(.special, s$sed_name, ignore.case = TRUE)]
  s <- s[as.integer(sub("SED", "", s$sed_code)) %% 10000L < 9000L]
  dd <- derive(s)
  GEO <- rbind(GEO, data.table(census = v, kind = "sed",
        region = unname(REGION_OF[substr(sub("SED", "", s$sed_code), 1, 1)]),
        skey = seat_key(s$seat), label = s$seat)[, (FEATS) := dd[, FEATS, with = FALSE]][], fill = TRUE)
  cc <- fread(file.path(CEN, sprintf("census-ced-%s.csv", v)), showProgress = FALSE)
  dc <- derive(cc)
  GEO <- rbind(GEO, data.table(census = v, kind = "ced", region = "fed",
        skey = seat_key(cc$seat), label = cc$seat)[, (FEATS) := dc[, FEATS, with = FALSE]][], fill = TRUE)
  # Northern Territory (scripts/fetch_census_sed_nt.R): a separate file per vintage.
  fnt <- file.path(CEN, sprintf("census-sed-%s-nt.csv", v))
  if (file.exists(fnt)) {
    sn <- fread(fnt, showProgress = FALSE)
    sn <- sn[!grepl(.special, sn$seat, ignore.case = TRUE)]
    sn <- sn[as.integer(sub("SED", "", sn$sed_code)) %% 10000L < 9000L]
    dn <- derive(sn)
    GEO <- rbind(GEO, data.table(census = v, kind = "sed", region = "nt",
          skey = seat_key(sn$seat), label = sn$seat)[, (FEATS) := dn[, FEATS, with = FALSE]][], fill = TRUE)
  }
}
# Tas / ACT state districts are out of scope here (Hare-Clark seats are named
# after federal divisions and would collide with them).
GEO <- GEO[GEO$kind %in% c("ced", "ced04") | GEO$region %in% c("nsw", "vic", "qld", "sa", "wa", "nt")]
dupg <- GEO[, .N, by = .(census, kind, region, skey)][N > 1]
if (nrow(dupg)) { cat("CW2! duplicate geography keys, keeping first:\n"); print(dupg)
  GEO <- GEO[!duplicated(GEO[, .(census, kind, region, skey)])] }
cat("CW2  geography table: rows per census / kind (ced = federal divisions, sed = state districts)\n")
print(dcast(GEO[, .N, by = .(census, grp = ifelse(kind %in% c("ced", "ced04"), kind, paste0("sed-", region)))],
            census ~ grp, value.var = "N", fill = 0L))
# Federal counts must be the divisions: 150 in 2006/2011/2016, 151 in 2021.
stopifnot(GEO[kind == "ced" & census %in% c("2006", "2011", "2016"), .N, by = census]$N == 150L)

# ---- source B table: the 2016 census reaggregated onto later SED boundaries ----
# One row per (boundary year, state, seat). The leading digit of final_code is the
# state; seat names repeat across states (Murray, Albert Park), so the state is part
# of the key. Rows with no code (the files' non-geographic remainder) are dropped.
REAG <- rbindlist(lapply(sort(unique(REAG_FOR)), function(v) {
  f <- file.path(CEN, sprintf("census-sed-2016-reaggregated-to-%s.csv", v))
  d <- fread(f, showProgress = FALSE)
  if (!all(c("final_code", "final_name") %in% names(d))) stop("CW2! ", f, " lacks final_code / final_name")
  code <- as.character(d$final_code)
  reg <- unname(REGION_OF[substr(code, 1, 1)])
  keep <- !is.na(code) & nzchar(code) & reg %in% c("nsw", "vic", "qld", "sa", "wa")
  d <- derive(d[keep])
  data.table(bvint = v, region = reg[keep], skey = seat_key(d$final_name))[, (FEATS) := d[, FEATS, with = FALSE]][]
}))
dupr <- REAG[, .N, by = .(bvint, region, skey)][N > 1]
if (nrow(dupr)) { cat("CW2! duplicate reaggregated keys, keeping first:\n"); print(dupr)
  REAG <- REAG[!duplicated(REAG[, .(bvint, region, skey)])] }
cat("CW2  2016 census reaggregated: seats per boundary year and state\n")
print(dcast(REAG[, .N, by = .(bvint, region)], bvint ~ region, value.var = "N", fill = 0L))
# For each key, the pair's own boundary year first, else the nearest other (earlier on
# a tie) -- the retired builder's fill order, so its rows are reproduced.
reag_rows <- function(p, keys) {
  own <- REAG_FOR[[p]]
  yr <- as.integer(sub("^[a-z]+", "", p))
  rr <- REAG[REAG$region == region_of_pair[[p]]]
  vy <- as.integer(rr$bvint)
  rr <- rr[order(rr$bvint != own, abs(vy - yr), vy)]
  hit <- rr[match(keys, rr$skey)]
  hit[, own_bounds := !is.na(bvint) & bvint == own]
  hit
}

# ---- cells ------------------------------------------------------------------
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
PAIRS <- unique(c(vapply(all_election_pairs(), function(p) p$election, ""), "vic2010",
                  names(SAME_BOUNDS), names(NEW_DATES)))
.cand_keep <- CAND$election %in% PAIRS
cand_cells <- unique(data.table(pair = CAND$election[.cand_keep], seat = CAND$seat[.cand_keep]))
# Predecessor: the most recent election of the same region strictly before this one.
.el <- unique(CAND$election)
.el_reg <- sub("[0-9]{4}$", "", .el)
.el_yr <- suppressWarnings(as.integer(sub("^[a-z]+", "", .el)))
prev_of <- vapply(PAIRS, function(p) {
  ok <- .el_reg == sub("[0-9]{4}$", "", p) & is.finite(.el_yr) & .el_yr < as.integer(sub("^[a-z]+", "", p))
  if (!any(ok)) NA_character_ else .el[ok][which.max(.el_yr[ok])]
}, character(1))
# Every pair since 2026-10-27 (Pete: GO): the 12 pairs added 2026-10-13 now get their
# previous election's seats too, as the harnesses need for abolished divisions.
PRED_PAIRS <- PAIRS
prev_cells_for <- function(pp) rbindlist(lapply(pp[!is.na(prev_of[pp])], function(p)
  data.table(pair = p, seat = CAND$seat[CAND$election == prev_of[[p]]])))
cells <- unique(rbindlist(list(cand_cells, prev_cells_for(PRED_PAIRS))))
cells[, skey := seat_key(seat)]
cells <- cells[!duplicated(cells[, .(pair, skey)])]
if (!all(PAIRS %in% cells$pair)) stop("CW3! no contested seats in candidacies.csv for: ",
                                      paste(setdiff(PAIRS, cells$pair), collapse = ", "))
cat(sprintf("CW3  %d cells over %d pairs: contested seats, plus the previous election's seats for %d pairs\n",
            nrow(cells), uniqueN(cells$pair), length(PRED_PAIRS)))
# CW3b: what the other pairs would gain from the same rule (rows NOT written).
.other <- setdiff(PAIRS, PRED_PAIRS)
.gain <- prev_cells_for(.other)
if (nrow(.gain)) {
  .gain[, skey := seat_key(seat)]
  .gk <- paste(.gain$pair, .gain$skey); .ck <- paste(cells$pair, cells$skey)
  .g <- unique(.gain[!.gk %in% .ck], by = c("pair", "skey"))
  cat(sprintf("CW3b %d previous-election seats have NO row under %d of the %d other pairs (abolished at a redistribution; not added, see header):\n",
              nrow(.g), uniqueN(.g$pair), length(.other)))
  if (nrow(.g)) print(.g[, .(n = .N, seats = paste(seat, collapse = ", ")), by = pair])
}

ED <- c(election_dates(setdiff(PAIRS, names(NEW_DATES))),
        stats::setNames(as.Date(NEW_DATES), names(NEW_DATES)))[PAIRS]
region_of_pair <- sub("[0-9]{4}$", "", PAIRS); names(region_of_pair) <- PAIRS
pref_census <- function(p) {
  if (p %in% names(PREF_OVERRIDE)) return(list(y = PREF_OVERRIDE[[p]], why = "override"))
  # PUBLISHED before polling day, not merely taken (generalises the nt2016 / qld2012 overrides; flips fed2022 and
  # sa2022 to 2016 and wa2017 to 2011 under CENSUS_RELEASE as entered)
  before <- names(CENSUS_RELEASE)[as.Date(CENSUS_RELEASE) < ED[[p]]]
  if (length(before)) list(y = max(before), why = "latest census published before polling day")
  else list(y = "2006", why = "no census before polling day on disk (2001 not fetched)")
}
# LOOKAHEAD (and so blanked by blank_census_lookahead.R) when the census was PUBLISHED after polling day, not only
# taken after it: a later census matched by name for fed2022 (2021, published June 2022) was otherwise kept.
note_la <- function(y, p) if (as.Date(CENSUS_RELEASE[[y]]) > ED[[p]]) "LOOKAHEAD: " else ""

res <- list()
for (p in PAIRS) {
  greg <- region_of_pair[[p]]; gkind <- if (greg == "fed") "ced" else "sed"
  pc <- pref_census(p); y <- pc$y
  cp <- cells[cells$pair == p]
  contested <- unique(seat_key(CAND$seat[CAND$election == (if (p %in% names(SAME_BOUNDS)) SAME_BOUNDS[[p]] else p)]))
  G <- GEO[GEO$kind == gkind & GEO$region == greg, ]
  Gp <- G[G$census == y]
  exact_geo <- length(contested) > 0 && setequal(contested, Gp$skey)
  n <- nrow(cp)
  cat(sprintf("CW3a %-8s preferred census %s (%s) | contested seats %3d, geography seats %3d, in both %3d | boundaries identical: %s\n",
              p, y, pc$why, length(contested), nrow(Gp), length(intersect(contested, Gp$skey)), exact_geo))
  out <- data.table(pair = p, seat = cp$seat, vintage = NA_character_, exact = FALSE,
                    vintage_note = NA_character_)
  out[, (FEATS) := NA_real_]
  done <- rep(FALSE, n)
  put <- function(i, src, vint, ex, note) {
    if (!length(i)) return(invisible())
    for (f in FEATS) set(out, i, f, src[[f]])
    set(out, i, "vintage", vint); set(out, i, "exact", ex); set(out, i, "vintage_note", note)
    done[i] <<- TRUE
  }
  m <- match(cp$skey, Gp$skey)
  # A
  if (exact_geo) {
    i <- which(!is.na(m)); put(i, Gp[m[i]], y, TRUE,
      sprintf("%scensus %s %s, seat set identical to the election's (%d seats)", note_la(y, p), y, toupper(gkind), length(contested)))
  }
  # B (state pairs in REAG_FOR, preferred census >= 2016): 2016 census reaggregated
  if (gkind == "sed" && as.integer(y) >= 2016 && p %in% names(REAG_FOR)) {
    b <- reag_rows(p, cp$skey)
    i <- which(!done & !is.na(b$bvint) & is.finite(b$yr12_pct))
    if (length(i)) {
      own_i <- b$own_bounds[i]; ex_i <- own_i & (p %in% REAG_EXACT)
      note_i <- ifelse(ex_i,
        sprintf("census 2016 reaggregated onto election boundaries (ABS %s SED boundaries); 2021 not reaggregated, so older census on exact boundaries -- not look-ahead", b$bvint[i]),
        ifelse(own_i,
          sprintf("census 2016 reaggregated onto the ABS %s SED boundaries, matched by seat name (not recorded as this election's boundaries); 2021 not reaggregated -- not look-ahead", b$bvint[i]),
          sprintf("census 2016 reaggregated onto the ABS %s SED boundaries, BORROWED: seat not in this election's own %s reaggregation, matched by name, boundaries differ -- not look-ahead", b$bvint[i], REAG_FOR[[p]])))
      put(i, b[i], "2016", ex_i, note_i)
    }
  }
  # C
  i <- which(!done & !is.na(m))
  if (length(i)) put(i, Gp[m[i]], y, FALSE,
    sprintf("%scensus %s %s matched by seat name; boundaries differ from the election's%s", note_la(y, p), y, toupper(gkind),
            if (pc$why != "override" && !length(which(as.Date(CENSUS_DATE) < ED[[p]]))) "; no earlier census on disk" else ""))
  # D: nearest later census by name
  later <- names(CENSUS_DATE)[as.integer(names(CENSUS_DATE)) > as.integer(y)]
  for (ly in later) {
    Gl <- G[G$census == ly]; ml <- match(cp$skey, Gl$skey); i <- which(!done & !is.na(ml))
    if (length(i)) put(i, Gl[ml[i]], ly, FALSE,
      sprintf("%scensus %s %s matched by name: no match in the preferred %s census; nearest later census used", note_la(ly, p), ly, toupper(gkind), y))
  }
  # F: federal seats only in the PREVIOUS election's set (abolished at the last
  # redistribution) can live only in the 2006 census on 2004 boundaries.
  if (gkind == "ced") {
    G4 <- GEO[GEO$kind == "ced04"]; m4 <- match(cp$skey, G4$skey); i <- which(!done & !is.na(m4))
    if (length(i)) put(i, G4[m4[i]], "2006", FALSE,
      sprintf("%scensus 2006 CED on 2004 boundaries matched by name (division not in the preferred %s geography)", note_la("2006", p), y))
  }
  out[, pref := y]
  res[[p]] <- out
}
R <- rbindlist(res)
stopifnot(nrow(R) == nrow(cells), !anyDuplicated(R[, .(pair, seat)]))

# ---- summary ----------------------------------------------------------------
R[, la := grepl("^LOOKAHEAD", vintage_note)]
cat("\nCW4  per pair: preferred census, rows, vintages used, exact share, rows with NA yr12, LOOKAHEAD rows\n")
S <- R[, .(pref = pref[1], date = format(ED[[pair[1]]]), rows = .N,
           vintages = paste(sort(unique(na.omit(vintage))), collapse = "/"),
           exact = sprintf("%.0f%%", 100 * mean(exact)), na = sum(!is.finite(yr12_pct)),
           lookahead = sum(la)), by = pair]
print(S[order(pair)], nrows = 100)
cat("\nCW4a per-feature NA counts over all rows (0 = fully populated):\n")
print(vapply(FEATS, function(f) sum(!is.finite(R[[f]])), integer(1)))
if (any(vapply(FEATS, function(f) mean(is.finite(R[[f]])) == 0, logical(1)))) stop("CW4! a feature is 100% empty")
cat("\nCW4b how rows were sourced (note text prefix):\n")
print(R[, .N, by = .(src = sub("\\d{4}", "YYYY", substr(vintage_note, 1, 60)))][order(-N)])

cat("\nCW5  PROOF OF VINTAGE CHOICE: polling day against census day (every fallback is flagged)\n")
for (p in c("fed2007", "vic2010", "nsw2019", "fed2016", "nsw2011", "qld2012", "nt2016", "nt2024")) {
  y <- unique(R$pref[R$pair == p])
  cat(sprintf("CW5  %-8s polling day %s | census used %s taken %s | census before election: %s\n",
              p, format(ED[[p]]), y, CENSUS_DATE[[y]], as.Date(CENSUS_DATE[[y]]) < ED[[p]]))
}

OUTCOLS <- c("pair", "seat", "vintage", "exact", FEATS, "vintage_note")
# No census taken after polling day reaches the model (Pete, 2026-10-14): LOOKAHEAD rows are blanked.
source(file.path("scripts", "blank_census_lookahead.R"))
R <- blank_census_lookahead(R, "this build")

v7 <- exact_label_violations(R)
cat(sprintf("CW7  rows whose note and exact flag disagree about the election's boundaries: %d (expect 0)\n", nrow(v7)))
if (nrow(v7)) { print(v7[, .(pair, seat, exact, vintage_note)]); stop("CW7! boundary label and exact flag disagree") }
v10 <- pre_census_violations(R, ED, min(as.Date(CENSUS_RELEASE)))
cat(sprintf("CW10 pairs polled before the first census release on disk (%s): %s | carrying a census value: %s (expect none)\n",
            min(CENSUS_RELEASE), paste(v10$early, collapse = ", "),
            if (length(v10$bad)) paste(v10$bad, collapse = ", ") else "none"))
if (length(v10$bad)) stop("CW10! a pair polled before any census was published carries census values: ",
                          paste(v10$bad, collapse = ", "))
v11 <- lookahead_violations(R, ED, CENSUS_RELEASE)
cat(sprintf("CW11 rows with census values: %d | of those, census not published before polling day (or year/date unknown): %d (expect 0)\n",
            sum(Reduce(`|`, lapply(FEATS, function(f) is.finite(R[[f]])), rep(FALSE, nrow(R)))), nrow(v11)))
if (nrow(v11)) { print(v11[, .(pair, seat, vintage, vintage_note)], nrows = 50)
  stop("CW11! census values from a census published after polling day") }

# CW9: what this build changes against the table it replaces (or --compare).
if (file.exists(COMPARE)) {
  dd <- census_diff(R[, OUTCOLS, with = FALSE], fread(COMPARE, showProgress = FALSE))
  cat(sprintf("\nCW9  against %s: rows %d (was %d), %d matched by (pair, seat), %d only in the new build, %d only in the old\n",
              COMPARE, dd$n_new, dd$n_old, dd$common, nrow(dd$only_new), nrow(dd$only_old)))
  if (nrow(dd$only_new)) print(dd$only_new[, .(n = .N, seats = paste(seat, collapse = ", ")), by = pair])
  if (nrow(dd$only_old)) print(dd$only_old[, .(n = .N, seats = paste(seat, collapse = ", ")), by = pair])
  cat(sprintf("CW9  cells that differ: %d\n", nrow(dd$cells)))
  if (nrow(dd$cells)) {
    print(dcast(dd$cells[, .N, by = .(pair, column)], pair ~ column, value.var = "N", fill = 0L), nrows = 100)
    nn <- dd$cells[dd$cells$column != "vintage_note"]
    cat(sprintf("CW9  every differing cell outside vintage_note (%d):\n", nrow(nn)))
    if (nrow(nn)) print(nn, nrows = 500)
    cat("CW9  vintage_note changes, old -> new text (pair counts):\n")
    print(dd$cells[dd$cells$column == "vintage_note", .N, by = .(pair, old = substr(old, 1, 70), new = substr(new, 1, 90))], nrows = 100)
  }
} else cat(sprintf("\nCW9  no table at %s to compare against\n", COMPARE))

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
fwrite(R[, OUTCOLS, with = FALSE], file.path(OUT_DIR, "census-features.csv"))
cat(sprintf("\nCW8  wrote %s (%d rows, %d pairs)\n", file.path(OUT_DIR, "census-features.csv"), nrow(R), uniqueN(R$pair)))
