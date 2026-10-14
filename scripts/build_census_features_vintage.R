# Census features with the vintage that PRECEDES each election (no look-ahead).
#
# WHY. scripts/build_census_features.R gives every older pair a 2016 or 2021
# census: fed2007-fed2016 take census-ced-2016, and every pre-2022 state pair
# takes a "2021"-labelled SED file that is in fact the 2016 census
# (census-sed-2016-reaggregated-to-X.csv; the label is the BOUNDARY year, the
# data are 2016 -- national Tot_P_P 21,197,487 against 21,197,492 in the raw
# 2016 SED file, 24.2M in the 2021 one). AUSPOL_DEMO_RESID=2 reads all seven
# columns, so its backtest gain on pre-2016 pairs includes look-ahead.
#
# RULE (Pete, 2026-10-13): census taken BEFORE the election. 2006 census
# (8 Aug 2006) for elections 2007-2010, 2011 (9 Aug 2011) for 2011-2015, 2016
# (9 Aug 2016) for 2016-2020, 2021 (10 Aug 2021) after. Applied by DATE, not by
# year, so fed2016 (2 Jul 2016, five weeks BEFORE the 2016 census) takes 2011
# and wa2021 (13 Mar 2021) takes 2016. Flip a pair with PREF_OVERRIDE below.
# Elections before the 2006 census (wa2001, wa2005) have no earlier census on
# disk (2001 not fetched): they take 2006 and are flagged LOOKAHEAD.
#
# WRITES output/census-features-vintage.csv: pair, seat, vintage, exact, the 7
# features, vintage_note. `vintage` is the CENSUS YEAR OF THE DATA (the old file's
# state `vintage` was a boundary year). exact = the census geography's boundaries
# equal the election's (seat sets identical) or, for borrowed reaggregated rows,
# the old file's flag. vintage_note starts with LOOKAHEAD when the census
# post-dates the election, so no row carries look-ahead silently.
#
# SOURCE ORDER per (pair, seat):
#   A  the preferred census's own geography, when the pair's contested seat set
#      EQUALS that geography's seat set (boundaries match). exact = TRUE.
#   B  (state pairs, preferred census >= 2016 only) the existing file's row:
#      2016 census reaggregated onto the election's boundaries. Older census on
#      the right boundaries; used because 2021 was never reaggregated.
#   C  the preferred census, matched by seat NAME (boundaries differ: exact FALSE).
#   D  the nearest LATER census, matched by name (LOOKAHEAD).
#   E  the existing file's row (LOOKAHEAD when its census post-dates the election).
#
# FEATURE MAPPING. ABS 2011 BCP table B01 and 2006 BCP table B01 ("Selected
# Person Characteristics by Sex") carry the same 108 cells in the same order as
# the 2016/2021 G01 columns the old script uses, with the same column names in
# 2011. 2006 columns are called B1..B108; they are renamed POSITIONALLY to the
# 2011 B01 names and the seven features' cells are asserted against the 2006
# cell descriptions (BCP2006_cell_desc_dp.xls) -- see CHECK CW1. derive() is a
# verbatim copy of build_census_features.R's, so definitions cannot drift:
#   yr12_pct        Yr 12 / (Yr 12+11+10+9+8-or-below)  B01 Highest year of school
#   born_aus_pct    Birthplace_Australia_P / Tot_P_P     B01 Birthplace
#   indig_pct       Indigenous_P_Tot_P / Tot_P_P         B01 Indigenous total
#   over55_pct      Age 55-64, 65-74, 75-84 / Tot_P_P    B01 Age groups
#   under35_pct     Age 15-19, 20-24, 25-34 / Tot_P_P    B01 Age groups
#   lang_other_pct  Lang_spoken_home_Oth_Lang_P / Tot_P_P B01 Language at home
#   edu_25plus_pct  Age_psns_att_edu_inst_25_ov_P / Tot_P_P B01 Educ. institution
#
# Check codes: CW. Does not edit or read-write any existing output.
options(auspol.root = normalizePath("."))
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages({library(data.table); library(readxl)})

OUT <- "output"; CEN <- "external/reference/census"
RAW <- "external/reference/abs/raw"
CENSUS_DATE <- c("2006" = "2006-08-08", "2011" = "2011-08-09",
                 "2016" = "2016-08-09", "2021" = "2021-08-10")
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
# Live pairs whose boundaries are the predecessor's (documented in
# build_census_features.R: vic2026 = vic2022, nsw2027 = nsw2023).
SAME_BOUNDS <- c(vic2026 = "vic2022", nsw2027 = "nsw2023")

# ---- verbatim from scripts/build_census_features.R ------------------------
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
# Tas / ACT / NT state districts are out of scope here (Hare-Clark seats are named
# after federal divisions and would collide with them); mainland states only.
GEO <- GEO[GEO$kind %in% c("ced", "ced04") | GEO$region %in% c("nsw", "vic", "qld", "sa", "wa", "nt")]
dupg <- GEO[, .N, by = .(census, kind, region, skey)][N > 1]
if (nrow(dupg)) { cat("CW2! duplicate geography keys, keeping first:\n"); print(dupg)
  GEO <- GEO[!duplicated(GEO[, .(census, kind, region, skey)])] }
cat("CW2  geography table: rows per census / kind (ced = federal divisions, sed = state districts)\n")
print(dcast(GEO[, .N, by = .(census, grp = ifelse(kind %in% c("ced", "ced04"), kind, paste0("sed-", region)))],
            census ~ grp, value.var = "N", fill = 0L))
# Federal counts must be the divisions: 150 in 2006/2011/2016, 151 in 2021.
stopifnot(GEO[kind == "ced" & census %in% c("2006", "2011", "2016"), .N, by = census]$N == 150L)

# ---- cells and the old file -------------------------------------------------
OLD <- fread(file.path(OUT, "census-features.csv"), showProgress = FALSE)
CAND <- fread(file.path(OUT, "candidacies.csv"), showProgress = FALSE)
PAIRS <- unique(c(vapply(all_election_pairs(), function(p) p$election, ""), "vic2010",
                  unique(OLD$pair), names(NEW_DATES)))
cells <- unique(rbindlist(list(
  OLD[, .(pair, seat)],
  unique(data.table(pair = CAND$election, seat = CAND$seat))[pair %in% PAIRS])))
cells <- cells[pair %in% PAIRS]
cells[, skey := seat_key(seat)]
cells <- cells[!duplicated(cells[, .(pair, skey)])]
OLD[, skey := seat_key(seat)]
OLD[, real_census := ifelse(grepl("^(vic|nsw|qld|sa|wa)", pair), "2016", as.character(vintage))]
cat(sprintf("CW3  %d cells over %d pairs (old file: %d cells, %d pairs; vic2010 new)\n",
            nrow(cells), uniqueN(cells$pair), nrow(OLD), uniqueN(OLD$pair)))

ED <- c(election_dates(setdiff(PAIRS, names(NEW_DATES))),
        stats::setNames(as.Date(NEW_DATES), names(NEW_DATES)))[PAIRS]
region_of_pair <- sub("[0-9]{4}$", "", PAIRS); names(region_of_pair) <- PAIRS
pref_census <- function(p) {
  if (p %in% names(PREF_OVERRIDE)) return(list(y = PREF_OVERRIDE[[p]], why = "override"))
  before <- names(CENSUS_DATE)[as.Date(CENSUS_DATE) < ED[[p]]]
  if (length(before)) list(y = max(before), why = "latest census taken before polling day")
  else list(y = "2006", why = "no census before polling day on disk (2001 not fetched)")
}
note_la <- function(y, p) if (as.Date(CENSUS_DATE[[y]]) > ED[[p]]) "LOOKAHEAD: " else ""

res <- list()
for (p in PAIRS) {
  greg <- region_of_pair[[p]]; gkind <- if (greg == "fed") "ced" else "sed"
  pc <- pref_census(p); y <- pc$y
  cp <- cells[cells$pair == p]
  contested <- unique(seat_key(CAND$seat[CAND$election == (if (p %in% names(SAME_BOUNDS)) SAME_BOUNDS[[p]] else p)]))
  G <- GEO[GEO$kind == gkind & GEO$region == greg, ]
  Gp <- G[G$census == y]
  exact_geo <- length(contested) > 0 && setequal(contested, Gp$skey)
  o <- OLD[OLD$pair == p]
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
  # B (state pairs, preferred census >= 2016): existing 2016-census reaggregated row
  if (gkind == "sed" && as.integer(y) >= 2016) {
    mo <- match(cp$skey, o$skey); i <- which(!done & !is.na(mo) & is.finite(o$yr12_pct[mo]))
    if (length(i)) put(i, o[mo[i]], "2016", o$exact[mo[i]],
      sprintf("census 2016 reaggregated onto election boundaries (existing file, old label %s); 2021 not reaggregated, so older census on exact boundaries -- not look-ahead", o$vintage[mo[i]]))
  }
  # C
  i <- which(!done & !is.na(m))
  if (length(i)) put(i, Gp[m[i]], y, FALSE,
    sprintf("%scensus %s %s matched by seat name; boundaries differ from the election's%s", note_la(y, p), y, toupper(gkind),
            if (pc$why != "override" && !length(which(as.Date(CENSUS_DATE) < ED[[p]]))) "; no earlier census on disk" else ""))
  # D: nearest later census by name
  later <- setdiff(names(CENSUS_DATE)[as.integer(names(CENSUS_DATE)) > as.integer(y)], character())
  for (ly in later) {
    Gl <- G[G$census == ly]; ml <- match(cp$skey, Gl$skey); i <- which(!done & !is.na(ml))
    if (length(i)) put(i, Gl[ml[i]], ly, FALSE,
      sprintf("%scensus %s %s matched by name: no match in the preferred %s census; nearest later census used", note_la(ly, p), ly, toupper(gkind), y))
  }
  # E: existing row
  mo <- match(cp$skey, o$skey); i <- which(!done & !is.na(mo) & is.finite(o$yr12_pct[mo]))
  if (length(i)) put(i, o[mo[i]], o$real_census[mo[i]], FALSE,
    sprintf("%sexisting census-features.csv row (census %s, old label %s); no census %s match",
            vapply(o$real_census[mo[i]], function(v) note_la(v, p), ""), o$real_census[mo[i]], o$vintage[mo[i]], y))
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

# ---- validation vs the old file ----------------------------------------------
cat("\nCW5  PROOF OF VINTAGE CHOICE: polling day against census day (3 pairs, plus every fallback is flagged)\n")
for (p in c("fed2007", "vic2010", "nsw2019", "fed2016", "nsw2011", "qld2012", "nt2016", "nt2024")) {
  y <- unique(R$pref[R$pair == p])
  cat(sprintf("CW5  %-8s polling day %s | census used %s taken %s | census before election: %s\n",
              p, format(ED[[p]]), y, CENSUS_DATE[[y]], as.Date(CENSUS_DATE[[y]]) < ED[[p]]))
}
cat("CW5  rows by vintage actually used, against the old file's real census year:\n")
cmp <- merge(R[, c("pair", "seat", "vintage", FEATS), with = FALSE][, skey := seat_key(seat)],
             OLD[, c("pair", "skey", "real_census", FEATS), with = FALSE],
             by = c("pair", "skey"), suffixes = c("", "_old"))
print(cmp[, .(rows = .N, new = paste(sort(unique(vintage)), collapse = "/"),
              old = paste(sort(unique(real_census)), collapse = "/"),
              changed_vintage = sum(vintage != real_census, na.rm = TRUE)), by = pair][order(pair)])
chg <- cmp[!is.na(real_census) & !is.na(vintage) & vintage != real_census & is.finite(yr12_pct) & is.finite(yr12_pct_old)]
cat(sprintf("\nCW6  where the census year changed (n = %d rows): per pair, correlation new vs old and mean (new - old)\n", nrow(chg)))
cat("CW6  correlation near 1 = same ranking of seats; mean difference in percentage points (new minus old)\n")
corr_tab <- rbindlist(lapply(FEATS, function(f) {
  chg[, {
    a <- get(f); b <- get(paste0(f, "_old")); ok <- is.finite(a) & is.finite(b)
    .(feature = f, n = sum(ok), r = if (sum(ok) > 3) round(cor(a[ok], b[ok]), 3) else NA_real_,
      mean_diff = round(mean(a[ok] - b[ok]), 2))
  }, by = pair]
}))
print(dcast(corr_tab, pair ~ feature, value.var = "r")[order(pair)], nrows = 100)
print(dcast(corr_tab, pair ~ feature, value.var = "mean_diff")[order(pair)], nrows = 100)
cat("\nCW6  pooled over changed rows, per feature:\n")
print(rbindlist(lapply(FEATS, function(f) {
  a <- chg[[f]]; b <- chg[[paste0(f, "_old")]]; ok <- is.finite(a) & is.finite(b)
  data.table(feature = f, n = sum(ok), r = round(cor(a[ok], b[ok]), 3),
             mean_diff = round(mean(a[ok] - b[ok]), 2), sd_diff = round(sd(a[ok] - b[ok]), 2))
})))
# CW7: identical rows are suspicious if the census changed (an old row copied as new).
same <- chg[, Reduce(`&`, lapply(FEATS, function(f) abs(get(f) - get(paste0(f, "_old"))) < 1e-9))]
cat(sprintf("CW7  rows whose census year changed but whose features are byte-equal to the old row: %d (expect 0)\n", sum(same, na.rm = TRUE)))

OUTCOLS <- c("pair", "seat", "vintage", "exact", FEATS, "vintage_note")
# No census taken after polling day reaches the model (Pete, 2026-10-14): LOOKAHEAD rows are blanked.
source(file.path("scripts", "blank_census_lookahead.R"))
R <- blank_census_lookahead(R, "this build")
# AFTER THE SWAP, output/census-features.csv IS the vintage file, so OLD above is no longer
# the pre-vintage file and source B (reaggregated rows) would re-derive the existing pairs
# from already-vintaged rows. AUSPOL_CENSUS_VINTAGE_BASE names a copy of the vintage file
# as it stood: its pairs are kept VERBATIM and only pairs absent from it are taken from R.
BASE_F <- Sys.getenv("AUSPOL_CENSUS_VINTAGE_BASE", "")
if (nzchar(BASE_F)) {
  BASE <- fread(BASE_F, showProgress = FALSE)
  add <- R[!pair %in% BASE$pair, OUTCOLS, with = FALSE]
  cat(sprintf("CW9  base %s: %d rows, %d pairs kept verbatim; %d rows for %d new pairs taken from this build\n",
              BASE_F, nrow(BASE), uniqueN(BASE$pair), nrow(add), uniqueN(add$pair)))
  # Textual append: the base file's bytes are copied as they are, never re-serialised.
  file.copy(BASE_F, file.path(OUT, "census-features-vintage.csv"), overwrite = TRUE)
  fwrite(add, file.path(OUT, "census-features-vintage.csv"), append = TRUE, col.names = FALSE)
  R <- rbind(BASE[, OUTCOLS, with = FALSE], add)
} else fwrite(R[, OUTCOLS, with = FALSE], file.path(OUT, "census-features-vintage.csv"))
# The rows for the pairs added 2026-10-13, on their own, for merging into a main
# checkout whose census-features-vintage.csv has the older pairs.
fwrite(R[pair %in% names(NEW_DATES), c("pair", "seat", "vintage", "exact", FEATS, "vintage_note"), with = FALSE],
       file.path(OUT, "census-features-vintage-newpairs.csv"))
cat(sprintf("\nCW8  wrote %s/census-features-vintage.csv (%d rows)\n", OUT, nrow(R)))
